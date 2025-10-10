# M-Clearance Immigration – User Guide

M-Clearance Immigration is a mobile application that digitises vessel clearance workflows between maritime agents and immigration officers. This guide helps you install the app, understand each module, and complete daily tasks from either role.

## Table of Contents
- [Getting Started](#getting-started)
  - [Device Requirements](#device-requirements)
  - [Install from Google Play](#install-from-google-play)
  - [Update to the Latest Version](#update-to-the-latest-version)
- [Account Types](#account-types)
- [First-Time Access](#first-time-access)
  - [Registration (Agent)](#registration-agent)
  - [Email Verification](#email-verification)
  - [Officer Account Provisioning](#officer-account-provisioning)
- [Logging In and Out](#logging-in-and-out)
  - [Forgotten Password](#forgotten-password)
- [Agent Experience](#agent-experience)
  - [Home Dashboard](#home-dashboard)
  - [Submitting Arrival or Departure Clearance](#submitting-arrival-or-departure-clearance)
  - [Uploading Corporate Documents](#uploading-corporate-documents)
  - [Tracking Application Status](#tracking-application-status)
  - [Notifications](#notifications)
  - [Application History & Documents](#application-history--documents)
  - [Profile, Language, and Preferences](#profile-language-and-preferences)
  - [Agent Logout](#agent-logout)
- [Officer Experience](#officer-experience)
  - [Officer Dashboard](#officer-dashboard)
  - [Account Verification Queue](#account-verification-queue)
  - [Arrival & Departure Application Review](#arrival--departure-application-review)
  - [Submission Detail Actions](#submission-detail-actions)
  - [Officer Reports](#officer-reports)
  - [Email & Legal Content Management](#email--legal-content-management)
  - [Officer Notifications](#officer-notifications)
  - [Officer Settings & Logout](#officer-settings--logout)
- [Connectivity Awareness](#connectivity-awareness)
- [Language Support](#language-support)
- [Help & Escalation](#help--escalation)
- [Quick Reference](#quick-reference)

---

## Getting Started

### Device Requirements
- Android 10 (API level 29) or newer
- Stable internet connection (Wi-Fi or cellular data)
- At least 200 MB of free storage for installation and document caching
- Camera and photo library permissions if you plan to capture or upload images

### Install from Google Play
1. Open the **Google Play Store** on your Android device.
2. Search for **“M-Clearance Immigration”**.
3. Tap **Install** and wait until the download completes.
4. Once installed, tap **Open** or launch the app from your home screen.

> **Tip:** Enable automatic updates in the Play Store to receive improvements and security fixes without manual steps.

### Update to the Latest Version
- Open the Play Store, search for **M-Clearance Immigration**, and tap **Update** if available.
- You can also enable “Auto-update” on the app’s Play Store page.

---

## Account Types

| Role    | Description | Access Highlights |
|--------|-------------|-------------------|
| **Agent** | Maritime agency staff responsible for submitting vessel arrival and departure requests. | Dashboard, clearance forms, document upload, history, notifications, profile management. |
| **Officer** | Immigration officer or admin who reviews applications and manages supporting content. | Dashboard counters, account verification, arrival/departure queues, submission detail actions, reports, email/legal settings. |

You will only see modules applicable to your role after logging in.

---

## First-Time Access

### Registration (Agent)
1. On the login screen, tap **Create an Account**.
2. Fill in corporate name, username, full name, nationality, email, and password.
3. Accept the terms and policies to continue.
4. Submit the form – your account enters the verification pipeline with status **Pending Email Verification**.

### Email Verification
- Upon registration you receive a 4-digit verification code via email (MailerSend integration).
- Enter the code on the **Confirmation** screen. A countdown prevents rapid resend requests.
- If the email fails to arrive, wait for the cooldown to finish and tap **Resend Code**.

### Officer Account Provisioning
- Officer accounts are created and managed by system administrators.
- Officers receive credentials separately; there is no self-service registration for this role.

---

## Logging In and Out

1. Enter your registered **email** and **password** on the login screen.
2. The system checks your role and status:
   - **Approved Agent:** redirected to the user dashboard.
   - **Approved Officer/Admin:** directed to the officer dashboard.
   - **Pending Email Verification:** sent to the confirmation screen.
   - **Pending Documents:** sent to the document upload module.
   - **Pending Approval:** shown the registration pending screen.
   - **Rejected:** login is blocked; a message explains the reason.

To logout, open your profile/settings page and confirm the sign-out prompt.

### Forgotten Password
1. Tap **Forgot Password** on the login screen.
2. Enter your email address.
3. Check your inbox for a password reset link sent via Firebase Authentication.
4. Follow the instructions in the email to set a new password, then log back in.

---

## Agent Experience

### Home Dashboard
- Greets you with your name and profile photo (if uploaded).
- Shows quick action cards for **Arrival Clearance** and **Departure Clearance**.
- Displays your three most recent applications with status badges.
- Badge counter on the notification bell reflects unread items in real time.

### Submitting Arrival or Departure Clearance
1. From the home dashboard, tap the corresponding clearance card.
2. Complete step-by-step forms covering vessel details, flag, port, crew counts, schedules, and supporting documents.
3. Upload or capture required files:
   - Port clearance document
   - Crew list (multiple files supported)
   - Notification letter
4. Review the summary on the final step and submit.
5. A success message directs you to the **Submission Sent** screen; the status updates to **Waiting** while officers review it.

### Uploading Corporate Documents
- If your account status is **Pending Documents**, you are redirected to the **Upload Documents** module.
- Provide **NIB** and **KTP** files via camera, gallery, or file picker.
- The app enforces required formats and ensures uploads only start when prerequisites are met.
- Once officers review your documents, the status advances to **Pending Approval**.

### Tracking Application Status
- Navigate to **History** from the bottom navigation bar.
- Filter by **All**, **Arrival**, or **Departure**.
- Use search to find a vessel by ship name, agent name, or flag.
- Tap an item to open detailed screens that show:
  - Submitted data
  - Officer remarks
  - Decision history
  - Download links for generated documents

### Notifications
- Tap the bell icon on the home screen or open **Notifications** from the history tab.
- New updates automatically appear and badge counts sync with the server.
- Swipe or tap to mark individual items as read, or use **Mark all as read**.
- Notifications fall into three categories:
  - Updates (general changes)
  - Approved (clearance granted)
  - Revision (action required)

### Application History & Documents
- Access to previously approved or rejected submissions, along with downloadable copies of attachments.
- Use filters to focus on specific action items that require follow-up (e.g., revision requested).

### Profile, Language, and Preferences
- Open **Settings** from the bottom navigation bar.
- Update personal information, corporate details, and profile photo.
- Switch between **English (EN)** and **Bahasa Indonesia (ID)** instantly.
- Toggle appearance (System, Light, Dark Mode).
- Review privacy and security guidelines, change password, or manage notification preferences.

### Agent Logout
- Scroll to the bottom of the **Settings** page and tap **Logout**.
- Confirm to sign out and return to the login screen. Pending uploads are cancelled.

---

## Officer Experience

### Officer Dashboard
- Shows live counters for:
  - Pending account verifications
  - Pending arrival clearances
  - Pending departure clearances
- Provides quick entry buttons to inspect the relevant queues.
- Displays headline statistics and recent officer activities when available.

### Account Verification Queue
1. Open **Account Verification** from the dashboard.
2. Filter users by status: all, waiting, or reviewed.
3. Search by username, email, corporate name, or nationality.
4. Tap a user to view full registration details, review uploaded documents, and approve or reject the account.

### Arrival & Departure Application Review
1. Choose **Arrival Verification** or **Departure Verification**.
2. Filter by waiting or reviewed submissions; search by ship name, agent, or flag.
3. Tap an entry to open the **Submission Detail** screen (see next section).

### Submission Detail Actions
- Inspect voyage information, crew data, and all attachments (downloadable within the app).
- Take one of the following actions:
  - **Approve** – marks the application as cleared and sends notifications to the agent.
  - **Request Revision** – specify required changes; status updates to **Revision** for the agent.
  - **Reject** – record the reason; the agent is informed immediately.
- Actions trigger audit logs and update counters on the officer dashboard.

### Officer Reports
- Access **Reports** from the bottom navigation bar.
- Select a date range to refresh arrival/departure statistics and trends.
- Generate downloadable summaries (e.g., PDF) for audits or monthly reporting.
- If cloud functions are temporarily unavailable, the screen falls back to Firestore aggregation.

### Email & Legal Content Management
- **Email Configuration:** adjust SMTP credentials, sender name, template IDs, and message bodies used in OTP and password reset flows.
- **Legal Content Editor:** maintain Terms & Conditions and Privacy Policy in both English and Indonesian. Changes propagate to user-facing screens immediately.

### Officer Notifications
- Dedicated notification screen mirroring the agent experience but scoped to officer updates (new submissions, revisions, system alerts).
- Supports bulk or individual mark-as-read.

### Officer Settings & Logout
- Manage personal profile, change password, switch language/theme, view account metadata.
- Logout option prompts for confirmation; confirms sign out across linked devices.

---

## Connectivity Awareness
- The app monitors internet availability via the **Connectivity Gate** widget.
- When offline:
  - A persistent banner or dialog indicates loss of network.
  - Submission and upload buttons are temporarily disabled to avoid data loss.
- Use the **Retry** option on the **No Connection** screen once connectivity is restored.

---

## Language Support
- Fully localised in **English** and **Bahasa Indonesia**.
- Change language from the settings screen. The interface reloads instantly without restarting the app.

---

## Help & Escalation
- **Self-service:** Review onscreen guidance, tooltips, and the privacy/security section.
- **In-app Issues:** Capture screenshots and note the time of occurrence; contact your system administrator or support channel defined by your organisation.
- **Email Delivery Problems:** Administrators can inspect the MailerSend extension logs or the in-app email configuration screens.
- **Authentication Support:** For persistent login issues, contact the support desk to verify account status.

---

## Quick Reference

| Task | Location | Notes |
|------|----------|-------|
| Install app | Google Play → M-Clearance Immigration | Requires Android login and internet. |
| Verify email | Confirmation screen after registration | 4-digit OTP; respects resend cooldown. |
| Submit arrival clearance | User Home → Arrival card | Multi-step form with document uploads. |
| Track status | Bottom navigation → History | Filter by arrival/departure; tap for details. |
| Officer approve submission | Arrival/Departure list → Submission detail | Approve, request revision, or reject with notes. |
| Change language | User/Officer Settings → Language | English ↔ Indonesian instantly. |
| Reset password | Login → Forgot Password | Email link via Firebase Auth. |
| Logout | Settings → Logout | Confirm to terminate active session. |

---

If you need a printable copy, export this README as PDF or consult your organisation’s internal documentation portal. Stay updated by installing app updates promptly and reviewing release notes shared alongside each Play Store release.

