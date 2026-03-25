$data = (Get-Content 'C:\Users\khall\HealthcareFraudDashboard\data\actions.json' -Raw | ConvertFrom-Json).actions
$vaguePatterns = @('/opa"', '/opa/pr"', 'newsroom"', 'newsroom/press-releases"', 'index.html"',
                   'usao-edky"', 'usao-sdfl"', 'usao-edny"', 'usao-cdca"', 'usao-ma"',
                   'usao-edva"', 'usao-ndga"', 'usao-edca"', 'reuters.com"',
                   'reports-and-publications"', 'hhs.gov/about"', 'whitehouse.gov"',
                   'about/news"', 'criminal/media"', 'oig.hhs.gov/reports/all"')

foreach ($a in $data) {
    $link = $a.link
    # Flag if link ends at a section/homepage rather than a specific page
    $isVague = ($link -match '/(newsroom|opa|usao-\w+|about/news|reports-and-publications|press-releases|criminal/media)/?$') -or
               ($link -eq 'https://www.reuters.com') -or
               ($link -match 'whitehouse\.gov/?$') -or
               ($link -match 'hhs\.gov/about/news/index\.html') -or
               ($link -match 'oig\.hhs\.gov/reports/all/?$') -or
               ($link -match 'cms\.gov/newsroom/?$') -or
               ($link -match 'cms\.gov/newsroom/press-releases/?$') -or
               ($link -match 'justice\.gov/criminal/media/\d+/dl$')
    if ($isVague) {
        Write-Host "[$($a.id)]"
        Write-Host "  title: $($a.title)"
        Write-Host "  link:  $link"
    }
}
