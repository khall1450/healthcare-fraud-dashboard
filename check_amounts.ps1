$data = (Get-Content 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json' -Raw | ConvertFrom-Json).actions
foreach ($a in $data) {
    if ($a.agency -ne 'DOJ' -and [double]$a.amount_numeric -gt 0) {
        Write-Host ("[$($a.agency)] [$($a.type)] $($a.amount)")
    }
}
