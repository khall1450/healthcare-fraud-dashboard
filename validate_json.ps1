$file = 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json'
try {
    $content = Get-Content $file -Raw -Encoding UTF8
    $parsed = $content | ConvertFrom-Json
    Write-Host "JSON valid. Actions count: $($parsed.actions.Count)"
} catch {
    Write-Host "JSON ERROR: $_"
}
