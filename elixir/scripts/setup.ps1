param([string]$Platform)
$ErrorActionPreference = 'Stop'
$platforms = @('bluesky', 'mastodon')
if ($Platform) {
    if ($Platform -notin $platforms) { throw 'Usage: .\setup.ps1 [bluesky|mastodon]' }
    $platforms = @($Platform)
}
foreach ($product in $platforms) {
    & escript (Join-Path $PSScriptRoot 'chorusdraft') $product --base (Join-Path $PSScriptRoot $product) --setup
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
