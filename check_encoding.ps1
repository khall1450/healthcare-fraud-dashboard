$file = 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json'
$content = Get-Content $file -Raw -Encoding UTF8
$emDash = [char]0x2014
$emDashCount = ([regex]::Matches($content, [regex]::Escape($emDash))).Count
Write-Host "Em dashes (U+2014) found: $emDashCount"
$bad = [char]0x00E2 + [char]0x20AC
$badCount = ([regex]::Matches($content, [regex]::Escape($bad))).Count
Write-Host "Remaining mojibake (a-circ+euro prefix): $badCount"
$joseGood = ([regex]::Matches($content, 'Jos[e\u00e9]')).Count
Write-Host "Jose entries: $joseGood"
# Show first 3 em dash context
$matches = [regex]::Matches($content, '.{20}' + [regex]::Escape($emDash) + '.{20}')
$matches | Select-Object -First 3 | ForEach-Object { Write-Host "  ...  $($_.Value)  ..." }
