# User Flow Checklist

Use this as a living guide to validate user-facing flows after changes.

## Environment
- [ ] Firebase configured (`lib/firebase_options.dart`)
- [ ] Firestore DB ID: `m-clearance-imigrasi-db`
- [ ] Auth enabled for Email/Password

## Localization
- [x] EN/ID keys exist for user screens (home/history/profile)
- [x] Fallback to EN then ID for missing keys

## Authentication
- [x] Login redirects based on Firestore user status
- [x] Logout clears session and cache; refresh stays logged out

## Home
- [x] App bar localized (`userHome.title`)
- [x] Recent applications list (read-only) shows items or empty state
- [ ] Add combined arrival/departure feed (enhancement)

## Submissions
- [ ] Clearance Form UI (placeholder): navigates and displays type + agent name
- [ ] Verification loading (placeholder) screen title localized
- [ ] Clearance result (placeholder) shows vessel name

## Notifications
- [ ] Open user notifications screen (placeholder) and verify localized strings

## Backend Integration Notes
- Applications collection fields expected:
  - `type`: `arrival` | `departure`
  - `status`: `waiting` | `revision` | `approved` | `declined`
  - `agentUid`, `agentName`, `shipName`, `flag`, `updatedAt`
- The app currently reads only; no create/update for user applications yet

## Debug (Web)
- `flutter run -d chrome --web-renderer canvaskit`
- Watch console logs; use Flutter Inspector for widgets

