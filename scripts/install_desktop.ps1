param([string]$Destination)
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

if (-not $Destination) {
    $version = (Get-Content -LiteralPath (Join-Path $src 'VERSION') -Raw).Trim()
    $Destination = Join-Path $env:LOCALAPPDATA "ChorusDraft-$version"
}
$dest = [IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $dest) {
    throw "Destination already exists: $dest. Choose another directory or remove the old install first."
}

function Verify-Package($root) {
    foreach ($line in [IO.File]::ReadAllLines((Join-Path $root 'MANIFEST.sha256'))) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw 'Invalid package manifest.' }
        $expected = $Matches[1]
        $relative = $Matches[2]
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[/\\])\.\.([/\\]|$)') {
            throw 'Invalid manifest path.'
        }
        $actual = (Get-FileHash -LiteralPath (Join-Path $root $relative) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -ne $expected) { throw "Package checksum failed: $relative" }
    }
}

function Register-Application($installRoot) {
    if (-not $env:APPDATA) { throw 'APPDATA is not set.' }
    $null = New-Item -ItemType Directory -Path $env:APPDATA -Force
    $programs = [IO.Path]::Combine($env:APPDATA, 'Microsoft', 'Windows', 'Start Menu', 'Programs')
    $null = New-Item -ItemType Directory -Path $programs -Force
    $exe = [IO.Path]::GetFullPath((Join-Path $installRoot 'launcher\ChorusDraft.exe'))
    $shortcut = Join-Path $programs 'ChorusDraft.lnk'
    try {
        $shell = New-Object -ComObject WScript.Shell
        $link = $shell.CreateShortcut($shortcut)
        $link.TargetPath = $exe
        $link.WorkingDirectory = [IO.Path]::GetFullPath($installRoot)
        $link.Description = 'Bluesky and Mastodon drafting bot'
        $link.Save()
    } catch {
        $cmd = Join-Path $programs 'ChorusDraft.cmd'
        Set-Content -LiteralPath $cmd -Value "@echo off`r`nstart `"`" `"$exe`"`r`n" -Encoding ascii
    }
}

function Launch-Gui($installRoot) {
    if ($env:CI -eq 'true') { return $false }
    $exe = Join-Path $installRoot 'launcher\ChorusDraft.exe'
    if (-not (Test-Path -LiteralPath $exe)) { return $false }
    try {
        Start-Process -FilePath $exe -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

Verify-Package $src
$null = New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force
$null = New-Item -ItemType Directory -Path $dest
foreach ($item in Get-ChildItem -LiteralPath $src) {
    if ($item.Name -in @('desktop-source', 'build-scripts')) { continue }
    Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse
}
& (Join-Path $dest 'elixir\setup.ps1')
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Register-Application $dest
if (Launch-Gui $dest) {
    Write-Output "Installed ChorusDraft in $dest and opened the desktop app."
} else {
    Write-Output "Installed ChorusDraft in $dest."
    Write-Output "Open ChorusDraft from the Start menu or run: $(Join-Path $dest 'bot.bat')"
}
Write-Output 'Edit elixir\bluesky\.env and/or elixir\mastodon\.env before use.'
exit 0
