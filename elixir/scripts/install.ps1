param([string]$Destination)
$ErrorActionPreference = 'Stop'
$parent = Split-Path $PSScriptRoot -Parent
if ((Test-Path -LiteralPath (Join-Path $parent 'bot.bat')) -and (Test-Path -LiteralPath (Join-Path $parent 'launcher\ChorusDraft.exe'))) {
    & (Join-Path $parent 'install.ps1') @PSBoundParameters
    exit $LASTEXITCODE
}
if (-not $Destination) {
    $version = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
    $Destination = Join-Path $env:LOCALAPPDATA "ChorusDraft-$version"
}
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) {
    throw "Destination already exists: $dest. Choose another directory or remove the old install first."
}
& (Join-Path $PSScriptRoot 'verify.ps1') $PSScriptRoot
$null = New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force
$null = New-Item -ItemType Directory -Path $dest
foreach ($item in @('chorusdraft','run.ps1','setup.ps1','install.ps1','verify.ps1','bluesky','mastodon','source','README.md','RELEASE_NOTES.md','CHANGELOG.md','SECURITY.md','LICENSE','NOTICE','THIRD_PARTY_NOTICES.md','VERSION','MANIFEST.sha256')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $item) -Destination $dest -Recurse
}
& (Join-Path $dest 'verify.ps1') $dest
& (Join-Path $dest 'setup.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Output "Installed ChorusDraft in $dest. Edit bluesky\.env and/or mastodon\.env before use."
