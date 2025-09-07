# Technical Specification: Authentication and Data Storage

This document outlines the technical details of the authentication and data storage architecture for the M-Clearance Imigrasi application. It serves as a blueprint for developing a new, reliable test suite for the core backend logic.

## 1. Data Structures

### 1.1. UserModel

The `UserModel` represents the data structure for a user in the application, stored in Firestore.

**Firestore Collection:** `users`
**Document ID:** User's UID from Firebase Authentication

| Field                  | Data Type                  | Description                                                                                             |
| ---------------------- | -------------------------- | ------------------------------------------------------------------------------------------------------- |
| `uid`                  | `String`                   | The user's unique identifier, same as the Firebase Auth UID.                                            |
| `email`                | `String`                   | The user's email address.                                                                               |
| `corporateName`        | `String`                   | The name of the corporation the user represents.                                                        |
| `username`             | `String`                   | The user's chosen username.                                                                             |
| `fullName`             | `String`                   | The user's full name.                                                                                   |
| `role`                 | `String`                   | The user's role in the system (e.g., 'user', 'admin'). Defaults to 'user'.                              |
| `status`               | `String`                   | The user's account status (e.g., 'pending_email_verification', 'active'). Defaults to 'pending_email_verification'. |
| `createdAt`            | `Timestamp`                | The timestamp when the user account was created.                                                        |
| `updatedAt`            | `Timestamp`                | The timestamp when the user account was last updated.                                                   |
| `documents`            | `List<Map<String, dynamic>>` | A list of uploaded documents. Each map contains `documentName`, `storagePath`, and `uploadedAt`.        |
| `hasUploadedDocuments` | `bool`                     | A flag indicating whether the user has uploaded any documents. Defaults to `false`.                     |
| `isEmailVerified`      | `bool`                     | A flag indicating whether the user's email address has been verified. Defaults to `false`.              |

## 2. Core Functionalities: AuthService

The `AuthService` class encapsulates all business logic related to user authentication, registration, and data management.

### 2.1. User Registration

**Method:** `registerWithEmailAndPassword(String email, String password, String corporateName, String username, String fullName)`

**Expected Behavior:**

1.  Creates a new user in Firebase Authentication with the provided `email` and `password`.
2.  Upon successful creation, it creates a corresponding user document in the `users` collection in Firestore with the user's details.
3.  The initial `status` of the user is set to `pending_email_verification`.
4.  Sends a verification email to the user's email address.
5.  If the Firestore document creation fails, the newly created Firebase Auth user is deleted to prevent orphaned accounts.

### 2.2. User Sign-In

**Method:** `signInWithEmailAndPassword(String email, String password)`

**Expected Behavior:**

1.  Authenticates the user with Firebase Authentication using the provided `email` and `password`.
2.  If authentication is successful, it retrieves the user's data from the `users` collection in Firestore.
3.  Returns a `UserModel` object containing the user's data.
4.  Returns `null` if authentication fails.

### 2.3. User Sign-Out

**Method:** `signOut()`

**Expected Behavior:**

1.  Signs the user out of Firebase Authentication.

### 2.4. Document Upload

**Method:** `uploadDocument(String uid, File file, String docName)`

**Expected Behavior:**

1.  Uploads the provided `file` to Firebase Storage in the `users/{uid}/documents/{docName}` path.
2.  Upon successful upload, it retrieves the download URL of the file.
3.  Updates the corresponding user's document in Firestore by adding a new map to the `documents` array. This map contains the `documentName`, the `storagePath` (download URL), and the `uploadedAt` timestamp.
4.  Returns the download URL of the uploaded document.

## 3. Interaction Points

The `AuthService` interacts with the following Firebase services:

*   **Firebase Authentication:** For user creation, sign-in, sign-out, email verification, and password reset.
*   **Cloud Firestore:** For storing and retrieving user data in the `users` collection.
*   **Firebase Storage:** For storing user-uploaded documents.

The following diagram illustrates the interactions:

```mermaid
graph TD
    A[Client App] -->|Auth Requests| B(AuthService)
    B -->|Firebase Auth| C{Firebase Authentication}
    B -->|User Data| D{Cloud Firestore}
    B -->|Document Uploads| E{Firebase Storage}