# Officer Flow Checklist

Use this checklist to validate officer/admin flows end-to-end after any changes. Items marked [x] are expected to work now. Keep this list updated as scope evolves.

## Environment
- [x] Firebase project configured via `lib/firebase_options.dart`
- [x] Firestore: using default database (client and functions)
- [x] Storage bucket: `m-clearance-imigrasi.firebasestorage.app`
- [x] Functions deployed (optional for local dev): `functions/index.js`

## Localization
- [x] English and Indonesian keys exist for officer screens
- [x] No more "not found" in Admin Home (home/report/settings, office name, cards)
- [x] Fallback: if a key missing in current language, use EN then ID
- [ ] Visual check on these screens in EN/ID:
  - [ ] Admin Home (cards + app bar)
  - [ ] Officer Report
  - [ ] Account Verification list/detail
  - [ ] Arrival/Departure Verification list/detail
  - [x] Notifications

## Authentication & Session
- [x] Login as officer/admin routes to Admin Home
- [x] Logout clears FirebaseAuth session and local cache
- [x] Refresh after logout stays logged out (lands on Login)
- [ ] AuthWrapper redirects correctly based on `users/{uid}.status`
  - [ ] officer/admin -> Admin Home
  - [ ] user approved -> User Home
  - [ ] pending_email_verification -> Email Verification
  - [ ] pending_documents -> Upload Documents
  - [ ] pending_approval -> Registration Pending

## Admin Home (Officer)
- [x] Bottom nav labels localized (Home, Report, Settings)
- [x] Cards visible:
  - [x] Arrival Verification (Agent Submissions)
  - [x] Departure Verification (Agent Submissions)
  - [x] Account Verification (Agent Registrations)
- [ ] Tapping each card navigates to respective list screens

## Account Verification
- [ ] List shows items with filters (All/Waiting/Reviewed)
- [ ] Detail shows user data + docs (NIB, KTP) with mock preview
- [ ] Actions:
  - [ ] Reject -> status updates to `rejected` with toast
  - [ ] Verify -> status updates to `approved` with toast

## Arrival/Departure Verification
- [ ] List shows applications (All/Waiting/Reviewed)
- [ ] Detail shows metadata + document checks
- [ ] Actions:
  - [ ] Reject Submission
  - [ ] Require Fixing (Revision notes)
  - [ ] Finish Verification (Approve)

## Notifications
- [ ] Officer notifications page opens from bell icon and Settings
- [ ] "Mark all as read" shows simulation message

## Reports
- [ ] Officer Report tab renders summary cards
- [ ] Generate report shows simulation message, item appears in history

## Debugging With Chrome (Flutter Web)
- Ensure Chrome installed and Flutter set up for web.
- Commands:
  - `flutter clean && flutter pub get`
  - `flutter run -d chrome --web-renderer canvaskit`
  - Optional faster refresh: `flutter run -d chrome -t lib/main.dart`
- Tips:
  - Open Chrome DevTools Console for runtime logs.
  - Use Flutter Inspector to locate widgets when verifying translations.
  - For integration tests (if configured): `flutter test integration_test/officer_flow_test.dart`

## Backend Integration Notes
- Firestore client uses the default database via `AuthService`.
- Functions use the same databaseId; triggers enqueue review items and send notifications.
- Officer callable APIs (examples):
  - `setUserRole(uid, role)` -> admin only
  - `officerDecideAccount(targetUid, decision, note?)` -> officer/admin
  - Dashboard stats: `getOfficerDashboardStats()`

## Regression Guardrails
- [ ] After editing `app_strings.dart`, re-open Admin Home in EN and ID to ensure no key regressions
- [ ] Verify logout again: press logout, refresh browser → stays on Login
- [ ] If adding new officer screens, add translation keys under both `EN` and `ID`
