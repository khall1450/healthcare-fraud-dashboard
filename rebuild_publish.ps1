$src = Get-Content 'C:/Users/khall/HealthcareFraudDashboard/www/index.html' -Raw -Encoding UTF8

# Replace refresh button with static "Updates daily" badge
$src = $src -replace '(?s)<button class="btn btn-refresh"[^>]*>.*?</button>', '<span class="last-updated-badge"><i class="fa-solid fa-rotate-right me-1"></i> Updates daily</span>'

# Remove triggerRefresh, loadData (replace with version that doesn't call /api/refresh)
# loadData still works fine via fetch('data/actions.json') - no change needed

Set-Content 'C:/Users/khall/HealthcareFraudDashboard/.publish/index.html' -Value $src -Encoding UTF8

# Verify key features are present
$checks = @('showStatDetail', 'statModal', 'bootstrap.bundle', 'STAT_FILTERS', 'Updates daily')
foreach ($check in $checks) {
    $found = $src -match [regex]::Escape($check)
    Write-Host "$check : $(if ($found) {'OK'} else {'MISSING'})" -ForegroundColor $(if ($found) {'Green'} else {'Red'})
}
