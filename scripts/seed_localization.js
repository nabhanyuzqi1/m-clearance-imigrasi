#!/usr/bin/env node
/**
 * Seed Firestore localization documents from localization_strings.json
 * using the Firebase CLI refresh token for authentication.
 *
 * Requirements:
 *   - Run `firebase login` beforehand so that the CLI stores credentials.
 *   - Ensure the active project is the intended target (firebase use).
 */

const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'm-clearance-imigrasi-sampit';
const VERSION = process.env.LOCALIZATION_VERSION || '1.0.0';
const FIRESTORE_BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`;

function readFirebaseCliConfig() {
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );

  if (!fs.existsSync(configPath)) {
    throw new Error(
      `Firebase CLI config not found at ${configPath}. Run "firebase login" first.`,
    );
  }

  return JSON.parse(fs.readFileSync(configPath, 'utf8'));
}

function loadLocalizationStrings() {
  const filePath = path.join(process.cwd(), 'localization_strings.json');
  if (!fs.existsSync(filePath)) {
    throw new Error(`localization_strings.json not found at ${filePath}`);
  }
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

async function obtainAccessToken(config) {
  const tokens = config.tokens || {};
  const refreshToken = tokens.refresh_token;
  if (!refreshToken) {
    throw new Error(
      'Refresh token not found. Re-run "firebase login" to refresh credentials.',
    );
  }

  const expiresAt = tokens.expires_at;
  const accessToken = tokens.access_token;
  const now = Date.now();

  if (accessToken && expiresAt && Number(expiresAt) - now > 60_000) {
    return accessToken;
  }

  const clientId =
    (config.user && config.user.azp) ||
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
  const clientSecret = 'notasecret';

  const formData = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  });

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: formData.toString(),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `Failed to refresh access token (${response.status}): ${text}`,
    );
  }

  const json = await response.json();
  const newAccessToken = json.access_token;
  if (!newAccessToken) {
    throw new Error('OAuth token response missing access_token');
  }

  // Persist updated tokens for next run.
  const updatedConfig = {
    ...config,
    tokens: {
      ...tokens,
      access_token: newAccessToken,
      expires_at: now + Number(json.expires_in || 3600) * 1000,
    },
  };
  const configPath = path.join(
    os.homedir(),
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  fs.writeFileSync(configPath, JSON.stringify(updatedConfig, null, 2));

  return newAccessToken;
}

function toFirestoreValue(value) {
  if (value === null) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'boolean') return { booleanValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value)
      ? { integerValue: value }
      : { doubleValue: value };
  }
  if (Array.isArray(value)) {
    return {
      arrayValue: {
        values: value.map(toFirestoreValue),
      },
    };
  }
  if (typeof value === 'object') {
    const fields = {};
    for (const [key, nested] of Object.entries(value)) {
      fields[key] = toFirestoreValue(nested);
    }
    return { mapValue: { fields } };
  }
  throw new Error(`Unsupported Firestore value type: ${typeof value}`);
}

function buildDocument(pathSegment, data) {
  const name = `projects/${PROJECT_ID}/databases/(default)/documents/${pathSegment}`;
  const fields = {};
  for (const [key, value] of Object.entries(data)) {
    fields[key] = toFirestoreValue(value);
  }
  return { name, fields };
}

async function seedLocalization() {
  const config = readFirebaseCliConfig();
  const token = await obtainAccessToken(config);
  const stringsData = loadLocalizationStrings();
  const now = Date.now();

  const stringsDoc = {
    strings: stringsData,
    lastUpdated: now,
    version: VERSION,
  };
  const metaDoc = {
    lastUpdated: now,
    version: VERSION,
  };

  const commitBody = {
    writes: [
      { update: buildDocument('localization/strings', stringsDoc) },
      { update: buildDocument('localization/meta', metaDoc) },
    ],
  };

  console.log(
    `Committing localization documents to ${PROJECT_ID} (version ${VERSION})...`,
  );

  const response = await fetch(FIRESTORE_BASE_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(commitBody),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(
      `Firestore commit failed (${response.status}): ${text}`,
    );
  }

  const result = await response.json();
  console.log(
    `Localization documents updated successfully at ${new Date(now).toISOString()}`,
  );
  if (result.writeResults && result.writeResults.length > 0) {
    console.log(
      `Committed ${result.writeResults.length} write(s) to Firestore.`,
    );
  }
}

seedLocalization().catch((err) => {
  console.error('Failed to seed localization data:', err);
  process.exitCode = 1;
});
