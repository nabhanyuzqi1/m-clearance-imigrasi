const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { Resend } = require("resend");

// Initialize Admin SDK exactly once
admin.initializeApp();

// Initialize Realtime Database
const rtdb = admin.database();

// Use default Firestore database everywhere
const db = admin.firestore();
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

// Counter management helpers
async function updateUserCounters(oldStatus, newStatus) {
  const countersRef = db.collection('counters').doc('dashboard');
  const updates = {};

  if (oldStatus && oldStatus !== newStatus) {
    if (oldStatus === 'pending_approval') updates.pendingAccounts = FieldValue.increment(-1);
  }
  if (newStatus) {
    if (newStatus === 'pending_approval') updates.pendingAccounts = FieldValue.increment(1);
  }

  if (Object.keys(updates).length > 0) {
    await countersRef.set(updates, { merge: true });
  }
}

async function updateApplicationCounters(oldType, oldStatus, newType, newStatus) {
  const countersRef = db.collection('counters').doc('dashboard');
  const updates = {};

  if (oldType && oldStatus && (oldType !== newType || oldStatus !== newStatus)) {
    if (oldStatus === 'waiting') {
      if (oldType === 'arrival') updates.pendingArrival = FieldValue.increment(-1);
      else if (oldType === 'departure') updates.pendingDeparture = FieldValue.increment(-1);
    }
  }
  if (newType && newStatus) {
    if (newStatus === 'waiting') {
      if (newType === 'arrival') updates.pendingArrival = FieldValue.increment(1);
      else if (newType === 'departure') updates.pendingDeparture = FieldValue.increment(1);
    }
  }

  if (Object.keys(updates).length > 0) {
    await countersRef.set(updates, { merge: true });
  }
}

// Resend client (lazy-init)
// Direct Resend integration using Resend SDK

async function resolveUserEmail(uid, fallbackEmail) {
  if (fallbackEmail) return fallbackEmail;
  try {
    const u = await admin.auth().getUser(uid);
    if (u && u.email) return u.email;
  } catch (_) {}
  try {
    const snap = await db.collection('users').doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (data.email) return data.email;
    }
  } catch (_) {}
  return '';
}

async function resolveUserName(uid, fallbackEmail) {
  // Try auth displayName first
  try {
    const u = await admin.auth().getUser(uid);
    if (u && u.displayName) return u.displayName;
  } catch (_) {}
  // Try Firestore username
  try {
    const snap = await db.collection('users').doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (data.username) return data.username;
    }
  } catch (_) {}
  // Fallback to email local-part
  const email = await resolveUserEmail(uid, fallbackEmail);
  if (email && email.includes('@')) return email.split('@')[0];
  return 'User';
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
 * Email Configuration Service
 * Fetches email settings from Firebase Realtime Database with caching and fallback to environment variables.
 */
class EmailConfigService {
  constructor() {
    this.config = null;
    this.lastFetched = 0;
    this.cacheDuration = 5 * 60 * 1000; // 5 minutes cache
  }

  async getConfig() {
    const now = Date.now();
    if (this.config && (now - this.lastFetched) < this.cacheDuration) {
      return this.config;
    }

    try {
      const snapshot = await rtdb.ref('email_config').once('value');
      const data = snapshot.val();
      if (data) {
        this.config = data;
        this.lastFetched = now;
        console.log('[EmailConfigService] Fetched config from RTDB at email_config');
        return this.config;
      }
    } catch (error) {
      console.error('[EmailConfigService] Failed to fetch config from RTDB:', error);
    }

    // Fallback to environment variables
    console.log('[EmailConfigService] Using fallback config from environment');
    return this.getFallbackConfig();
  }

  getFallbackConfig() {
    return {
      global: {
        apiKey: process.env.RESEND_API_KEY || '',
        from: 'noreply@mclearanceisam.com',
        fromName: 'M-Clearance',
        accountName: 'M-Clearance',
        supportEmail: 'support@mclearanceisam.com',
        maxRetries: Number(process.env.MAX_EMAIL_RETRIES) || 3,
        cooldownSeconds: Number(process.env.MAILERSEND_COOLDOWN_SECONDS) || 60,
        maxAttempts: Number(process.env.MAILERSEND_MAX_ATTEMPTS) || 5,
      },
      templates: {
        verification: {
          templateId: '',
          subject: 'Your verification code',
          tags: ['email_verification'],
        },
      },
    };
  }

  async getGlobalSettings() {
    const config = await this.getConfig();
    // Handle both RTDB flat structure and fallback nested structure
    const globalConfig = config.global || config;
    return {
      apiKey: globalConfig.apiKey || process.env.RESEND_API_KEY || '',
      from: globalConfig.fromEmail || globalConfig.from || '',
      fromName: globalConfig.fromName || 'M-Clearance System',
      accountName: globalConfig.accountName || globalConfig.fromName || 'M-Clearance System',
      supportEmail: globalConfig.supportEmail || globalConfig.fromEmail || globalConfig.from || '',
      maxRetries: globalConfig.maxRetries || 3,
      cooldownSeconds: globalConfig.cooldownSeconds || 60,
      maxAttempts: globalConfig.maxAttempts || 5,
    };
  }

  async getTemplateSettings(templateName = 'verification') {
    const config = await this.getConfig();
    // Handle both RTDB flat structure and fallback nested structure
    const templatesConfig = config.templates || config;
    const templateFieldMap = {
      verification: {
        subject: templatesConfig.verification?.subject || 'Your verification code - M-Clearance',
        html: templatesConfig.verification?.html || '<p>Your verification code is: {code}</p>',
        text: templatesConfig.verification?.text || 'Your verification code is: {code}',
        tags: ['email_verification']
      },
      passwordReset: {
        subject: templatesConfig.passwordReset?.subject || 'Password Reset Request - M-Clearance',
        html: templatesConfig.passwordReset?.html || '<p>Reset your password: {resetLink}</p>',
        text: templatesConfig.passwordReset?.text || 'Reset your password: {resetLink}',
        tags: ['password_reset']
      },
      approval: {
        subject: templatesConfig.approval?.subject || 'Application Approved - M-Clearance',
        html: templatesConfig.approval?.html || '<p>Your application has been approved.</p>',
        text: templatesConfig.approval?.text || 'Your application has been approved.',
        tags: ['application_approval']
      },
      rejection: {
        subject: templatesConfig.rejection?.subject || 'Application Status Update - M-Clearance',
        html: templatesConfig.rejection?.html || '<p>Your application requires additional information.</p>',
        text: templatesConfig.rejection?.text || 'Your application requires additional information.',
        tags: ['application_rejection']
      }
    };
    return templateFieldMap[templateName] || {};
  }
}

const emailConfig = new EmailConfigService();

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

        // Update counters if status is pending_approval (though initially it's not)
        if (initDoc.status === 'pending_approval') {
          await updateUserCounters(null, initDoc.status);
        }
        return;
      }

      // If doc exists, only update fields once and keep idempotent behavior
      const data = snap.data() || {};
      const oldStatus = data.status;
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

        // Update counters if status changed
        if (updates.status && updates.status !== oldStatus) {
          await updateUserCounters(oldStatus, updates.status);
        }
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
            // Update counters for the enforced status change
            await updateUserCounters(curStatus, "pending_approval");
          } else {
            console.log("[onUserDocUpdate] Skipped enforcement; current status:", curStatus);
          }
        });
      }

      // 2) Update counters for status changes
      if (beforeStatus !== afterStatus) {
        await updateUserCounters(beforeStatus, afterStatus);
        console.log("[onUserDocUpdate] Updated counters for status change:", beforeStatus, "->", afterStatus);
      }

      // 3) Enqueue review item idempotently
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

      // 4) Notifications on terminal decision transitions (approved/rejected)
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

  const functionStart = DateTime.now();
  console.log('[getOfficerDashboardStats] Function started');

  const startOfDay = new Date();
  startOfDay.setUTCHours(0, 0, 0, 0);

  // Try to get from counters first for better performance
  const countersRef = db.collection('counters').doc('dashboard');
  const countersSnap = await countersRef.get();
  let counters = {};
  if (countersSnap.exists) {
    counters = countersSnap.data() || {};
  }

  // Helper to count a query without loading all docs (fallback)
  async function countQuery(q, label) {
    const queryStart = DateTime.now();
    const snap = await q.select(admin.firestore.FieldPath.documentId()).get();
    const queryTime = DateTime.now().difference(queryStart);
    console.log(`[getOfficerDashboardStats] ${label} count took ${queryTime.inMilliseconds}ms, returned ${snap.size} docs`);
    return snap.size;
  }

  const usersCol = db.collection('users');
  const applicationsCol = db.collection('applications');

  const countStart = DateTime.now();

  // Use counters where available, fallback to counting
  const [
    pendingAccounts,
    approvedToday,
    rejectedToday,
    pendingArrival,
    pendingDeparture,
  ] = await Promise.all([
    counters.pendingAccounts !== undefined ? Promise.resolve(counters.pendingAccounts) : countQuery(usersCol.where('status', '==', 'pending_approval'), 'pendingAccounts'),
    countQuery(usersCol.where('status', '==', 'approved').where('updatedAt', '>=', Timestamp.fromDate(startOfDay)), 'approvedToday'), // Daily counts still need query
    countQuery(usersCol.where('status', '==', 'rejected').where('updatedAt', '>=', Timestamp.fromDate(startOfDay)), 'rejectedToday'), // Daily counts still need query
    counters.pendingArrival !== undefined ? Promise.resolve(counters.pendingArrival) : countQuery(applicationsCol.where('type', '==', 'arrival').where('status', '==', 'waiting'), 'pendingArrival'),
    counters.pendingDeparture !== undefined ? Promise.resolve(counters.pendingDeparture) : countQuery(applicationsCol.where('type', '==', 'departure').where('status', '==', 'waiting'), 'pendingDeparture'),
  ]);

  const countTime = DateTime.now().difference(countStart);
  console.log(`[getOfficerDashboardStats] All counts took ${countTime.inMilliseconds}ms`);

  const totalTime = DateTime.now().difference(functionStart);
  console.log(`[getOfficerDashboardStats] Total function time: ${totalTime.inMilliseconds}ms`);

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

  // Fetch dynamic configuration
  const globalSettings = await emailConfig.getGlobalSettings();
  const templateSettings = await emailConfig.getTemplateSettings('verification');

  // Optimized transaction: minimize reads, use server timestamps
  let code, now, expiresAt, emailDocId;
  try {
    const result = await db.runTransaction(async (txn) => {
      const snap = await txn.get(userRef);
      const data = snap.exists ? (snap.data() || {}) : {};
      const ver = data.verification || {};
      const issuedAt = ver.issuedAt;
      const nowTs = FieldValue.serverTimestamp(); // Use server timestamp for consistency
      if (issuedAt && typeof issuedAt.toMillis === 'function') {
        const elapsedSec = Math.floor((Timestamp.now().toMillis() - issuedAt.toMillis()) / 1000);
        const remain = (globalSettings.cooldownSeconds || 60) - elapsedSec;
        if (remain > 0) {
          return { cooldown: true, retryAfterSec: remain };
        }
      }
      const raw = Math.floor(Math.random() * 10000);
      const newCode = raw.toString().padStart(4, '0');
      const expires = Timestamp.fromMillis(Timestamp.now().toMillis() + 10 * 60 * 1000);
      const mailId = `${uid}_${Date.now()}`; // Use Date.now() for uniqueness
      txn.set(userRef, {
        verification: {
          code: newCode,
          issuedAt: nowTs,
          expiresAt: expires,
          attempts: 0,
          emailDocId: mailId,
        },
        updatedAt: nowTs,
      }, { merge: true });
      return { code: newCode, now: Timestamp.now(), expiresAt: expires, emailDocId: mailId };
    });
    if (result && result.cooldown) {
      return { ok: false, reason: 'cooldown', retryAfterSec: result.retryAfterSec };
    }
    ({ code, now, expiresAt, emailDocId } = result);
  } catch (e) {
    console.error('[issueEmailVerificationCode] transaction failed:', e);
    throw e;
  }

  console.log('[issueEmailVerificationCode] uid:', uid, 'code_issued');

  // Send email directly using Resend API
  const tokenEmail = (context.auth && context.auth.token && context.auth.token.email) || '';
  const recipientEmail = await resolveUserEmail(uid, tokenEmail);
  const recipientName = await resolveUserName(uid, tokenEmail);
  if (!recipientEmail) {
    console.warn('[issueEmailVerificationCode] Could not resolve recipient email for uid:', uid);
    return { ok: true, sent: false, reason: 'noRecipientEmail' };
  }

  try {
    // Initialize Resend client
    const resend = new Resend(process.env.RESEND_API_KEY);

    const subject = templateSettings.subject || 'Your verification code';
    const html = (templateSettings.html || '<p>Hello {name},</p><p>Your verification code is <b>{code}</b>.<br/>It expires in 10 minutes.</p><p>Regards,<br/>{accountName}</p>')
      .replace(/{name}/g, recipientName)
      .replace(/{code}/g, code)
      .replace(/{accountName}/g, globalSettings.accountName);
    const text = (templateSettings.text || 'Hello {name},\nYour verification code is {code}. It expires in 10 minutes.\nRegards, {accountName}')
      .replace(/{name}/g, recipientName)
      .replace(/{code}/g, code)
      .replace(/{accountName}/g, globalSettings.accountName);

    // Prepare email data for Resend
    const emailData = {
      from: `${globalSettings.fromName} <${globalSettings.from}>`,
      to: recipientEmail,
      subject: subject,
      html: html,
      text: text,
      reply_to: globalSettings.supportEmail || globalSettings.from,
    };

    // Send the email
    const { data, error } = await resend.emails.send(emailData);

    if (error) {
      console.error('[issueEmailVerificationCode] Failed to send email:', error);
      return { ok: true, sent: false, reason: 'sendFailed', error: error.message };
    }

    console.log('[issueEmailVerificationCode] Email sent successfully:', data);
    return { ok: true, sent: true, messageId: data?.id };
  } catch (e) {
    // If thrown by cooldown guard
    if (e && typeof e.message === 'string' && e.message.startsWith('cooldown:')) {
      const remain = Number(e.message.split(':')[1] || '60');
      return { ok: false, reason: 'cooldown', retryAfterSec: remain };
    }
    console.error('[issueEmailVerificationCode] Failed to send email:', e);
    return { ok: true, sent: false, reason: 'sendFailed', error: e.message };
  }
});

/**
 * verifyEmailCode (callable)
 * Validates a submitted 4-digit code, marks Firebase Auth emailVerified=true,
 * and updates Firestore (isEmailVerified and status transition).
 */
/**
 * initializeCounters (callable)
 * Initialize dashboard counters by counting existing documents.
 * Run this once after deployment to set up counters.
 */
exports.initializeCounters = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  ensureOfficerOrAdmin(context);

  console.log('[initializeCounters] Starting counter initialization');

  const countersRef = db.collection('counters').doc('dashboard');

  // Count users
  const pendingAccountsSnap = await db.collection('users').where('status', '==', 'pending_approval').select(admin.firestore.FieldPath.documentId()).get();
  const pendingAccounts = pendingAccountsSnap.size;

  // Count applications
  const pendingArrivalSnap = await db.collection('applications').where('type', '==', 'arrival').where('status', '==', 'waiting').select(admin.firestore.FieldPath.documentId()).get();
  const pendingArrival = pendingArrivalSnap.size;

  const pendingDepartureSnap = await db.collection('applications').where('type', '==', 'departure').where('status', '==', 'waiting').select(admin.firestore.FieldPath.documentId()).get();
  const pendingDeparture = pendingDepartureSnap.size;

  await countersRef.set({
    pendingAccounts,
    pendingArrival,
    pendingDeparture,
    lastUpdated: FieldValue.serverTimestamp(),
  });

  console.log('[initializeCounters] Counters initialized:', { pendingAccounts, pendingArrival, pendingDeparture });

  return { success: true, counters: { pendingAccounts, pendingArrival, pendingDeparture } };
});

exports.verifyEmailCode = functions.https.onCall(async (data, context) => {
  requireAuth(context);
  const uid = context.auth.uid;
  const submitted = (data && data.code) ? String(data.code) : '';
  if (!/^\d{4}$/.test(submitted)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid code format.');
  }

  const userRef = db.collection('users').doc(uid);

  // Fetch dynamic configuration
  const globalSettings = await emailConfig.getGlobalSettings();

  // Use transaction for atomic verification
  await db.runTransaction(async (txn) => {
    const snap = await txn.get(userRef);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'User document not found.');
    }
    const doc = snap.data() || {};
    const ver = doc.verification || {};
    const code = ver.code || '';
    const expiresAt = ver.expiresAt;
    const attempts = Number(ver.attempts || 0);

    if (!code) {
      throw new functions.https.HttpsError('failed-precondition', 'No active verification code.');
    }
    if (attempts >= (globalSettings.maxAttempts || 5)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Too many attempts. Please request a new code later.');
    }
    if (expiresAt && typeof expiresAt.toMillis === 'function') {
      if (Timestamp.now().toMillis() > expiresAt.toMillis()) {
        throw new functions.https.HttpsError('deadline-exceeded', 'Code expired.');
      }
    }
    if (code !== submitted) {
      txn.update(userRef, { 'verification.attempts': attempts + 1 });
      throw new functions.https.HttpsError('permission-denied', 'Incorrect code.');
    }

    // Mark Auth user as emailVerified = true (outside transaction for Auth API)
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
    txn.update(userRef, updates);
  });

  // Update Auth after transaction succeeds
  await admin.auth().updateUser(uid, { emailVerified: true });

  return { ok: true };
});

/**
 * testEmailSend (callable)
 * Test function to verify direct Resend integration
 * Sends a test email directly using Resend API
 */
exports.testEmailSend = functions.https.onCall(async (data, context) => {
  try {
    console.log('[testEmailSend] Testing direct Resend integration...');

    // Get configuration
    const globalSettings = await emailConfig.getGlobalSettings();
    const templateSettings = await emailConfig.getTemplateSettings('verification');

    console.log('[testEmailSend] Global settings:', JSON.stringify(globalSettings, null, 2));
    console.log('[testEmailSend] Template settings:', JSON.stringify(templateSettings, null, 2));

    // Initialize Resend client
    const resend = new Resend(process.env.RESEND_API_KEY);

    // Test email parameters - use provided data or defaults
    const testRecipient = (data && data.email) || 'mclearanceisam@gmail.com';
    const testName = (data && data.name) || 'Test User';

    const subject = templateSettings.subject || 'Test Email - Direct Resend Integration';
    const html = (templateSettings.html || '<p>Hello {name},</p><p>This is a test email sent using Resend API.</p><p>Regards,<br/>{accountName}</p>')
      .replace(/{name}/g, testName)
      .replace(/{accountName}/g, globalSettings.accountName);
    const text = (templateSettings.text || 'Hello {name},\n\nThis is a test email sent using Resend API.\n\nRegards,\n{accountName}')
      .replace(/{name}/g, testName)
      .replace(/{accountName}/g, globalSettings.accountName);

    // Prepare email data for Resend
    const emailData = {
      from: `${globalSettings.fromName} <${globalSettings.from}>`,
      to: testRecipient,
      subject: subject,
      html: html,
      text: text,
      reply_to: globalSettings.supportEmail || globalSettings.from,
    };

    console.log('[testEmailSend] Sending email to:', testRecipient);
    console.log('[testEmailSend] From:', emailData.from);
    console.log('[testEmailSend] Subject:', emailData.subject);

    // Send the email
    const { data: emailDataResponse, error } = await resend.emails.send(emailData);

    if (error) {
      console.error('[testEmailSend] Failed to send email:', error);
      return {
        success: false,
        error: error.message,
        recipient: testRecipient,
        message: 'Test email sending failed'
      };
    }

    console.log('[testEmailSend] Email sent successfully:', emailDataResponse);

    return {
      success: true,
      messageId: emailDataResponse?.id,
      recipient: testRecipient,
      templateUsed: !!templateSettings.html,
      templateSubject: templateSettings.subject,
      message: 'Test email sent successfully via direct Resend integration with HTML templates'
    };
  } catch (error) {
    console.error('[testEmailSend] Error:', error);
    return {
      success: false,
      error: error.message,
      message: 'Test email sending failed'
    };
  }
});


/**
 * Applications triggers
 * - Ensure defaults on create
 * - Update counters on create
 * - Notify user on status decision transitions (approved/declined)
 */
exports.onApplicationCreate = functions.firestore
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

    // Update counters for new application
    const type = data.type || 'arrival';
    const status = updates.status || data.status || 'waiting';
    await updateApplicationCounters(null, null, type, status);
    console.log("[onApplicationCreate] Updated counters for new application:", type, status);
  });

exports.onApplicationUpdate = functions.firestore
  .document('applications/{appId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data() || {};
      const after = change.after.data() || {};
      const userUid = after.agentUid || before.agentUid;

      const beforeType = before.type;
      const afterType = after.type;
      const beforeStatus = before.status;
      const afterStatus = after.status;

      // Update counters if type or status changed
      if (beforeType !== afterType || beforeStatus !== afterStatus) {
        await updateApplicationCounters(beforeType, beforeStatus, afterType, afterStatus);
        console.log("[onApplicationUpdate] Updated counters for application change:", beforeType, beforeStatus, "->", afterType, afterStatus);
      }

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

