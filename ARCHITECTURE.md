# Project Architecture (Pragmatic Clean/MVC Hybrid)

This project uses a simple, pragmatic layering that balances Clean Architecture with Flutter ergonomics and the current scope.

## Layers
- `lib/app/models/`: immutable model objects (no Firestore classes). Mapping helpers live near models.
- `lib/app/repositories/`: data access (Firestore only for now), exposes read-only streams and futures.
- `lib/app/services/`: cross-cutting services (auth, local storage, notifications). Auth wires Firebase SDKs.
- `lib/app/views/`: UI widgets/screens. Widgets use repositories/services; no direct Firebase imports here when possible.
- `lib/app/config/`: routes, theme, constants.
- `lib/app/localization/`: `AppStrings` map and helper with language fallback (EN → ID).

## Read-only Policy (current phase)
- Frontend accesses Firestore via repositories with read-only queries.
- Cloud Functions callable endpoints are reserved for the next phase.

## How to add a new screen
1. Define or update the model and mapping if needed.
2. Add a repository method that returns a `Stream<List<Model>>` or `Future<List<Model>>`.
3. Build the UI using a `StreamBuilder`/`FutureBuilder` and wire localization strings in `app_strings.dart`.
4. Keep all backend details inside repositories/services — not in the widget tree.

## Firebase setup
- Firestore databaseId: `m-clearance-imigrasi-db` (client + functions).
- Offline persistence enabled in `AuthService`.

