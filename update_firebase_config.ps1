# Firebase Configuration Update Script
# Run this script after you get your Firebase config from Firebase Console

Write-Host "=== Firebase Configuration Updater ===" -ForegroundColor Cyan
Write-Host ""

$apiKey = Read-Host "Enter your Firebase API Key"
$authDomain = Read-Host "Enter your Firebase Auth Domain"
$projectId = Read-Host "Enter your Firebase Project ID"
$storageBucket = Read-Host "Enter your Firebase Storage Bucket"
$messagingSenderId = Read-Host "Enter your Messaging Sender ID"
$appId = Read-Host "Enter your App ID"

Write-Host ""
Write-Host "Updating lib/main.dart..." -ForegroundColor Yellow

$mainDartPath = "lib\main.dart"
$content = Get-Content $mainDartPath -Raw

# Replace Firebase configuration
$content = $content -replace "apiKey: 'YOUR_API_KEY'", "apiKey: '$apiKey'"
$content = $content -replace "appId: 'YOUR_APP_ID'", "appId: '$appId'"
$content = $content -replace "messagingSenderId: 'YOUR_MESSAGING_SENDER_ID'", "messagingSenderId: '$messagingSenderId'"
$content = $content -replace "projectId: 'YOUR_PROJECT_ID'", "projectId: '$projectId'"
$content = $content -replace "authDomain: 'YOUR_AUTH_DOMAIN'", "authDomain: '$authDomain'"
$content = $content -replace "storageBucket: 'YOUR_STORAGE_BUCKET'", "storageBucket: '$storageBucket'"

Set-Content -Path $mainDartPath -Value $content -NoNewline

Write-Host "✓ Firebase configuration updated successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Make sure you've enabled Authentication (Email/Password) in Firebase Console"
Write-Host "2. Make sure you've created Firestore Database"
Write-Host "3. Set up Firestore security rules (see FIREBASE_SETUP.md)"
Write-Host "4. Run: flutter run -d chrome"
