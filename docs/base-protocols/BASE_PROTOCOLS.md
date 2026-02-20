# Base Development Protocols
> **Author:** Mrswami  
> **Status:** Living Document — update as new standards are adopted  
> **Applies to:** All web apps, mobile apps, and hybrid apps regardless of stack

---

## Table of Contents

1. [Credential & Autofill Support](#1-credential--autofill-support)
2. [Cross-Browser Compatibility](#2-cross-browser-compatibility)
3. [Copy-Paste & Clipboard](#3-copy-paste--clipboard)
4. [Authentication Standards](#4-authentication-standards)
5. [Firebase Standards](#5-firebase-standards)
6. [Security Protocols](#6-security-protocols)
7. [Accessibility (a11y)](#7-accessibility-a11y)
8. [Performance Standards](#8-performance-standards)
9. [Responsive Design](#9-responsive-design)
10. [Error Handling & Feedback](#10-error-handling--feedback)
11. [State Management](#11-state-management)
12. [Git & Repository Standards](#12-git--repository-standards)
13. [Environment & Config Management](#13-environment--config-management)
14. [Deployment Checklist](#14-deployment-checklist)

---

## 1. Credential & Autofill Support

> Every app with login/signup forms MUST support browser and OS-level autofill and password managers (Chrome, Safari, Firefox, Edge, LastPass, 1Password, Bitwarden, etc.)

### Flutter Web
```dart
// ALWAYS wrap credential forms in AutofillGroup
AutofillGroup(
  child: Column(
    children: [
      TextFormField(
        autofillHints: const [AutofillHints.email, AutofillHints.username],
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        enableInteractiveSelection: true,
      ),
      TextFormField(
        autofillHints: const [AutofillHints.password],
        obscureText: true,
        textInputAction: TextInputAction.done,
        enableInteractiveSelection: true, // allows paste
      ),
    ],
  ),
)

// ALWAYS call after successful login — triggers browser "Save Password?" prompt
TextInput.finishAutofillContext(shouldSave: true);

// ALWAYS call after failed login — tells browser NOT to save
TextInput.finishAutofillContext(shouldSave: false);
```

### Hidden Username Field Rule
When the email/username is displayed as text (not an input), ALWAYS add a hidden `TextFormField` with the email value BEFORE the password field. Browsers need to see a username input before a password input to:
- Associate saved passwords with the correct account
- Show autofill suggestions
- Offer to save credentials after login

```dart
// Hidden but browser-readable username field
SizedBox(
  height: 0,
  child: Opacity(
    opacity: 0,
    child: TextFormField(
      controller: emailController, // pre-filled with user's email
      autofillHints: const [AutofillHints.email, AutofillHints.username],
      focusNode: FocusNode(skipTraversal: true), // skip in tab order
      enableInteractiveSelection: false,
    ),
  ),
)
```

### Signup Forms
Use `AutofillHints.newPassword` (not `AutofillHints.password`) so password managers know to generate and save a NEW credential:
```dart
autofillHints: const [AutofillHints.newPassword],
```

### Web index.html
Every Flutter web app's `index.html` MUST include:
```html
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="format-detection" content="telephone=no">
<style>
  /* Allows browser autofill overlays to render above Flutter canvas */
  flt-glass-pane { z-index: 0 !important; }
</style>
```

### React / Next.js / HTML
```html
<!-- Always set autocomplete on inputs -->
<input type="email" name="email" autocomplete="email" />
<input type="password" name="password" autocomplete="current-password" />
<input type="password" name="new-password" autocomplete="new-password" />
```

---

## 2. Cross-Browser Compatibility

> All apps must be tested and functional on Chrome, Firefox, Safari, and Edge minimum.

### Required Meta Tags (All Web Apps)
```html
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta content="IE=Edge" http-equiv="X-UA-Compatible">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
```

### Testing Matrix
| Browser | Desktop | Mobile |
|---------|---------|--------|
| Chrome  | ✅ Required | ✅ Required |
| Firefox | ✅ Required | ⚠️ Recommended |
| Safari  | ✅ Required | ✅ Required (iOS) |
| Edge    | ✅ Required | ⚠️ Recommended |
| Samsung | —       | ⚠️ Recommended |

### CSS / Flutter
- Avoid browser-specific CSS prefixes without fallbacks
- Use `flutter_web_plugins` for web-specific behavior
- Test all animations — Safari handles them differently
- Never rely on `localStorage` alone — use cookies as fallback where needed

---

## 3. Copy-Paste & Clipboard

> Users must ALWAYS be able to copy and paste in input fields. Never disable it.

### Flutter
```dart
// ALWAYS include on text inputs
enableInteractiveSelection: true,

// ALWAYS provide context menu for password fields
contextMenuBuilder: (context, editableTextState) =>
    AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    ),
```

### Rules
- ✅ ALWAYS allow paste into password fields (even when obscured)
- ✅ ALWAYS allow copy on selectable/non-sensitive text
- ✅ Use `SelectableText` for emails, IDs, keys the user may need to copy
- ❌ NEVER block right-click context menus on input fields
- ❌ NEVER disable paste via JavaScript or `onPaste` handlers

---

## 4. Authentication Standards

### Required Features for Every Auth System
- [ ] Email + Password login
- [ ] Password visibility toggle (eye icon)
- [ ] **Remember Me** checkbox on every login form
- [ ] Wrong password → show reset option immediately
- [ ] Password reset via email link (Firebase: `sendPasswordResetEmail`)
- [ ] "Save Password?" prompt on successful login (autofill context)
- [ ] Loading states on all auth buttons
- [ ] Clear, human-readable error messages (no raw Firebase error codes)
- [ ] Clear remembered state on explicit logout

### Remember Me — Implementation Standard

"Remember Me" must be implemented on **every** app with authentication, regardless of platform.

#### How It Works
| State | Firebase Persistence | Behavior |
|-------|---------------------|----------|
| Remember Me ✅ | `Persistence.LOCAL` | Session survives browser/app close — auto-login on return |
| Remember Me ❌ | `Persistence.SESSION` | Session ends when tab/app is closed |

#### Flutter Web Implementation
```dart
// 1. Import
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';

// 2. State variable
bool _rememberMe = false;

// 3. Load saved preference on screen init
Future<void> _loadRememberMeState() async {
  final remembered = await RememberMeService.getRememberedUser();
  setState(() {
    _rememberMe = remembered?.toLowerCase() == currentUserName.toLowerCase();
  });
}

// 4. Set Firebase persistence BEFORE signIn (web only)
if (kIsWeb) {
  await FirebaseAuth.instance.setPersistence(
    _rememberMe ? Persistence.LOCAL : Persistence.SESSION,
  );
}

// 5. After successful login — save or clear
if (_rememberMe) {
  await RememberMeService.setRemembered(userName);
} else {
  await RememberMeService.clearRemembered();
}

// 6. On logout — always clear
await RememberMeService.clearRemembered();
await firebaseService.signOut();
```

#### UI Requirements
- Checkbox labeled **"Remember me on this device"** below password field
- Pre-check the box if this user was previously remembered
- On the user-selection screen: show a green ring + checkmark badge on the remembered user's avatar
- Show "Welcome back, [Name]!" instead of generic greeting when a user is remembered

#### RememberMeService (use `shared_preferences`)
```dart
class RememberMeService {
  static Future<void> setRemembered(String userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remembered_user', userName);
    await prefs.setBool('remember_me_enabled', true);
  }

  static Future<void> clearRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remembered_user');
    await prefs.setBool('remember_me_enabled', false);
  }

  static Future<String?> getRememberedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('remember_me_enabled') ?? false;
    if (!enabled) return null;
    return prefs.getString('remembered_user');
  }
}
```

#### Mobile Note
On iOS/Android, Firebase Auth always uses `LOCAL` persistence by default. The `setPersistence()` call is web-only — guard it with `if (kIsWeb)`. On mobile, still use `RememberMeService` to drive the UI badge/greeting.

### Error Message Mapping (Firebase)
```dart
switch (e.code) {
  case 'wrong-password':
  case 'invalid-credential':
    return 'Incorrect password. Would you like to reset it?';
  case 'user-not-found':
    return 'No account found with this email.';
  case 'email-already-in-use':
    return 'An account already exists with this email.';
  case 'weak-password':
    return 'Password must be at least 6 characters.';
  case 'too-many-requests':
    return 'Too many attempts. Please try again later or reset your password.';
  case 'user-disabled':
    return 'This account has been disabled. Contact support.';
  case 'network-request-failed':
    return 'No internet connection. Please check your network.';
  default:
    return 'Something went wrong. Please try again.';
}
```

### Password Requirements (Minimum)
- Minimum 8 characters (6 is Firebase minimum but 8 is recommended)
- Show strength indicator on signup
- Allow paste — never block it

---

## 5. Firebase Standards

### Initialization
Always wrap Firebase init in try/catch and continue gracefully:
```dart
try {
  await Firebase.initializeApp(options: firebaseOptions);
  await UserSetupService.createDefaultUsersIfNeeded();
} catch (e) {
  debugPrint('Firebase init error: $e');
  // App continues — show offline mode or error screen
}
```

### Firestore Security Rules (Base Template)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isAuthenticated() {
      return request.auth != null;
    }
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    // Each collection: only owner can read/write their data
    match /{collection}/{docId} {
      allow read: if isOwner(resource.data.userId);
      allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
      allow update, delete: if isOwner(resource.data.userId);
    }
  }
}
```

### Firebase Config — Never Hardcode in Public Repos
- Store Firebase config in environment variables or a gitignored file
- Use `.env` + `flutter_dotenv` for local dev
- Use GitHub Secrets for CI/CD

```
# .gitignore — always include these
.env
firebase_config.dart
google-services.json
GoogleService-Info.plist
```

---

## 6. Security Protocols

### Secrets & Keys
- ❌ NEVER commit API keys, tokens, or passwords to git
- ❌ NEVER expose Plaid/Stripe/backend secrets client-side
- ✅ ALWAYS use `.gitignore` for `.env`, config files, key files
- ✅ ALWAYS use GitHub Secrets for CI/CD workflows
- ✅ ALWAYS rotate tokens that were accidentally committed

### Sensitive Data
- ❌ NEVER log passwords, tokens, or PII to console in production
- ✅ Use `kDebugMode` checks before any sensitive debug logging
- ✅ Encrypt sensitive data in Firestore where applicable

### GitHub Tokens
- Set expiry dates on all personal access tokens
- Use fine-grained tokens with minimal required permissions
- Renew before expiry — calendar reminder recommended

---

## 7. Accessibility (a11y)

### Required for All Apps
- [ ] All interactive elements have `tooltip` or `semanticsLabel`
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] App works with keyboard-only navigation (Tab, Enter, Escape)
- [ ] Images have alt text / semantic labels
- [ ] Font sizes are never below 12px (14px preferred minimum)
- [ ] Focus states are visible on all interactive elements

### Flutter
```dart
// Always add tooltips to icon buttons
IconButton(
  tooltip: 'Show password',
  icon: Icon(Icons.visibility),
  onPressed: () {},
)

// Use Semantics for custom widgets
Semantics(
  label: 'Jacob user profile button',
  button: true,
  child: GestureDetector(...),
)
```

---

## 8. Performance Standards

### Flutter Web
- Use `flutter build web --release` for production (never ship debug builds)
- Add `--tree-shake-icons` to remove unused icons
- Lazy-load routes with `go_router`
- Avoid rebuilding entire widget trees — use `const` constructors everywhere possible

### General
- Images: compress before upload, use WebP where supported
- Avoid blocking the main thread with heavy computation — use `Isolate` or `compute()`
- Cache Firestore queries where data doesn't change frequently
- Set appropriate Firestore indexes for queries with multiple `where` clauses

---

## 9. Responsive Design

### Breakpoints (Standard)
| Name | Width |
|------|-------|
| Mobile | < 600px |
| Tablet | 600px – 1024px |
| Desktop | > 1024px |

### Flutter
```dart
// Always constrain forms to a max width
ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 460),
  child: ...,
)

// Use LayoutBuilder for responsive layouts
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth < 600) {
      return MobileLayout();
    }
    return DesktopLayout();
  },
)
```

---

## 10. Error Handling & Feedback

### Rules
- ✅ ALWAYS show loading indicators on async actions
- ✅ ALWAYS show human-readable error messages (not stack traces)
- ✅ ALWAYS give success feedback (SnackBar, dialog, or navigation)
- ✅ Use `try/catch` on ALL Firebase and API calls
- ❌ NEVER show blank screens on error — always show a fallback UI

### Standard Error Widget
```dart
Widget buildError(String message) => Center(
  child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: () => /* retry logic */,
        child: const Text('Try Again'),
      ),
    ],
  ),
);
```

---

## 11. State Management

### Current Standard: Provider
- Use `Provider` for global state (auth, user data)
- Use `StatefulWidget` for local UI state
- Use `StreamBuilder` for Firestore real-time data

### Rules
- ❌ Do NOT use `setState` for data that multiple widgets need
- ✅ Keep business logic OUT of widgets — put it in services
- ✅ Services go in `lib/services/`, models in `lib/models/`

---

## 12. Git & Repository Standards

### Branch Strategy
```
main          → production-ready code only
develop       → integration branch
feature/xxx   → new features
fix/xxx       → bug fixes
hotfix/xxx    → urgent production fixes
```

### Commit Message Format
```
feat: add autofill support to login screen
fix: correct password reset email flow
refactor: move auth logic to FirebaseService
docs: update BASE_PROTOCOLS with autofill standards
chore: bump firebase_core to 3.15.2
```

### Required Files in Every Repo
```
README.md               ← Project overview, setup, usage
.gitignore              ← Never commit secrets/build artifacts
docs/base-protocols/    ← This standards folder
```

### .gitignore Minimum
```
# Secrets
.env
*.key
firebase_config.dart
google-services.json
GoogleService-Info.plist

# Build artifacts
build/
.dart_tool/
*.iml

# IDE
.idea/
.vscode/
```

---

## 13. Environment & Config Management

### Setup for Flutter
```
lib/
  config/
    env.dart          ← environment constants (never secrets)
    firebase_options.dart  ← gitignored, generated by FlutterFire CLI
```

### Using FlutterFire CLI (Recommended over manual config)
```bash
# Install
dart pub global activate flutterfire_cli

# Configure (generates firebase_options.dart automatically)
flutterfire configure
```

This is preferred over manually pasting Firebase config into `main.dart`.

---

## 14. Deployment Checklist

Before deploying any app to production:

### Code
- [ ] All `YOUR_API_KEY` / `YOUR_PROJECT_ID` placeholders replaced
- [ ] No hardcoded passwords or secrets
- [ ] `flutter analyze` passes with no errors
- [ ] App tested on Chrome, Firefox, Safari, Edge

### Firebase
- [ ] Firestore security rules published (not in test mode)
- [ ] Authentication method(s) enabled
- [ ] Firebase Hosting configured (if using)

### GitHub
- [ ] GitHub Actions workflow present (`.github/workflows/deploy.yml`)
- [ ] GitHub Secrets set for any CI/CD keys
- [ ] Repository visibility set correctly (public/private)

### Build
```bash
# Flutter web production build
flutter build web --release --tree-shake-icons

# Test locally before deploying
cd build/web && python -m http.server 8000
```

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-02-18 | Initial document created | Mrswami |
| 2026-02-18 | Added Remember Me standard to Auth section | Mrswami |

---

> This document is version-controlled. Any additions to these protocols should be committed with a `docs:` prefix commit message and the changelog updated.
