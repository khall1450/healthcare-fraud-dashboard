$j = Get-Content 'data/actions.json' -Raw | ConvertFrom-Json
Write-Output "Total entries: $($j.actions.Count)"
Write-Output ""

# Check for mojibake
Write-Output "=== MOJIBAKE CHARACTERS ==="
foreach ($a in $j.actions) {
    $text = $a.title + " " + $a.description
    if ($text -match "\u00e2\u0080\u0093" -or $text -match "\u00e2\u0080\u0099" -or $text -match "\u00c3\u00a9" -or $text -match "\u00c3\u00a1" -or $text -match "\u00e2\u0080\u0094" -or $text -match "\u00e2\u0080\u00a6") {
        Write-Output "  $($a.id)"
    }
}
Write-Output ""

# Check for missing dollar signs in titles
Write-Output "=== MISSING DOLLAR SIGNS IN TITLES ==="
foreach ($a in $j.actions) {
    if ($a.title -match 'for \.\d|for  [A-Z]|to  [A-Z]|to \.\d|Pay \.\d|Pay  [A-Z]| \$[A-Z]') {
        Write-Output "  $($a.id): $($a.title)"
    }
}
Write-Output ""

# Check for generic links
Write-Output "=== GENERIC LINKS ==="
$genericLinks = @(
    'https://www.justice.gov/opa',
    'https://www.cms.gov/newsroom',
    'https://www.hhs.gov/about/news/index.html',
    'https://oig.hhs.gov/reports-and-publications/',
    'https://oig.hhs.gov/fraud/enforcement/',
    'https://www.reuters.com',
    'https://www.justice.gov/usao-cdca',
    'https://www.propublica.org/topics/health-care'
)
foreach ($a in $j.actions) {
    if ($a.link -in $genericLinks) {
        Write-Output "  $($a.id): $($a.link)"
    }
}
