# GitHub Repository Setup Script
# This script creates a new private repo and renames an existing repo

param(
    [Parameter(Mandatory=$false)]
    [string]$GitHubToken
)

# If token not provided, try environment variable or prompt
if (-not $GitHubToken) {
    $GitHubToken = $env:GITHUB_TOKEN
}

if (-not $GitHubToken) {
    Write-Host "GitHub Personal Access Token required." -ForegroundColor Yellow
    Write-Host "You can:" -ForegroundColor Yellow
    Write-Host "  1. Set environment variable: `$env:GITHUB_TOKEN = 'your_token'" -ForegroundColor Cyan
    Write-Host "  2. Pass as parameter: .\github-setup.ps1 -GitHubToken 'your_token'" -ForegroundColor Cyan
    Write-Host "  3. Enter it now (will be hidden):" -ForegroundColor Cyan
    $secureToken = Read-Host -AsSecureString "GitHub Token"
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $GitHubToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

$headers = @{
    "Authorization" = "token $GitHubToken"
    "Accept" = "application/vnd.github.v3+json"
}

$username = "mrswami"
$baseUrl = "https://api.github.com"

# Function to create a new repository
function Create-Repository {
    param(
        [string]$RepoName,
        [bool]$IsPrivate = $true
    )
    
    $body = @{
        name = $RepoName
        private = $IsPrivate
        description = "Rent Calculator Application"
        auto_init = $false
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/user/repos" -Method Post -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "✓ Successfully created repository: $RepoName" -ForegroundColor Green
        Write-Host "  Repository URL: $($response.html_url)" -ForegroundColor Cyan
        return $response
    }
    catch {
        Write-Host "✗ Error creating repository: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode -eq 422) {
            Write-Host "  Repository may already exist or name is invalid" -ForegroundColor Yellow
        }
        return $null
    }
}

# Function to rename a repository
function Rename-Repository {
    param(
        [string]$OldName,
        [string]$NewName
    )
    
    $body = @{
        name = $NewName
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$baseUrl/repos/$username/$OldName" -Method Patch -Headers $headers -Body $body -ContentType "application/json"
        Write-Host "✓ Successfully renamed repository: $OldName → $NewName" -ForegroundColor Green
        Write-Host "  New repository URL: $($response.html_url)" -ForegroundColor Cyan
        return $response
    }
    catch {
        Write-Host "✗ Error renaming repository: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.Response.StatusCode -eq 404) {
            Write-Host "  Repository '$OldName' not found" -ForegroundColor Yellow
        }
        elseif ($_.Exception.Response.StatusCode -eq 422) {
            Write-Host "  New name '$NewName' may already exist or be invalid" -ForegroundColor Yellow
        }
        return $null
    }
}

Write-Host "`n=== GitHub Repository Setup ===" -ForegroundColor Cyan
Write-Host "Username: $username`n" -ForegroundColor Cyan

# Step 1: Create new rent calculator repository
Write-Host "Step 1: Creating new repository 'rent-calculator'..." -ForegroundColor Yellow
$newRepo = Create-Repository -RepoName "rent-calculator" -IsPrivate $true

# Step 2: Rename existing repository
Write-Host "`nStep 2: Renaming repository 'rent-friends' to 'rave-friends'..." -ForegroundColor Yellow
$renamedRepo = Rename-Repository -OldName "rent-friends" -NewName "rave-friends"

Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
if ($newRepo) {
    Write-Host "New repository created: $($newRepo.html_url)" -ForegroundColor Green
}
if ($renamedRepo) {
    Write-Host "Repository renamed: $($renamedRepo.html_url)" -ForegroundColor Green
}
