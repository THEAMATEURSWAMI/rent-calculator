$apiKey = "AIzaSyDrhe_jNTXrGF1xiclVPXWAuztRAglGXuM"
$signInUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey"
$deleteUrl = "https://identitytoolkit.googleapis.com/v1/accounts:delete?key=$apiKey"

$users = @(
    @{ name = "Jacob"; email = "jacob@rentcalc.app"; password = "Jacob@2024!" },
    @{ name = "Nico";  email = "nico@rentcalc.app";  password = "Nico@2024!"  },
    @{ name = "Eddy";  email = "eddy@rentcalc.app";  password = "Eddy@2024!"  }
)

Write-Host "=== Deleting old default users ===" -ForegroundColor Cyan

foreach ($user in $users) {
    Write-Host "Processing $($user.name)..." -ForegroundColor Yellow
    $signInBody = @{ email = $user.email; password = $user.password; returnSecureToken = $true } | ConvertTo-Json
    try {
        $signIn = Invoke-RestMethod -Uri $signInUrl -Method Post -Body $signInBody -ContentType "application/json"
        $deleteBody = @{ idToken = $signIn.idToken } | ConvertTo-Json
        Invoke-RestMethod -Uri $deleteUrl -Method Post -Body $deleteBody -ContentType "application/json" | Out-Null
        Write-Host "  Deleted: $($user.email)" -ForegroundColor Green
    } catch {
        $code = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error.message
        if ($code -match "NOT_FOUND|INVALID_PASSWORD|INVALID_LOGIN_CREDENTIALS") {
            Write-Host "  Skipped $($user.name): $code" -ForegroundColor Gray
        } else {
            Write-Host "  Error for $($user.name): $code" -ForegroundColor Red
        }
    }
}

Write-Host "Done! Restart the Flutter app to recreate accounts with password: 46464061" -ForegroundColor Green
