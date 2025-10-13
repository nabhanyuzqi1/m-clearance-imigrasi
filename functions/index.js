const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
const { Resend } = require("resend");
const { logger } = require("firebase-functions");
const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

// Initialize Admin SDK exactly once
admin.initializeApp();

// Use default Firestore database everywhere
const db = admin.firestore();
const { FieldValue, Timestamp } = admin.firestore;

// Helpers
function requireAuth(context) {
  if (!context.auth) {
    const err = new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required.",
    );
    throw err;
  }
}

// Counter management helpers
async function updateUserCounters(oldStatus, newStatus) {
  const countersRef = db.collection("counters").doc("dashboard");
  const updates = {};

  if (oldStatus && oldStatus !== newStatus) {
    if (oldStatus === "pending_approval")
      updates.pendingAccounts = FieldValue.increment(-1);
  }
  if (newStatus) {
    if (newStatus === "pending_approval")
      updates.pendingAccounts = FieldValue.increment(1);
  }

  if (Object.keys(updates).length > 0) {
    await countersRef.set(updates, { merge: true });
  }
}

async function updateApplicationCounters(
  oldType,
  oldStatus,
  newType,
  newStatus,
) {
  const countersRef = db.collection("counters").doc("dashboard");
  const updates = {};

  if (
    oldType &&
    oldStatus &&
    (oldType !== newType || oldStatus !== newStatus)
  ) {
    if (oldStatus === "waiting") {
      if (oldType === "arrival")
        updates.pendingArrival = FieldValue.increment(-1);
      else if (oldType === "departure")
        updates.pendingDeparture = FieldValue.increment(-1);
    }
  }
  if (newType && newStatus) {
    if (newStatus === "waiting") {
      if (newType === "arrival")
        updates.pendingArrival = FieldValue.increment(1);
      else if (newType === "departure")
        updates.pendingDeparture = FieldValue.increment(1);
    }
  }

  if (Object.keys(updates).length > 0) {
    await countersRef.set(updates, { merge: true });
  }
}

async function recordNotification(uid, payload = {}) {
  if (!uid) return null;
  const timestamp =
    payload.timestamp instanceof Timestamp
      ? payload.timestamp
      : Timestamp.now();
  const notificationsRef = db
    .collection("notifications")
    .doc(uid)
    .collection("items");
  const notifId = payload.id || notificationsRef.doc().id;

  const typeValue = typeof payload.type === "number" ? payload.type : 0;

  const notificationData = {
    title: payload.title || "Notification",
    body: payload.body || "",
    date: timestamp,
    createdAt: timestamp,
    type: typeValue,
    userId: uid,
    isRead: false,
    ...(payload.extra && typeof payload.extra === "object"
      ? payload.extra
      : {}),
  };

  await notificationsRef.doc(notifId).set(notificationData, { merge: false });
  return notifId;
}

async function notifyRoles(roles, payload = {}, options = {}) {
  if (!Array.isArray(roles) || roles.length === 0) return;
  const uniqueRoles = Array.from(new Set(roles.filter(Boolean)));
  if (uniqueRoles.length === 0) return;

  const snapshot = await db
    .collection("users")
    .where("role", "in", uniqueRoles)
    .get();

  const skipUid = options.skipUid;
  const tasks = [];
  snapshot.forEach((doc) => {
    const uid = doc.id;
    if (skipUid && uid === skipUid) return;
    tasks.push(
      recordNotification(uid, {
        ...payload,
        id: payload.id ? `${payload.id}_${uid}` : undefined,
      }),
    );
  });

  await Promise.all(tasks);
}

const SECURITY_CHALLENGES_COLLECTION = "securityChallenges";
const OTP_EXPIRY_MINUTES = 5;

function generateTwoFactorCode() {
  const value = crypto.randomInt(100000, 1000000);
  return value.toString().padStart(6, "0");
}

function hashTwoFactorCode(code) {
  return crypto.createHash("sha256").update(code).digest("hex");
}

function maskEmailAddress(email) {
  if (!email || typeof email !== "string") return "";
  const [userPart, domainPart] = email.split("@");
  if (!userPart || !domainPart) return email;
  const visible = userPart.slice(0, 2);
  return `${visible}${userPart.length > 2 ? "***" : ""}@${domainPart}`;
}

async function sendTwoFactorEmail({
  uid,
  email,
  name,
  code,
  deviceName,
  language,
}) {
  const replacements = {
    name: name || email,
    code,
    deviceName: deviceName || "New device",
    timestamp: new Date().toLocaleString("en-US", {
      timeZone: "Asia/Jakarta",
    }),
    expiresInMinutes: OTP_EXPIRY_MINUTES.toString(),
  };

  try {
    await sendEmailFromTemplate({
      templateName: "twoFactorCode",
      language: (language || "en").toLowerCase(),
      to: email,
      replacements,
      includeSuperAdmin: false,
    });
  } catch (err) {
    console.error(
      "[sendTwoFactorEmail] Template delivery failed, using fallback",
      err,
    );
    const globalSettings = await emailConfig.getGlobalSettings();
    const resend = new Resend(
      globalSettings.apiKey || process.env.RESEND_API_KEY,
    );
    const safeAccountName =
      globalSettings.accountName || globalSettings.fromName || "M-Clearance";
    const subject = `Your ${safeAccountName} security code`;
    const fallbackHtml = `<p>Hello ${replacements.name},</p>
      <p>Your security code is <strong style="font-size:24px;letter-spacing:4px;">${code}</strong>.</p>
      <p>Device: ${replacements.deviceName}<br/>Time: ${replacements.timestamp}</p>
      <p>The code expires in ${OTP_EXPIRY_MINUTES} minutes.</p>`;
    const emailData = {
      from: `${globalSettings.fromName || safeAccountName} <${globalSettings.from}>`,
      to: email,
      subject,
      html: fallbackHtml,
      text: `Hello ${replacements.name},\n\nYour security code is ${code}. It expires in ${OTP_EXPIRY_MINUTES} minutes.\nDevice: ${replacements.deviceName}\nTime: ${replacements.timestamp}`,
      reply_to: globalSettings.supportEmail || globalSettings.from,
    };
    await resend.emails.send(emailData);
  }
}

async function sendLoginAlertEmail({
  email,
  name,
  deviceName,
  ipAddress,
  trusted,
}) {
  const globalSettings = await emailConfig.getGlobalSettings();
  const resend = new Resend(
    globalSettings.apiKey || process.env.RESEND_API_KEY,
  );
  const safeAccountName =
    globalSettings.accountName || globalSettings.fromName || "M-Clearance";
  const subject = `New login on your ${safeAccountName} account`;
  const timestamp = new Date().toLocaleString("en-US", {
    timeZone: "Asia/Jakarta",
  });
  const bodyDevice = deviceName || "Unknown device";
  const trustLabel = trusted ? "trusted device" : "untrusted device";
  const replacements = {
    name: name || email,
    device: bodyDevice,
    trustLabel,
    ipAddress: ipAddress || "Unavailable",
    timestamp,
  };

  try {
    await sendEmailFromTemplate({
      templateName: "loginAlert",
      language: "en",
      to: email,
      replacements,
      includeSuperAdmin: false,
    });
  } catch (err) {
    console.error(
      "[sendLoginAlertEmail] Template send failed, falling back",
      err,
    );
    await resend.emails.send({
      from: `${globalSettings.fromName || safeAccountName} <${globalSettings.from}>`,
      to: email,
      subject,
      html: `<p>Hello ${replacements.name},</p>
        <p>A new login was detected on ${replacements.device} (${replacements.trustLabel}).</p>
        <p>Time: ${replacements.timestamp}<br/>IP Address: ${replacements.ipAddress}</p>
        <p>If this was you, no further action is required. If not, please reset your password immediately.</p>
        <p>Regards,<br/>${safeAccountName} Support</p>`,
      text:
        `Hello ${replacements.name}\n\n` +
        `A new login was detected on ${replacements.device} (${replacements.trustLabel}).\n` +
        `Time: ${replacements.timestamp}\nIP Address: ${replacements.ipAddress}\n\n` +
        `If this was you, no action is required. If not, please reset your password immediately.\n\n` +
        `${safeAccountName} Support`,
      reply_to: globalSettings.supportEmail || globalSettings.from,
    });
  }
}

exports.onNotificationWrite = functions
  .region("asia-southeast1")
  .firestore.document("notifications/{uid}/items/{notifId}")
  .onWrite(async (change, context) => {
    const uid = context.params.uid;
    if (!uid) return;

    let delta = 0;
    const beforeData = change.before.exists ? change.before.data() || {} : null;
    const afterData = change.after.exists ? change.after.data() || {} : null;

    if (!beforeData && afterData) {
      const unread = afterData.isRead !== true;
      if (unread) delta += 1;
    } else if (beforeData && !afterData) {
      const wasUnread = beforeData.isRead !== true;
      if (wasUnread) delta -= 1;
    } else if (beforeData && afterData) {
      const wasUnread = beforeData.isRead !== true;
      const nowUnread = afterData.isRead !== true;
      if (wasUnread !== nowUnread) {
        delta += nowUnread ? 1 : -1;
      }
    }

    if (delta === 0) return;

    const metaRef = db.collection("notifications").doc(uid);
    await metaRef.set(
      {
        unreadCount: FieldValue.increment(delta),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });

// Resend client (lazy-init)
// Direct Resend integration using Resend SDK

async function resolveUserEmail(uid, fallbackEmail) {
  if (fallbackEmail) return fallbackEmail;
  try {
    const u = await admin.auth().getUser(uid);
    if (u && u.email) return u.email;
  } catch (_) {}
  try {
    const snap = await db.collection("users").doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (data.email) return data.email;
    }
  } catch (_) {}
  return "";
}

async function resolveUserName(uid, fallbackEmail) {
  // Try auth displayName first
  try {
    const u = await admin.auth().getUser(uid);
    if (u && u.displayName) return u.displayName;
  } catch (_) {}
  // Try Firestore username
  try {
    const snap = await db.collection("users").doc(uid).get();
    if (snap.exists) {
      const data = snap.data() || {};
      if (data.username) return data.username;
    }
  } catch (_) {}
  // Fallback to email local-part
  const email = await resolveUserEmail(uid, fallbackEmail);
  if (email && email.includes("@")) return email.split("@")[0];
  return "User";
}

const securityInitiateTwoFactor = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    const uid = context.auth.uid;
    const device = data && data.device ? data.device : {};
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();
    const userData = userDoc.exists ? userDoc.data() || {} : {};

    const fallbackEmail =
      (context.auth.token && context.auth.token.email) || "";
    const email = await resolveUserEmail(uid, fallbackEmail);
    if (!email) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Authenticated user does not have an email address.",
      );
    }

    const code = generateTwoFactorCode();
    const codeHash = hashTwoFactorCode(code);
    const challengeId = crypto.randomUUID();
    const expiresAtDate = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60000);
    const expiresAt = Timestamp.fromDate(expiresAtDate);
    const sanitizedDevice = {
      fingerprint: device.fingerprint || null,
      deviceId: device.deviceId || null,
      deviceName: device.deviceName || null,
      platform: device.platform || null,
      osVersion: device.osVersion || null,
      brand: device.brand || null,
      model: device.model || null,
      locale: device.locale || null,
      rememberDeviceDays: device.rememberDeviceDays || null,
    };

    await db
      .collection(SECURITY_CHALLENGES_COLLECTION)
      .doc(challengeId)
      .set({
        uid,
        codeHash,
        expiresAt,
        createdAt: Timestamp.now(),
        consumed: false,
        attempts: 0,
        device: sanitizedDevice,
        ipAddress: context.rawRequest?.ip || null,
      });

    const name = await resolveUserName(uid, email);
    await sendTwoFactorEmail({
      uid,
      email,
      name,
      code,
      deviceName: sanitizedDevice.deviceName || sanitizedDevice.platform,
      language: (userData.language || "en").toLowerCase(),
    });

    return {
      challengeId,
      expiresAt: expiresAtDate.getTime(),
      delivery: {
        type: "email",
        target: maskEmailAddress(email),
      },
    };
  });

const securityVerifyTwoFactor = functions
  .region("asia-southeast1")
  .https.onCall(async (data) => {
    const challengeId = data && data.challengeId;
    const code = data && data.code;
    const trustDevice = !!(data && data.trustDevice);
    const device = data && data.device ? data.device : {};

    if (!challengeId || typeof challengeId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "challengeId must be provided.",
      );
    }
    if (!code || typeof code !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "code must be provided as a string.",
      );
    }

    const challengeRef = db
      .collection(SECURITY_CHALLENGES_COLLECTION)
      .doc(challengeId);
    const challengeSnap = await challengeRef.get();
    if (!challengeSnap.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Two-factor challenge not found or already consumed.",
      );
    }

    const challenge = challengeSnap.data();
    if (challenge.consumed) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "This verification code has already been used.",
      );
    }

    const nowMs = Date.now();
    if (challenge.expiresAt && challenge.expiresAt.toMillis() < nowMs) {
      await challengeRef.update({
        consumed: true,
        expired: true,
        consumedAt: Timestamp.now(),
      });
      throw new functions.https.HttpsError(
        "deadline-exceeded",
        "This verification code has expired.",
      );
    }

    const submittedHash = hashTwoFactorCode(code);
    if (submittedHash !== challenge.codeHash) {
      await challengeRef.update({
        attempts: FieldValue.increment(1),
        lastAttemptAt: Timestamp.now(),
      });
      throw new functions.https.HttpsError(
        "permission-denied",
        "Invalid verification code.",
      );
    }

    const uid = challenge.uid;
    const sessionId =
      device.fingerprint || device.deviceId || crypto.randomUUID();
    const rememberDeviceDays = parseInt(device.rememberDeviceDays, 10) || 30;
    const trustedUntilDate = trustDevice
      ? new Date(Date.now() + rememberDeviceDays * 24 * 60 * 60 * 1000)
      : null;
    const now = Timestamp.now();

    const sessionsCollection = db
      .collection("users")
      .doc(uid)
      .collection("sessions");
    const sessionRef = sessionsCollection.doc(sessionId);
    const existingSession = await sessionRef.get();
    const sessionPayload = {
      deviceName: device.deviceName || "Unknown device",
      platform: device.platform || "unknown",
      appVersion: device.appVersion || "—",
      ipAddress: device.ipAddress || "",
      location: device.location || "",
      lastActive: now,
      isCurrent: true,
      isRevoked: false,
      trusted: trustDevice,
      updatedAt: now,
    };
    if (device.locale) sessionPayload.locale = device.locale;
    if (trustedUntilDate) {
      sessionPayload.trustedUntil = Timestamp.fromDate(trustedUntilDate);
    } else {
      sessionPayload.trustedUntil = FieldValue.delete();
    }
    if (!existingSession.exists) {
      sessionPayload.createdAt = now;
    }

    await sessionRef.set(sessionPayload, { merge: true });

    const activeSessionsSnapshot = await sessionsCollection
      .where("isCurrent", "==", true)
      .get();
    if (!activeSessionsSnapshot.empty) {
      const batch = db.batch();
      activeSessionsSnapshot.forEach((doc) => {
        if (doc.id !== sessionId) {
          batch.update(doc.ref, { isCurrent: false });
        }
      });
      await batch.commit();
    }

    await challengeRef.update({
      consumed: true,
      consumedAt: now,
      successfulAttempts: FieldValue.increment(1),
    });

    return {
      success: true,
      sessionId,
      trustedUntil: trustedUntilDate ? trustedUntilDate.getTime() : null,
    };
  });

const securityLogLoginEvent = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    const uid = context.auth.uid;
    const device = data && data.device ? data.device : {};
    const trusted = !!(data && data.trusted);
    const rememberDeviceDays = parseInt(device.rememberDeviceDays, 10) || 30;
    const sessionId =
      device.fingerprint || device.deviceId || crypto.randomUUID();
    const now = Timestamp.now();

    const sessionsCollection = db
      .collection("users")
      .doc(uid)
      .collection("sessions");
    const sessionRef = sessionsCollection.doc(sessionId);
    const existingSession = await sessionRef.get();
    const sessionPayload = {
      deviceName: device.deviceName || "Unknown device",
      platform: device.platform || "unknown",
      appVersion: device.appVersion || "—",
      ipAddress:
        (context.rawRequest && context.rawRequest.ip) || device.ipAddress || "",
      location: device.location || "",
      lastActive: now,
      isCurrent: true,
      isRevoked: false,
      trusted,
      updatedAt: now,
    };
    if (device.locale) sessionPayload.locale = device.locale;
    if (trusted) {
      sessionPayload.trustedUntil = Timestamp.fromDate(
        new Date(Date.now() + rememberDeviceDays * 24 * 60 * 60 * 1000),
      );
    } else {
      sessionPayload.trustedUntil = FieldValue.delete();
    }
    if (!existingSession.exists) {
      sessionPayload.createdAt = now;
    }

    await sessionRef.set(sessionPayload, { merge: true });

    const activeSessionsSnapshot = await sessionsCollection
      .where("isCurrent", "==", true)
      .get();
    if (!activeSessionsSnapshot.empty) {
      const batch = db.batch();
      activeSessionsSnapshot.forEach((doc) => {
        if (doc.id !== sessionId) {
          batch.update(doc.ref, { isCurrent: false });
        }
      });
      await batch.commit();
    }

    const otherSessionsSnapshot = await sessionsCollection
      .where(admin.firestore.FieldPath.documentId(), "!=", sessionId)
      .where("isCurrent", "==", true)
      .get();
    if (!otherSessionsSnapshot.empty) {
      const batch = db.batch();
      otherSessionsSnapshot.forEach((doc) => {
        batch.update(doc.ref, { isCurrent: false });
      });
      await batch.commit();
    }

    const settingsSnap = await db
      .collection("users")
      .doc(uid)
      .collection("security")
      .doc("settings")
      .get();
    const settings = settingsSnap.exists ? settingsSnap.data() || {} : {};
    const loginAlertsEnabled = settings.loginAlertsEnabled !== false;

    if (loginAlertsEnabled) {
      const fallbackEmail =
        (context.auth.token && context.auth.token.email) || "";
      const email = await resolveUserEmail(uid, fallbackEmail);
      if (email) {
        const name = await resolveUserName(uid, email);
        await sendLoginAlertEmail({
          email,
          name,
          deviceName: device.deviceName || device.platform || "Unknown device",
          ipAddress:
            (context.rawRequest && context.rawRequest.ip) ||
            device.ipAddress ||
            "",
          trusted,
        });
      }
    }

    return { ok: true };
  });

exports.security = {
  initiateTwoFactor: securityInitiateTwoFactor,
  verifyTwoFactor: securityVerifyTwoFactor,
  logLoginEvent: securityLogLoginEvent,
};

function normalizeRole(role) {
  if (!role || typeof role !== "string") {
    return null;
  }
  const normalized = role.toLowerCase();
  return ["user", "officer", "admin"].includes(normalized) ? normalized : null;
}

async function callerRole(context) {
  if (!context.auth) {
    return "unauthenticated";
  }

  const uid = context.auth.uid;
  const tokenRole = normalizeRole(
    context.auth.token && context.auth.token.role,
  );

  try {
    const userSnap = await db.collection("users").doc(uid).get();
    if (userSnap.exists) {
      const firestoreRole = normalizeRole((userSnap.data() || {}).role);
      if (firestoreRole) {
        if (firestoreRole !== tokenRole && firestoreRole !== "user") {
          try {
            await admin
              .auth()
              .setCustomUserClaims(uid, { role: firestoreRole });
            console.log(
              `[callerRole] Synced custom claims for ${uid} to role '${firestoreRole}'`,
            );
          } catch (syncError) {
            console.error(
              "[callerRole] Failed to sync custom claims role:",
              syncError,
            );
          }
        }
        return firestoreRole;
      }
    }
  } catch (error) {
    console.error("[callerRole] Error fetching role:", error);
  }

  if (tokenRole) {
    return tokenRole;
  }

  return "user";
}

async function ensureOfficerOrAdmin(context) {
  const role = await callerRole(context);
  if (role !== "officer" && role !== "admin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Officer or admin role required.",
    );
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
    if (this.config && now - this.lastFetched < this.cacheDuration) {
      return this.config;
    }
    try {
      const snapshot = await admin.database().ref("emailConfig").get();
      if (snapshot.exists()) {
        this.config = snapshot.val();
        this.lastFetched = now;
        return this.config;
      }
      console.log("[EmailConfigService] RTDB config not found, using fallback");
    } catch (error) {
      console.error("[EmailConfigService] Failed to fetch RTDB config:", error);
    }

    this.config = this.getFallbackConfig();
    this.lastFetched = now;
    return this.config;
  }

  getFallbackConfig() {
    const verificationHtmlEn = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Email Verification</title>
</head>
<body style="margin:0;padding:0;background-color:#f5f7fb;font-family:'Segoe UI',Arial,sans-serif;color:#1f2933;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
    <tr>
      <td align="center" style="padding:24px;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:600px;background-color:#ffffff;border-radius:14px;overflow:hidden;box-shadow:0 18px 45px rgba(102,126,234,0.18);">
          <tr>
            <td align="center" style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);padding:40px 24px;">
              <h1 style="margin:0;font-size:28px;letter-spacing:0.5px;color:#ffffff;text-transform:uppercase;">{accountName}</h1>
              <p style="margin:12px 0 0 0;font-size:16px;color:rgba(255,255,255,0.78);">Email Verification</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 32px 48px 32px;background-color:#ffffff;">
              <h2 style="margin-top:0;margin-bottom:16px;font-size:22px;color:#1f2933;">Verify Your Email Address</h2>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#4b5563;">Hello <strong>{name}</strong>,</p>
              <p style="margin:0 0 24px 0;font-size:16px;line-height:1.6;color:#4b5563;">Thank you for registering with {accountName}. Please enter the verification code below to complete your registration.</p>
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="margin:24px 0;">
                <tr>
                  <td align="center" style="background:#f5f7ff;border:2px dashed #667eea;padding:24px 16px;border-radius:12px;">
                    <p style="margin:0;font-size:14px;font-weight:600;letter-spacing:0.35em;color:#667eea;text-transform:uppercase;">Your Verification Code</p>
                    <p style="margin:12px 0 0 0;font-size:42px;font-weight:700;letter-spacing:0.2em;color:#4c51bf;">{code}</p>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#4b5563;">This code will expire in <strong>10 minutes</strong>. Please keep it confidential to protect your account.</p>
              <p style="margin:0 0 32px 0;font-size:16px;line-height:1.6;color:#4b5563;">If you didn’t request this verification, you can safely ignore this message.</p>
              <hr style="border:none;border-top:1px solid #e5e7eb;margin:0 0 24px 0;" />
              <p style="margin:0;font-size:14px;line-height:1.6;color:#6b7280;text-align:center;">Best regards,<br /><strong>{accountName} Team</strong><br /><a href="mailto:{supportEmail}" style="color:#667eea;text-decoration:none;font-weight:600;">{supportEmail}</a></p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

    const verificationHtmlId = `<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Verifikasi Email</title>
</head>
<body style="margin:0;padding:0;background-color:#f5f7fb;font-family:'Segoe UI',Arial,sans-serif;color:#1f2933;">
  <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
    <tr>
      <td align="center" style="padding:24px;">
        <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:600px;background-color:#ffffff;border-radius:14px;overflow:hidden;box-shadow:0 18px 45px rgba(102,126,234,0.18);">
          <tr>
            <td align="center" style="background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);padding:40px 24px;">
              <h1 style="margin:0;font-size:28px;letter-spacing:0.5px;color:#ffffff;text-transform:uppercase;">{accountName}</h1>
              <p style="margin:12px 0 0 0;font-size:16px;color:rgba(255,255,255,0.78);">Verifikasi Email</p>
            </td>
          </tr>
          <tr>
            <td style="padding:40px 32px 48px 32px;background-color:#ffffff;">
              <h2 style="margin-top:0;margin-bottom:16px;font-size:22px;color:#1f2933;">Mohon Verifikasi Alamat Email Anda</h2>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#4b5563;">Halo <strong>{name}</strong>,</p>
              <p style="margin:0 0 24px 0;font-size:16px;line-height:1.6;color:#4b5563;">Terima kasih telah mendaftar di {accountName}. Silakan gunakan kode verifikasi berikut untuk melengkapi proses pendaftaran Anda.</p>
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="margin:24px 0;">
                <tr>
                  <td align="center" style="background:#f5f7ff;border:2px dashed #667eea;padding:24px 16px;border-radius:12px;">
                    <p style="margin:0;font-size:14px;font-weight:600;letter-spacing:0.35em;color:#667eea;text-transform:uppercase;">Kode Verifikasi Anda</p>
                    <p style="margin:12px 0 0 0;font-size:42px;font-weight:700;letter-spacing:0.2em;color:#4c51bf;">{code}</p>
                  </td>
                </tr>
              </table>
              <p style="margin:0 0 16px 0;font-size:16px;line-height:1.6;color:#4b5563;">Kode ini akan kedaluwarsa dalam <strong>10 menit</strong>. Mohon jaga kerahasiaannya demi keamanan akun Anda.</p>
              <p style="margin:0 0 32px 0;font-size:16px;line-height:1.6;color:#4b5563;">Jika Anda tidak merasa meminta verifikasi ini, silakan abaikan email ini.</p>
              <hr style="border:none;border-top:1px solid #e5e7eb;margin:0 0 24px 0;" />
              <p style="margin:0;font-size:14px;line-height:1.6;color:#6b7280;text-align:center;">Salam hangat,<br /><strong>Tim {accountName}</strong><br /><a href="mailto:{supportEmail}" style="color:#667eea;text-decoration:none;font-weight:600;">{supportEmail}</a></p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

    const verificationTextEn = `Hello {name},\n\nYour verification code for {accountName} is {code}.\nThe code will expire in 10 minutes.\nIf you didn't request this verification, please ignore this email.\n\nBest regards,\n{accountName} Team\n{supportEmail}`;

    const verificationTextId = `Halo {name},\n\nKode verifikasi Anda untuk {accountName} adalah {code}.\nKode ini akan kedaluwarsa dalam 10 menit.\nJika Anda tidak meminta verifikasi ini, silakan abaikan email ini.\n\nSalam hangat,\nTim {accountName}\n{supportEmail}`;

    const clearanceStatusHtml = `<!DOCTYPE html>
<html lang=\"en\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>{statusHeadline}</title>
  <style>
    body { margin: 0; padding: 0; background-color: #f5f7fb; font-family: 'Segoe UI', Arial, sans-serif; color: #1f2933; }
    .wrapper { width: 100%; padding: 24px 0; }
    .container { max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 14px; overflow: hidden; box-shadow: 0 18px 45px rgba(102, 126, 234, 0.18); }
    .hero { background: linear-gradient(135deg, #0ea5e9 0%, #2563eb 100%); text-align: center; padding: 36px 24px; }
    .hero h1 { margin: 0; font-size: 24px; letter-spacing: 0.4px; color: #ffffff; text-transform: uppercase; }
    .content { padding: 36px 32px 44px 32px; }
    .meta { font-size: 14px; color: #475569; margin-bottom: 24px; }
    .meta strong { color: #1f2937; }
    .card { border: 1px solid #e2e8f0; border-radius: 12px; padding: 20px 24px; margin: 24px 0; background: #f8fafc; }
    .card h3 { margin: 0 0 12px 0; font-size: 16px; color: #0f172a; }
    .card p { margin: 0; font-size: 15px; color: #334155; line-height: 1.6; }
    .notes { border-left: 4px solid #f59e0b; background: #fff7ed; padding: 18px 20px; border-radius: 10px; margin-top: 24px; color: #92400e; font-size: 15px; }
    .footer { border-top: 1px solid #e2e8f0; margin-top: 32px; padding-top: 24px; text-align: center; font-size: 13px; color: #64748b; }
    .footer a { color: #2563eb; text-decoration: none; font-weight: 600; }
  </style>
</head>
<body>
  <div class=\"wrapper\">
    <table role=\"presentation\" cellspacing=\"0\" cellpadding=\"0\" border=\"0\" width=\"100%\">
      <tr>
        <td align=\"center\">
          <table role=\"presentation\" cellspacing=\"0\" cellpadding=\"0\" border=\"0\" class=\"container\">
            <tr>
              <td class=\"hero\">
                <h1>{accountName}</h1>
              </td>
            </tr>
            <tr>
              <td class=\"content\">
                <div class=\"meta\">
                  <strong>Vessel:</strong> {shipName}<br />
                  <strong>Clearance Type:</strong> {type}<br />
                  <strong>Status:</strong> {statusLabel}
                </div>
                <div class=\"card\">
                  <h3>{statusHeadline}</h3>
                  <p>{statusSummary}</p>
                  <p>{actionText}</p>
                </div>
                {notesParagraph}
                <div class=\"footer\">
                  <p>Best regards,<br /><strong>{accountName} Team</strong><br /><a href=\"mailto:{supportEmail}\">{supportEmail}</a></p>
                </div>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </div>
</body>
</html>`;

    const clearanceStatusText = `Hello {name},\n\nVessel: {shipName}\nClearance type: {type}\nStatus: {statusLabel}\n\n{statusSummary}\n{actionText}\n{notesText}\n\nBest regards,\n{accountName} Team\n{supportEmail}`;

    return {
      global: {
        apiKey: process.env.RESEND_API_KEY || "",
        from: "noreply@mclearanceisam.com",
        fromName: "M-Clearance",
        accountName: "M-Clearance",
        supportEmail: "support@mclearanceisam.com",
        superAdminEmail: "mclearanceisam@gmail.com",
        maxRetries: Number(process.env.MAX_EMAIL_RETRIES) || 3,
        cooldownSeconds: Number(process.env.MAILERSEND_COOLDOWN_SECONDS) || 60,
        maxAttempts: Number(process.env.MAILERSEND_MAX_ATTEMPTS) || 5,
        portalUrl: process.env.PORTAL_URL || "https://mclearanceisam.com",
        passwordResetRedirectUrl:
          process.env.PASSWORD_RESET_REDIRECT_URL ||
          process.env.PORTAL_URL ||
          "https://mclearanceisam.com/reset-password",
      },
      templates: {
        verification: {
          defaultLanguage: "en",
          tags: ["email_verification"],
          languages: {
            en: {
              subject: "Verify your email address - {accountName}",
              html: verificationHtmlEn,
              text: verificationTextEn,
            },
            id: {
              subject: "Verifikasi alamat email Anda - {accountName}",
              html: verificationHtmlId,
              text: verificationTextId,
            },
          },
        },
        passwordReset: {
          subject: "Password reset request - {accountName}",
          html: "<p>Hello {name},</p><p>You requested to reset your password.</p><p>You can create a new password using the link below:</p><p><a href='{resetLink}'>{resetLink}</a></p><p>If you didn’t request a reset, you can safely ignore this email.</p><p>Regards,<br/>{accountName} Team</p>",
          text: "Hello {name},\n\nYou requested a password reset for {accountName}. Use the following link to set a new password:\n{resetLink}\n\nIf you didn’t request this, you can ignore this message.\n\nRegards, {accountName} Team",
          tags: ["password_reset"],
        },
        approval: {
          subject: "Application approved - {accountName}",
          html: clearanceStatusHtml,
          text: clearanceStatusText,
          tags: ["application_approval"],
        },
        revision: {
          subject: "Application requires revision - {accountName}",
          html: clearanceStatusHtml,
          text: clearanceStatusText,
          tags: ["application_revision"],
        },
        rejection: {
          subject: "Application update - {accountName}",
          html: clearanceStatusHtml,
          text: clearanceStatusText,
          tags: ["application_rejection"],
        },
      },
    };
  }

  async getGlobalSettings() {
    const config = await this.getConfig();
    // Handle both RTDB flat structure and fallback nested structure
    const globalConfig = config.global || config;
    return {
      apiKey: globalConfig.apiKey || process.env.RESEND_API_KEY || "",
      from: globalConfig.fromEmail || globalConfig.from || "",
      fromName: globalConfig.fromName || "M-Clearance System",
      accountName:
        globalConfig.accountName ||
        globalConfig.fromName ||
        "M-Clearance System",
      supportEmail:
        globalConfig.supportEmail ||
        globalConfig.fromEmail ||
        globalConfig.from ||
        "",
      maxRetries: globalConfig.maxRetries || 3,
      cooldownSeconds: globalConfig.cooldownSeconds || 60,
      maxAttempts: globalConfig.maxAttempts || 5,
      superAdminEmail:
        globalConfig.superAdminEmail || "mclearanceisam@gmail.com",
      portalUrl:
        globalConfig.portalUrl ||
        process.env.PORTAL_URL ||
        "https://mclearanceisam.com",
      passwordResetRedirectUrl:
        globalConfig.passwordResetRedirectUrl ||
        process.env.PASSWORD_RESET_REDIRECT_URL ||
        process.env.PORTAL_URL ||
        "https://mclearanceisam.com/reset-password",
    };
  }

  async getTemplateSettings(templateName = "verification", language = "en") {
    const config = await this.getConfig();
    // Handle both RTDB flat structure and fallback nested structure
    const templatesConfig = config.templates || config;
    const defaults = this.getFallbackConfig().templates || {};
    const rawTemplate = templatesConfig[templateName] || {};
    const defaultTemplate = defaults[templateName] || {};

    const mergedLanguages = {
      ...(defaultTemplate.languages || {}),
      ...(rawTemplate.languages || {}),
    };

    const normalizedLang = (
      language ||
      rawTemplate.defaultLanguage ||
      defaultTemplate.defaultLanguage ||
      "en"
    ).toLowerCase();
    const langKey = normalizedLang.split("-")[0];

    const localized =
      mergedLanguages[normalizedLang] || mergedLanguages[langKey] || {};
    const fallbackLang = mergedLanguages[rawTemplate.defaultLanguage]?.subject
      ? mergedLanguages[rawTemplate.defaultLanguage]
      : mergedLanguages[defaultTemplate.defaultLanguage] || {};

    const subject =
      localized.subject ||
      fallbackLang.subject ||
      rawTemplate.subject ||
      defaultTemplate.subject ||
      "Notification";
    const html =
      localized.html ||
      fallbackLang.html ||
      rawTemplate.html ||
      defaultTemplate.html ||
      "<p>{code}</p>";
    const text =
      localized.text ||
      fallbackLang.text ||
      rawTemplate.text ||
      defaultTemplate.text ||
      "{code}";
    const tags = rawTemplate.tags || defaultTemplate.tags || [];

    return {
      subject,
      html,
      text,
      tags,
      language: normalizedLang,
    };
  }
}

const emailConfig = new EmailConfigService();
const FONT_DIR = path.join(__dirname, "fonts");
const IMMIGRATION_LOGO_DATA = null; // Will be loaded from storage
const ISAM_LOGO_DATA = null; // Will be loaded from storage

function normalizeEmails(value) {
  if (!value) return null;
  const array = Array.isArray(value) ? value : [value];
  const cleaned = array
    .map((item) => (item || "").toString().trim())
    .filter((item) => item.length > 0);
  if (cleaned.length === 0) return null;
  return Array.from(new Set(cleaned));
}

function isValidEmail(value) {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  if (!trimmed) return false;
  // Lightweight sanity guard; defers strict RFC validation to the provider.
  return /.+@.+\..+/.test(trimmed);
}

function normalizeTags(value) {
  if (!value) return null;
  const source = Array.isArray(value) ? value : [value];
  const normalized = source
    .map((tag) => {
      if (typeof tag === "string") {
        return { name: tag };
      }
      if (tag && typeof tag === "object") {
        const name = typeof tag.name === "string" ? tag.name : undefined;
        if (name) {
          const entry = { name };
          if (
            Object.prototype.hasOwnProperty.call(tag, "value") &&
            typeof tag.value === "string"
          ) {
            entry.value = tag.value;
          }
          return entry;
        }
      }
      return null;
    })
    .filter(Boolean);
  return normalized.length > 0 ? normalized : null;
}

function escapeHtml(input) {
  if (typeof input !== "string" || input.length === 0) return input || "";
  return input
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function sanitizeTextNode(input) {
  if (typeof input !== "string") return "";
  return input
    .replace(/[<>]/g, "")
    .replace(/&/g, " and ")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

async function loadImageAsDataUrl(relativePath) {
  try {
    const fullPath = path.join(__dirname, relativePath);
    const buffer = fs.readFileSync(fullPath);
    const lower = relativePath.toLowerCase();
    const mime = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
      ? 'jpeg'
      : lower.endsWith('.svg')
        ? 'svg+xml'
        : 'png';
    return `data:image/${mime};base64,${buffer.toString('base64')}`;
  } catch (error) {
    console.warn('[loadImageAsDataUrl] Failed to load asset:', relativePath, error);
    return null;
  }
}

async function loadLogoFromStorage() {
  try {
    const bucket = admin.storage().bucket();
    console.log('[loadLogoFromStorage] Attempting to load logos from storage');

    // Try to load immigration logo - use the same logo for both to save memory
    const logoPaths = ['app_logo/immigration_logo.png', 'immigration_logo.png'];
    let logoData = null;

    for (const path of logoPaths) {
      try {
        const file = bucket.file(path);
        const [exists] = await file.exists();
        if (exists) {
          console.log(`[loadLogoFromStorage] Found logo at: ${path}`);
          const [buffer] = await file.download();

          // Optimize memory usage - use smaller base64 encoding
          logoData = `data:image/png;base64,${buffer.toString('base64')}`;
          break;
        }
      } catch (pathError) {
        console.warn(`[loadLogoFromStorage] Failed to load from ${path}:`, pathError.message);
      }
    }

    console.log('[loadLogoFromStorage] Logo loading result:', !!logoData);

    // Return the same logo for both to save memory
    return {
      immigrationLogo: logoData,
      isamLogo: logoData
    };
  } catch (error) {
    console.error('[loadLogoFromStorage] Failed to load logos from storage:', error);
    return { immigrationLogo: null, isamLogo: null };
  }
}

function generateClearanceCodeValue(applicationId, type) {
  const prefix =
    typeof type === "string" && type.toLowerCase().startsWith("dep")
      ? "DEP"
      : "ARR";
  const now = new Date();
  const stamp = now
    .toISOString()
    .replace(/[-:T.]/g, "")
    .slice(0, 14);
  const sanitizedId = (applicationId || "")
    .toString()
    .replace(/[^a-zA-Z0-9]/g, "")
    .toUpperCase();
  const idFragment =
    sanitizedId.length >= 6
      ? sanitizedId.slice(0, 6)
      : sanitizedId.padEnd(6, "X");
  const random = Math.floor(Math.random() * 9000) + 1000;
  return `ISAM-${prefix}-${stamp}-${idFragment}-${random}`;
}

async function createShortUrl(longUrl) {
  try {
    // Generate a simple short ID based on timestamp and random number
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substring(2, 8);
    const shortId = `${timestamp}${random}`;

    // Store the mapping in Firestore for later retrieval
    const shortUrlRef = db.collection('shortUrls').doc(shortId);
    await shortUrlRef.set({
      originalUrl: longUrl,
      shortId: shortId,
      createdAt: FieldValue.serverTimestamp(),
      clickCount: 0,
    });

    // Return the short URL format
    return `https://mclearanceisam.com/s/${shortId}`;
  } catch (error) {
    console.error('[createShortUrl] Failed to create short URL:', error);
    return longUrl; // Fallback to original URL if shortening fails
  }
}

function emailPreferenceAllowsApplicationUpdates(preferences) {
  if (preferences === false) return false;
  if (!preferences || typeof preferences !== "object") return true;

  if (preferences.applicationUpdatesEmail === false) return false;
  if (preferences.applicationUpdates === false) return false;

  const emailPref = preferences.email;
  if (emailPref === false) return false;
  if (emailPref && typeof emailPref === "object") {
    if (emailPref.enabled === false) return false;
    if (emailPref.applicationUpdates === false) return false;
  }

  return true;
}

function applyTemplate(template, replacements = {}) {
  const replaceAll = (input) => {
    let output = input || "";
    for (const [key, value] of Object.entries(replacements)) {
      const pattern = new RegExp(`\\{${key}\\}`, "g");
      output = output.replace(pattern, value ?? "");
    }
    return output;
  };

  return {
    subject: replaceAll(template.subject || ""),
    html: replaceAll(template.html || ""),
    text: replaceAll(template.text || ""),
    tags: template.tags || [],
  };
}

async function sendEmailFromTemplate({
  templateName,
  language,
  to,
  cc,
  bcc,
  replacements = {},
  includeSuperAdmin = false,
  globalSettings,
  templateSettings,
}) {
  const resolvedGlobal =
    globalSettings || (await emailConfig.getGlobalSettings());
  const resolvedTemplate =
    templateSettings ||
    (await emailConfig.getTemplateSettings(templateName, language));

  const senderAddress = (resolvedGlobal.from || "").trim();
  if (!isValidEmail(senderAddress)) {
    console.error(
      "[sendEmailFromTemplate] Invalid or missing sender address:",
      senderAddress,
    );
    throw new functions.https.HttpsError(
      "failed-precondition",
      "Email sender address is not configured correctly.",
    );
  }

  const finalReplacements = {
    accountName: resolvedGlobal.accountName,
    supportEmail: resolvedGlobal.supportEmail || resolvedGlobal.from,
    ...replacements,
  };

  const rendered = applyTemplate(resolvedTemplate, finalReplacements);

  const toList = normalizeEmails(to);
  if (!toList || toList.length === 0) {
    throw new Error("No email recipients specified.");
  }

  const ccList = normalizeEmails(cc);
  const bccList = normalizeEmails(bcc);
  const finalBcc = new Set(bccList || []);

  if (includeSuperAdmin && resolvedGlobal.superAdminEmail) {
    if (isValidEmail(resolvedGlobal.superAdminEmail)) {
      finalBcc.add(resolvedGlobal.superAdminEmail.trim());
    } else {
      console.warn(
        "[sendEmailFromTemplate] Skipped invalid super admin email:",
        resolvedGlobal.superAdminEmail,
      );
    }
  }

  if (!resolvedGlobal.apiKey && !process.env.RESEND_API_KEY) {
    console.warn(
      "[sendEmailFromTemplate] Missing Resend API key. Email skipped.",
    );
    return;
  }

  const resend = new Resend(
    resolvedGlobal.apiKey || process.env.RESEND_API_KEY,
  );

  const message = {
    from: `${resolvedGlobal.fromName || "M-Clearance"} <${senderAddress}>`,
    to: toList,
    subject: rendered.subject,
    html: rendered.html,
    text: rendered.text,
  };

  const replyToCandidate =
    (resolvedGlobal.supportEmail && resolvedGlobal.supportEmail.trim()) ||
    senderAddress;
  if (isValidEmail(replyToCandidate)) {
    message.reply_to = replyToCandidate;
  }

  if (ccList && ccList.length > 0) {
    const filtered = ccList.filter((address) => isValidEmail(address));
    if (filtered.length > 0) {
      message.cc = filtered;
    }
  }
  if (finalBcc.size > 0) {
    const filteredBcc = Array.from(finalBcc).filter((address) =>
      isValidEmail(address),
    );
    if (filteredBcc.length > 0) {
      message.bcc = filteredBcc;
    }
  }
  const normalizedTags = normalizeTags(rendered.tags);
  if (normalizedTags) {
    message.tags = normalizedTags;
  }

  console.log("[sendEmailFromTemplate] Dispatching email via Resend", {
    to: message.to,
    subject: message.subject,
    hasCc: Array.isArray(message.cc) && message.cc.length > 0,
    hasBcc: Array.isArray(message.bcc) && message.bcc.length > 0,
    tags: message.tags || [],
  });

  const { error } = await resend.emails.send(message);
  if (error) {
    throw new Error(error.message || "Failed to send email via Resend");
  }
}

/**
 * onAuth user create
 * - Create users/{uid} doc if absent with initial fields aligned to app schema
 * - Idempotent updates when doc already exists
 * - If email is already verified, set isEmailVerified=true and status=pending_documents once
 */
exports.onUserCreate = functions
  .region("asia-southeast1")
  .runWith({
    memory: "1GB",
    timeoutSeconds: 300
  })
  .auth.user()
  .onCreate(async (user) => {
    console.log(
      "[onUserCreate] Function triggered for user:",
      user.uid,
      "email:",
      user.email,
      "emailVerified:",
      user.emailVerified,
    );

    const uid = user.uid;
    const email = user.email || "";
    console.log(
      "[onUserCreate] Processing uid:",
      uid,
      "emailVerified:",
      !!user.emailVerified,
    );

    // Best-effort to assign default role via custom claims; swallow errors to avoid retries
    try {
      console.log("[onUserCreate] Setting custom claims for uid:", uid);
      await admin.auth().setCustomUserClaims(uid, { role: "user" });
      console.log(
        "[onUserCreate] Custom claims set successfully for uid:",
        uid,
      );
    } catch (e) {
      console.error(
        "[onUserCreate] setCustomUserClaims failed for uid:",
        uid,
        "error:",
        e,
      );
    }

    const userRef = db.collection("users").doc(uid);
    console.log("[onUserCreate] User ref created for uid:", uid);

    try {
      console.log("[onUserCreate] Starting transaction for uid:", uid);
      await db.runTransaction(async (txn) => {
        console.log(
          "[onUserCreate] Inside transaction, getting user doc for uid:",
          uid,
        );
        const snap = await txn.get(userRef);
        const now = FieldValue.serverTimestamp();
        console.log(
          "[onUserCreate] User doc exists:",
          snap.exists,
          "for uid:",
          uid,
        );

        if (!snap.exists) {
          const verified = !!user.emailVerified;
          const initDoc = {
            email,
            uid,
            role: "user",
            status: verified
              ? "pending_documents"
              : "pending_email_verification",
            isEmailVerified: verified,
            hasUploadedDocuments: false,
            documents: [],
            createdAt: now,
            updatedAt: now,
          };
          console.log(
            "[onUserCreate] Setting initial user doc for uid:",
            uid,
            "with status:",
            initDoc.status,
          );
          txn.set(userRef, initDoc);
          console.log("[onUserCreate] Created user doc:", uid);

          // Update counters if status is pending_approval (though initially it's not)
          if (initDoc.status === "pending_approval") {
            console.log(
              "[onUserCreate] Updating counters for initial status pending_approval",
            );
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
        if (typeof data.hasUploadedDocuments !== "boolean")
          updates.hasUploadedDocuments = false;
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
          console.log(
            "[onUserCreate] Updating existing user doc for uid:",
            uid,
            "with updates:",
            updates,
          );
          txn.update(userRef, updates);
          console.log(
            "[onUserCreate] Updated existing user doc:",
            uid,
            updates,
          );

          // Update counters if status changed
          if (updates.status && updates.status !== oldStatus) {
            console.log(
              "[onUserCreate] Updating counters for status change from",
              oldStatus,
              "to",
              updates.status,
            );
            await updateUserCounters(oldStatus, updates.status);
          }
        } else {
          console.log("[onUserCreate] No-op for existing user doc:", uid);
        }
      });
      console.log(
        "[onUserCreate] Transaction completed successfully for uid:",
        uid,
      );
    } catch (error) {
      console.error(
        "[onUserCreate] Transaction error for uid:",
        uid,
        "error:",
        error,
      );
    }
    console.log("[onUserCreate] Function completed for uid:", uid);
  });

/**
 * onUserDocUpdate status/queue sync
 * - When user uploads documents or moves pending_documents -> pending_approval:
 *     * Ensure status becomes pending_approval once (from pending_documents)
 *     * Enqueue a review item (reviewQueue) idempotently
 * - When status transitions to approved/rejected:
 *     * Create a notification item under notifications/{uid}/items idempotently
 */
exports.onUserDocUpdate = functions
  .region("asia-southeast1")
  .firestore.document("users/{uid}")
  .onUpdate(async (change, context) => {
    const uid = context.params.uid;
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const userRef = change.after.ref;

    const beforeStatus = before.status || "pending_email_verification";
    const afterStatus = after.status || "pending_email_verification";
    const email = after.email || before.email || "";

    const becameApproved =
      beforeStatus !== "approved" && afterStatus === "approved";
    const becameRejected =
      beforeStatus !== "rejected" && afterStatus === "rejected";
    const hasDocsNowTrue =
      before.hasUploadedDocuments !== true &&
      after.hasUploadedDocuments === true;
    const movedToPendingApproval =
      beforeStatus === "pending_documents" &&
      afterStatus === "pending_approval";
    const shouldEnforcePendingApproval =
      beforeStatus === "pending_documents" &&
      (hasDocsNowTrue || afterStatus === "pending_approval");

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
            console.log(
              "[onUserDocUpdate] Enforced pending_approval for uid:",
              uid,
            );
            // Update counters for the enforced status change
            await updateUserCounters(curStatus, "pending_approval");
          } else {
            console.log(
              "[onUserDocUpdate] Skipped enforcement; current status:",
              curStatus,
            );
          }
        });
      }

      // 2) Update counters for status changes
      if (beforeStatus !== afterStatus) {
        await updateUserCounters(beforeStatus, afterStatus);
        console.log(
          "[onUserDocUpdate] Updated counters for status change:",
          beforeStatus,
          "->",
          afterStatus,
        );
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
          console.log(
            "[onUserDocUpdate] Review item already exists:",
            reviewId,
          );
        }

        const accountName =
          after.corporateName ||
          after.fullName ||
          after.username ||
          email ||
          uid;
        await notifyRoles(
          ["officer", "admin"],
          {
            id: reviewId,
            title: "New account pending review",
            body: `Account ${accountName} is ready for verification.`,
            type: 0,
            extra: {
              status: "pending_approval",
              targetUid: uid,
            },
          },
          { skipUid: uid },
        );
      }

      // 4) Notifications on terminal decision transitions (approved/rejected)
      if (becameApproved || becameRejected) {
        const statusType = becameApproved ? "approved" : "rejected";
        const decidedAtMs = getUpdatedAtMillis();
        const timestamp = Timestamp.fromMillis(decidedAtMs);
        const title =
          statusType === "approved" ? "Account Approved" : "Account Rejected";
        const body =
          statusType === "approved"
            ? "Your account has been approved. You can now access all features."
            : `Your account has been rejected${after.decisionNote ? `: ${after.decisionNote}` : "."}`;
        const notifId = `${statusType}_${decidedAtMs}`;

        await recordNotification(uid, {
          id: notifId,
          title,
          body,
          timestamp,
          type: statusType === "approved" ? 1 : 0,
          extra: {
            status: statusType,
            decidedBy: after.decidedBy || before.decidedBy || null,
          },
        });
        console.log("[onUserDocUpdate] Created notification:", notifId);

        const accountName =
          after.corporateName ||
          after.fullName ||
          after.username ||
          after.email ||
          uid;
        await notifyRoles(
          ["officer", "admin"],
          {
            title:
              statusType === "approved"
                ? "Account verified"
                : "Account rejected",
            body: `Account ${accountName} has been ${statusType}.`,
            timestamp,
            type: 0,
            extra: {
              status: statusType,
              targetUid: uid,
            },
          },
          { skipUid: uid },
        );
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
exports.onDocumentFinalize = functions
  .region("asia-southeast1")
  .runWith({
    memory: "1GB",
    timeoutSeconds: 300
  })
  .storage.object()
  .onFinalize(async (object) => {
    try {
      const name = object.name; // e.g., "users/<uid>/documents/<filename>"
      const bucket = object.bucket;

      if (!name || !bucket) {
        console.log(
          "[onDocumentFinalize] Missing object name or bucket, skipping.",
        );
        return;
      }

      const parts = name.split("/");
      let uid = null;
      let filename = parts[parts.length - 1] || "document";

      // Support either "users/{uid}/documents/..." or "documents/{uid}/..."
      if (
        parts.length >= 4 &&
        parts[0] === "users" &&
        parts[2] === "documents"
      ) {
        uid = parts[1];
      } else if (parts.length >= 2 && parts[0] === "documents") {
        uid = parts[1];
      }

      if (!uid) {
        console.log(
          "[onDocumentFinalize] Object path is not a recognized user document path:",
          name,
        );
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

        const normalizeReference = (value) => {
          if (!value || typeof value !== "string") return "";
          const trimmed = value.trim();
          if (!trimmed) return "";
          if (trimmed.startsWith("gs://")) {
            const withoutProtocol = trimmed.slice(5);
            const slashIndex = withoutProtocol.indexOf("/");
            if (slashIndex === -1) return withoutProtocol;
            return withoutProtocol.slice(slashIndex + 1);
          }
          if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
            try {
              const uri = new URL(trimmed);
              const segments = uri.pathname.split("/").filter(Boolean);
              const oIndex = segments.indexOf("o");
              if (oIndex !== -1 && oIndex + 1 < segments.length) {
                const encoded = segments[oIndex + 1];
                return decodeURIComponent(encoded);
              }
              if (segments.length) {
                return decodeURIComponent(segments[segments.length - 1]);
              }
            } catch (error) {
              console.warn(
                "[onDocumentFinalize] Failed to normalise URL reference",
                error,
              );
            }
            return trimmed;
          }
          return trimmed;
        };

        const existingKeys = docs
          .map((d) => {
            if (!d || typeof d !== "object") return "";
            const ref =
              d.storagePath || d.downloadUrl || d.path || d.url || d.reference;
            return normalizeReference(ref);
          })
          .filter((v) => Boolean(v));

        const candidateKey = normalizeReference(storagePath);
        const alreadyPresent =
          existingKeys.includes(candidateKey) ||
          docs.some((d) => {
            if (!d || typeof d !== "object") return false;
            const docName = (d.documentName || "").toString().toLowerCase();
            return docName && docName === filename.toLowerCase();
          });

        if (alreadyPresent) {
          console.log(
            "[onDocumentFinalize] Document already recorded for uid:",
            uid,
            storagePath,
          );
          return;
        }

        // Use object.timeCreated to keep uploadedAt deterministic for idempotency
        const uploadedAt = object.timeCreated
          ? Timestamp.fromDate(new Date(object.timeCreated))
          : FieldValue.serverTimestamp();

        const inferDocumentType = (value) => {
          if (!value) return null;
          const lower = value.toLowerCase();
          if (lower.includes("ktp")) return "ktp";
          if (lower.includes("nib")) return "nib";
          return null;
        };

        const metadata = object.metadata || {};
        const documentType =
          metadata.documentType || inferDocumentType(filename);
        const originalName =
          metadata.originalName || metadata.original_name || filename;
        const downloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(
          name,
        )}?alt=media`;

        const entry = {
          documentName: filename,
          storagePath: name,
          downloadUrl,
          uploadedAt,
        };

        if (documentType) {
          entry.documentType = documentType;
        }

        if (originalName) {
          entry.originalName = originalName;
        }

        // Append without touching status; do not mutate updatedAt here to avoid unintended triggers
        txn.update(userRef, {
          documents: FieldValue.arrayUnion(entry),
        });

        console.log(
          "[onDocumentFinalize] Appended document entry for uid:",
          uid,
          entry,
        );
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
exports.setUserRole = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    const role = await callerRole(context);
    if (role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Admin role required.",
      );
    }

    const targetUid = (data && data.uid) || "";
    const newRole = (data && data.role) || "";
    if (!targetUid || !["user", "officer", "admin"].includes(newRole)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Provide uid and role in [user|officer|admin].",
      );
    }

    await admin.auth().setCustomUserClaims(targetUid, { role: newRole });

    const userRef = db.collection("users").doc(targetUid);
    const now = FieldValue.serverTimestamp();
    await userRef.set({ role: newRole, updatedAt: now }, { merge: true });

    return { ok: true, uid: targetUid, role: newRole };
  });

/**
 * generateClearanceDocument (helper)
 * Generates a PDF document containing the application data with M-Clearance ISam logo and uploads it to Firebase Storage.
 */
async function generateClearanceDocument(uid, application, officerUid = null) {
  // Load logos from Firebase Storage
  const logos = await loadLogoFromStorage();
  const immigrationLogo = logos.immigrationLogo;
  const isamLogo = logos.isamLogo;
  console.log(
    "[generateClearanceDocument] Starting PDF generation for user:",
    uid,
    "application:",
    application.id,
  );

  try {
    const PDFMake = require("pdfmake");
    console.log("[generateClearanceDocument] PDFMake loaded successfully");

    const fonts = {
      Roboto: {
        normal: path.join(FONT_DIR, "Roboto-Regular.ttf"),
        bold: path.join(FONT_DIR, "Roboto-Bold.ttf"),
        italics: path.join(FONT_DIR, "Roboto-Italic.ttf"),
        bolditalics: path.join(FONT_DIR, "Roboto-BoldItalic.ttf"),
      },
    };
    const pdfMake = new PDFMake(fonts);
    console.log("[generateClearanceDocument] PDFMake instance created");

    const bucket = admin.storage().bucket();
    const generatedMillis = Date.now();
    const safeShipName = (application.shipName || "Unknown").replace(
      /[^a-zA-Z0-9]/g,
      "_",
    );
    const rawApplicationId = application.id || safeShipName || "application";
    const filename = `clearance_documents/${uid}/${rawApplicationId}_${generatedMillis}.pdf`;
    const downloadToken = crypto.randomUUID();
    const encodedPath = encodeURIComponent(filename);
    const bucketName = bucket.name;
    const longDownloadUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodedPath}?alt=media&token=${downloadToken}`;

    // Create short URL for better QR code scannability
    const shortDownloadUrl = await createShortUrl(longDownloadUrl);
    const downloadUrl = shortDownloadUrl !== longDownloadUrl ? shortDownloadUrl : longDownloadUrl;
    const clearanceCode =
      (application.clearanceCode && application.clearanceCode.trim()) ||
      generateClearanceCodeValue(rawApplicationId, application.type);

    const asDate = (value) => {
      if (!value) return null;
      if (typeof value === "number") return new Date(value);
      if (typeof value === "string") {
        const parsed = Date.parse(value);
        return Number.isNaN(parsed) ? null : new Date(parsed);
      }
      if (value.toDate) {
        try {
          return value.toDate();
        } catch (error) {
          console.warn(
            "[generateClearanceDocument] Unable to convert Firestore Timestamp via toDate():",
            error,
          );
        }
      }
      if (value.toMillis) {
        try {
          return new Date(value.toMillis());
        } catch (error) {
          console.warn(
            "[generateClearanceDocument] Unable to convert Firestore Timestamp via toMillis():",
            error,
          );
        }
      }
      return null;
    };

    const formatDate = (value, fallback = "N/A") => {
      const date = asDate(value);
      if (!date || Number.isNaN(date.getTime())) return fallback;
      return date.toLocaleString("en-US", {
        day: "2-digit",
        month: "long",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      });
    };

    const submittedAtText = formatDate(application.createdAt);
    const approvedAtText = formatDate(application.updatedAt);
    const status = (application.status || "").toString().toUpperCase() || "N/A";
    const applicationTypeRaw = (application.type || "")
      .toString()
      .toLowerCase();
    const applicationType =
      applicationTypeRaw === "arrival" || applicationTypeRaw === "kedatangan"
        ? "Arrival"
        : applicationTypeRaw === "departure" ||
            applicationTypeRaw === "keberangkatan"
          ? "Departure"
          : applicationTypeRaw || "Arrival";

    const officerName =
      application.clearanceResultSignedBy ||
      application.officerName ||
      "Immigration Officer";
    const officerCorporate =
      application.clearanceResultSignedByCorporate ||
      application.officerCorporateName ||
      "Directorate General of Immigration";

    // Logos are already loaded above

    const officerNameClean = sanitizeTextNode(officerName);
    const officerCorporateClean = sanitizeTextNode(officerCorporate);

    const agentCorporateName = sanitizeTextNode(
      application.agentCorporateName ||
        application.corporateName ||
        application.agentCompany ||
        application.agentOrganization ||
        application.agentName ||
        "Shipping Agency",
    );
    const agentPersonName = sanitizeTextNode(
      application.agentContactName ||
        application.agentRepresentative ||
        application.agentFullName ||
        application.agentPerson ||
        application.agentContact ||
        application.agentName ||
        "Authorized Representative",
    );

    const agentDisplayPair =
      agentCorporateName === agentPersonName
        ? agentCorporateName
        : `${agentCorporateName} - ${agentPersonName}`;
    const officerDisplayPair =
      officerCorporateClean === officerNameClean
        ? officerCorporateClean
        : `${officerCorporateClean} - ${officerNameClean}`;

    const agentQrPayload = `${uid}`;
    const officerQrPayload = `OFFICER_${officerUid || 'SYSTEM'}`;

    const headerColumns = [
      {
        width: 'auto',
        alignment: 'left',
        stack: [
          ...(immigrationLogo
            ? [
                {
                  image: immigrationLogo,
                  width: 60,
                  margin: [0, 0, 0, 8],
                },
              ]
            : []),
          {
            text: 'Directorate General of Immigration',
            style: 'companyHeader',
          },
          {
            text: 'Republic of Indonesia',
            style: 'companySubheader',
          },
        ],
      },
      {
        width: '*',
        alignment: 'right',
        stack: [
          {
            width: 90,
            stack: [
              {
                width: 85,
                stack: [
                  {
                    qr: downloadUrl,
                    fit: 85,
                    alignment: 'right',
                  },
                  // Removed small logo from center top header - keeping only left logo
                ],
              },
            ],
          },
          {
            text: clearanceCode,
            style: 'qrLabel',
            alignment: 'right',
            margin: [0, 6, 0, 0],
          },
        ],
      },
    ];

    const docDefinition = {
      content: [
        {
          columns: headerColumns,
          columnGap: 15,
          margin: [0, 0, 0, 8],
        },
        {
          canvas: [
            {
              type: "line",
              x1: 0,
              y1: 0,
              x2: 515,
              y2: 0,
              lineWidth: 1.5,
              lineColor: "#003049",
            },
          ],
          margin: [0, 0, 0, 12],
        },
        {
          text: "Immigration Clearance Certificate",
          style: "title",
        },
        {
          text: "Official confirmation of vessel clearance approval",
          style: "subtitle",
          margin: [0, 0, 0, 18],
        },
        {
          columns: [
            {
              width: "*",
              table: {
                widths: [160, "*"],
                body: [
                  [
                    { text: "Application ID", style: "label" },
                    { text: rawApplicationId, style: "value" },
                  ],
                  [
                    { text: "Vessel Name", style: "label" },
                    { text: application.shipName || "N/A", style: "value" },
                  ],
                  [
                    { text: "Flag", style: "label" },
                    { text: application.flag || "N/A", style: "value" },
                  ],
                  [
                    { text: "Agent", style: "label" },
                    { text: application.agentName || "N/A", style: "value" },
                  ],
                  [
                    { text: "Application Type", style: "label" },
                    { text: applicationType, style: "value" },
                  ],
                  [
                    { text: "Declared Voyage", style: "label" },
                    { text: application.date || "N/A", style: "value" },
                  ],
                  [
                    { text: "Location / Port", style: "label" },
                    { text: application.location || "N/A", style: "value" },
                  ],
                  ...(applicationTypeRaw === "arrival"
                    ? [
                        [
                          { text: "Last Port", style: "label" },
                          { text: application.lastPort || application.port || application.lastPortOfCall || application.fromPort || "N/A", style: "value" },
                        ],
                      ]
                    : []),
                  ...(applicationTypeRaw === "departure"
                    ? [
                        [
                          { text: "Next Port", style: "label" },
                          { text: application.nextPort || "N/A", style: "value" },
                        ],
                      ]
                    : []),
                  [
                    { text: "Crew (WNI)", style: "label" },
                    {
                      text:
                        application.wniCrew != null
                          ? String(application.wniCrew)
                          : "0",
                      style: "value",
                    },
                  ],
                  [
                    { text: "Crew (WNA)", style: "label" },
                    {
                      text:
                        application.wnaCrew != null
                          ? String(application.wnaCrew)
                          : "0",
                      style: "value",
                    },
                  ],
                  [
                    { text: "Status", style: "label" },
                    { text: status, style: "value" },
                  ],
                  [
                    { text: "Submitted", style: "label" },
                    { text: submittedAtText, style: "value" },
                  ],
                  [
                    { text: "Approved", style: "label" },
                    { text: approvedAtText, style: "value" },
                  ],
                ],
              },
              layout: "lightHorizontalLines",
            },
          ],
          margin: [0, 0, 0, 12],
        },
        {
          text: "The Directorate General of Immigration certifies that the vessel and documents listed above have been reviewed and meet the clearance requirements set forth by Indonesian immigration authorities.",
          style: "paragraph",
          margin: [0, 0, 0, 18],
        },
        {
          text: "The embedded QR code links to the digitally signed certificate stored in the M-Clearance system. Presenting this certificate verifies the authenticity of the clearance decision for the vessel in question.",
          style: "note",
          margin: [0, 0, 0, 24],
        },
        {
          columns: [
            {
              width: "*",
              stack: [
                { text: "Digital Signature Agen", style: "signatureLabel" },
                {
                  stack: [
                    {
                      qr: agentQrPayload,
                      fit: 70,
                      alignment: "left",
                    },
                  ],
                },
                {
                  text: "Digital acknowledgement via M-Clearance",
                  style: "signatureHint",
                },
                { text: "", margin: [0, 12, 0, 0] },
                { text: "______________________________", style: "signatureLine" },
                { text: agentPersonName, style: "signatureName", margin: [0, 6, 0, 0] },
                { text: agentCorporateName, style: "signatureCorp" },
              ],
            },
            {
              width: "*",
              stack: [
                { text: "Digital Signature Officer Imigrasi", style: "signatureLabel" },
                {
                  stack: [
                    {
                      qr: officerQrPayload,
                      fit: 70,
                      alignment: "left",
                    },
                  ],
                },
                {
                  text: "Ditandatangani secara digital oleh Direktorat Jenderal Imigrasi",
                  style: "signatureHint",
                },
                { text: "", margin: [0, 12, 0, 0] },
                { text: "______________________________", style: "signatureLine" },
                { text: officerNameClean, style: "signatureName", margin: [0, 6, 0, 0] },
                { text: officerCorporateClean, style: "signatureCorp" },
              ],
            },
          ],
          columnGap: 20,
          margin: [0, 0, 0, 10],
        },
        ...(application.notes
          ? [
              {
                text: "Officer Notes",
                style: "notesHeader",
                margin: [0, 0, 0, 6],
              },
              {
                text: application.notes,
                style: "notesText",
                margin: [0, 0, 0, 24],
              },
            ]
          : []),
        {
          text: `Ref: ${rawApplicationId}`,
          style: "footer",
          alignment: "center",
          margin: [0, 3, 0, 0],
        },
      ],
      styles: {
        companyHeader: {
          fontSize: 14,
          bold: true,
          color: "#003049",
        },
        companySubheader: {
          fontSize: 10,
          color: "#495057",
        },
        title: {
          fontSize: 22,
          bold: true,
          color: "#003049",
          margin: [0, 0, 0, 8],
        },
        subtitle: {
          fontSize: 12,
          color: "#495057",
        },
        qrLabel: {
          fontSize: 10,
          bold: true,
          color: "#003049",
        },
        label: {
          fontSize: 10,
          bold: true,
          color: "#495057",
        },
        value: {
          fontSize: 10,
          color: "#212529",
        },
        paragraph: {
          fontSize: 11,
          lineHeight: 1.4,
          color: "#212529",
        },
        note: {
          fontSize: 9,
          italics: true,
          color: "#6c757d",
        },
        signatureLabel: {
          fontSize: 11,
          bold: true,
          color: "#003049",
        },
        signatureHint: {
          fontSize: 9,
          italics: true,
          color: "#6c757d",
        },
        signatureQrLabel: {
          fontSize: 9,
          color: "#1f2937",
        },
        signatureLine: {
          fontSize: 11,
          color: "#adb5bd",
        },
        signatureName: {
          fontSize: 11,
          bold: true,
          color: "#212529",
        },
        signatureCorp: {
          fontSize: 9,
          color: "#6c757d",
        },
        notesHeader: {
          fontSize: 11,
          bold: true,
          color: "#d00000",
        },
        notesText: {
          fontSize: 10,
          color: "#495057",
          lineHeight: 1.3,
        },
        footer: {
          fontSize: 8,
          color: "#6c757d",
          italics: true,
        },
      },
      defaultStyle: {
        font: "Roboto",
      },
    };

    console.log("[generateClearanceDocument] Creating PDF document...");

    // Create PDF document
    const pdfDoc = pdfMake.createPdfKitDocument(docDefinition);
    console.log("[generateClearanceDocument] PDF document created");

    // Use streaming approach to reduce memory usage
    console.log("[generateClearanceDocument] Starting PDF generation with streaming");

    return new Promise((resolve, reject) => {
      const file = bucket.file(filename);

      // Pipe PDF directly to storage to avoid buffering in memory
      const stream = file.createWriteStream({
        metadata: {
          contentType: "application/pdf",
          metadata: {
            firebaseStorageDownloadTokens: downloadToken,
            applicationId: rawApplicationId,
            generatedAt: new Date(generatedMillis).toISOString(),
            generatedBy: officerName,
            clearanceCode,
          },
        },
      });

      stream.on("error", (uploadError) => {
        console.error("[generateClearanceDocument] Upload stream error:", uploadError);
        reject(new Error(`Upload failed: ${uploadError.message}`));
      });

      stream.on("finish", () => {
        console.log("[generateClearanceDocument] PDF uploaded successfully via stream");
        resolve(downloadUrl);
      });

      pdfDoc.pipe(stream);

      pdfDoc.on("error", (error) => {
        console.error("[generateClearanceDocument] PDF generation error:", error);
        stream.end();
        reject(new Error(`PDF generation failed: ${error.message}`));
      });

      pdfDoc.end();
    });
  } catch (e) {
    console.error("[generateClearanceDocument] Unexpected error:", e);
    throw new Error(`PDF generation failed: ${e.message}`);
  }
}

/**
 * Officer/Admin decision on a user account pending approval.
 * Input: { targetUid: string, decision: 'approved'|'rejected', note?: string }
 * Effect: updates users/{uid}.status and updatedAt. Optionally stores decidedBy/note metadata.
 * onUserDocUpdate will generate notifications.
 */
exports.officerDecideAccount = functions
  .region("asia-southeast1")
  .runWith({
    memory: "1GB",
    timeoutSeconds: 300
  })
  .https.onCall(async (data, context) => {
    try {
      requireAuth(context);
      const callerUid = context.auth.uid;
      const userRef = db.collection("users").doc(callerUid);
      const userSnap = await userRef.get();

      if (!userSnap.exists) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Caller user document not found.",
        );
      }

      const userData = userSnap.data() || {};
      const role = userData.role;

      if (role !== "officer" && role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          `Officer or admin role required. Your role is '${role}'.`,
        );
      }

      const targetUid = (data && data.targetUid) || "";
      const decision = (data && data.decision) || "";
      const note = (data && (data.note || data.reason)) || "";

      if (!targetUid || !["approved", "rejected"].includes(decision)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Provide targetUid and decision in [approved|rejected].",
        );
      }

      const callerEmail =
        (context.auth.token && context.auth.token.email) || "";
      const targetUserRef = db.collection("users").doc(targetUid);
      const applicationRef = db.collection("applications").doc(targetUid);

      let applicationData = null;

      await db.runTransaction(async (txn) => {
        const snap = await txn.get(targetUserRef);
        if (!snap.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "User document not found.",
          );
        }
        const data = snap.data() || {};
        const status = data.status || "pending_email_verification";
        if (status !== "pending_approval") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            `User status must be pending_approval. Got: ${status}`,
          );
        }

        if (decision === "approved") {
          const applicationSnap = await txn.get(applicationRef);
          if (applicationSnap.exists) {
            applicationData = {
              id: applicationSnap.id,
              ...(applicationSnap.data() || {}),
            };
          } else {
            logger.warn(
              `[officerDecideAccount] No application document found for uid ${targetUid}. Skipping clearance document generation.`,
            );
          }
        }

        const updates = {
          status: decision,
          updatedAt: FieldValue.serverTimestamp(),
          decidedBy: callerEmail || callerUid,
        };
        if (note && typeof note === "string" && note.length <= 1000) {
          updates.decisionNote = note;
        }
        txn.update(targetUserRef, updates);
      });

      if (decision === "approved" && applicationData) {
        try {
          const documentUrl = await generateClearanceDocument(
            targetUid,
            applicationData,
          );
          await applicationRef.update({
            clearanceDocumentUrl: documentUrl,
            updatedAt: FieldValue.serverTimestamp(),
          });
        } catch (e) {
          logger.error(
            "[officerDecideAccount] generateClearanceDocument error:",
            e,
          );
          await applicationRef.set(
            {
              clearanceDocumentError:
                e.message || "Failed to generate document",
              updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
      }

      return { ok: true, uid: targetUid, status: decision };
    } catch (error) {
      logger.error("[officerDecideAccount] Unexpected error", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error?.message || "Failed to process officer decision.",
      );
    }
  });

exports.logOfficerActivity = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    try {
      requireAuth(context);
      await ensureOfficerOrAdmin(context);

      const uid = context.auth.uid;
      const rawTitle = data && typeof data.title === "string" ? data.title : "";
      const rawDescription =
        data && typeof data.description === "string" ? data.description : "";

      const title = rawTitle.trim();
      if (!title) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "title is required",
        );
      }

      const description = rawDescription.trim() || "No additional details";
      const type =
        data && typeof data.type === "string" && data.type.trim()
          ? data.type.trim()
          : "activity";
      const status =
        data && typeof data.status === "string" && data.status.trim()
          ? data.status.trim()
          : null;
      const iconData =
        data && typeof data.iconData === "string" && data.iconData.trim()
          ? data.iconData.trim()
          : null;

      const activityDoc = {
        userId: uid,
        title,
        description,
        type,
        date: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      };

      if (status) activityDoc.status = status;
      if (iconData) activityDoc.iconData = iconData;

      const metadata =
        data && typeof data.metadata === "object" ? data.metadata : null;
      if (metadata && metadata !== null) {
        const sanitized = {};
        Object.keys(metadata).forEach((key) => {
          const value = metadata[key];
          if (
            value === null ||
            typeof value === "string" ||
            typeof value === "number" ||
            typeof value === "boolean"
          ) {
            sanitized[key] = value;
          }
        });
        if (Object.keys(sanitized).length > 0) {
          activityDoc.metadata = sanitized;
        }
      }

      const activityRef = db.collection("officer_activities").doc();
      await activityRef.set(activityDoc, { merge: false });

      try {
        await db
          .collection("users")
          .doc(uid)
          .collection("activity_logs")
          .doc(activityRef.id)
          .set(activityDoc, { merge: false });
      } catch (fallbackError) {
        logger.warn(
          "[logOfficerActivity] Failed to write fallback activity log",
          fallbackError,
        );
      }

      return { success: true, id: activityRef.id };
    } catch (error) {
      logger.error("[logOfficerActivity] Unexpected error", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error?.message || "Failed to log officer activity.",
      );
    }
  });

exports.sendClearanceCertificate = functions
  .region("asia-southeast1")
  .runWith({
    memory: "2GB",
    timeoutSeconds: 540,
    maxInstances: 100
  })
  .https.onCall(async (data, context) => {
    try {
      requireAuth(context);
      await ensureOfficerOrAdmin(context);

      const applicationId =
        data && typeof data.applicationId === "string"
          ? data.applicationId.trim()
          : "";
      if (!applicationId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "applicationId is required.",
        );
      }

      const applicationRef = db.collection("applications").doc(applicationId);
      const applicationSnap = await applicationRef.get();
      if (!applicationSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          `Application ${applicationId} not found.`,
        );
      }

      const application = {
        id: applicationSnap.id,
        ...(applicationSnap.data() || {}),
      };

      const status = (application.status || "").toString().toLowerCase();
      if (status !== "approved") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Application must be approved before sending eClearance.",
        );
      }

      const agentUid = (application.agentUid || "").toString();
      if (!agentUid) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Application is missing agent information.",
        );
      }

      const officerUid = context.auth.uid;
      const officerDoc = await db.collection("users").doc(officerUid).get();
      const officerData = officerDoc.exists ? officerDoc.data() || {} : {};

      const providedOfficerName =
        data && typeof data.officerName === "string"
          ? data.officerName.trim()
          : "";
      const providedOfficerCorporate =
        data && typeof data.officerCorporateName === "string"
          ? data.officerCorporateName.trim()
          : "";

      const officerName =
        providedOfficerName ||
        officerData.fullName ||
        officerData.name ||
        context.auth.token?.name ||
        context.auth.token?.email ||
        "Immigration Officer";

      const officerCorporate =
        providedOfficerCorporate ||
        officerData.corporateName ||
        officerData.organization ||
        officerName;

      const clearanceCode =
        (application.clearanceCode && application.clearanceCode.trim()) ||
        generateClearanceCodeValue(application.id, application.type);

      const pdfApplication = {
        ...application,
        clearanceResultSignedBy: officerName,
        clearanceResultSignedByCorporate: officerCorporate,
        clearanceCode,
      };

      let downloadUrl;
      try {
        downloadUrl = await generateClearanceDocument(
          agentUid,
          pdfApplication,
          officerUid,
        );
        console.log("[sendClearanceCertificate] PDF generated successfully:", downloadUrl);
      } catch (error) {
        logger.error(
          "[sendClearanceCertificate] generateClearanceDocument failed",
          error,
        );
        console.error("[sendClearanceCertificate] PDF generation error details:", {
          message: error.message,
          stack: error.stack,
          agentUid,
          applicationId,
        });
        throw new functions.https.HttpsError(
          "internal",
          `PDF generation failed: ${error?.message || "Unknown error"}`,
        );
      }

      const updateTimestamp = FieldValue.serverTimestamp();
      console.log("[sendClearanceCertificate] Updating application document:", applicationId);

      await applicationRef.update({
        clearanceResultFile: downloadUrl,
        clearanceResultGeneratedAt: updateTimestamp,
        clearanceResultSentAt: updateTimestamp,
        clearanceResultSignedBy: officerName,
        clearanceResultSignedByCorporate: officerCorporate,
        clearanceCode,
        updatedAt: updateTimestamp,
      });

      console.log("[sendClearanceCertificate] Application document updated successfully");

      const safeShipName = sanitizeTextNode(
        application.shipName || application.vesselName || "your vessel",
      );

      try {
        const notificationTimestamp = Timestamp.now();
        await recordNotification(agentUid, {
          title: "eClearance Available",
          body: `Your clearance document for ${safeShipName} is ready to download.`,
          timestamp: notificationTimestamp,
          type: 1,
          extra: {
            applicationId,
            clearanceCode,
            status: "approved",
            documentUrl: downloadUrl,
          },
        });
      } catch (notifError) {
        logger.warn(
          "[sendClearanceCertificate] Failed to create agent notification",
          notifError,
        );
      }

      let emailSent = false;
      try {
        const agentSnapshot = await db.collection("users").doc(agentUid).get();
        const agentData = agentSnapshot.exists ? agentSnapshot.data() || {} : {};
        const preferences = agentData.notificationPreferences || null;

        const fallbackEmail =
          (application.agentEmail && application.agentEmail.trim()) ||
          (agentData.email && agentData.email.trim()) ||
          "";
        const agentEmail = await resolveUserEmail(agentUid, fallbackEmail);

        console.log("[sendClearanceCertificate] Email resolution:", {
          agentUid,
          fallbackEmail,
          resolvedEmail: agentEmail,
          preferences,
        });

        if (agentEmail && emailPreferenceAllowsApplicationUpdates(preferences)) {
          const typeLabel =
            typeof application.type === "string" &&
            application.type.toLowerCase().includes("departure")
              ? "Departure"
              : "Arrival";

          const globalSettings = await emailConfig.getGlobalSettings();
          console.log("[sendClearanceCertificate] Global settings loaded");

          const portalUrl =
            typeof globalSettings.portalUrl === "string" &&
            globalSettings.portalUrl.trim().length > 0
              ? globalSettings.portalUrl.trim()
              : "https://mclearanceisam.com";

          const languageCandidates = [
            application.language,
            application.locale,
            agentData.preferredLanguage,
            agentData.language,
            agentData.locale,
          ].filter((value) => typeof value === "string" && value.trim().length);
          const emailLanguage =
            languageCandidates.length > 0
              ? languageCandidates[0].trim().toLowerCase()
              : "en";

          const agentDisplayName =
            sanitizeTextNode(
              agentData.corporateName ||
                agentData.fullName ||
                agentData.name ||
                agentData.username ||
                application.agentName ||
                agentEmail,
            ) || "Agent";

          const clearanceTemplate = {
            subject: "eClearance Certificate for {shipName}",
            html: `<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>eClearance Certificate</title>
  </head>
  <body style="margin:0;padding:0;background-color:#f4f6fb;font-family:'Segoe UI',Arial,sans-serif;color:#1f2937;">
    <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%">
      <tr>
        <td align="center" style="padding:24px;">
          <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="max-width:640px;background-color:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 18px 45px rgba(37,99,235,0.18);">
            <tr>
              <td align="left" style="padding:32px 32px 24px 32px;background:linear-gradient(135deg,#1e3a8a 0%,#2563eb 100%);">
                <h1 style="margin:0;font-size:24px;color:#ffffff;letter-spacing:0.5px;text-transform:uppercase;">M-Clearance iSam</h1>
                <p style="margin:12px 0 0 0;font-size:14px;color:rgba(255,255,255,0.78);">Official Clearance Certificate</p>
              </td>
            </tr>
            <tr>
              <td style="padding:32px 32px 40px 32px;">
                <p style="margin:0;font-size:16px;color:#374151;">Hello <strong>{name}</strong>,</p>
                <p style="margin:16px 0 0 0;font-size:16px;color:#4b5563;line-height:1.6;">
                  The <strong>{typeLabel}</strong> clearance for your vessel <strong>{shipName}</strong> has been completed. The official eClearance document is now available.
                </p>
                <table role="presentation" cellspacing="0" cellpadding="0" border="0" width="100%" style="margin:24px 0;background:#f3f4f6;border-radius:12px;">
                  <tr>
                    <td style="padding:20px 24px;">
                      <p style="margin:0;font-size:14px;color:#6b7280;">Clearance Code</p>
                      <p style="margin:6px 0 0 0;font-size:20px;font-weight:700;color:#1d4ed8;letter-spacing:0.08em;">{clearanceCode}</p>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding:0 24px 24px 24px;">
                      <a href="{downloadUrl}" style="display:inline-block;padding:14px 22px;background-color:#2563eb;color:#ffffff;text-decoration:none;font-size:15px;font-weight:600;border-radius:10px;">Download eClearance</a>
                    </td>
                  </tr>
                </table>
                <p style="margin:0 0 16px 0;font-size:15px;color:#4b5563;line-height:1.6;">
                  Signed by: <strong>{officerName}</strong><br />
                  {officerCorporate}
                </p>
                <p style="margin:0 0 24px 0;font-size:15px;color:#4b5563;line-height:1.6;">
                  You can also access this document anytime from your dashboard: <a href="{portalUrl}" style="color:#2563eb;">{portalUrl}</a>
                </p>
                <p style="margin:0;font-size:13px;color:#6b7280;">If you did not request this clearance or believe this email was sent in error, please contact our support team immediately.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`,
            text: `Hello {name},\n\nYour {typeLabel} clearance for {shipName} is complete.\nClearance Code: {clearanceCode}\n\nDownload the eClearance document here: {downloadUrl}\n\nSigned by: {officerName} - {officerCorporate}\nPortal: {portalUrl}\n\nIf you did not request this clearance, please contact support immediately.\n\nRegards,\n{accountName}\nSupport: {supportEmail}`,
            tags: [{ name: "notification", value: "clearanceCertificate" }],
          };

          console.log("[sendClearanceCertificate] Sending email to:", agentEmail);
          await sendEmailFromTemplate({
            templateName: "clearanceCertificate",
            language: emailLanguage,
            to: agentEmail,
            replacements: {
              name: agentDisplayName,
              shipName: safeShipName,
              typeLabel,
              downloadUrl,
              clearanceCode,
              officerName: sanitizeTextNode(officerName),
              officerCorporate: sanitizeTextNode(officerCorporate),
              portalUrl,
            },
            includeSuperAdmin: true,
            globalSettings,
            templateSettings: clearanceTemplate,
          });

          emailSent = true;
          console.log("[sendClearanceCertificate] Email sent successfully");
        } else {
          console.log("[sendClearanceCertificate] Email not sent - no valid email or preferences disabled");
        }
      } catch (emailError) {
        logger.error(
          "[sendClearanceCertificate] Failed to dispatch email",
          emailError,
        );
        console.error("[sendClearanceCertificate] Email error details:", {
          message: emailError.message,
          stack: emailError.stack,
          agentUid,
        });
        // Don't throw here - email failure shouldn't fail the whole operation
      }

      const responsePayload = {
        ok: true,
        applicationId,
        downloadUrl,
        clearanceCode,
        signedBy: officerName,
        signedByCorporate: officerCorporate,
        emailSent,
        sentAt: new Date().toISOString(),
      };

      logger.info(
        "[sendClearanceCertificate] Completed callable",
        responsePayload,
      );

      return responsePayload;
    } catch (error) {
      logger.error("[sendClearanceCertificate] Unexpected error", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error?.message || "Failed to send clearance certificate.",
      );
    }
  });

exports.getOfficerActivities = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    try {
      requireAuth(context);
      await ensureOfficerOrAdmin(context);

      const uid = context.auth.uid;
      const rawLimit =
        data && typeof data.limit !== "undefined" ? Number(data.limit) : 10;
      const limit = Number.isFinite(rawLimit)
        ? Math.min(Math.max(Math.floor(rawLimit), 1), 50)
        : 10;

      const buildQuery = (ref) =>
        ref.where("userId", "==", uid).orderBy("date", "desc").limit(limit);

      const serializeDoc = (doc) => {
        const payload = doc.data() || {};
        const result = {
          id: doc.id,
          ...payload,
        };

        if (payload.date instanceof Timestamp) {
          result.date = payload.date.toMillis();
        }
        if (payload.createdAt instanceof Timestamp) {
          result.createdAt = payload.createdAt.toMillis();
        }

        return result;
      };

      let snapshot = await buildQuery(
        db.collection("officer_activities"),
      ).get();

      if (snapshot.empty) {
        snapshot = await buildQuery(
          db.collection("users").doc(uid).collection("activity_logs"),
        ).get();
      }

      return snapshot.docs.map(serializeDoc);
    } catch (error) {
      logger.error("[getOfficerActivities] Unexpected error", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error?.message || "Failed to load officer activities.",
      );
    }
  });

/**
 * - pendingArrival/pendingDeparture: applications awaiting review by type
 */
exports.getOfficerDashboardStats = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    await ensureOfficerOrAdmin(context);

    const functionStart = Date.now();
    console.log("[getOfficerDashboardStats] Function started");

    const startOfDay = new Date();
    startOfDay.setUTCHours(0, 0, 0, 0);

    // Try to get from counters first for better performance
    const countersRef = db.collection("counters").doc("dashboard");
    const countersSnap = await countersRef.get();
    let counters = {};
    if (countersSnap.exists) {
      counters = countersSnap.data() || {};
    }

    // Helper to count a query without loading all docs (fallback)
    async function countQuery(q, label) {
      const queryStart = Date.now();
      try {
        const snap = await q
          .select(admin.firestore.FieldPath.documentId())
          .get();
        const queryTime = Date.now() - queryStart;
        console.log(
          `[getOfficerDashboardStats] ${label} count took ${queryTime}ms, returned ${snap.size} docs`,
        );
        return snap.size;
      } catch (error) {
        logger.error(`[getOfficerDashboardStats] ${label} query failed`, error);
        return 0;
      }
    }

    const usersCol = db.collection("users");
    const applicationsCol = db.collection("applications");

    const countStart = Date.now();

    // Use counters where available, fallback to counting
    const [
      pendingAccounts,
      approvedToday,
      rejectedToday,
      pendingArrival,
      pendingDeparture,
    ] = await Promise.all([
      counters.pendingAccounts !== undefined
        ? Promise.resolve(counters.pendingAccounts)
        : countQuery(
            usersCol.where("status", "==", "pending_approval"),
            "pendingAccounts",
          ),
      countQuery(
        usersCol
          .where("status", "==", "approved")
          .where("updatedAt", ">=", Timestamp.fromDate(startOfDay)),
        "approvedToday",
      ),
      countQuery(
        usersCol
          .where("status", "==", "rejected")
          .where("updatedAt", ">=", Timestamp.fromDate(startOfDay)),
        "rejectedToday",
      ),
      counters.pendingArrival !== undefined
        ? Promise.resolve(counters.pendingArrival)
        : countQuery(
            applicationsCol
              .where("type", "==", "arrival")
              .where("status", "==", "waiting"),
            "pendingArrival",
          ),
      counters.pendingDeparture !== undefined
        ? Promise.resolve(counters.pendingDeparture)
        : countQuery(
            applicationsCol
              .where("type", "==", "departure")
              .where("status", "==", "waiting"),
            "pendingDeparture",
          ),
    ]);

    const countTime = Date.now() - countStart;
    console.log(`[getOfficerDashboardStats] All counts took ${countTime}ms`);

    const totalTime = Date.now() - functionStart;
    console.log(
      `[getOfficerDashboardStats] Total function time: ${totalTime}ms`,
    );

    return {
      pendingAccounts,
      approvedToday,
      rejectedToday,
      pendingArrival,
      pendingDeparture,
    };
  });
/**
 * Get officer monthly statistics
 */
exports.getOfficerMonthlyStats = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    await ensureOfficerOrAdmin(context);

    const now = new Date();
    const startInput =
      typeof data?.startDate === "string" ? new Date(data.startDate) : null;
    const endInput =
      typeof data?.endDate === "string" ? new Date(data.endDate) : null;

    const start =
      startInput && !Number.isNaN(startInput.getTime())
        ? startInput
        : new Date(now.getFullYear(), now.getMonth(), 1);
    const end = endInput && !Number.isNaN(endInput.getTime()) ? endInput : now;

    start.setHours(0, 0, 0, 0);
    end.setHours(23, 59, 59, 999);

    const startTs = Timestamp.fromDate(start);
    const endTs = Timestamp.fromDate(end);

    const applicationsCol = db.collection("applications");
    const usersCol = db.collection("users");

    async function countQuery(query, label) {
      try {
        const snapshot = await query
          .select(admin.firestore.FieldPath.documentId())
          .get();
        logger.info(
          `[getOfficerMonthlyStats] ${label} returned ${snapshot.size} docs`,
        );
        return snapshot.size;
      } catch (error) {
        logger.error(`[getOfficerMonthlyStats] ${label} query failed`, error);
        return 0;
      }
    }

    const [
      arrivalTotal,
      arrivalPending,
      arrivalApproved,
      arrivalDeclined,
      arrivalRevision,
      arrivalProduced,
      departureTotal,
      departurePending,
      departureApproved,
      departureDeclined,
      departureRevision,
      departureProduced,
      accountsTotal,
      accountsPending,
      accountsApproved,
      accountsRejected,
    ] = await Promise.all([
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "arrival_total",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("status", "==", "waiting")
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "arrival_pending",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("status", "==", "approved")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "arrival_approved",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("status", "==", "declined")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "arrival_declined",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("status", "==", "revision")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "arrival_revision",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "arrival")
          .where("clearanceResultGeneratedAt", ">=", startTs)
          .where("clearanceResultGeneratedAt", "<=", endTs),
        "arrival_produced",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "departure_total",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("status", "==", "waiting")
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "departure_pending",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("status", "==", "approved")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "departure_approved",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("status", "==", "declined")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "departure_declined",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("status", "==", "revision")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "departure_revision",
      ),
      countQuery(
        applicationsCol
          .where("type", "==", "departure")
          .where("clearanceResultGeneratedAt", ">=", startTs)
          .where("clearanceResultGeneratedAt", "<=", endTs),
        "departure_produced",
      ),
      countQuery(
        usersCol
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "accounts_total",
      ),
      countQuery(
        usersCol
          .where("status", "==", "pending_approval")
          .where("createdAt", ">=", startTs)
          .where("createdAt", "<=", endTs),
        "accounts_pending",
      ),
      countQuery(
        usersCol
          .where("status", "==", "approved")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "accounts_approved",
      ),
      countQuery(
        usersCol
          .where("status", "==", "rejected")
          .where("updatedAt", ">=", startTs)
          .where("updatedAt", "<=", endTs),
        "accounts_rejected",
      ),
    ]);

    const arrivalProcessed = arrivalApproved + arrivalDeclined;
    const departureProcessed = departureApproved + departureDeclined;
    const accountsProcessed = accountsApproved + accountsRejected;

    return {
      range: {
        start: start.toISOString(),
        end: end.toISOString(),
      },
      arrival: {
        total: arrivalTotal,
        pending: arrivalPending,
        approved: arrivalApproved,
        declined: arrivalDeclined,
        revision: arrivalRevision,
        produced: arrivalProduced,
        processed: arrivalProcessed,
      },
      departure: {
        total: departureTotal,
        pending: departurePending,
        approved: departureApproved,
        declined: departureDeclined,
        revision: departureRevision,
        produced: departureProduced,
        processed: departureProcessed,
      },
      accounts: {
        total: accountsTotal,
        pending: accountsPending,
        approved: accountsApproved,
        rejected: accountsRejected,
        processed: accountsProcessed,
      },
      totals: {
        pending: arrivalPending + departurePending + accountsPending,
        approved: arrivalApproved + departureApproved + accountsApproved,
        rejected: arrivalDeclined + departureDeclined + accountsRejected,
        revision: arrivalRevision + departureRevision,
        produced: arrivalProduced + departureProduced,
        applications: arrivalTotal + departureTotal,
      },
    };
  });

/**
 * issueEmailVerificationCode (callable)
 * Generates a short-lived 4-digit code for email verification and stores it on users/{uid}.
 * Optionally integrate with email provider; for now we only store and return masked info.
 */
exports.issueEmailVerificationCode = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    console.log(
      "[issueEmailVerificationCode] Function started for uid:",
      context.auth.uid,
    );
    const startTime = Date.now();
    requireAuth(context);
    const uid = context.auth.uid;
    const userRef = db.collection("users").doc(uid);

    console.time("[issueEmailVerificationCode] Config fetch");
    // Fetch dynamic configuration
    const globalSettings = await emailConfig.getGlobalSettings();
    const requestedLanguage =
      typeof data?.language === "string" && data.language.trim().length > 0
        ? data.language.trim().toLowerCase()
        : "en";
    const templateSettings = await emailConfig.getTemplateSettings(
      "verification",
      requestedLanguage,
    );
    console.timeEnd("[issueEmailVerificationCode] Config fetch");
    console.log(
      "[issueEmailVerificationCode] Config fetched in",
      Date.now() - startTime,
      "ms",
    );

    console.time("[issueEmailVerificationCode] Transaction");
    // Optimized transaction: minimize reads, use server timestamps
    let code, now, expiresAt, emailDocId;
    try {
      const result = await db.runTransaction(async (txn) => {
        const snap = await txn.get(userRef);
        const data = snap.exists ? snap.data() || {} : {};
        const ver = data.verification || {};
        const issuedAt = ver.issuedAt;
        const nowTs = FieldValue.serverTimestamp(); // Use server timestamp for consistency
        if (issuedAt && typeof issuedAt.toMillis === "function") {
          const elapsedSec = Math.floor(
            (Timestamp.now().toMillis() - issuedAt.toMillis()) / 1000,
          );
          const remain = (globalSettings.cooldownSeconds || 60) - elapsedSec;
          if (remain > 0) {
            return { cooldown: true, retryAfterSec: remain };
          }
        }
        const raw = Math.floor(Math.random() * 10000);
        const newCode = raw.toString().padStart(4, "0");
        const expires = Timestamp.fromMillis(
          Timestamp.now().toMillis() + 10 * 60 * 1000,
        );
        const mailId = `${uid}_${Date.now()}`; // Use Date.now() for uniqueness
        txn.set(
          userRef,
          {
            verification: {
              code: newCode,
              issuedAt: nowTs,
              expiresAt: expires,
              attempts: 0,
              emailDocId: mailId,
            },
            updatedAt: nowTs,
          },
          { merge: true },
        );
        return {
          code: newCode,
          now: Timestamp.now(),
          expiresAt: expires,
          emailDocId: mailId,
        };
      });
      console.timeEnd("[issueEmailVerificationCode] Transaction");
      console.log(
        "[issueEmailVerificationCode] Transaction completed in",
        Date.now() - startTime,
        "ms",
      );
      if (result && result.cooldown) {
        return {
          ok: false,
          reason: "cooldown",
          retryAfterSec: result.retryAfterSec,
        };
      }
      ({ code, now, expiresAt, emailDocId } = result);
    } catch (e) {
      console.error("[issueEmailVerificationCode] transaction failed:", e);
      throw e;
    }

    console.log("[issueEmailVerificationCode] uid:", uid, "code_issued");
    console.time("[issueEmailVerificationCode] User resolution");
    // Send email directly using Resend API
    const tokenEmail =
      (context.auth && context.auth.token && context.auth.token.email) || "";
    const recipientEmail = await resolveUserEmail(uid, tokenEmail);
    const recipientName = await resolveUserName(uid, tokenEmail);
    console.timeEnd("[issueEmailVerificationCode] User resolution");
    console.log(
      "[issueEmailVerificationCode] User resolved in",
      Date.now() - startTime,
      "ms",
    );

    if (!recipientEmail) {
      console.warn(
        "[issueEmailVerificationCode] Could not resolve recipient email for uid:",
        uid,
      );
      return { ok: true, sent: false, reason: "noRecipientEmail" };
    }

    console.time("[issueEmailVerificationCode] Email send");
    try {
      // Initialize Resend client
      const resend = new Resend(process.env.RESEND_API_KEY);

      const safeAccountName =
        globalSettings.accountName || globalSettings.fromName || "M-Clearance";
      const supportEmail =
        globalSettings.supportEmail ||
        globalSettings.from ||
        "support@mclearanceisam.com";
      const expiresInMinutes = 10;

      const subjectTemplate =
        templateSettings.subject || "Your verification code";
      const subject = subjectTemplate
        .replace(/{name}/g, recipientName)
        .replace(/{code}/g, code)
        .replace(/{accountName}/g, safeAccountName)
        .replace(/{supportEmail}/g, supportEmail)
        .replace(/{language}/g, requestedLanguage);

      const htmlTemplate =
        templateSettings.html ||
        "<p>Hello {name},</p><p>Your verification code is <b>{code}</b>.</p>";
      const html = htmlTemplate
        .replace(/{name}/g, recipientName)
        .replace(/{code}/g, code)
        .replace(/{accountName}/g, safeAccountName)
        .replace(/{supportEmail}/g, supportEmail)
        .replace(/{language}/g, requestedLanguage)
        .replace(/{expiresInMinutes}/g, expiresInMinutes.toString());

      const textTemplate =
        templateSettings.text ||
        "Hello {name},\nYour verification code is {code}.";
      const text = textTemplate
        .replace(/{name}/g, recipientName)
        .replace(/{code}/g, code)
        .replace(/{accountName}/g, safeAccountName)
        .replace(/{supportEmail}/g, supportEmail)
        .replace(/{language}/g, requestedLanguage)
        .replace(/{expiresInMinutes}/g, expiresInMinutes.toString());

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
      console.timeEnd("[issueEmailVerificationCode] Email send");
      console.log(
        "[issueEmailVerificationCode] Email sent in",
        Date.now() - startTime,
        "ms",
      );

      if (error) {
        console.error(
          "[issueEmailVerificationCode] Failed to send email:",
          error,
        );
        return {
          ok: true,
          sent: false,
          reason: "sendFailed",
          error: error.message,
        };
      }

      console.log(
        "[issueEmailVerificationCode] Email sent successfully:",
        data,
      );
      console.log(
        "[issueEmailVerificationCode] Total function time:",
        Date.now() - startTime,
        "ms",
      );
      return { ok: true, sent: true, messageId: data?.id };
    } catch (e) {
      // If thrown by cooldown guard
      if (
        e &&
        typeof e.message === "string" &&
        e.message.startsWith("cooldown:")
      ) {
        const remain = Number(e.message.split(":")[1] || "60");
        return { ok: false, reason: "cooldown", retryAfterSec: remain };
      }
      console.error("[issueEmailVerificationCode] Failed to send email:", e);
      console.log(
        "[issueEmailVerificationCode] Total function time before error:",
        Date.now() - startTime,
        "ms",
      );
      return { ok: true, sent: false, reason: "sendFailed", error: e.message };
    }
  });

exports.sendPasswordResetEmailLink = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    const rawEmail =
      data && typeof data.email === "string" ? data.email.trim() : "";
    if (!rawEmail) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Email is required.",
      );
    }

    const email = rawEmail.toLowerCase();
    const requestedLanguage =
      data &&
      typeof data.language === "string" &&
      data.language.trim().length > 0
        ? data.language.trim().toLowerCase()
        : null;

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
    } catch (error) {
      if (error && error.code === "auth/user-not-found") {
        console.warn(
          "[sendPasswordResetEmailLink] No auth user found for email, returning success to avoid enumeration:",
          email,
        );
        return { ok: true };
      }
      logger.error(
        "[sendPasswordResetEmailLink] Failed to resolve user by email",
        error,
      );
      throw new functions.https.HttpsError(
        "internal",
        "Failed to process password reset request.",
      );
    }

    const uid = userRecord.uid;
    let userDocData = null;
    if (uid) {
      try {
        const userSnap = await db.collection("users").doc(uid).get();
        if (userSnap.exists) {
          userDocData = userSnap.data() || {};
        }
      } catch (fetchError) {
        console.warn(
          "[sendPasswordResetEmailLink] Failed to fetch Firestore user document:",
          uid,
          fetchError,
        );
      }
    }

    const languageCandidates = [
      requestedLanguage,
      userDocData && typeof userDocData.preferredLanguage === "string"
        ? userDocData.preferredLanguage
        : null,
      userDocData && typeof userDocData.language === "string"
        ? userDocData.language
        : null,
      userDocData && typeof userDocData.locale === "string"
        ? userDocData.locale
        : null,
    ].filter(Boolean);
    const language =
      languageCandidates.length > 0
        ? languageCandidates[0].toLowerCase()
        : "en";

    const globalSettings = await emailConfig.getGlobalSettings();
    const templateSettings = await emailConfig.getTemplateSettings(
      "passwordReset",
      language,
    );

    let resetLink;

    const redactError = (error) => ({
      code: error?.code || error?.errorInfo?.code || null,
      message: error?.message || null,
    });

    try {
      resetLink = await admin.auth().generatePasswordResetLink(email);
    } catch (error) {
      if (error && error.code === "auth/user-not-found") {
        console.warn(
          "[sendPasswordResetEmailLink] generatePasswordResetLink user-not-found for email:",
          email,
        );
        return { ok: true };
      }
      const errorDetail = redactError(error);
      logger.error(
        "[sendPasswordResetEmailLink] Failed to generate reset link",
        error,
      );
      console.error(
        "[sendPasswordResetEmailLink] Failure detail:",
        errorDetail,
      );
      throw new functions.https.HttpsError(
        "internal",
        "Could not generate password reset link.",
        errorDetail,
      );
    }

    if (language && typeof language === "string") {
      const separator = resetLink.includes("?") ? "&" : "?";
      resetLink = `${resetLink}${separator}lang=${encodeURIComponent(language)}`;
    }

    const nameCandidates = [
      userDocData && typeof userDocData.corporateName === "string"
        ? userDocData.corporateName
        : null,
      userDocData && typeof userDocData.fullName === "string"
        ? userDocData.fullName
        : null,
      userDocData && typeof userDocData.username === "string"
        ? userDocData.username
        : null,
      userDocData && typeof userDocData.name === "string"
        ? userDocData.name
        : null,
      userRecord.displayName,
    ].filter((value) => typeof value === "string" && value.trim().length > 0);
    const resolvedName =
      nameCandidates.length > 0
        ? nameCandidates[0].trim()
        : await resolveUserName(uid, email);

    try {
      await sendEmailFromTemplate({
        templateName: "passwordReset",
        language,
        to: email,
        replacements: {
          name: resolvedName,
          resetLink,
        },
        includeSuperAdmin: true,
        globalSettings,
        templateSettings,
      });
    } catch (error) {
      logger.error(
        "[sendPasswordResetEmailLink] Failed to dispatch email",
        error,
      );
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send password reset email.",
      );
    }

    return { ok: true };
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
exports.initializeCounters = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    await ensureOfficerOrAdmin(context);

    console.log("[initializeCounters] Starting counter initialization");

    const countersRef = db.collection("counters").doc("dashboard");

    // Count users
    const pendingAccountsSnap = await db
      .collection("users")
      .where("status", "==", "pending_approval")
      .select(admin.firestore.FieldPath.documentId())
      .get();
    const pendingAccounts = pendingAccountsSnap.size;

    // Count applications
    const pendingArrivalSnap = await db
      .collection("applications")
      .where("type", "==", "arrival")
      .where("status", "==", "waiting")
      .select(admin.firestore.FieldPath.documentId())
      .get();
    const pendingArrival = pendingArrivalSnap.size;

    const pendingDepartureSnap = await db
      .collection("applications")
      .where("type", "==", "departure")
      .where("status", "==", "waiting")
      .select(admin.firestore.FieldPath.documentId())
      .get();
    const pendingDeparture = pendingDepartureSnap.size;

    await countersRef.set({
      pendingAccounts,
      pendingArrival,
      pendingDeparture,
      lastUpdated: FieldValue.serverTimestamp(),
    });

    console.log("[initializeCounters] Counters initialized:", {
      pendingAccounts,
      pendingArrival,
      pendingDeparture,
    });

    return {
      success: true,
      counters: { pendingAccounts, pendingArrival, pendingDeparture },
    };
  });

exports.verifyEmailCode = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    const uid = context.auth.uid;
    const submitted = data && data.code ? String(data.code) : "";
    if (!/^\d{4}$/.test(submitted)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Invalid code format.",
      );
    }

    const userRef = db.collection("users").doc(uid);

    // Fetch dynamic configuration
    const globalSettings = await emailConfig.getGlobalSettings();

    // Use transaction for atomic verification
    await db.runTransaction(async (txn) => {
      const snap = await txn.get(userRef);
      if (!snap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User document not found.",
        );
      }
      const doc = snap.data() || {};
      const ver = doc.verification || {};
      const code = ver.code || "";
      const expiresAt = ver.expiresAt;
      const attempts = Number(ver.attempts || 0);

      if (!code) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "No active verification code.",
        );
      }
      if (attempts >= (globalSettings.maxAttempts || 5)) {
        throw new functions.https.HttpsError(
          "resource-exhausted",
          "Too many attempts. Please request a new code later.",
        );
      }
      if (expiresAt && typeof expiresAt.toMillis === "function") {
        if (Timestamp.now().toMillis() > expiresAt.toMillis()) {
          throw new functions.https.HttpsError(
            "deadline-exceeded",
            "Code expired.",
          );
        }
      }
      if (code !== submitted) {
        txn.update(userRef, { "verification.attempts": attempts + 1 });
        throw new functions.https.HttpsError(
          "permission-denied",
          "Incorrect code.",
        );
      }

      // Mark Auth user as emailVerified = true (outside transaction for Auth API)
      // Reflect in Firestore and transition status once
      const updates = {
        isEmailVerified: true,
        updatedAt: FieldValue.serverTimestamp(),
        verification: FieldValue.delete(),
      };
      const currentStatus = doc.status || "pending_email_verification";
      if (currentStatus === "pending_email_verification") {
        updates.status = "pending_documents";
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
exports.testEmailSend = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    try {
      console.log("[testEmailSend] Testing direct Resend integration...");

      // Get configuration
      const globalSettings = await emailConfig.getGlobalSettings();
      const templateSettings =
        await emailConfig.getTemplateSettings("verification");

      console.log(
        "[testEmailSend] Global settings:",
        JSON.stringify(globalSettings, null, 2),
      );
      console.log(
        "[testEmailSend] Template settings:",
        JSON.stringify(templateSettings, null, 2),
      );

      // Initialize Resend client
      const resend = new Resend(process.env.RESEND_API_KEY);

      // Test email parameters - use provided data or defaults
      const testRecipient = (data && data.email) || "mclearanceisam@gmail.com";
      const testName = (data && data.name) || "Test User";

      const subject =
        templateSettings.subject || "Test Email - Direct Resend Integration";
      const html = (
        templateSettings.html ||
        "<p>Hello {name},</p><p>This is a test email sent using Resend API.</p><p>Regards,<br/>{accountName}</p>"
      )
        .replace(/{name}/g, testName)
        .replace(/{accountName}/g, globalSettings.accountName);
      const text = (
        templateSettings.text ||
        "Hello {name},\n\nThis is a test email sent using Resend API.\n\nRegards,\n{accountName}"
      )
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

      console.log("[testEmailSend] Sending email to:", testRecipient);
      console.log("[testEmailSend] From:", emailData.from);
      console.log("[testEmailSend] Subject:", emailData.subject);

      // Send the email
      const { data: emailDataResponse, error } =
        await resend.emails.send(emailData);

      if (error) {
        console.error("[testEmailSend] Failed to send email:", error);
        return {
          success: false,
          error: error.message,
          recipient: testRecipient,
          message: "Test email sending failed",
        };
      }

      console.log(
        "[testEmailSend] Email sent successfully:",
        emailDataResponse,
      );

      return {
        success: true,
        messageId: emailDataResponse?.id,
        recipient: testRecipient,
        templateUsed: !!templateSettings.html,
        templateSubject: templateSettings.subject,
        message:
          "Test email sent successfully via direct Resend integration with HTML templates",
      };
    } catch (error) {
      console.error("[testEmailSend] Error:", error);
      return {
        success: false,
        error: error.message,
        message: "Test email sending failed",
      };
    }
  });

/**
 * generateHistoryPDF (callable)
 * Generates a PDF document for application history details with M-Clearance ISam logo.
 */
exports.generateHistoryPDF = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    const uid = context.auth.uid;
    const applicationId = data?.applicationId;

    if (!applicationId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Application ID is required.",
      );
    }

    try {
      console.log(
        "[generateHistoryPDF] Starting PDF generation for application:",
        applicationId,
      );

      // Get application data
      const applicationRef = db.collection("applications").doc(applicationId);
      const applicationSnap = await applicationRef.get();

      if (!applicationSnap.exists) {
        console.error(
          "[generateHistoryPDF] Application not found:",
          applicationId,
        );
        throw new functions.https.HttpsError(
          "not-found",
          "Application not found.",
        );
      }

      const application = {
        id: applicationSnap.id,
        ...(applicationSnap.data() || {}),
      };
      console.log(
        "[generateHistoryPDF] Retrieved application data for:",
        applicationId,
      );

      // Ownership check is handled by Firestore rules

      // Generate PDF
      console.log("[generateHistoryPDF] Calling generateClearanceDocument...");
      const pdfUrl = await generateClearanceDocument(uid, application, null);

      console.log(
        "[generateHistoryPDF] PDF generated successfully for application:",
        applicationId,
        "URL:",
        pdfUrl,
      );
      return { success: true, pdfUrl };
    } catch (error) {
      console.error(
        "[generateHistoryPDF] Error generating PDF for application:",
        applicationId,
        error,
      );

      // Provide more specific error messages
      if (error.code === "not-found") {
        throw error;
      } else if (error.code === "permission-denied") {
        throw error;
      } else {
        // Log the full error for debugging
        console.error("[generateHistoryPDF] Full error details:", {
          message: error.message,
          stack: error.stack,
          code: error.code,
        });
        throw new functions.https.HttpsError(
          "internal",
          `Failed to generate PDF: ${error.message}`,
        );
      }
    }
  });

/**
 * Applications triggers
 * - Ensure defaults on create
 * - Update counters on create
 * - Notify user on status decision transitions (approved/declined)
 */
exports.onApplicationCreate = functions
  .region("asia-southeast1")
  .firestore.document("applications/{appId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const updates = {};
    if (!data.createdAt) updates.createdAt = FieldValue.serverTimestamp();
    if (!data.updatedAt) updates.updatedAt = FieldValue.serverTimestamp();
    if (!data.status) updates.status = "waiting";
    if (Object.keys(updates).length) {
      await snap.ref.update(updates);
    }

    // Update counters for new application
    const type = data.type || "arrival";
    const status = updates.status || data.status || "waiting";
    await updateApplicationCounters(null, null, type, status);
    console.log(
      "[onApplicationCreate] Updated counters for new application:",
      type,
      status,
    );
  });

exports.onApplicationUpdate = functions
  .region("asia-southeast1")
  .firestore.document("applications/{appId}")
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
        await updateApplicationCounters(
          beforeType,
          beforeStatus,
          afterType,
          afterStatus,
        );
        console.log(
          "[onApplicationUpdate] Updated counters for application change:",
          beforeType,
          beforeStatus,
          "->",
          afterType,
          afterStatus,
        );
      }

      if (!userUid) return;

      const becameApproved =
        before.status !== "approved" && after.status === "approved";
      const becameDeclined =
        before.status !== "declined" && after.status === "declined";
      const becameRevision =
        before.status !== "revision" && after.status === "revision";
      if (!(becameApproved || becameDeclined || becameRevision)) return;

      const status = becameApproved
        ? "approved"
        : becameDeclined
          ? "declined"
          : "revision";
      const type = after.type || before.type || "arrival";
      const shipName = after.shipName || before.shipName || type;
      const officerName = after.officerName || before.officerName;
      const note = after.notes || before.notes;

      let corporateName =
        after.corporateName ||
        before.corporateName ||
        after.agentName ||
        before.agentName ||
        null;
      let agentUserData = null;

      if (userUid) {
        try {
          const userSnapshot = await db.collection("users").doc(userUid).get();
          if (userSnapshot.exists) {
            agentUserData = userSnapshot.data() || {};
          }
        } catch (fetchError) {
          console.warn(
            "[onApplicationUpdate] Failed fetching agent user data:",
            userUid,
            fetchError,
          );
        }
      }

      if (!corporateName && agentUserData) {
        corporateName =
          agentUserData.corporateName ||
          agentUserData.fullName ||
          agentUserData.name ||
          agentUserData.username ||
          agentUserData.email ||
          corporateName;
      }

      const applicationDate =
        after.date ||
        before.date ||
        after.arrivalDate ||
        before.arrivalDate ||
        after.departureDate ||
        before.departureDate ||
        null;

      const titleMap = {
        approved: "Application Approved",
        declined: "Application Declined",
        revision: "Application Requires Revision",
      };

      let body = "";
      switch (status) {
        case "approved":
          body = `Your ${type} application for ${shipName} has been approved.`;
          break;
        case "declined":
          body = `Your ${type} application for ${shipName} has been declined.`;
          break;
        case "revision":
          body = `Your ${type} application for ${shipName} requires additional information.`;
          break;
        default:
          body = `Your ${type} application for ${shipName} has been updated.`;
          break;
      }

      if (note) {
        body = `${body} Officer notes: ${note}`;
      }

      const timestamp = Timestamp.now();
      const notifId = `${context.params.appId}_${status}_${timestamp.toMillis()}`;
      await recordNotification(userUid, {
        id: notifId,
        title: titleMap[status] || "Application Update",
        body,
        timestamp,
        type: status === "approved" ? 1 : status === "revision" ? 2 : 0,
        extra: {
          applicationId: context.params.appId,
          applicationType: type,
          status,
          officerName: officerName || null,
          officerNote: note || null,
        },
      });
      console.log("[onApplicationUpdate] Notification created:", notifId);

      await notifyRoles(
        ["officer", "admin"],
        {
          title: "Application status changed",
          body: `${corporateName || "Applicant"} - ${shipName}${
            applicationDate ? ` (${applicationDate})` : ""
          } has been ${
            status === "revision" ? "marked for revision" : status
          }.`,
          type: 0,
          timestamp,
          extra: {
            applicationId: context.params.appId,
            status,
            targetUid: userUid,
            corporateName: corporateName || null,
            shipName,
            applicationDate: applicationDate || null,
          },
        },
        { skipUid: userUid },
      );

      try {
        const normalizedType =
          typeof type === "string" && type.length > 0
            ? type.toLowerCase()
            : "arrival";
        const typeLabel =
          normalizedType === "arrival"
            ? "Arrival"
            : normalizedType === "departure"
              ? "Departure"
              : sanitizeTextNode(type || "Clearance");
        const safeShipName = sanitizeTextNode(shipName) || "your vessel";
        const officerNoteText = note ? sanitizeTextNode(note) : "";
        const documentUrlCandidate =
          after.clearanceDocumentUrl ||
          after.clearanceResultFile ||
          before.clearanceDocumentUrl ||
          before.clearanceResultFile ||
          null;
        const safeDocumentUrl =
          typeof documentUrlCandidate === "string" &&
          /^https?:\/\//i.test(documentUrlCandidate)
            ? documentUrlCandidate
            : null;

        const globalSettings = await emailConfig.getGlobalSettings();
        const portalUrl =
          typeof globalSettings.portalUrl === "string" &&
          globalSettings.portalUrl.trim().length > 0
            ? globalSettings.portalUrl.trim()
            : "https://mclearanceisam.com";

        const statusEmailMeta = {
          approved: {
            templateName: "approval",
            statusLabel: "Approved",
            headline: "Clearance Approved",
            summary: `Your ${typeLabel.toLowerCase()} clearance for ${safeShipName} has been approved.`,
            action: safeDocumentUrl
              ? `Download the clearance certificate or sign in to the portal (${portalUrl}).`
              : `Sign in to the portal to review the clearance package: ${portalUrl}.`,
          },
          declined: {
            templateName: "rejection",
            statusLabel: "Declined",
            headline: "Clearance Declined",
            summary: `We were unable to approve your ${typeLabel.toLowerCase()} clearance for ${safeShipName}.`,
            action: `Review the details and next steps in the portal: ${portalUrl}.`,
          },
          revision: {
            templateName: "revision",
            statusLabel: "Needs Revision",
            headline: "Additional Information Required",
            summary: `Your ${typeLabel.toLowerCase()} clearance for ${safeShipName} requires additional information.`,
            action: `Provide the requested updates in the portal: ${portalUrl}.`,
          },
        };

        const emailMeta = statusEmailMeta[status];
        if (!emailMeta) {
          console.warn(
            "[onApplicationUpdate] Missing email metadata for status:",
            status,
          );
          return;
        }

        const agentEmailCandidates = [
          typeof after.agentEmail === "string" ? after.agentEmail : null,
          typeof before.agentEmail === "string" ? before.agentEmail : null,
          agentUserData && typeof agentUserData.email === "string"
            ? agentUserData.email
            : null,
        ].filter((value) => value && value.trim().length > 0);

        const agentEmailFallback =
          agentEmailCandidates.length > 0 ? agentEmailCandidates[0] : "";
        const agentEmail = await resolveUserEmail(userUid, agentEmailFallback);

        const languageCandidates = [
          typeof after.language === "string" ? after.language : null,
          typeof before.language === "string" ? before.language : null,
          typeof after.locale === "string" ? after.locale : null,
          typeof before.locale === "string" ? before.locale : null,
          agentUserData && typeof agentUserData.preferredLanguage === "string"
            ? agentUserData.preferredLanguage
            : null,
          agentUserData && typeof agentUserData.language === "string"
            ? agentUserData.language
            : null,
          agentUserData && typeof agentUserData.locale === "string"
            ? agentUserData.locale
            : null,
        ].filter((value) => value && value.trim().length > 0);

        const emailLanguage =
          languageCandidates.length > 0
            ? languageCandidates[0].trim().toLowerCase()
            : "en";

        const agentNameCandidates = [
          corporateName,
          agentUserData && agentUserData.fullName,
          agentUserData && agentUserData.username,
          agentUserData && agentUserData.name,
          agentEmail,
        ].filter((value) => value && value.toString().trim().length > 0);

        const agentDisplayName =
          agentNameCandidates.length > 0
            ? agentNameCandidates[0].toString().trim()
            : await resolveUserName(userUid, agentEmail);

        const officerEmails = new Map();
        const addOfficerEmail = (candidate) => {
          if (typeof candidate !== "string") return;
          const trimmed = candidate.trim();
          if (!trimmed || !trimmed.includes("@")) return;
          if (
            agentEmail &&
            agentEmail.trim().length > 0 &&
            trimmed.toLowerCase() === agentEmail.trim().toLowerCase()
          ) {
            return;
          }
          officerEmails.set(trimmed.toLowerCase(), trimmed);
        };

        [
          after.decidedBy,
          before.decidedBy,
          after.officerEmail,
          before.officerEmail,
          after.reviewedByEmail,
          before.reviewedByEmail,
          after.lastUpdatedByEmail,
          before.lastUpdatedByEmail,
        ].forEach(addOfficerEmail);

        if (officerEmails.size === 0) {
          for (const role of ["officer", "admin"]) {
            try {
              const snapshot = await db
                .collection("users")
                .where("role", "==", role)
                .select("email", "status", "notificationPreferences")
                .limit(10)
                .get();
              snapshot.forEach((doc) => {
                const data = doc.data() || {};
                if (data.status && data.status !== "approved") return;
                if (
                  !emailPreferenceAllowsApplicationUpdates(
                    data.notificationPreferences,
                  )
                ) {
                  return;
                }
                addOfficerEmail(data.email);
              });
            } catch (officerFetchError) {
              console.warn(
                `[onApplicationUpdate] Failed to fetch ${role} recipients:`,
                officerFetchError,
              );
            }
          }
        }

        const recipientList = [];
        if (agentEmail && agentEmail.trim().length > 0) {
          recipientList.push(agentEmail.trim());
        }

        const officerList = Array.from(officerEmails.values());
        if (recipientList.length === 0 && officerList.length > 0) {
          recipientList.push(officerList.shift());
        }

        const recipientKeys = new Set(
          recipientList.map((address) => address.toLowerCase()),
        );
        const ccList = officerList.filter(
          (address) => !recipientKeys.has(address.toLowerCase()),
        );

        if (recipientList.length === 0) {
          console.warn(
            "[onApplicationUpdate] Skipped email send due to missing recipients:",
            context.params.appId,
          );
          return;
        }

        const notesHtmlParts = [];
        const notesTextParts = [];

        if (safeDocumentUrl) {
          notesHtmlParts.push(
            `<div class="notes"><strong>Clearance document:</strong> <a href="${safeDocumentUrl}">${safeDocumentUrl}</a></div>`,
          );
          notesTextParts.push(`Clearance document: ${safeDocumentUrl}`);
        }

        if (officerNoteText) {
          notesHtmlParts.push(
            `<div class="notes"><strong>Officer note:</strong> ${officerNoteText}</div>`,
          );
          notesTextParts.push(`Officer note: ${officerNoteText}`);
        }

        const notesParagraph = notesHtmlParts.join("");
        const notesText = notesTextParts.join("\n");

        await sendEmailFromTemplate({
          templateName: emailMeta.templateName,
          language: emailLanguage,
          to: recipientList,
          cc: ccList,
          replacements: {
            name: agentDisplayName,
            shipName: safeShipName,
            type: typeLabel,
            statusLabel: emailMeta.statusLabel,
            statusHeadline: emailMeta.headline,
            statusSummary: emailMeta.summary,
            actionText: emailMeta.action,
            notesParagraph,
            notesText,
          },
          includeSuperAdmin: true,
          globalSettings,
          templateSettings: await emailConfig.getTemplateSettings(
            emailMeta.templateName,
            emailLanguage,
          ),
        });
        console.log(
          "[onApplicationUpdate] Status email dispatched for application:",
          context.params.appId,
        );
      } catch (emailError) {
        console.error(
          "[onApplicationUpdate] Failed to send status email:",
          emailError,
        );
      }
    } catch (e) {
      console.error("[onApplicationUpdate] Error:", e);
    }
  });

async function generateMonthlyReportPDF(uid, stats) {
  console.log(
    "[generateMonthlyReportPDF] Starting PDF generation for user:",
    uid,
  );

  try {
    const PDFMake = require("pdfmake");
    const fonts = {
      Roboto: {
        normal: "node_modules/pdfmake/build/vfs_fonts.js#Roboto-Regular.ttf",
        bold: "node_modules/pdfmake/build/vfs_fonts.js#Roboto-Medium.ttf",
      },
    };
    const pdfMake = new PDFMake(fonts);

    const now = new Date();
    const date = new Date(now.getFullYear(), now.getMonth(), 1);
    const title = `Monthly Report - ${date.getMonth() + 1}/${date.getFullYear()}`;

    const docDefinition = {
      content: [
        { text: title, style: "header", alignment: "center" },
        {
          text: `Generated on: ${now.toLocaleString()}`,
          style: "subheader",
          alignment: "center",
        },
        {
          text: `Generated by: Officer ${uid}`,
          style: "subheader",
          alignment: "center",
        },
        { text: "", margin: [0, 0, 0, 20] },
        {
          table: {
            widths: ["*", "auto"],
            body: [
              [
                { text: "Category", style: "tableHeader" },
                { text: "Count", style: "tableHeader" },
              ],
              ["Pending Arrivals", stats.pendingArrival?.toString() ?? "0"],
              ["Pending Departures", stats.pendingDeparture?.toString() ?? "0"],
              ["Pending Accounts", stats.pendingAccounts?.toString() ?? "0"],
            ],
          },
          layout: "lightHorizontalLines",
        },
      ],
      styles: {
        header: { fontSize: 18, bold: true, margin: [0, 0, 0, 10] },
        subheader: { fontSize: 12, margin: [0, 0, 0, 5] },
        tableHeader: { bold: true, fontSize: 13, color: "black" },
      },
      defaultStyle: { font: "Roboto" },
    };

    const pdfDoc = pdfMake.createPdfKitDocument(docDefinition);
    const chunks = [];
    pdfDoc.on("data", (chunk) => chunks.push(chunk));

    return new Promise((resolve, reject) => {
      pdfDoc.on("end", () => {
        const result = Buffer.concat(chunks);
        resolve(result);
      });
      pdfDoc.on("error", reject);
      pdfDoc.end();
    });
  } catch (e) {
    console.error("[generateMonthlyReportPDF] Unexpected error:", e);
    throw new Error(`PDF generation failed: ${e.message}`);
  }
}

exports.generateMonthlyReport = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    await ensureOfficerOrAdmin(context);

    const { stats } = data;
    const uid = context.auth.uid;

    try {
      const now = new Date();
      const date = new Date(now.getFullYear(), now.getMonth(), 1);
      const title = `Monthly Report - ${date.getMonth() + 1}/${date.getFullYear()}`;

      // Generate PDF
      const pdfBytes = await generateMonthlyReportPDF(uid, stats);

      // Upload to Firebase Storage
      const bucket = admin.storage().bucket();
      const filename = `reports/${uid}/monthly_${date.getFullYear()}_${date.getMonth() + 1}.pdf`;
      const file = bucket.file(filename);

      await file.save(pdfBytes, {
        metadata: { contentType: "application/pdf" },
      });

      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: "03-09-2491",
      });

      // Save report metadata to Firestore
      const reportData = {
        title,
        type: "monthly",
        date: Timestamp.fromDate(date),
        createdBy: uid,
        createdAt: Timestamp.now(),
        pdfUrl: signedUrl,
        stats,
      };

      const reportRef = await db.collection("reports").add(reportData);

      return { success: true, reportId: reportRef.id, pdfUrl: signedUrl };
    } catch (error) {
      logger.error("Error generating monthly report", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to generate monthly report.",
      );
    }
  });

/**
 * Updates the status of a user account.
 * @param {object} data - The data object containing the UID, status, and rejection reason.
 * @param {object} context - The context object containing authentication information.
 * @returns {object} - An object indicating the success of the operation.
 */
exports.updateUserAccountStatus = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    requireAuth(context);
    await ensureOfficerOrAdmin(context);

    const { uid, status, rejectionReason } = data;

    if (!uid || !status) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "UID and status are required.",
      );
    }

    const userRef = db.collection("users").doc(uid);

    try {
      await db.runTransaction(async (transaction) => {
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new functions.https.HttpsError("not-found", "User not found.");
        }

        const updates = {
          status,
          updatedAt: FieldValue.serverTimestamp(),
        };

        if (status === "rejected") {
          updates.rejectionReason = rejectionReason;
        } else {
          updates.rejectionReason = FieldValue.delete();
        }

        transaction.update(userRef, updates);
      });

      return { success: true };
    } catch (error) {
      logger.error("Error updating user account status", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update user account status.",
      );
    }
  });

/**
 * resolveShortUrlHTTP (HTTP endpoint)
 * Resolves a short URL ID to the original long URL for web dashboard
 */
exports.createShortUrl = functions
  .region("asia-southeast1")
  .https.onCall(async (data, context) => {
    const longUrl = data?.longUrl;

    if (!longUrl || typeof longUrl !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "longUrl must be provided as a string.",
      );
    }

    try {
      // Generate a simple short ID based on timestamp and random number
      const timestamp = Date.now().toString(36);
      const random = Math.random().toString(36).substring(2, 8);
      const shortId = `${timestamp}${random}`;

      // Store the mapping in Firestore for later retrieval
      const shortUrlRef = db.collection('shortUrls').doc(shortId);
      await shortUrlRef.set({
        originalUrl: longUrl,
        shortId: shortId,
        createdAt: FieldValue.serverTimestamp(),
        clickCount: 0,
      });

      // Return the short URL format
      return {
        shortUrl: `https://mclearanceisam.com/s/${shortId}`,
        shortId: shortId,
      };
    } catch (error) {
      console.error('[createShortUrl] Failed to create short URL:', error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create short URL.",
      );
    }
  });

exports.resolveShortUrlHTTP = functions
  .region("asia-southeast1")
  .https.onRequest(async (req, res) => {
    console.log("[resolveShortUrlHTTP] Request received:", {
      method: req.method,
      url: req.url,
      query: req.query,
      body: req.body,
      headers: req.headers
    });

    // Enable CORS - set headers first before any other processing
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    res.set('Access-Control-Max-Age', '3600');

    if (req.method === 'OPTIONS') {
      console.log("[resolveShortUrlHTTP] CORS preflight request");
      res.status(204).send('');
      return;
    }

    try {
      const shortId = req.query.id || req.body?.shortId;
      console.log("[resolveShortUrlHTTP] Extracted shortId:", shortId);

      if (!shortId || typeof shortId !== "string") {
        console.log("[resolveShortUrlHTTP] Invalid shortId:", shortId, "Type:", typeof shortId);
        res.status(400).json({
          error: "INVALID_ARGUMENT",
          message: "shortId must be provided as a string."
        });
        return;
      }

      console.log("[resolveShortUrlHTTP] Looking up short URL:", shortId, "Length:", shortId.length);

      const shortUrlRef = db.collection("shortUrls").doc(shortId);
      const shortUrlSnap = await shortUrlRef.get();

      if (!shortUrlSnap.exists) {
        console.log("[resolveShortUrlHTTP] Short URL not found:", shortId);
        res.status(404).json({
          error: "NOT_FOUND",
          message: "Short URL not found or expired."
        });
        return;
      }

      const shortUrlData = shortUrlSnap.data();
      console.log("[resolveShortUrlHTTP] Found short URL data:", Object.keys(shortUrlData));
      const originalUrl = shortUrlData.originalUrl;
      console.log("[resolveShortUrlHTTP] Original URL exists:", !!originalUrl);

      if (!originalUrl) {
        console.log("[resolveShortUrlHTTP] No original URL found for:", shortId, "Data keys:", Object.keys(shortUrlData));
        res.status(404).json({
          error: "NOT_FOUND",
          message: "Original URL not found."
        });
        return;
      }

      console.log("[resolveShortUrlHTTP] Found original URL, updating click count for:", shortId);

      // Update click count
      await shortUrlRef.update({
        clickCount: FieldValue.increment(1),
        lastAccessed: FieldValue.serverTimestamp(),
      });

      console.log("[resolveShortUrlHTTP] Successfully resolved URL for:", shortId, "Original URL:", originalUrl.substring(0, 100) + "...");

      res.status(200).json({
        success: true,
        originalUrl,
        shortId,
        clickCount: (shortUrlData.clickCount || 0) + 1,
      });
    } catch (error) {
      console.error("[resolveShortUrl] Error:", error);
      res.status(500).json({
        error: "INTERNAL",
        message: "Failed to resolve short URL."
      });
    }
  });
