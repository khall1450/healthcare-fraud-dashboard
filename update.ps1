param([switch]$Silent)

$ErrorActionPreference = 'Continue'
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Definition }
$DataFile  = Join-Path $ScriptDir "data/actions.json"

$Keywords = @(
    'health care fraud', 'healthcare fraud', 'medicare fraud', 'medicaid fraud',
    'hospice fraud', 'home care fraud', 'home health fraud', 'prescription fraud',
    'opioid fraud', 'health fraud', 'fraud takedown',
    'false claims', 'false billing', 'improper billing', 'kickback', 'overbilling',
    'upcoding', 'phantom billing', 'identity theft.*medicare', 'durable medical',
    'program integrity'
)

# ALL matched items must also contain at least one healthcare-specific term
$HealthcareTerms = @(
    'medicare', 'medicaid', 'tricare', 'health care', 'healthcare', 'hospital',
    'clinic', 'physician', 'medical', 'patient', 'prescription', 'pharmacist',
    'pharmacy', 'hospice', 'home health', 'nursing home', 'assisted living',
    '\bcms\b', '\bhhs\b', '\boig\b', 'health insurance', 'health plan',
    'clinical', 'diagnosis', 'therapy', 'dental fraud', 'ambulance fraud',
    '\bdme\b', 'durable medical', 'behavioral health', 'substance abuse',
    'affordable care act', 'aca enrollment', 'chip program'
)

$Feeds = @(
    @{ Name = 'DOJ';     Agency = 'DOJ';     Url = 'https://www.justice.gov/news/rss';                       Enabled = $true },
    @{ Name = 'HHS-OIG'; Agency = 'HHS-OIG'; Url = 'https://oig.hhs.gov/rss/oig-rss.xml';                   Enabled = $true },
    @{ Name = 'CMS';     Agency = 'CMS';     Url = 'https://www.cms.gov/newsroom/rss/press-releases';        Enabled = $true },
    @{ Name = 'HHS';     Agency = 'HHS';     Url = 'https://www.hhs.gov/rss/news.xml';                       Enabled = $true },
    @{ Name = 'DOJ-USAO';Agency = 'DOJ';     Url = 'https://www.justice.gov/usao/pressreleases/rss';         Enabled = $true }
)

function Write-Log { param([string]$Msg, [string]$Color = 'White'); if (-not $Silent) { Write-Host "  $Msg" -ForegroundColor $Color } }
function Test-AnyKeyword { param([string]$Text); $lower = $Text.ToLower(); foreach ($kw in $Keywords) { if ($lower -match $kw) { return $true } }; return $false }
function Test-HealthcareContext { param([string]$Text); $lower = $Text.ToLower(); foreach ($term in $HealthcareTerms) { if ($lower -match $term) { return $true } }; return $false }

function Get-ActionType {
    param([string]$Title, [string]$Desc)
    $text = "$Title $Desc".ToLower()
    if ($text -match 'plead|convict|indict|charg|guilty|arrest|prosecut') { return 'Criminal Enforcement' }
    if ($text -match 'civil|settlement|civil.+action|false claims act')    { return 'Civil Action' }
    if ($text -match 'audit|review|report|oig')                            { return 'Audit' }
    if ($text -match 'rule|regulation|final.+rule|proposed.+rule|loophole'){ return 'Rule/Regulation' }
    if ($text -match 'task force|division|unit|strike force|creat')        { return 'Structural/Organizational' }
    if ($text -match 'investigat|fact.?find|mission')                      { return 'Investigation' }
    if ($text -match 'ai|artificial intelligence|machine learning')        { return 'Technology/Innovation' }
    return 'Administrative Action'
}

function Get-StateName {
    param([string]$Text)
    $stateMap = @{ 'California'='CA';'Florida'='FL';'Minnesota'='MN';'New York'='NY';'Kentucky'='KY';'Maine'='ME';'Arizona'='AZ';'Texas'='TX';'Ohio'='OH';'Wisconsin'='WI';'Indiana'='IN';'Michigan'='MI';'Georgia'='GA';'Illinois'='IL';'Louisiana'='LA';'Pennsylvania'='PA';'Tennessee'='TN';'Nevada'='NV';'Colorado'='CO';'Washington'='WA';'Oregon'='OR' }
    foreach ($state in $stateMap.Keys) { if ($Text -match "\b$state\b") { return $stateMap[$state] } }
    return $null
}

function Get-ExtractAmount {
    param([string]$Text)
    if ($Text -match '\$[\d,]+(?:\.\d+)?\s*billion') { return @{ display = $Matches[0]; numeric = [double]($Matches[0] -replace '[\$,billion\s]','') * 1e9 } }
    if ($Text -match '\$[\d,]+(?:\.\d+)?\s*million')  { return @{ display = $Matches[0]; numeric = [double]($Matches[0] -replace '[\$,million\s]','') * 1e6 } }
    return $null
}

function New-ActionId {
    param([string]$Agency, [string]$Date, [string]$Link)
    $hash = [System.Math]::Abs(($Link ?? $Date + $Agency).GetHashCode())
    return "$($Agency.ToLower() -replace '\W','-')-$Date-$hash"
}

Write-Log "Loading existing data..." Cyan
$data = Get-Content $DataFile -Raw -Encoding UTF8 | ConvertFrom-Json

$existingLinks = @{}
foreach ($a in $data.actions) { if ($a.link) { $existingLinks[$a.link] = $true } }

$added = 0
$newActions = [System.Collections.Generic.List[object]]::new()

foreach ($feed in ($Feeds | Where-Object { $_.Enabled })) {
    Write-Log "Fetching $($feed.Name)..." White
    try {
        $resp = Invoke-WebRequest -Uri $feed.Url -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
        [xml]$xml = $resp.Content
        $items = $xml.rss.channel.item
        if (-not $items) { $items = $xml.feed.entry }
        if (-not $items) { continue }

        $count = 0
        foreach ($item in $items) {
            $title   = ($item.title.'#text' ?? $item.title) -as [string]
            $desc    = ($item.description.'#text' ?? $item.description ?? $item.summary.'#text' ?? '') -as [string]
            $link    = ($item.link ?? $item.link.href ?? '') -as [string]
            $pubDate = ($item.pubDate ?? $item.published ?? $item.updated ?? '') -as [string]

            if (-not $title) { continue }
            $descClean = $desc -replace '<[^>]+>', '' -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' -replace '&nbsp;',' '
            $descClean = $descClean.Trim()

            if (-not (Test-AnyKeyword "$title $descClean")) { continue }
            if (-not (Test-HealthcareContext "$title $descClean")) { continue }
            if ($link -and $existingLinks.ContainsKey($link)) { continue }

            $dateStr = try { [DateTime]::Parse($pubDate).ToString('yyyy-MM-dd') } catch { (Get-Date).ToString('yyyy-MM-dd') }
            $amtInfo  = Get-ExtractAmount "$title $descClean"
            $stateAbb = Get-StateName "$title $descClean"
            $atype    = Get-ActionType $title $descClean

            $newActions.Add([PSCustomObject]@{
                id             = New-ActionId $feed.Agency $dateStr $link
                date           = $dateStr
                agency         = $feed.Agency
                type           = $atype
                title          = ($title -replace '\s+', ' ').Trim()
                description    = if ($descClean.Length -gt 600) { $descClean.Substring(0,600) + '…' } else { $descClean }
                amount         = if ($amtInfo) { $amtInfo.display } else { $null }
                amount_numeric = if ($amtInfo) { $amtInfo.numeric } else { 0 }
                officials      = @()
                link           = $link
                link_label     = "$($feed.Name) Press Release"
                social_posts   = @()
                tags           = @()
                state          = $stateAbb
                source_type    = 'official'
                auto_fetched   = $true
            })
            if ($link) { $existingLinks[$link] = $true }
            $added++
            $count++
        }
        Write-Log "  $($feed.Name): $count new items." $(if ($count -gt 0) {'Green'} else {'Gray'})
    } catch {
        Write-Log "  WARNING: $($feed.Name) - $($_.Exception.Message)" Yellow
    }
}

$data.metadata.last_updated = (Get-Date).ToString('o')

if ($added -gt 0) {
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($a in $data.actions) { $all.Add($a) }
    foreach ($a in $newActions) { $all.Add($a) }
    $data.actions = $all.ToArray()
    Write-Log "Added $added new action(s)." Green
} else {
    Write-Log "No new actions found." Cyan
}

$data | ConvertTo-Json -Depth 10 | Set-Content $DataFile -Encoding UTF8
Write-Log "Saved." Green
Write-Output "ADDED:$added"
