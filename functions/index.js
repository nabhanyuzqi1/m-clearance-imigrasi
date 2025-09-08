const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Admin SDK exactly once
admin.initializeApp();

const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

/**
 * onAuth user create
 * - Create users/{uid} doc if absent with initial fields aligned to app schema
 * - Idempotent updates when doc already exists
 * - If email is already verified, set isEmailVerified=true and status=pending_documents once
 */
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const email = user.email || "";
  console.log("[onUserCreate] uid:", uid, "emailVerified:", !!user.emailVerified);

  // Best-effort to assign default role via custom claims; swallow errors to avoid retries
  try {
    await admin.auth().setCustomUserClaims(uid, { role: "user" });
  } catch (e) {
    console.error("[onUserCreate] setCustomUserClaims failed:", e);
  }

  const userRef = db.collection("users").doc(uid);

  try {
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(userRef);
      const now = FieldValue.serverTimestamp();

      if (!snap.exists) {
        const verified = !!user.emailVerified;
        const initDoc = {
          email,
          uid,
          role: "user",
          status: verified ? "pending_documents" : "pending_email_verification",
          isEmailVerified: verified,
          hasUploadedDocuments: false,
          documents: [],
          createdAt: now,
          updatedAt: now,
        };
        txn.set(userRef, initDoc);
        console.log("[onUserCreate] Created user doc:", uid);
        return;
      }

      // If doc exists, only update fields once and keep idempotent behavior
      const data = snap.data() || {};
      const updates = {};

      // Ensure required fields exist without flipping user-defined values
      if (typeof data.email !== "string") updates.email = email;
      if (typeof data.uid !== "string") updates.uid = uid;
      if (!data.role) updates.role = "user";
      if (typeof data.hasUploadedDocuments !== "boolean") updates.hasUploadedDocuments = false;
      if (!Array.isArray(data.documents)) updates.documents = [];

      // If email already verified in Auth and not yet reflected in Firestore, set once
      if (user.emailVerified && data.isEmailVerified !== true) {
        updates.isEmailVerified = true;
        const currentStatus = data.status || "pending_email_verification";
        if (currentStatus === "pending_email_verification") {
          updates.status = "pending_documents";
        }
      }

      // createdAt should be set if missing
      if (!data.createdAt) updates.createdAt = now;

      if (Object.keys(updates).length > 0) {
        updates.updatedAt = now;
        txn.update(userRef, updates);
        console.log("[onUserCreate] Updated existing user doc:", uid, updates);
      } else {
        console.log("[onUserCreate] No-op for existing user doc:", uid);
      }
    });
  } catch (error) {
    console.error("[onUserCreate] Error:", error);
  }
});

/**
 * onUserDocUpdate status/queue sync
 * - When user uploads documents or moves pending_documents -> pending_approval:
 *     * Ensure status becomes pending_approval once (from pending_documents)
 *     * Enqueue a review item (reviewQueue) idempotently
 * - When status transitions to approved/rejected:
 *     * Create a notification item under notifications/{uid}/items idempotently
 */
exports.onUserDocUpdate = functions.firestore
  .document("users/{uid}")
  .onUpdate(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const userRef = change.after.ref;

    const beforeStatus = before.status || "pending_email_verification";
    const afterStatus = after.status || "pending_email_verification";
    const email = after.email || before.email || "";

    const becameApproved = beforeStatus !== "approved" && afterStatus === "approved";
    const becameRejected = beforeStatus !== "rejected" && afterStatus === "rejected";
    const hasDocsNowTrue = before.hasUploadedDocuments !== true && after.hasUploadedDocuments === true;
    const movedToPendingApproval = beforeStatus === "pending_documents" && afterStatus === "pending_approval";
    const shouldEnforcePendingApproval =
      beforeStatus === "pending_documents" && (hasDocsNowTrue || afterStatus === "pending_approval");

    // Helper to read a stable updatedAt millisecond value for dedupe IDs
    const getUpdatedAtMillis = () => {
      const ts = after.updatedAt;
      if (ts && typeof ts.toMillis === "function") {
        return ts.toMillis();
      }
      // Fallback to server time to avoid undefined, still reasonably idempotent per update
      return Date.now();
    };

    try {
      // 1) Enforce pending_approval when first documents uploaded or client indicates transition
      if (shouldEnforcePendingApproval && afterStatus !== "pending_approval") {
        await db.runTransaction(async (txn) => {
          const snap = await txn.get(userRef);
          const cur = snap.data() || {};
          const curStatus = cur.status || "pending_email_verification";
          if (curStatus === "pending_documents") {
            txn.update(userRef, {
              status: "pending_approval",
              updatedAt: FieldValue.serverTimestamp(),
            });
            console.log("[onUserDocUpdate] Enforced pending_approval for uid:", uid);
          } else {
            console.log("[onUserDocUpdate] Skipped enforcement; current status:", curStatus);
          }
        });
      }

      // 2) Enqueue review item idempotently
      if (hasDocsNowTrue || movedToPendingApproval) {
        const submittedAtMs = getUpdatedAtMillis();
        const reviewId = `${uid}_${submittedAtMs}`;
        const reviewRef = db.collection("reviewQueue").doc(reviewId);
        const exists = await reviewRef.get();
        if (!exists.exists) {
          await reviewRef.set({
            uid,
            email,
            submittedAt: Timestamp.fromMillis(submittedAtMs),
          });
          console.log("[onUserDocUpdate] Enqueued review item:", reviewId);
        } else {
          console.log("[onUserDocUpdate] Review item already exists:", reviewId);
        }
      }

      // 3) Notifications on terminal decision transitions (approved/rejected)
      if (becameApproved || becameRejected) {
        const statusType = becameApproved ? "approved" : "rejected";
        const message =
          statusType === "approved"
            ? "Your account has been approved."
            : "Your account has been rejected.";
        const decidedAtMs = getUpdatedAtMillis();
        const notifId = `${statusType}_${decidedAtMs}`;
        const notifRef = db.collection("notifications").doc(uid).collection("items").doc(notifId);

        const notifSnap = await notifRef.get();
        if (!notifSnap.exists) {
          await notifRef.set({
            type: statusType,
            message,
            createdAt: Timestamp.fromMillis(decidedAtMs),
          });
          console.log("[onUserDocUpdate] Created notification:", notifId);
        } else {
          console.log("[onUserDocUpdate] Notification already exists:", notifId);
        }
      }
    } catch (error) {
      console.error("[onUserDocUpdate] Error:", error);
    }
  });

/**
 * onStorage finalize (optional safety net)
 * - If object path matches users/{uid}/documents/... OR documents/{uid}/...
 *   append a document reference to users/{uid}.documents
 * - Idempotent based on storagePath (gs://bucket/name) or file name
 * - Does NOT modify status; only appends to documents if not already present
 */
exports.onDocumentFinalize = functions.storage.object().onFinalize(async (object) => {
  try {
    const name = object.name; // e.g., "users/<uid>/documents/<filename>"
    const bucket = object.bucket;

    if (!name || !bucket) {
      console.log("[onDocumentFinalize] Missing object name or bucket, skipping.");
      return;
    }

    const parts = name.split("/");
    let uid = null;
    let filename = parts[parts.length - 1] || "document";

    // Support either "users/{uid}/documents/..." or "documents/{uid}/..."
    if (parts.length >= 4 && parts[0] === "users" && parts[2] === "documents") {
      uid = parts[1];
    } else if (parts.length >= 2 && parts[0] === "documents") {
      uid = parts[1];
    }

    if (!uid) {
      console.log("[onDocumentFinalize] Object path is not a recognized user document path:", name);
      return;
    }

    const storagePath = `gs://${bucket}/${name}`;
    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (txn) => {
      const snap = await txn.get(userRef);
      if (!snap.exists) {
        console.warn("[onDocumentFinalize] User doc not found for uid:", uid);
        return;
      }

      const data = snap.data() || {};
      const docs = Array.isArray(data.documents) ? data.documents : [];

      const alreadyPresent = docs.some((d) => {
        if (!d || typeof d !== "object") return false;
        return d.storagePath === storagePath || d.documentName === filename;
      });

      if (alreadyPresent) {
        console.log("[onDocumentFinalize] Document already recorded for uid:", uid, storagePath);
        return;
      }

      // Use object.timeCreated to keep uploadedAt deterministic for idempotency
      const uploadedAt =
        object.timeCreated
          ? Timestamp.fromDate(new Date(object.timeCreated))
          : FieldValue.serverTimestamp();

      const entry = {
        documentName: filename,
        storagePath: storagePath,
        uploadedAt: uploadedAt,
      };

      // Append without touching status; do not mutate updatedAt here to avoid unintended triggers
      txn.update(userRef, {
        documents: FieldValue.arrayUnion(entry),
      });

      console.log("[onDocumentFinalize] Appended document entry for uid:", uid, entry);
    });
  } catch (error) {
    console.error("[onDocumentFinalize] Error:", error);
  }
});