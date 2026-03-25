$data = (Get-Content 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json' -Raw | ConvertFrom-Json).actions
foreach ($a in $data) {
    Write-Host "--- $($a.id)"
    Write-Host "    link: $($a.link)"
    if ($a.social_posts.Count -gt 0) {
        foreach ($p in $a.social_posts) {
            Write-Host "    x_url: $($p.post_url)  account: $($p.account)"
        }
    }
}
