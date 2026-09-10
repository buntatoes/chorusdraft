param()
$ErrorActionPreference = 'Stop'

function Assert-Exit([string]$Message) {
    if ($LASTEXITCODE -ne 0) { throw $Message }
}

function Assert-PrivateAcl([string]$Path) {
    $acl = Get-Acl -LiteralPath $Path
    if (-not $acl.AreAccessRulesProtected) { throw "ACL inheritance remains enabled: $Path" }
    $current = [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $allowed = @($current, 'S-1-5-18')
    foreach ($rule in $acl.Access) {
        $sid = $rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        if ($rule.AccessControlType -eq 'Allow' -and $sid -notin $allowed) {
            throw "Unexpected account can access private path: $Path"
        }
    }
}

$archives = @(Get-ChildItem -LiteralPath 'dist' -Filter 'ChorusDraft-elixir-*-windows.zip' -File)
if ($archives.Count -ne 1) { throw 'Expected exactly one ChorusDraft Windows archive.' }
$archive = $archives[0]
$sidecar = "$($archive.FullName).sha256"
$line = [IO.File]::ReadAllText($sidecar).Trim()
if ($line -notmatch '^([0-9a-f]{64})  ([^/\\]+)$') { throw 'Invalid archive checksum file.' }
if ($Matches[2] -ne $archive.Name) { throw 'Archive checksum names a different file.' }
$actual = (Get-FileHash -LiteralPath $archive.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $Matches[1]) { throw 'Archive checksum failed.' }

$work = Join-Path ([IO.Path]::GetTempPath()) ("chorusdraft-package-" + [Guid]::NewGuid())
try {
    $null = New-Item -ItemType Directory -Path $work
    Expand-Archive -LiteralPath $archive.FullName -DestinationPath $work
    $name = [IO.Path]::GetFileNameWithoutExtension($archive.Name)
    $package = Join-Path $work $name
    & (Join-Path $package 'verify.ps1') $package

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archive.FullName)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -match '(^|/)(\.env|data|logs|_build|\.git)(/|$)') {
                throw "Runtime data leaked into package: $($entry.FullName)"
            }
        }
    } finally {
        $zip.Dispose()
    }

    foreach ($dependency in @('mint','websockex','jason','telemetry','hpax')) {
        $licenses = @(Get-ChildItem -LiteralPath (Join-Path $package "source/deps/$dependency") -Recurse -File |
            Where-Object { $_.Name -match '^(license|copying)(\..*)?$' })
        if ($licenses.Count -eq 0) { throw "Missing dependency license: $dependency" }
    }

    & escript (Join-Path $package 'chorusdraft') bluesky --help
    Assert-Exit 'Packaged Bluesky command failed.'
    & escript (Join-Path $package 'chorusdraft') mastodon --help
    Assert-Exit 'Packaged Mastodon command failed.'

    if (-not (Test-Path -LiteralPath (Join-Path $package 'GUARD_LICENSE'))) { throw 'Package is missing GUARD_LICENSE.' }
    if (-not (Test-Path -LiteralPath (Join-Path $package 'source/guard/LICENSE'))) { throw 'Package source is missing Guard.' }
    if (-not (Test-Path -LiteralPath (Join-Path $package 'source/guard/lib/chorus_draft/guard/safety.ex'))) { throw 'Package source is missing Guard safety.' }
    if (-not (Test-Path -LiteralPath (Join-Path $package 'source/guard/lib/chorus_draft/guard/pii.ex'))) { throw 'Package source is missing Guard PII.' }
    $safetyFacade = Get-Content -LiteralPath (Join-Path $package 'source/lib/chorus_draft/safety.ex') -Raw
    if ($safetyFacade -match '@opt_out') { throw 'Safeguard implementation leaked into the Apache-licensed Safety facade.' }
    $piiFacade = Get-Content -LiteralPath (Join-Path $package 'source/lib/chorus_draft/pii.ex') -Raw
    if ($piiFacade -match '@credential') { throw 'Safeguard implementation leaked into the Apache-licensed PII facade.' }

    $installed = Join-Path $work "installed-$name"
    & (Join-Path $package 'install.ps1') $installed
    Assert-Exit 'Package installation failed.'

    $autoHome = Join-Path $work 'auto-home'
    $null = New-Item -ItemType Directory -Path $autoHome
    $autoOut = ((& { $env:LOCALAPPDATA = $autoHome; & (Join-Path $package 'install.ps1') }) | Out-String).TrimEnd()
    if ($autoOut -notmatch 'Installed ChorusDraft in (.+)\. Edit') { throw 'Automatic install did not report a destination.' }
    $autoInstalled = $Matches[1]
    if (-not (Test-Path -LiteralPath $autoInstalled)) { throw 'Automatic install directory is missing.' }
    if (-not (Test-Path -LiteralPath (Join-Path $autoInstalled 'run.ps1'))) { throw 'Automatic install is incomplete.' }

    Set-Content -LiteralPath (Join-Path $installed 'bluesky/.env') -NoNewline -Encoding utf8 -Value 'SENTINEL=$(do-not-execute)'
    & (Join-Path $installed 'setup.ps1')
    Assert-Exit 'Installed setup command failed.'
    if ((Get-Content -LiteralPath (Join-Path $installed 'bluesky/.env') -Raw) -ne 'SENTINEL=$(do-not-execute)') {
        throw 'Setup overwrote an existing configuration.'
    }
    Assert-PrivateAcl (Join-Path $installed 'bluesky')
    Assert-PrivateAcl (Join-Path $installed 'bluesky/.env')

    $overwrote = $true
    try { & (Join-Path $package 'install.ps1') $installed } catch { $overwrote = $false }
    if ($overwrote) { throw 'Installer overwrote an existing directory.' }

    Push-Location (Join-Path $package 'source')
    try {
        $env:HEX_OFFLINE = '1'
        $env:MIX_ENV = 'prod'
        & mix escript.build
        Assert-Exit 'Offline source rebuild failed.'
        & escript '.\chorusdraft' bluesky --help
        Assert-Exit 'Rebuilt Bluesky command failed.'
        & escript '.\chorusdraft' mastodon --help
        Assert-Exit 'Rebuilt Mastodon command failed.'
    } finally {
        Pop-Location
    }
} finally {
    if (Test-Path -LiteralPath $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
