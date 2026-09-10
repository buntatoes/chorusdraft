$ErrorActionPreference = 'Stop'
$env:ERL_CRASH_DUMP = 'NUL'
$env:ERL_CRASH_DUMP_SECONDS = '0'
$BotRoot = $PSScriptRoot
function Show-Help {
    Write-Output @'
ChorusDraft
Run .\bot.bat to open the desktop launcher. Use menu for the terminal menu.
Usage: .\bot.bat bluesky|mastodon COMMAND [options]
Examples:
  .\bot.bat bluesky setup
  .\bot.bat mastodon review

'@
}
function Invoke-Bot([string]$Runtime, [string]$Platform, [string[]]$CommandArgs) {
    if ($Platform -notin @('bluesky', 'mastodon')) { throw 'Choose bluesky or mastodon.' }
    if ($Runtime -ne 'elixir') { throw 'This launcher uses Elixir.' }
    if (-not (Get-Command escript -ErrorAction SilentlyContinue)) { throw 'Install Erlang/OTP 25+ and add escript to PATH.' }
    $executable = Join-Path $BotRoot 'elixir/chorusdraft'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'Build the Elixir executable or use a desktop download.' }
    & escript $executable $Platform @CommandArgs --base (Join-Path $BotRoot "elixir/$Platform") | Out-Host
    return $LASTEXITCODE
}
function Read-Choice([string]$Prompt) {
    $value = Read-Host $Prompt
    if ($null -eq $value -or $value -in @('q', 'Q')) { exit 0 }
    return $value
}
function Show-Menu {
    if ([Console]::IsInputRedirected) { throw 'The menu needs an interactive terminal. Use .\bot.bat help for direct commands.' }
    while ($true) {
        $runtime = 'elixir'
        Write-Host "`n1) Bluesky`n2) Mastodon`nb) Back`nq) Quit"
        $platformChoice = Read-Choice 'Platform'
        if ($platformChoice -eq '1') { $platform = 'bluesky' }
        elseif ($platformChoice -eq '2') { $platform = 'mastodon' }
        else { $runtime = $null; continue }
        while ($true) {
            Write-Host "`n$runtime / $platform"
            Write-Host @'
1) Set up configuration
2) Draft a post
3) Review drafts
4) Start drafting and monitoring
5) Listen for mentions
6) Draft replies to mentions
7) Search public posts
8) Write a post for review
9) Command help
10) Version
b) Change bot
q) Quit
'@
            $choice = Read-Choice 'Action'
            if ($choice -eq 'b') { break }
            $actions = @{'1'='setup'; '2'='draft'; '3'='review'; '4'='start'; '5'='listen'; '6'='replies'; '7'='search'; '8'='post'; '9'='help'; '10'='version'}
            if (-not $actions.ContainsKey($choice)) { Write-Host 'Choose an action from the menu.'; continue }
            $commandArgs = @($actions[$choice])
            if ($choice -in @('7', '8')) {
                $value = Read-Host 'Text (blank cancels)'
                if ([string]::IsNullOrEmpty($value)) { continue }
                $commandArgs += $value
            }
            try {
                $code = Invoke-Bot $runtime $platform $commandArgs
                if ($code -ne 0) { Write-Host 'The command did not complete. You can choose another action.' }
                elseif ($commandArgs[0] -eq 'setup') {
                    $folder = "elixir/$platform"
                    Write-Host "Edit $(Join-Path $BotRoot "$folder/.env") with your account and AI settings before drafting."
                }
            } catch { Write-Host $_.Exception.Message }
        }
        $runtime = $null
    }
}
try {
    $arguments = @($args)
    if ($arguments.Count -eq 0) {
        & (Join-Path $BotRoot 'bot.bat')
        exit 0
    }
    if ($arguments[0] -in @('help', '-h', '--help')) { Show-Help; exit 0 }
    if ($arguments[0] -eq 'menu') { Show-Menu; exit 0 }
    if ($arguments[0] -in @('bluesky', 'mastodon')) { $arguments = @('elixir') + $arguments }
    if ($arguments.Count -lt 2) { Show-Help; exit 1 }
    $commandArgs = if ($arguments.Count -gt 2) { @($arguments[2..($arguments.Count - 1)]) } else { @('help') }
    $code = Invoke-Bot $arguments[0] $arguments[1] $commandArgs
    exit $code
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
