param([string]$Platform)
$ErrorActionPreference = 'Stop'
$platforms = @('bluesky', 'mastodon')
if ($Platform) {
    if ($Platform -notin $platforms) { throw 'Usage: .\setup.ps1 [bluesky|mastodon]' }
    $platforms = @($Platform)
}
foreach ($platform in $platforms) {
    & escript (Join-Path $PSScriptRoot 'chorusdraft') $platform --base (Join-Path $PSScriptRoot $platform) --setup
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
