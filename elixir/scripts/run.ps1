param([string]$Platform)
$ErrorActionPreference = 'Stop'
$env:ERL_CRASH_DUMP = 'NUL'
$env:ERL_CRASH_DUMP_SECONDS = '0'
if ($Platform -notin @('bluesky', 'mastodon')) { throw 'Usage: .\run.ps1 bluesky|mastodon [options]' }
& escript (Join-Path $PSScriptRoot 'chorusdraft') $Platform @args --base (Join-Path $PSScriptRoot $Platform)
exit $LASTEXITCODE
