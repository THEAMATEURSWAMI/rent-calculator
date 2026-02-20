# GitHub Repository Setup Instructions

This guide will help you create a new private repository for the rent calculator and rename your existing repository.

## Prerequisites

You'll need a GitHub Personal Access Token (PAT) with the following permissions:
- `repo` (full control of private repositories)

### Creating a GitHub Personal Access Token

1. Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Rent Calculator Setup")
4. Select the `repo` scope
5. Click "Generate token"
6. Copy the token immediately (you won't be able to see it again)

## Running the Setup Script

### Option 1: Using Environment Variable (Recommended)

```powershell
# Set your GitHub token as an environment variable
$env:GITHUB_TOKEN = "your_token_here"

# Run the script
.\github-setup.ps1 -GitHubToken $env:GITHUB_TOKEN
```

### Option 2: Direct Token Input

```powershell
# Run the script and enter token when prompted
.\github-setup.ps1 -GitHubToken "your_token_here"
```

### Option 3: Interactive Prompt

If you prefer not to pass the token as a parameter, you can modify the script to prompt for it securely.

## What the Script Does

1. **Creates a new repository**: `rent-calculator` (private) for account `mrswami`
2. **Renames existing repository**: `rent-friends` → `rave-friends`

## Manual Alternative

If you prefer to do this manually:

### Create New Repository
1. Go to https://github.com/new
2. Repository name: `rent-calculator`
3. Set to Private
4. Click "Create repository"

### Rename Existing Repository
1. Go to https://github.com/mrswami/rent-friends/settings
2. Scroll down to "Repository name"
3. Change from `rent-friends` to `rave-friends`
4. Click "Rename"

## Troubleshooting

- **401 Unauthorized**: Check that your token is valid and has the correct permissions
- **404 Not Found**: The repository `rent-friends` doesn't exist or you don't have access
- **422 Unprocessable Entity**: Repository name already exists or is invalid
