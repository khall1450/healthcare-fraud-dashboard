param([string]$Token = $env:GITHUB_TOKEN)

$RepoName   = "healthcare-fraud-dashboard"
$GitHubUser = "khall1450"
$ApiBase    = "https://api.github.com"

if (-not $Token) {
    Write-Host "GitHub Personal Access Token required." -ForegroundColor Yellow
    $SecureToken = Read-Host "Paste your token here" -AsSecureString
    $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureToken))
}

$Headers = @{
    Authorization = "token $Token"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "HealthcareFraudDashboard"
}

Write-Host ""
Write-Host "This will disable GitHub Pages and make the repo private." -ForegroundColor Yellow
Write-Host "The public website will be taken down." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Type 'yes' to confirm"

if ($confirm -ne "yes") {
    Write-Host "Cancelled." -ForegroundColor Gray
    exit 0
}

# Disable GitHub Pages
Write-Host "Disabling GitHub Pages..." -ForegroundColor Cyan
try {
    Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName/pages" `
        -Headers $Headers -Method DELETE | Out-Null
    Write-Host "GitHub Pages disabled." -ForegroundColor Green
} catch {
    Write-Host "Pages already disabled or not configured." -ForegroundColor Yellow
}

# Make repo private
Write-Host "Making repository private..." -ForegroundColor Cyan
Invoke-RestMethod -Uri "$ApiBase/repos/$GitHubUser/$RepoName" `
    -Headers $Headers -Method PATCH `
    -Body '{"private":true}' -ContentType "application/json" | Out-Null
Write-Host "Repository is now private." -ForegroundColor Green

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Dashboard taken down." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host " Run publish.ps1 to put it back up." -ForegroundColor Gray
Write-Host ""
