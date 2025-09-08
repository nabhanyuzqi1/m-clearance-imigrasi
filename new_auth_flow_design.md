# New Authentication Flow Technical Design

This document outlines the technical design for the new registration and login flow.

## 1. UserModel Changes

The `UserModel` will be updated to support the new flow.

### New Fields:
-   `isEmailVerified`: A boolean to track the user's email verification status.

### Updated `status` Enum:
The `status` field will be treated as an enum with the following possible values:
-   `pending_email_verification`: User has registered but not verified their email.
-   `pending_documents`: User has verified their email but has not uploaded the required documents.
-   `pending_approval`: User has uploaded documents and is awaiting admin approval.
-   `approved`: User is approved and can access the application.
-   `rejected`: User's application has been rejected by an admin.

### Updated `UserModel` Definition:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String corporateName;
  final String username;
  final String nationality;
  final String role;
  final String status; // Should be one of the enum values
  final bool isEmailVerified;
  final bool hasUploadedDocuments;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final List<Map<String, dynamic>> documents;

  UserModel({
    required this.uid,
    required this.email,
    required this.corporateName,
    required this.username,
    required this.nationality,
    required this.role,
    required this.status,
    required this.isEmailVerified,
    required this.hasUploadedDocuments,
    required this.createdAt,
    required this.updatedAt,
    required this.documents,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      corporateName: data['corporateName'] ?? '',
      username: data['username'] ?? '',
      nationality: data['nationality'] ?? '',
      role: data['role'] ?? 'user',
      status: data['status'] ?? 'pending_email_verification',
      isEmailVerified: data['isEmailVerified'] ?? false,
      hasUploadedDocuments: data['hasUploadedDocuments'] ?? false,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      documents: List<Map<String, dynamic>>.from(data['documents'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'corporateName': corporateName,
      'username': username,
      'nationality': nationality,
      'role': role,
      'status': status,
      'isEmailVerified': isEmailVerified,
      'hasUploadedDocuments': hasUploadedDocuments,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'documents': documents,
    };
  }
}
```

## 2. AuthService Modifications

The `AuthService` will be updated to handle the new authentication logic.

### New Methods:

-   `Future<void> sendVerificationEmail()`: Sends a verification email to the current user.
-   `Future<bool> isEmailVerified()`: Checks if the current user's email is verified.
-   `Future<void> reloadUser()`: Reloads the current user's data to get the latest status.

### Modified Methods:

-   `registerWithEmailAndPassword`: This method will be updated to set the initial user status to `pending_email_verification` and `isEmailVerified` to `false`. It will also trigger the sending of a verification email.
-   `signInWithEmailAndPassword`: This method will be updated to check the user's status after a successful login and return a `UserModel` object. The UI will then use this object to navigate to the correct screen.
-   `uploadDocument`: This method will be updated to change the user's status to `pending_approval` after the documents are successfully uploaded.

## 3. UI Component Plan

New screens will be created to handle the new steps in the authentication flow.

-   **`EmailVerificationScreen`**:
    -   Displays a message instructing the user to check their email for a verification code.
    -   Includes a text field for the user to enter the verification code.
    -   A "Verify" button that calls a new method in `AuthService` to verify the code.
    -   A "Resend Email" button.
-   **`UploadDocumentsScreen`**:
    -   Provides a form for the user to upload the required documents.
    -   Interacts with `AuthService.uploadDocument` to upload the files.
    -   Upon successful upload, navigates to the `RegistrationPendingScreen`.
-   **`RegistrationPendingScreen`**:
    -   Displays a message informing the user that their account is pending approval.
    -   This is a static screen with no interactive elements.

## 4. Navigation and Routing

The navigation flow will be updated to handle the different user statuses.

```mermaid
graph TD
    A[Start] --> B{User Authenticated?};
    B -- No --> C[Login/Register];
    C -- Login --> D{Check User Status};
    C -- Register --> E[Registration Process];
    E --> F[Send Verification Email];
    F --> G[Email Verification Screen];
    G -- Verified --> H[Upload Documents Screen];
    H -- Uploaded --> I[Pending Approval Screen];
    B -- Yes --> D;
    D -- pending_email_verification --> G;
    D -- pending_documents --> H;
    D -- pending_approval --> I;
    D -- approved --> J[Home Screen];
    D -- not_registered --> C;