# Authentication Flow Analysis

This document outlines the current user authentication flow based on the screens present in the `lib/app/views/screens/auth/` directory.

## Screens

The following screens are involved in the authentication process:

-   `splash_screen.dart`: The initial screen, likely used for checking the user's authentication state.
-   `login_screen.dart`: The screen where users can enter their credentials to log in.
-   `register_screen.dart`: The screen where new users can create an account.
-   `forgot_password_screen.dart`: The screen that allows users to reset their password.
-   `change_password_screen.dart`: The screen where users can change their password after being authenticated.
-   `upload_documents_screen.dart`: A screen for uploading documents, likely part of the registration process.
-   `registration_pending_screen.dart`: A screen that informs the user that their registration is pending approval.
-   `confirmation_screen.dart`: A generic confirmation screen, possibly used after registration or password reset.

## User Flow

The following is the inferred user flow for authentication:

1.  The user launches the app and is first shown the **Splash Screen**. This screen likely checks if the user is already logged in.
2.  If the user is not logged in, they are redirected to the **Login Screen**.
3.  From the **Login Screen**, the user can:
    -   Enter their credentials to log in.
    -   Navigate to the **Register Screen** to create a new account.
    -   Navigate to the **Forgot Password Screen** if they have forgotten their password.
4.  On the **Register Screen**, the user enters their details and is likely redirected to the **Upload Documents Screen** to provide necessary documentation.
5.  After submitting their registration and documents, the user is shown the **Registration Pending Screen**, indicating that their account is awaiting admin approval.
6.  The **Confirmation Screen** may be used to confirm successful registration or password reset.
7.  Once logged in, the user may have the option to navigate to the **Change Password Screen** from a profile or settings page.

This analysis provides a foundational understanding of the existing authentication flow, which will be crucial for integrating Firebase Authentication.