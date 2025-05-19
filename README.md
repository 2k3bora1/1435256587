# Chit Fund Manager - Flutter App

A Flutter application for managing chit funds, loans, and member data. This app is designed to work alongside the Python desktop application, sharing the same SQLite database via Google Drive synchronization.

## Features

- **Member Management**: Add, edit, and view members with their personal details and documents
- **Loan Management**: Create loans with EMI schedules, track payments, and manage loan documents
- **Chit Fund Management**: Create and manage chit funds, track bids and payments
- **Group Management**: Organize members into groups for easier management
- **Payment Collection**: Collect EMI payments and generate receipts
- **Google Drive Sync**: Synchronize data with Google Drive to share between devices and with the Python desktop app
- **Offline Support**: Work offline and sync when internet is available

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio or Visual Studio Code with Flutter extensions
- Android device or emulator (API level 21+) or iOS device (iOS 11+)

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/chit_fund_flutter.git
   ```

2. Navigate to the project directory:
   ```
   cd chit_fund_flutter
   ```

3. Install dependencies:
   ```
   flutter pub get
   ```

4. Run the app:
   ```
   flutter run
   ```

### Building for Production

#### Android

```
flutter build apk --release
```

The APK file will be available at `build/app/outputs/flutter-apk/app-release.apk`.

#### iOS

```
flutter build ios --release
```

Then open the Xcode project in the `ios` folder and archive it for distribution.

## Synchronization with Python App

This Flutter app is designed to work with the Python desktop application by sharing the same SQLite database file through Google Drive. The synchronization process works as follows:

1. When the app starts, it checks if a local database exists
2. If no local database exists, it attempts to download from Google Drive
3. If a database exists on Google Drive, it downloads it
4. If no database exists on Google Drive, it creates a new one and uploads it
5. After making changes, the app uploads the database to Google Drive
6. The Python app follows a similar process to ensure both apps use the same data

## Project Structure

```
lib/
├── config/             # App configuration
│   ├── constants.dart  # App-wide constants
│   ├── routes.dart     # Navigation routes
│   └── themes.dart     # UI themes
├── models/             # Data models
│   ├── chit_fund.dart  # Chit fund related models
│   ├── group.dart      # Group related models
│   ├── loan.dart       # Loan related models
│   ├── member.dart     # Member model
│   └── user.dart       # User model for authentication
├── screens/            # UI screens
│   ├── chit_funds/     # Chit fund screens
│   ├── dashboard/      # Dashboard screen
│   ├── groups/         # Group screens
│   ├── loans/          # Loan screens
│   ├── login/          # Authentication screens
│   ├── members/        # Member screens
│   └── payments/       # Payment screens
├── services/           # Business logic
│   ├── auth_service.dart     # Authentication service
│   ├── database_service.dart # Database operations
│   ├── drive_service.dart    # Google Drive integration
│   ├── sync_service.dart     # Data synchronization
│   └── utility_service.dart  # Utility functions
├── widgets/            # Reusable UI components
│   ├── form_fields.dart      # Form input widgets
│   └── image_picker_widget.dart # Image selection widget
└── main.dart           # App entry point
```

## Authentication

The app uses the same authentication system as the Python desktop application. Users created in one app can log in to the other. Passwords are securely hashed using bcrypt.

## Database Schema

The app uses SQLite with the following main tables:

- `users`: App users with authentication details
- `members`: Member information and documents
- `groups`: Groups of members
- `group_members`: Many-to-many relationship between groups and members
- `loans`: Loan information
- `loan_emis`: EMI schedule for loans
- `loan_emi_payments`: Payment records for loan EMIs
- `chit_funds`: Chit fund information
- `chit_members`: Members participating in chit funds
- `chit_bids`: Bid information for chit funds
- `chit_emis`: EMI schedule for chit funds

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Flutter team for the amazing framework
- SQLite for the embedded database
- Google Drive API for synchronization capabilities
