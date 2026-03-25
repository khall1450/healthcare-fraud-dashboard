$actions = (Get-Content 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json' -Raw | ConvertFrom-Json).actions

$totalFraud    = ($actions | Measure-Object -Property amount_numeric -Sum).Sum
$criminalTotal = ($actions | Where-Object { $_.type -eq 'Criminal Enforcement' } | Measure-Object -Property amount_numeric -Sum).Sum
$civilTotal    = ($actions | Where-Object { $_.type -eq 'Civil Action' } | Measure-Object -Property amount_numeric -Sum).Sum
$auditTotal    = ($actions | Where-Object { $_.type -eq 'Audit' } | Measure-Object -Property amount_numeric -Sum).Sum
$largest       = ($actions | Measure-Object -Property amount_numeric -Maximum).Maximum
$withAmounts   = ($actions | Where-Object { $_.amount_numeric -gt 0 }).Count

Write-Host "Total fraud alleged/found (all types): `$$([Math]::Round($totalFraud/1e9,1))B"
Write-Host "Criminal enforcement total:            `$$([Math]::Round($criminalTotal/1e9,1))B"
Write-Host "Civil settlements total:               `$$([Math]::Round($civilTotal/1e6,0))M"
Write-Host "Audit/improper payments total:         `$$([Math]::Round($auditTotal/1e9,1))B"
Write-Host "Largest single case:                   `$$([Math]::Round($largest/1e9,1))B"
Write-Host "Actions with dollar amounts:           $withAmounts of $($actions.Count)"
Write-Host ""
Write-Host "Top 10 by amount:"
$actions | Where-Object { $_.amount_numeric -gt 0 } | Sort-Object amount_numeric -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host "  `$$([Math]::Round($_.amount_numeric/1e6,1))M  $($_.date)  $($_.title.Substring(0,[Math]::Min(60,$_.title.Length)))"
}
