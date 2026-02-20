# Rent Calculator

A Flutter web application for tracking rent dues, calculating rent, and managing budgets with Plaid integration for automatic expense tracking.

## Features

- 🏠 **Rent Tracking**: Track rent payments, due dates, and payment history
- 💰 **Rent Calculation**: Calculate total rent due, split rent among roommates, and view monthly averages
- 📊 **Budget Management**: Create budgets by category and track spending
- 💳 **Expense Tracking**: Manually add expenses or sync automatically via Plaid
- 🔗 **Plaid Integration**: Securely connect bank accounts to automatically track transactions
- 📱 **Responsive Design**: Works on web, Android, and iOS

## Tech Stack

- **Frontend**: Flutter (Web, Android, iOS)
- **Backend**: Firebase (Authentication, Firestore, Storage)
- **Banking Integration**: Plaid API
- **State Management**: Provider
- **Routing**: GoRouter

## Prerequisites

- Flutter SDK (3.10.8 or higher)
- Firebase account
- Plaid account (for bank integration)
- Git

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/Mrswami/rent-calculator.git
cd rent-calculator
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable Authentication (Email/Password)
3. Create a Firestore database
4. Get your Firebase configuration:
   - Go to Project Settings → General
   - Scroll down to "Your apps" and add a web app
   - Copy the Firebase configuration

5. Update `lib/main.dart` with your Firebase configuration:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_AUTH_DOMAIN',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  ),
);
```

### 4. Plaid Setup (Optional)

1. Sign up for a Plaid account at [Plaid](https://plaid.com/)
2. Get your Plaid API keys (sandbox for development)
3. Set up a backend API to handle Plaid requests securely
4. Update `lib/services/plaid_service.dart` with your backend URL:

```dart
final PlaidService _plaidService = PlaidService(
  baseUrl: 'https://your-backend-url.com',
);
```

**Note**: Plaid integration requires a backend server. The client-side code makes requests to your backend, which then communicates with Plaid API to keep credentials secure.

### 5. Firestore Security Rules

Set up Firestore security rules in Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /rent_payments/{paymentId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /expenses/{expenseId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
    match /budgets/{budgetId} {
      allow read, write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

## Running the App

### Web

```bash
flutter run -d chrome
```

### Android

```bash
flutter run -d android
```

### iOS

```bash
flutter run -d ios
```

## Building for Production

### Web

```bash
flutter build web
```

The output will be in `build/web/` directory.

### Android

```bash
flutter build apk --release
# or
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
│   ├── rent_payment.dart
│   ├── expense.dart
│   ├── budget.dart
│   └── plaid_account.dart
├── services/                 # Business logic services
│   ├── firebase_service.dart
│   ├── plaid_service.dart
│   └── rent_calculator_service.dart
├── screens/                 # UI screens
│   ├── auth/
│   ├── dashboard/
│   ├── rent/
│   ├── budget/
│   ├── expenses/
│   └── plaid/
├── widgets/                  # Reusable widgets
└── utils/                    # Utilities
    └── app_router.dart
```

## Deployment

### GitHub Pages

The app can be deployed to GitHub Pages using GitHub Actions. See `.github/workflows/deploy.yml` for the deployment workflow.

### Firebase Hosting

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login: `firebase login`
3. Initialize: `firebase init hosting`
4. Build: `flutter build web`
5. Deploy: `firebase deploy --only hosting`

## Development

### Adding New Features

1. Create models in `lib/models/`
2. Add services in `lib/services/`
3. Create screens in `lib/screens/`
4. Update routing in `lib/utils/app_router.dart`

### Code Style

Follow Flutter/Dart style guidelines. The project uses `flutter_lints` for code analysis.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is private and proprietary.

## Support

For issues and questions, please open an issue on GitHub.

## Roadmap

- [ ] Add roommate management
- [ ] Implement Plaid Link SDK integration
- [ ] Add expense categorization suggestions
- [ ] Create budget alerts and notifications
- [ ] Add data export functionality
- [ ] Implement dark mode toggle
- [ ] Add charts and visualizations
- [ ] Multi-currency support
