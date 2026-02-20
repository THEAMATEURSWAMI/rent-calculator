# Quick Setup Guide

## 1. Firebase Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or select an existing one
3. Enable Authentication → Sign-in method → Email/Password
4. Create Firestore Database (Start in test mode, then update security rules)
5. Copy your Firebase config from Project Settings → General → Your apps → Web app
6. Update `lib/main.dart` with your Firebase credentials:

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

## 2. Firestore Security Rules

Go to Firestore Database → Rules and paste:

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

## 3. Plaid Setup (Optional)

1. Sign up at [Plaid](https://plaid.com/)
2. Create a backend API to handle Plaid requests (for security)
3. Update `lib/services/plaid_service.dart` with your backend URL
4. Implement Plaid Link SDK integration (see Plaid documentation)

## 4. Run the App

```bash
# Install dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Build for production
flutter build web
```

## 5. Deploy

### GitHub Pages (via GitHub Actions)
- Push to `main` branch
- GitHub Actions will automatically build and deploy

### Firebase Hosting
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
flutter build web
firebase deploy --only hosting
```

## Troubleshooting

- **Firebase errors**: Make sure you've enabled Authentication and Firestore
- **Build errors**: Run `flutter clean` then `flutter pub get`
- **Plaid errors**: Ensure backend URL is configured in `plaid_service.dart`
