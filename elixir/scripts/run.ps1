param([string]$Platform)
$ErrorActionPreference = 'Stop'
if ($Platform -notin @('bluesky', 'mastodon')) { throw 'Usage: .\run.ps1 bluesky|mastodon [options]' }
& escript (Join-Path $PSScriptRoot 'chorusdraft') $Platform --base (Join-Path $PSScriptRoot $Platform) @args
exit $LASTEXITCODE
