param([string]$Token = $env:GITHUB_TOKEN)

$RepoName   = "healthcare-fraud-dashboard"
$GitHubUser = "khall1450"
$Branch     = "main"
$ApiBase    = "https://api.github.com"
$PublishDir = "$PSScriptRoot\.publish"

if (-not $Token) {
    Write-Host "A GitHub Personal Access Token is required." -ForegroundColor Yellow
    $SecureToken = Read-Host "Paste your token here" -AsSecureString
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken))
}

$Headers = @{
    Authorization = "token $Token"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "HealthcareFraudDashboard"
}

Write-Host "Generating dashboard..." -ForegroundColor Cyan
& "$PSScriptRoot\generate.ps1"

if (-not (Test-Path "$PSScriptRoot\dashboard.html")) {
    Write-Error "dashboard.html not found. Aborting."
    exit 1
}

Write-Host "Checking GitHub repository..." -ForegroundColor Cyan
$repoCheck = Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName" `
    -Headers $Headers -Method GET -ErrorAction SilentlyContinue

if (-not $repoCheck) {
    Write-Host "Creating repository '$RepoName'..." -ForegroundColor Cyan
    $body = @{
        name        = $RepoName
        description = "Healthcare Fraud Enforcement Dashboard"
        private     = $false
        auto_init   = $false
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "$ApiBase/user/repos" `
            -Headers $Headers -Method POST -Body $body -ContentType "application/json" | Out-Null
        Write-Host "Repository created." -ForegroundColor Green
    } catch {
        Write-Error "Failed to create repository: $_"
        exit 1
    }
} else {
    Write-Host "Repository already exists." -ForegroundColor Green
}

if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }
New-Item -ItemType Directory -Path $PublishDir | Out-Null
Copy-Item "$PSScriptRoot\dashboard.html" "$PublishDir\index.html"
Set-Content "$PublishDir\README.md" -Encoding UTF8 -Value "# Healthcare Fraud Enforcement Dashboard`n`nLive dashboard tracking federal healthcare fraud enforcement actions."

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
Push-Location $PublishDir
try {
    git init -b $Branch 2>&1 | Out-Null
    git config user.email "khall1450@users.noreply.github.com"
    git config user.name  "khall1450"
    git add .
    git commit -m "Deploy healthcare fraud dashboard" 2>&1 | Out-Null
    $RemoteUrl = "https://${Token}@github.com/$GitHubUser/$RepoName.git"
    git remote add origin $RemoteUrl 2>&1 | Out-Null
    git push --force origin $Branch 2>&1 | Out-Null
} finally {
    Pop-Location
}

# Ensure repo is public (required for GitHub Pages on free accounts)
Write-Host "Making repository public..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName" `
    -Headers $Headers -Method PATCH `
    -Body '{"private":false}' -ContentType "application/json" | Out-Null

Write-Host "Enabling GitHub Pages..." -ForegroundColor Cyan
$pagesBody = @{ source = @{ branch = $Branch; path = "/" } } | ConvertTo-Json
try {
    Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName/pages" `
        -Headers $Headers -Method POST -Body $pagesBody -ContentType "application/json" | Out-Null
    Write-Host "GitHub Pages enabled." -ForegroundColor Green
} catch {
    try {
        Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName/pages" `
            -Headers $Headers -Method PUT -Body $pagesBody -ContentType "application/json" | Out-Null
        Write-Host "GitHub Pages updated." -ForegroundColor Green
    } catch {
        Write-Host "Pages may already be configured." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Dashboard published!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host " URL: https://$GitHubUser.github.io/$RepoName/" -ForegroundColor Cyan
Write-Host " (May take 1-2 minutes to go live)" -ForegroundColor Yellow
Write-Host ""
