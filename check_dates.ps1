$actions = Get-Content 'C:\Users\khall\HealthcareFraudDashboard\research_actions.json' -Raw | ConvertFrom-Json
$sorted = $actions | Sort-Object date
Write-Host "Date range: $($sorted[0].date) to $($sorted[-1].date)"
Write-Host ""
Write-Host "All dates and titles:"
foreach ($a in $sorted) {
    Write-Host "$($a.date) | $($a.agency) | $($a.title.Substring(0, [Math]::Min(70, $a.title.Length)))"
}
