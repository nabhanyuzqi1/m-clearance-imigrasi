const functions = require("firebase-functions");
const admin = require("firebase-admin");

// Initialize Admin SDK exactly once
admin.initializeApp();

const db = admin.firestore(admin.app(), 'm-clearance-imigrasi-db');
const { FieldValue, Timestamp } = admin.firestore;

// Helpers
function requireAuth(context) {
  if (!context.auth) {
    const err = new functions.https.HttpsError(
      'unauthenticated',
      'Authentication required.'
    );
    throw err;
  }
}

function callerRole(context) {
  return (context.auth && context.auth.token && context.auth.token.role) || 'user';
}

function ensureOfficerOrAdmin(context) {
  const role = callerRole(context);
  if (role !== 'officer' && role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Officer or admin role required.');
  }
}

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
  .database('m-clearance-imigrasi-db')
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

/**
 * setUserRole (callable)
 * Admin-only function to assign a custom role (user|officer|admin) to a target user.
 * - Updates Firebase Auth custom claims
 * - Mirrors the role to Firestore users/{uid}.role and updates updatedAt
 */
exports.setUserRole = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const role = callerRole(context);
  if (role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin role required.');
  }

  const targetUid = (data && data.uid) || '';
  const newRole = (data && data.role) || '';
  if (!targetUid || !['user', 'officer', 'admin'].includes(newRole)) {
    throw new functions.https.HttpsError('invalid-argument', 'Provide uid and role in [user|officer|admin].');
  }

  await admin.auth().setCustomUserClaims(targetUid, { role: newRole });

  const userRef = db.collection('users').doc(targetUid);
  const now = FieldValue.serverTimestamp();
  await userRef.set({ role: newRole, updatedAt: now }, { merge: true });

  return { ok: true, uid: targetUid, role: newRole };
});

/**
 * officerDecideAccount (callable)
 * Officer/Admin decision on a user account pending approval.
 * Input: { targetUid: string, decision: 'approved'|'rejected', note?: string }
 * Effect: updates users/{uid}.status and updatedAt. Optionally stores decidedBy/note metadata.
 * onUserDocUpdate will generate notifications.
 */
exports.officerDecideAccount = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  ensureOfficerOrAdmin(context);

  const targetUid = (data && data.targetUid) || '';
  const decision = (data && data.decision) || '';
  const note = (data && data.note) || '';

  if (!targetUid || !['approved', 'rejected'].includes(decision)) {
    throw new functions.https.HttpsError('invalid-argument', 'Provide targetUid and decision in [approved|rejected].');
  }

  const callerUid = context.auth.uid;
  const callerEmail = (context.auth.token && context.auth.token.email) || '';
  const userRef = db.collection('users').doc(targetUid);

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'User document not found.');
    }
    const data = snap.data() || {};
    const status = data.status || 'pending_email_verification';
    if (status !== 'pending_approval') {
      throw new functions.https.HttpsError('failed-precondition', `User status must be pending_approval. Got: ${status}`);
    }

    const updates = {
      status: decision,
      updatedAt: FieldValue.serverTimestamp(),
      decidedBy: callerEmail || callerUid,
    };
    if (note && typeof note === 'string' && note.length <= 1000) {
      updates.decisionNote = note;
    }
    txn.update(userRef, updates);
  });

  return { ok: true, uid: targetUid, status: decision };
});

/**
 * getOfficerDashboardStats (callable)
 * Returns lightweight counts for officer dashboard cards.
 * - pendingAccounts: users with status == 'pending_approval'
 * - approvedToday: users moved to approved since midnight UTC
 * - rejectedToday: users moved to rejected since midnight UTC
 * - pendingArrival/pendingDeparture: applications awaiting review by type
 */
exports.getOfficerDashboardStats = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  ensureOfficerOrAdmin(context);

  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);

  // Helper to count a query without loading all docs (no count() aggregation in v8 Admin SDK)
  async function countQuery(q) {
    const snap = await q.select(admin.firestore.FieldPath.documentId()).get();
    return snap.size;
  }

  const usersCol = db.collection('users');
  const applicationsCol = db.collection('applications');

  const [
    pendingAccounts,
    approvedToday,
    rejectedToday,
    pendingArrival,
    pendingDeparture,
  ] = await Promise.all([
    countQuery(usersCol.where('status', '==', 'pending_approval')),
    countQuery(usersCol.where('status', '==', 'approved').where('updatedAt', '>=', Timestamp.fromDate(startOfDay))),
    countQuery(usersCol.where('status', '==', 'rejected').where('updatedAt', '>=', Timestamp.fromDate(startOfDay))),
    countQuery(applicationsCol.where('type', '==', 'arrival').where('status', '==', 'waiting')),
    countQuery(applicationsCol.where('type', '==', 'departure').where('status', '==', 'waiting')),
  ]);

  return {
    pendingAccounts,
    approvedToday,
    rejectedToday,
    pendingArrival,
    pendingDeparture,
  };
});

/**
 * issueEmailVerificationCode (callable)
 * Generates a short-lived 4-digit code for email verification and stores it on users/{uid}.
 * Optionally integrate with email provider; for now we only store and return masked info.
 */
exports.issueEmailVerificationCode = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const uid = context.auth.uid;
  const userRef = db.collection('users').doc(uid);

  // Generate a 4-digit code (0000-9999) as a string with leading zeros
  const raw = Math.floor(Math.random() * 10000);
  const code = raw.toString().padStart(4, '0');
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(now.toMillis() + 10 * 60 * 1000); // 10 minutes

  await userRef.set({
    verification: {
      code,
      issuedAt: now,
      expiresAt,
      attempts: 0,
    },
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('[issueEmailVerificationCode] uid:', uid, 'code:', code);
  // In production, send the code via email here.
  return { ok: true };
});

/**
 * verifyEmailCode (callable)
 * Validates a submitted 4-digit code, marks Firebase Auth emailVerified=true,
 * and updates Firestore (isEmailVerified and status transition).
 */
exports.verifyEmailCode = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const uid = context.auth.uid;
  const submitted = (data && data.code) ? String(data.code) : '';
  if (!/^\d{4}$/.test(submitted)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid code format.');
  }

  const userRef = db.collection('users').doc(uid);
  const snap = await userRef.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'User document not found.');
  }
  const doc = snap.data() || {};
  const ver = doc.verification || {};
  const code = ver.code || '';
  const expiresAt = ver.expiresAt;

  if (!code || code !== submitted) {
    // increment attempts to allow rate limiting if needed
    await userRef.set({ verification: { attempts: (ver.attempts || 0) + 1 } }, { merge: true });
    throw new functions.https.HttpsError('permission-denied', 'Incorrect code.');
  }
  if (expiresAt && typeof expiresAt.toMillis === 'function') {
    if (Timestamp.now().toMillis() > expiresAt.toMillis()) {
      throw new functions.https.HttpsError('deadline-exceeded', 'Code expired.');
    }
  }

  // Mark Auth user as emailVerified = true
  await admin.auth().updateUser(uid, { emailVerified: true });

  // Reflect in Firestore and transition status once
  const updates = {
    isEmailVerified: true,
    updatedAt: FieldValue.serverTimestamp(),
    verification: FieldValue.delete(),
  };
  const currentStatus = doc.status || 'pending_email_verification';
  if (currentStatus === 'pending_email_verification') {
    updates.status = 'pending_documents';
  }
  await userRef.set(updates, { merge: true });

  return { ok: true };
});

/**
 * Applications triggers
 * - Ensure defaults on create
 * - Notify user on status decision transitions (approved/declined)
 */
exports.onApplicationCreate = functions.firestore
  .database('m-clearance-imigrasi-db')
  .document('applications/{appId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const updates = {};
    if (!data.createdAt) updates.createdAt = FieldValue.serverTimestamp();
    if (!data.updatedAt) updates.updatedAt = FieldValue.serverTimestamp();
    if (!data.status) updates.status = 'waiting';
    if (Object.keys(updates).length) {
      await snap.ref.update(updates);
    }
  });

exports.onApplicationUpdate = functions.firestore
  .database('m-clearance-imigrasi-db')
  .document('applications/{appId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      const userUid = after.agentUid || before.agentUid;
      if (!userUid) return;

      const becameApproved = before.status !== 'approved' && after.status === 'approved';
      const becameDeclined = before.status !== 'declined' && after.status === 'declined';
      if (!(becameApproved || becameDeclined)) return;

      const type = after.type || before.type || 'arrival';
      const message = becameApproved
        ? `Your ${type} application has been approved.`
        : `Your ${type} application has been declined.`;
      const createdAt = Timestamp.now();
      const notifId = `${type}_${becameApproved ? 'approved' : 'declined'}_${createdAt.toMillis()}`;
      const notifRef = db.collection('notifications').doc(userUid).collection('items').doc(notifId);
      await notifRef.set({ type: 'application', message, createdAt });
    } catch (e) {
      console.error('[onApplicationUpdate] Error:', e);
    }
  });
