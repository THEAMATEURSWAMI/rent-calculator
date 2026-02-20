# Firebase Setup Guide

Follow these steps to set up Firebase for your Rent Calculator app.

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or **"Create a project"**
3. Enter project name: `rent-calculator` (or your preferred name)
4. Click **"Continue"**
5. **Disable** Google Analytics (optional, you can enable later if needed)
6. Click **"Create project"**
7. Wait for project creation (takes ~30 seconds)
8. Click **"Continue"**

## Step 2: Add Web App

1. In your Firebase project dashboard, click the **Web icon** (`</>`) or **"Add app"** → **Web**
2. Register your app:
   - App nickname: `Rent Calculator Web`
   - Check **"Also set up Firebase Hosting"** (optional, for deployment)
   - Click **"Register app"**
3. **Copy the Firebase configuration object** - you'll need this!
   It looks like:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIza...",
     authDomain: "rent-calculator.firebaseapp.com",
     projectId: "rent-calculator",
     storageBucket: "rent-calculator.appspot.com",
     messagingSenderId: "123456789",
     appId: "1:123456789:web:abcdef"
   };
   ```

## Step 3: Enable Authentication

1. In Firebase Console, go to **Build** → **Authentication**
2. Click **"Get started"**
3. Go to **"Sign-in method"** tab
4. Click **"Email/Password"**
5. Enable **"Email/Password"** (toggle ON)
6. Click **"Save"**

## Step 4: Create Firestore Database

1. In Firebase Console, go to **Build** → **Firestore Database**
2. Click **"Create database"**
3. Choose **"Start in test mode"** (we'll add security rules next)
4. Select a location (choose closest to your users)
5. Click **"Enable"**
6. Wait for database creation

## Step 5: Set Firestore Security Rules

1. In Firestore Database, go to **"Rules"** tab
2. Replace the default rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Rent payments collection
    match /rent_payments/{paymentId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Expenses collection
    match /expenses/{expenseId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Budgets collection
    match /budgets/{budgetId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }
  }
}
```

3. Click **"Publish"**

## Step 6: Update Your Flutter App

Once you have your Firebase config, update `lib/main.dart` with your credentials.

## Next Steps

After completing these steps, come back and I'll help you:
- Update the Firebase configuration in your code
- Test the authentication
- Verify Firestore connection
