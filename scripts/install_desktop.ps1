param([string]$Destination)
$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot

function Test-ChorusDraftInstall([string]$Root) {
    return (Test-Path -LiteralPath (Join-Path $Root 'VERSION')) -and
        (Test-Path -LiteralPath (Join-Path $Root 'elixir\chorusdraft'))
}

if (-not $Destination) {
    if (-not $env:LOCALAPPDATA) { throw 'LOCALAPPDATA is not set.' }
    $Destination = Join-Path $env:LOCALAPPDATA 'Programs\ChorusDraft'
}
$dest = [IO.Path]::GetFullPath($Destination)
$upgrade = $false
if (Test-Path -LiteralPath $dest) {
    if (-not (Test-ChorusDraftInstall $dest)) {
        throw "Destination already exists and is not a ChorusDraft install: $dest. Choose another directory or remove that path first."
    }
    $upgrade = $true
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

function Copy-AccountState($fromRoot, $toRoot) {
    foreach ($platform in @('bluesky', 'mastodon')) {
        $from = Join-Path $fromRoot (Join-Path 'elixir' $platform)
        $to = Join-Path $toRoot (Join-Path 'elixir' $platform)
        $null = New-Item -ItemType Directory -Path (Join-Path $to 'config') -Force
        $envFile = Join-Path $from '.env'
        if (Test-Path -LiteralPath $envFile) {
            Copy-Item -LiteralPath $envFile -Destination (Join-Path $to '.env') -Force
        }
        foreach ($folder in @('data', 'logs')) {
            $path = Join-Path $from $folder
            if (Test-Path -LiteralPath $path) {
                $target = Join-Path $to $folder
                if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
                Copy-Item -LiteralPath $path -Destination $target -Recurse
            }
        }
        foreach ($file in @('do_not_contact.txt', 'target_accounts.txt')) {
            $path = Join-Path $from (Join-Path 'config' $file)
            if (Test-Path -LiteralPath $path) {
                Copy-Item -LiteralPath $path -Destination (Join-Path $to (Join-Path 'config' $file)) -Force
            }
        }
    }
}

Verify-Package $src
$parent = Split-Path $dest -Parent
$null = New-Item -ItemType Directory -Path $parent -Force
$staging = Join-Path $parent ("chorusdraft-staging-" + [Guid]::NewGuid())
try {
    $null = New-Item -ItemType Directory -Path $staging
    foreach ($item in Get-ChildItem -LiteralPath $src) {
        Copy-Item -LiteralPath $item.FullName -Destination $staging -Recurse
    }
    Verify-Package $staging
    if ($upgrade) { Copy-AccountState $dest $staging }
    & (Join-Path $staging 'elixir\setup.ps1')
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    if ($upgrade) {
        $backup = "$dest.replacing"
        if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Recurse -Force }
        Rename-Item -LiteralPath $dest -NewName (Split-Path $backup -Leaf)
        try {
            Rename-Item -LiteralPath $staging -NewName (Split-Path $dest -Leaf)
        } catch {
            Rename-Item -LiteralPath $backup -NewName (Split-Path $dest -Leaf)
            throw
        }
        Remove-Item -LiteralPath $backup -Recurse -Force
    } else {
        Rename-Item -LiteralPath $staging -NewName (Split-Path $dest -Leaf)
    }
    Register-Application $dest
    if (Launch-Gui $dest) {
        Write-Output "Installed ChorusDraft in $dest and opened the desktop app."
    } else {
        Write-Output "Installed ChorusDraft in $dest."
        Write-Output "Open ChorusDraft from the Start menu or run: $(Join-Path $dest 'bot.bat')"
    }
    Write-Output 'Use Open configuration in the app to add your account and AI provider.'
    exit 0
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
