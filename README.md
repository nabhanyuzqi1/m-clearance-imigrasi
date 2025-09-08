# M-Clearance Immigration System

[![Flutter](https://img.shields.io/badge/Flutter-3.9.0-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive Flutter-based immigration clearance application system designed for maritime operations in Indonesia. The system supports both user (agent) and officer workflows for managing ship clearance applications, document verification, and immigration processes.

## 📋 Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Firebase Setup](#firebase-setup)
- [Running the Application](#running-the-application)
- [Project Structure](#project-structure)
- [Localization](#localization)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

### 🔐 Authentication & User Management
- **Multi-role Support**: User (Agent) and Officer roles
- **Email Verification**: Secure email verification workflow
- **Password Management**: Forgot password and change password functionality
- **Document Upload**: NIB and KTP document submission for registration

### 🚢 Clearance Application System
- **Arrival/Departure Applications**: Complete clearance workflow
- **Document Management**: Port clearance, crew lists, notification letters
- **Real-time Status Tracking**: Application status monitoring
- **Officer Verification**: Document review and approval system

### 🌐 Localization
- **Bilingual Support**: English and Indonesian (Bahasa Indonesia)
- **Dynamic Language Switching**: Runtime language changes
- **Comprehensive Coverage**: All screens and components localized

### 📱 User Interface
- **Responsive Design**: Optimized for mobile devices
- **Material Design**: Modern UI following Material Design principles
- **Intuitive Navigation**: Clean and user-friendly interface
- **Role-based Dashboards**: Different interfaces for users and officers

### 🔧 Technical Features
- **Firebase Integration**: Auth, Firestore, Storage
- **Named Database**: Custom Firestore database instance
- **Error Handling**: Comprehensive error management
- **State Management**: Provider pattern for state management
- **Route Management**: Centralized routing system

## 🏗️ Architecture

### Application Flow

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User/Agent    │────│   Application   │────│    Officer      │
│   Registration  │    │   Submission    │    │   Verification  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Email Verification│  │ Document Upload │  │ Status Updates   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Database Structure

```
Firestore Database: m-clearance-imigrasi-db
├── users/
│   ├── {uid}/
│   │   ├── email, username, corporateName
│   │   ├── role, status, documents[]
│   │   └── timestamps
├── clearance_applications/
│   ├── {applicationId}/
│   │   ├── ship details, voyage info
│   │   ├── documents, status
│   │   └── officer notes
└── notifications/
    ├── {notificationId}/
    │   ├── title, body, type
    │   └── timestamps
```

## 🛠️ Tech Stack

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Dart**: Programming language
- **Material Design**: UI component library

### Backend & Services
- **Firebase Authentication**: User authentication
- **Cloud Firestore**: NoSQL database
- **Firebase Storage**: File storage
- **Firebase Hosting**: Web deployment (optional)

### Development Tools
- **VS Code**: Primary IDE
- **Flutter SDK**: Development framework
- **Firebase CLI**: Firebase management
- **Git**: Version control

### Testing
- **Flutter Test**: Unit testing
- **Integration Test**: End-to-end testing
- **Mockito**: Mocking framework

## 📋 Prerequisites

### System Requirements
- **Flutter SDK**: `^3.9.0`
- **Dart SDK**: Included with Flutter
- **Android Studio**: For Android development
- **Xcode**: For iOS development (macOS only)
- **VS Code**: Recommended IDE

### Firebase Requirements
- **Firebase Project**: Active Firebase project
- **Firestore Database**: Named database `m-clearance-imigrasi-db`
- **Authentication**: Email/Password provider enabled
- **Storage**: Cloud Storage bucket configured

### Development Environment
```bash
# Check Flutter installation
flutter --version

# Check available devices
flutter devices

# Check Flutter doctor
flutter doctor
```

## 🚀 Installation

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/m-clearance-imigrasi.git
cd m-clearance-imigrasi
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure Firebase
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase (if not already done)
firebase init
```

### 4. Setup Environment
```bash
# Copy environment configuration
cp .env.example .env

# Edit .env with your Firebase configuration
```

## ⚙️ Configuration

### Firebase Configuration

#### 1. Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project: `m-clearance-imigrasi`
3. Enable Authentication with Email/Password provider
4. Create Firestore Database with name: `m-clearance-imigrasi-db`
5. Set up Storage bucket

#### 2. Download Configuration Files
```bash
# Download Firebase configuration
flutterfire configure --project=m-clearance-imigrasi
```

#### 3. Update Configuration Files
- `lib/firebase_options.dart`: Auto-generated by FlutterFire
- `android/app/google-services.json`: Download from Firebase Console
- `ios/Runner/GoogleService-Info.plist`: Download from Firebase Console

### Environment Variables
```env
# .env file
FIREBASE_PROJECT_ID=m-clearance-imigrasi
FIREBASE_API_KEY=your_api_key
FIREBASE_APP_ID=your_app_id
FIREBASE_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_STORAGE_BUCKET=m-clearance-imigrasi.appspot.com
```

## 🔥 Firebase Setup

### Firestore Security Rules
```javascript
// firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Officers can read all user data
    match /users/{userId} {
      allow read: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'officer';
    }

    // Clearance applications
    match /clearance_applications/{applicationId} {
      allow read, write: if request.auth != null;
      allow update: if request.auth != null &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'officer';
    }
  }
}
```

### Storage Security Rules
```javascript
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Users can upload to their own folder
    match /users/{userId}/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }

    // Officers can read all files
    match /users/{userId}/{allPaths=**} {
      allow read: if request.auth != null &&
        firestore.exists(/databases/(default)/documents/users/$(request.auth.uid)) &&
        firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'officer';
    }
  }
}
```

## ▶️ Running the Application

### Development Mode

#### Web (with Debug Service Filtering)
```bash
# Use the filtered script to hide DWDS noise
./tool/run_web_filtered.sh

# Or use VS Code task
# Command Palette → "Run Task" → "Flutter: Run Web (filtered)"
```

#### Android
```bash
flutter run
```

#### iOS (macOS only)
```bash
flutter run
```

### Production Mode
```bash
# Web
flutter build web --release

# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### Debug Commands
```bash
# Hot reload
r

# Hot restart
R

# Quit
q

# List available commands
h
```

## 📁 Project Structure

```
m-clearance-imigrasi/
├── android/                    # Android platform code
├── ios/                       # iOS platform code
├── lib/                       # Main Flutter application
│   ├── app/
│   │   ├── config/
│   │   │   ├── routes.dart    # Application routing
│   │   │   └── theme.dart     # App theme configuration
│   │   ├── localization/
│   │   │   └── app_strings.dart # Localization strings
│   │   ├── models/            # Data models
│   │   │   ├── user_model.dart
│   │   │   ├── clearance_application.dart
│   │   │   └── notification_item.dart
│   │   ├── services/          # Business logic services
│   │   │   ├── auth_service.dart
│   │   │   └── notification_services.dart
│   │   └── views/             # UI components
│   │       ├── screens/       # Screen widgets
│   │       │   ├── auth/      # Authentication screens
│   │       │   ├── user/      # User screens
│   │       │   └── officer/   # Officer screens
│   │       └── widgets/       # Reusable widgets
│   ├── firebase_options.dart  # Firebase configuration
│   └── main.dart             # Application entry point
├── test/                     # Unit tests
├── integration_test/         # Integration tests
├── web/                      # Web platform files
├── functions/                # Firebase Cloud Functions
├── tool/                     # Development tools
│   └── run_web_filtered.sh   # Web debug filter script
├── .vscode/                  # VS Code configuration
├── firebase.json            # Firebase configuration
├── pubspec.yaml             # Flutter dependencies
└── README.md                # This file
```

## 🌐 Localization

### Supported Languages
- **English (EN)**: Default language
- **Indonesian (ID)**: Bahasa Indonesia

### Usage in Code
```dart
import '../../../localization/app_strings.dart';

// Get localized string
String title = AppStrings.tr(
  context: context,
  screenKey: 'login',
  stringKey: 'welcome',
  langCode: 'EN', // or 'ID'
);
```

### Adding New Languages
1. Add new language map to `_localizedStrings` in `app_strings.dart`
2. Update all screen keys with translations
3. Test language switching functionality

## 🧪 Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Test Coverage
```bash
flutter test --coverage
```

### Mock Setup
```dart
// Using Mockito for service mocking
@GenerateMocks([AuthService, FirebaseAuth])
void main() {
  // Test implementation
}
```

## 🚀 Deployment

### Web Deployment
```bash
# Build for production
flutter build web --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Mobile Deployment

#### Android
```bash
# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

#### iOS
```bash
# Build for iOS
flutter build ios --release

# Archive for App Store
# Use Xcode to archive and upload
```

### Firebase Functions Deployment
```bash
# Deploy Cloud Functions
firebase deploy --only functions
```

## 🤝 Contributing

### Development Workflow
1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b feature/your-feature`
3. **Commit** your changes: `git commit -m 'Add some feature'`
4. **Push** to the branch: `git push origin feature/your-feature`
5. **Open** a Pull Request

### Code Style
```bash
# Format code
flutter format .

# Analyze code
flutter analyze

# Run tests before committing
flutter test
```

### Commit Message Convention
```
feat: add new clearance application feature
fix: resolve authentication bug
docs: update README with deployment instructions
style: format code according to Flutter guidelines
refactor: improve service layer architecture
test: add unit tests for auth service
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **Your Name** - *Initial work* - [Your GitHub](https://github.com/your-username)

## 🙏 Acknowledgments

- Flutter Team for the amazing framework
- Firebase for comprehensive backend services
- Material Design for beautiful UI components
- Indonesian Immigration Department for domain expertise

## 📞 Support

For support, email support@mclearance.com or join our Slack channel.

## 🔄 Version History

### v1.0.0 (Current)
- Initial release with core clearance functionality
- Multi-role authentication system
- Document upload and verification
- Bilingual localization support
- Firebase integration

---

**Made with ❤️ for efficient maritime immigration processes in Indonesia**
