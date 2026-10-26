<#
  Install-YTDownloader.ps1
  One-shot setup for the yt-dlp-in-Docker downloader stack.

  Does, in order:
    1. Installs Docker Desktop via winget (skipped if already present)
    2. Starts the Docker engine and waits for it
    3. Pulls the jauderho/yt-dlp image
    4. Writes YT-Downloader.ps1 (embedded below) to the install dir
    5. Sets execution policy (CurrentUser, RemoteSigned)
    6. Adds a global 'yt' command to your PowerShell profile

  Usage:
    .\Install-YTDownloader.ps1                       # default: installs to ~\Scripts
    .\Install-YTDownloader.ps1 -InstallDir D:\Tools  # custom location
    .\Install-YTDownloader.ps1 -SkipDockerInstall    # Docker already handled

  Links:
    yt-dlp        https://github.com/yt-dlp/yt-dlp
    docker image  https://hub.docker.com/r/jauderho/yt-dlp
    dockerfiles   https://github.com/jauderho/dockerfiles/tree/main/yt-dlp
    Docker Desktop https://www.docker.com/products/docker-desktop/
#>

#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InstallDir = "$HOME\Scripts",
    [switch]$SkipDockerInstall
)

$ErrorActionPreference = 'Stop'
$Image      = 'jauderho/yt-dlp:latest'
$DockerExe  = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$DockerCli  = 'C:\Program Files\Docker\Docker\resources\bin'
$ScriptPath = Join-Path $InstallDir 'YT-Downloader.ps1'

function Step { param([string]$Msg) Write-Host ("`n==> " + $Msg) -ForegroundColor Cyan }
function Ok   { param([string]$Msg) Write-Host ("    " + [char]0x2713 + " " + $Msg) -ForegroundColor Green }
function Warn { param([string]$Msg) Write-Host ("    ! " + $Msg) -ForegroundColor Yellow }
function Fail { param([string]$Msg) Write-Host ("    " + [char]0x2717 + " " + $Msg) -ForegroundColor Red }

function Test-DockerCli {
    $ErrorActionPreference = 'SilentlyContinue'
    try { docker --version 2>$null | Out-Null; return $LASTEXITCODE -eq 0 } catch { return $false }
}
function Test-DockerUp {
    $ErrorActionPreference = 'SilentlyContinue'
    try { docker version --format '{{.Server.Version}}' 2>$null | Out-Null; return $LASTEXITCODE -eq 0 } catch { return $false }
}

Write-Host ''
Write-Host '  YT-Downloader installer' -ForegroundColor Magenta
Write-Host '  -----------------------' -ForegroundColor DarkGray

# ---- 1. Docker Desktop --------------------------------------------------------
Step '1/6 Docker Desktop'
if ($SkipDockerInstall) {
    Warn 'skipped by flag'
} elseif (Test-DockerCli) {
    Ok "docker CLI already present ($(docker --version))"
} else {
    Warn 'docker not found - installing via winget (this is a ~500MB download)...'
    winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { Fail 'winget install failed.'; exit 1 }
    # winget does not update this session's PATH; add Docker CLI dir manually
    if (Test-Path $DockerCli) { $env:Path += ";$DockerCli" }
    if (Test-DockerCli) {
        Ok 'Docker Desktop installed'
    } else {
        Warn 'installed, but CLI not reachable in this session.'
        Warn 'Log out and back in (or reboot), then re-run this installer - it will resume from here.'
        exit 0
    }
}

# ---- 2. Start engine ----------------------------------------------------------
Step '2/6 Docker engine'
if (Test-DockerUp) {
    Ok 'engine already running'
} else {
    if (-not (Test-Path $DockerExe)) { Fail "Docker Desktop not found at $DockerExe"; exit 1 }
    Write-Host '    starting Docker Desktop (first boot can take a minute)...' -ForegroundColor DarkGray
    Start-Process $DockerExe | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $up = $false
    while ($sw.Elapsed.TotalSeconds -lt 300) {
        if (Test-DockerUp) { $up = $true; break }
        Start-Sleep 5
        Write-Host '    ...waiting' -ForegroundColor DarkGray
    }
    if ($up) { Ok 'engine is up' }
    else {
        Fail 'engine did not come up in 5 min.'
        Warn 'First launch may need you to accept the Docker service agreement in its window.'
        Warn 'Accept it, wait for the whale icon to settle, then re-run this installer.'
        exit 1
    }
}

# ---- 3. Pull image ------------------------------------------------------------
Step "3/6 Pull $Image"
docker pull $Image
if ($LASTEXITCODE -eq 0) { Ok 'image ready (rebuilt daily upstream - re-pull to update)' }
else { Fail 'pull failed - check network / Docker Hub status.'; exit 1 }

# ---- 4. Write the downloader script -------------------------------------------
Step "4/6 Install script -> $ScriptPath"
if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }

$DownloaderScript = @'
<#
  YT-Downloader.ps1  -  menu-driven yt-dlp-in-Docker downloader
  - auto-starts Docker Desktop
  - audio/video + quality menus, Explorer folder-picker
  - auto-uses ~\cookies.txt if present
  Installed by Install-YTDownloader.ps1

  NOTE: this file is deliberately pure ASCII. All fancy glyphs are built
  from codepoints below, so no editor/encoding can ever corrupt the script.
#>

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms | Out-Null

# ---- glyphs (encoding-proof) --------------------------------------------------
$G = @{
    TL   = [string][char]0x2554
    TR   = [string][char]0x2557
    BL   = [string][char]0x255A
    BR   = [string][char]0x255D
    H    = [string][char]0x2550
    V    = [string][char]0x2551
    R    = [string][char]0x2500
    Dot  = [string][char]0x25CF
    Ok   = [string][char]0x2713
    No   = [string][char]0x2717
    Arr  = [string][char]0x2192
    Pr   = [string][char]0x00BB
    N1   = [string][char]0x266A
    N2   = [string][char]0x266B
    Play = [string][char]0x25B6
    Dn   = [string][char]0x25BC
    Md   = [string][char]0x00B7
}

# ---- config -----------------------------------------------------------------
$Image       = 'jauderho/yt-dlp:latest'
$DockerExe   = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
$SaveDir     = "$HOME\downloads"
$CookiesFile = "$HOME\cookies.txt"
$SleepArgs   = @('--sleep-requests','2','--min-sleep-interval','5','--max-sleep-interval','15')
$LastKind    = 'ok'   # set by Invoke-Download, read by Start-Download (see note there)

# ---- ui helpers ---------------------------------------------------------------
$W = 56

function Write-Rule { Write-Host ('  ' + ($G.R * ($W + 2))) -ForegroundColor DarkCyan }

function Write-Status {
    param([string]$Label, [string]$Value, [ConsoleColor]$Color = 'Gray')
    Write-Host ('   ' + $G.Dot + ' ') -ForegroundColor DarkCyan -NoNewline
    Write-Host ($Label.PadRight(9)) -ForegroundColor DarkGray -NoNewline
    Write-Host $Value -ForegroundColor $Color
}

function Write-Item {
    param([string]$Num, [string]$Text, [string]$Hint = '')
    Write-Host '    [' -ForegroundColor DarkGray -NoNewline
    Write-Host $Num -ForegroundColor Yellow -NoNewline
    Write-Host '] ' -ForegroundColor DarkGray -NoNewline
    Write-Host $Text -ForegroundColor White -NoNewline
    if ($Hint) { Write-Host ('  ' + $Hint) -ForegroundColor DarkGray -NoNewline }
    Write-Host ''
}

function Write-Ok   { param([string]$Msg) Write-Host ("`n   " + $G.Ok + ' ' + $Msg) -ForegroundColor Green }
function Write-Bad  { param([string]$Msg) Write-Host ("`n   " + $G.No + ' ' + $Msg) -ForegroundColor Red }
function Write-Note { param([string]$Msg) Write-Host ('     ' + $Msg) -ForegroundColor Yellow }

function Write-Warn {
    # loud boxed banner for a failed download - the old script buried failures in a
    # single red line that scrolled past under yt-dlp's own output
    param([string]$Headline)
    $max = $W - 6
    if ($Headline.Length -gt $max) { $Headline = $Headline.Substring(0, $max) }
    Write-Host ''
    Write-Host ('  ' + $G.TL + ($G.H * $W) + $G.TR) -ForegroundColor Red
    Write-Host ('  ' + $G.V) -ForegroundColor Red -NoNewline
    Write-Host (('  ' + $G.No + '  ' + $Headline).PadRight($W)) -ForegroundColor Yellow -NoNewline
    Write-Host $G.V -ForegroundColor Red
    Write-Host ('  ' + $G.BL + ($G.H * $W) + $G.BR) -ForegroundColor Red
}

function Show-Banner {
    Clear-Host
    Write-Host ''
    Write-Host ('  ' + $G.TL + ($G.H * $W) + $G.TR) -ForegroundColor Cyan
    $title = '  ' + $G.N1 + ' ' + $G.N2 + '  Y T - D L P   D O W N L O A D E R  ' + $G.N2 + ' ' + $G.N1
    Write-Host ('  ' + $G.V) -ForegroundColor Cyan -NoNewline
    Write-Host ($title.PadRight($W)) -ForegroundColor Magenta -NoNewline
    Write-Host $G.V -ForegroundColor Cyan
    $sub = ('        Docker edition ' + $G.Md + ' jauderho/yt-dlp')
    Write-Host ('  ' + $G.V) -ForegroundColor Cyan -NoNewline
    Write-Host ($sub.PadRight($W)) -ForegroundColor DarkCyan -NoNewline
    Write-Host $G.V -ForegroundColor Cyan
    Write-Host ('  ' + $G.BL + ($G.H * $W) + $G.BR) -ForegroundColor Cyan

    $dockerUp = Test-DockerUp
    if ($dockerUp) { Write-Status 'Docker'  'running' Green }
    else           { Write-Status 'Docker'  'stopped' Red }
    if ($dockerUp) {
        $age = Get-ImageAgeDays
        if     ($age -lt 0)  { Write-Status 'Engine' ('image not pulled ' + $G.Md + ' run option 3') Yellow }
        elseif ($age -gt 14) { Write-Status 'Engine' ('updated ' + [string]$age + ' days ago ' + $G.Md + ' STALE, run option 3') Red }
        elseif ($age -gt 7)  { Write-Status 'Engine' ('updated ' + [string]$age + ' days ago ' + $G.Md + ' consider option 3') Yellow }
        elseif ($age -eq 0)  { Write-Status 'Engine' 'updated today' Green }
        else                 { Write-Status 'Engine' ('updated ' + [string]$age + ' day(s) ago') Green }
    }
    Write-Status 'Save to' $SaveDir Cyan
    if (Test-Path $CookiesFile -PathType Leaf) {
        Write-Status 'Cookies' ($CookiesFile + ' (authenticated)') Yellow
    } else {
        Write-Status 'Cookies' ('none ' + $G.Md + ' anonymous mode') DarkGray
    }
    Write-Rule
}

# ---- docker helpers -----------------------------------------------------------
function Test-DockerUp {
    # local EAP: with global 'Stop', PS 5.1 can turn native stderr under 2> redirection
    # into a terminating error, false-negativing this check
    $ErrorActionPreference = 'SilentlyContinue'
    try { docker version --format '{{.Server.Version}}' 2>$null | Out-Null; return $LASTEXITCODE -eq 0 }
    catch { return $false }
}

function ConvertTo-UtcDate {
    # RFC3339 -> [datetime] UTC, or $null. Docker emits 9 fractional digits; .NET
    # Parse accepts at most 7, so the fraction is trimmed off first.
    param([string]$Raw)
    if (-not $Raw) { return $null }
    $clean = $Raw.Trim().Trim('"') -replace '\.\d+(Z|[+-]\d{2}:\d{2})$','$1'
    if (-not $clean) { return $null }
    try {
        return [datetime]::Parse($clean, [Globalization.CultureInfo]::InvariantCulture,
               ([Globalization.DateTimeStyles]::AdjustToUniversal -bor [Globalization.DateTimeStyles]::AssumeUniversal))
    } catch { return $null }
}

function Get-ImageAgeDays {
    # Whole days since this image was last PULLED, or -1 if not pulled / unreadable.
    # Pull time (not build time) is the actionable number: 'rebuilt daily' upstream is
    # aspirational - the latest tag can itself lag a week - and docker run always serves
    # the LOCAL cache. A long-uncollected image is the usual cause of 403s, because
    # YouTube rotates its player JS and an old yt-dlp can no longer sign media URLs.
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $dt = ConvertTo-UtcDate (& docker image inspect $Image --format '{{json .Metadata.LastTagTime}}' 2>$null)
        # Docker writes a zero timestamp when it has no record; fall back to build date
        if ((-not $dt) -or ($dt.Year -lt 2000)) {
            $dt = ConvertTo-UtcDate (& docker image inspect $Image --format '{{.Created}}' 2>$null)
        }
        if ((-not $dt) -or ($dt.Year -lt 2000)) { return -1 }
        return [int]([datetime]::UtcNow - $dt).TotalDays
    } catch { return -1 }
}

function Ensure-Docker {
    if (Test-DockerUp) { return }
    Write-Host ("`n   " + $G.Dot + ' Docker engine down - starting Docker Desktop...') -ForegroundColor Yellow
    if (-not (Test-Path $DockerExe)) { throw "Docker Desktop not found at $DockerExe" }
    Start-Process $DockerExe | Out-Null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    Write-Host '     waiting ' -ForegroundColor DarkGray -NoNewline
    while ($sw.Elapsed.TotalSeconds -lt 120) {
        if (Test-DockerUp) { Write-Host ''; Write-Ok 'Docker engine is up.'; Start-Sleep 1; return }
        Write-Host $G.Md -ForegroundColor DarkCyan -NoNewline
        Start-Sleep 3
    }
    Write-Host ''
    throw 'Docker engine did not start within 120s. Launch Docker Desktop manually.'
}

# ---- menu helpers ---------------------------------------------------------------
function Read-Menu {
    param([string]$Title, [string[]]$Options, [string]$Default, [string[]]$Hints = @())
    Write-Host ('   ' + $Title) -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $hint = if ($i -lt $Hints.Count) { $Hints[$i] } else { '' }
        Write-Item ($i + 1) $Options[$i] $hint
    }
    Write-Host ('   ' + $G.Pr + ' ') -ForegroundColor Magenta -NoNewline
    $sel = (Read-Host "choice (default $Default)").Trim()
    if ([string]::IsNullOrWhiteSpace($sel)) { return $Default }
    if ($sel -notmatch '^\d+$' -or [int]$sel -lt 1 -or [int]$sel -gt $Options.Count) {
        Write-Note "invalid choice - using default ($Default)"
        return $Default
    }
    return $sel
}

function Pick-Folder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description         = 'Choose where to save downloads'
    $dlg.SelectedPath        = if (Test-Path $SaveDir) { $SaveDir } else { $HOME }
    $dlg.ShowNewFolderButton = $true
    $top = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false }
    if ($dlg.ShowDialog($top) -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    return $null
}

function Get-FormatArgs {
    Show-Banner
    $type = Read-Menu 'What do you want?' @('Audio  (MP3)','Video  (MP4)') '1' @($G.N1, $G.Play)
    if ($type -eq '2') {
        Write-Host ''
        $q = Read-Menu 'Video quality:' @('Best available','1080p','720p','480p') '1'
        $res = switch ($q) { '2'{"1080"} '3'{"720"} '4'{"480"} default{$null} }
        if ($res) {
            return @('-f',"bv*[height<=$res]+ba/b[height<=$res]",'--merge-output-format','mp4')
        }
        return @('-f','bv*+ba/b','--merge-output-format','mp4')
    } else {
        Write-Host ''
        $q = Read-Menu 'Audio bitrate:' @('320 kbps','256 kbps','192 kbps','Best native') '1' `
                       @('','','',('no re-encode ' + $G.Md + ' best quality per byte'))
        switch ($q) {
            '4'     { return @('-x','--audio-format','best','--embed-thumbnail','--embed-metadata') }
            '3'     { return @('-x','--audio-format','mp3','--audio-quality','192K','--embed-thumbnail','--embed-metadata') }
            '2'     { return @('-x','--audio-format','mp3','--audio-quality','256K','--embed-thumbnail','--embed-metadata') }
            default { return @('-x','--audio-format','mp3','--audio-quality','320K','--embed-thumbnail','--embed-metadata') }
        }
    }
}

# ---- info ---------------------------------------------------------------------
function Show-Info {
    $ErrorActionPreference = 'SilentlyContinue'
    Show-Banner
    Write-Host '   ENGINE / INSTALL INFO' -ForegroundColor Magenta
    Write-Host ''

    if (-not (Test-DockerUp)) {
        Write-Bad 'Docker engine is not running - start it first.'
        Read-Host "`n   Enter for menu"; return
    }

    Write-Host '   Engine (yt-dlp)' -ForegroundColor Cyan
    $ytv = (& docker run --rm $Image --version 2>$null)
    if (-not $ytv) { $ytv = 'unknown (image not pulled yet? run menu option 3)' }
    Write-Status 'version' $ytv Green
    $ytpath = (& docker run --rm --entrypoint which $Image yt-dlp 2>$null)
    Write-Status 'binary'  ($ytpath + '  (inside container)') Gray
    $ffv = (& docker run --rm --entrypoint ffmpeg $Image -version 2>$null | Select-Object -First 1)
    Write-Status 'ffmpeg'  $ffv Gray
    Write-Host ''

    Write-Host '   Image (local install)' -ForegroundColor Cyan
    Write-Status 'name' $Image White
    $id = (& docker image inspect $Image --format '{{.Id}}' 2>$null)
    $sz = (& docker image inspect $Image --format '{{.Size}}' 2>$null)
    $cr = (& docker image inspect $Image --format '{{.Created}}' 2>$null)
    $szMB = if ($sz) { '{0:N0} MB' -f ($sz / 1MB) } else { 'n/a' }
    $idShort = ($id -replace '^sha256:','')
    if ($idShort.Length -gt 12) { $idShort = $idShort.Substring(0,12) }
    Write-Status 'id'      $idShort Gray
    Write-Status 'size'    $szMB Gray
    Write-Status 'built'   $cr Gray
    $root = (& docker info --format '{{.DockerRootDir}}' 2>$null)
    Write-Status 'stored'  ($root + '  (Docker data root, inside the WSL2 VM)') Gray
    Write-Host ''

    Write-Host '   Runtime' -ForegroundColor Cyan
    Write-Status 'host dir'  $SaveDir Gray
    Write-Status 'container' '/downloads  (bind-mounted to save dir)' Gray
    Write-Host ''

    Write-Host '   Source' -ForegroundColor Cyan
    Write-Status 'yt-dlp'  'https://github.com/yt-dlp/yt-dlp' Cyan
    Write-Status 'docs'    'https://github.com/yt-dlp/yt-dlp#readme' Cyan
    Write-Status 'image'   'https://github.com/jauderho/dockerfiles/tree/main/yt-dlp' Cyan
    Write-Status 'hub'     'https://hub.docker.com/r/jauderho/yt-dlp' Cyan
    Write-Host ''
    Read-Host '   Enter for menu'
}

# ---- download -------------------------------------------------------------------
function Invoke-Download {
    param([string]$Url, [string[]]$FmtArgs)
    if (-not (Test-Path $SaveDir)) { New-Item -ItemType Directory -Path $SaveDir | Out-Null }
    $mount = ($SaveDir -replace '\\','/').TrimEnd('/')
    if ($mount -match '^[A-Za-z]:$') { $mount += '/' }
    $runArgs = @('run','--rm','-v',($mount + ':/downloads'))
    $cookieArgs = @()
    if (Test-Path $CookiesFile -PathType Leaf) {
        $cMount = $CookiesFile -replace '\\','/'
        $runArgs   += @('-v',($cMount + ':/cookies.txt:ro'))
        $cookieArgs = @('--cookies','/cookies.txt')
        Write-Host ("`n   " + $G.Dot + ' using cookies.txt (authenticated)') -ForegroundColor Yellow
    }
    $runArgs += @($Image) + $SleepArgs + $cookieArgs + $FmtArgs +
                @('-o','/downloads/%(title)s.%(ext)s',$Url)

    Write-Host ("`n   " + $G.Dn + " downloading...`n") -ForegroundColor Cyan

    # stdout streams live so the progress bar still renders; stderr is captured to a
    # temp file so the failure can be classified instead of always blaming the IP.
    # local EAP 'Continue': with global 'Stop', PS 5.1 turns native stderr under
    # redirection into a terminating NativeCommandError (same trap as Test-DockerUp).
    # Must NOT be 'SilentlyContinue' - that suppresses the write to $errFile as well,
    # leaving nothing to classify and sending every failure to the generic branch.
    $ErrorActionPreference = 'Continue'
    $errFile = Join-Path $env:TEMP ('ytdl-err-' + [guid]::NewGuid().ToString('N') + '.log')
    $code = 1
    $text = ''
    try {
        & docker @runArgs 2>$errFile
        $code = $LASTEXITCODE
    } catch {
        $text = [string]$_.Exception.Message
    } finally {
        if (Test-Path $errFile) {
            $text = $text + "`n" + [string](Get-Content $errFile -Raw)
            Remove-Item $errFile -Force
        }
    }

    if ($code -eq 0) {
        Write-Ok ('Done ' + $G.Arr + ' ' + $SaveDir)
        $script:LastKind = 'ok'
        return
    }

    # Two kinds of noise get mixed into the captured stderr before yt-dlp's own words:
    #   1. PS 5.1 writes its entire error-record decoration (stack trace, CategoryInfo,
    #      the ~~~~ underline) into the redirect target.
    #   2. Docker Desktop appends an unsolicited "What's next:" advert pointing at its
    #      AI assistant, which arrives mojibaked in a console codepage and makes a
    #      clean yt-dlp error look like the script itself broke.
    # Neither is from yt-dlp, so neither belongs on screen or in the classifier.
    $psNoise     = '^\s*\+|^At (line:|[A-Za-z]:\\)'
    $dockerNoise = 'What.s next:|Debug this container error|docker ai |docker scout |View a summary of image vulnerabilities|Learn more at https://docs\.docker\.com'
    $clean = (($text -split '\r?\n') |
        Where-Object { $_.Trim() -and $_ -notmatch $psNoise -and $_ -notmatch $dockerNoise } |
        ForEach-Object { ($_ -replace '^\s*docker\.exe\s*:\s*','').Trim() }) -join "`n"

    # Classify against yt-dlp's FATAL lines when there are any. yt-dlp retries past
    # transient trouble and reports it as WARNING; only ERROR actually killed the run.
    # Without this split, a recovered 'WARNING: ... 429' outranks the real
    # 'ERROR: ... Video unavailable' and a video that simply does not exist gets
    # reported as a rate limit, sending the user off to wait an hour for nothing.
    # Non-yt-dlp failures (e.g. the Docker daemon) have no ERROR: prefix, so fall back.
    $fatal = (($clean -split "`n") | Where-Object { $_ -match '^\s*ERROR\b' }) -join "`n"
    $probe = if ($fatal.Trim()) { $fatal } else { $clean }

    # Classify BEFORE printing anything, so the banner headline can name the real cause.
    # 403 and 429 are opposite failures: 403 = bad URL signature (update the image),
    # 429 = genuine IP rate limit (wait / change exit node). Telling the user to hop
    # VPNs on a 403 sends them chasing an IP problem that does not exist.
    # The age check MUST precede the 429 check: 'Sign in to confirm your age' would
    # otherwise be swallowed by 'Sign in to confirm' and misreported as a bot wall.
    $kind = 'unknown'
    if     ($probe -match 'HTTP Error 403|403: Forbidden|403 Forbidden')                  { $kind = '403' }
    elseif ($probe -match 'confirm your age|age-restricted|age_limit')                    { $kind = 'age' }
    elseif ($probe -match 'HTTP Error 429|Too Many Requests|Sign in to confirm|not a bot'){ $kind = '429' }
    # -match is case-insensitive; 'video (is )?unavailable' covers both of yt-dlp's
    # phrasings ('Video unavailable' and 'This video is unavailable')
    elseif ($probe -match 'Private video|video (is )?unavailable|video is not available|removed by the uploader|account associated with this video has been terminated|members-only|Join this channel|not available in your country') { $kind = 'unavailable' }
    elseif ($probe -match 'nsig|Unable to extract|player response|Signature extraction')  { $kind = 'extractor' }
    elseif ($probe -match 'Permission denied|Access is denied|No space left|Unable to rename') { $kind = 'filesystem' }
    elseif ($probe -match 'Cannot connect to the Docker daemon|error during connect')     { $kind = 'docker' }

    switch ($kind) {
        '403'         { Write-Warn 'FAILED - 403 Forbidden (stale image)' }
        'age'         { Write-Warn 'FAILED - age-gated video' }
        '429'         { Write-Warn 'FAILED - 429 rate limited (your IP)' }
        'unavailable' { Write-Warn 'FAILED - video not available to you' }
        'extractor'   { Write-Warn 'FAILED - extractor out of date' }
        'filesystem'  { Write-Warn 'FAILED - local disk / permissions' }
        'docker'      { Write-Warn 'FAILED - Docker engine unreachable' }
        default       { Write-Warn 'FAILED - unrecognized error' }
    }

    if ($clean.Trim()) {
        foreach ($ln in ($clean -split "`n")) { Write-Host ('   ' + $ln) -ForegroundColor DarkGray }
    }
    Write-Bad ('yt-dlp exited ' + $code)

    switch ($kind) {
        '403' {
            Write-Note '403 Forbidden - this is NOT your IP. Do not switch VPN.'
            Write-Note 'YouTube rotated its player JS; this image can no longer sign URLs.'
            $age = Get-ImageAgeDays
            if ($age -gt 7) { Write-Note ('Image last updated ' + [string]$age + ' days ago - that is almost certainly it.') }
            Write-Note 'Switching exit node mid-download invalidates the signed URL and'
            Write-Note 'causes MORE 403s. Rotating VPNs cannot fix this error.'
        }
        'age' {
            Write-Note 'Age-gated video - needs cookies.txt from a logged-in throwaway account.'
            Write-Note 'Not an IP problem: waiting or changing exit node will not help.'
        }
        '429' {
            Write-Note '429 / bot wall - THIS one really is your IP.'
            Write-Note 'Wait 30-60 min without retrying, or change exit node / use a hotspot.'
            Write-Note 'An exported cookies.txt in your home folder is the last resort.'
        }
        'unavailable' {
            Write-Note 'Video is private, members-only, or region-locked.'
            Write-Note 'Updating will not help; this one needs cookies (or a different region).'
        }
        'extractor' {
            Write-Note 'Extractor could not parse YouTube - the image needs updating.'
        }
        'filesystem' {
            Write-Note 'Local filesystem problem, not YouTube.'
            Write-Note 'Check the save folder is writable and that you have free space.'
        }
        'docker' {
            Write-Note 'Docker engine dropped out - restart Docker Desktop, then retry.'
        }
        default {
            Write-Note 'Unrecognized failure. Updating the image first fixes most.'
            Write-Note 'Only a 429 or bot-wall message means your IP is the problem.'
        }
    }

    $script:LastKind = $kind
}

function Start-Download {
    # Wraps Invoke-Download with a retry loop whose options follow the diagnosis.
    # A blind 'try again' is wrong here: retrying a 429 actively makes it worse, and
    # for an age-gated or private video no number of retries can ever succeed - so
    # which actions are offered, how they are labelled, and which one is the default
    # all change with the failure kind.
    param([string]$Url, [string[]]$FmtArgs)
    while ($true) {
        # Called as a bare statement on purpose: docker's stdout flows through this
        # function's output stream to the console, which is what keeps yt-dlp's
        # single-line progress bar rendering. Assigning or piping it would swallow
        # the progress display, so the result comes back via $script:LastKind.
        $script:LastKind = 'unknown'
        Invoke-Download -Url $Url -FmtArgs $FmtArgs
        $kind = $script:LastKind
        if ($kind -eq 'ok') { return }

        $canRetry  = $kind -notin @('age','unavailable')
        $wantsPull = $kind -in @('403','extractor','unknown')

        $opts = @(); $hints = @(); $map = @()
        if ($wantsPull) {
            $ph = 'recommended ' + $G.Md + ' fixes most failures'
            if     ($kind -eq '403')       { $ph = 'recommended ' + $G.Md + ' fixes most 403s' }
            elseif ($kind -eq 'extractor') { $ph = 'recommended ' + $G.Md + ' refreshes the extractor' }
            $opts += 'Update image, then retry'
            $hints += $ph
            $map += 'pullretry'
        }
        if ($canRetry) {
            $rh = 'after fixing the problem above'
            if ($kind -eq '429')  { $rh = 'NOT recommended ' + $G.Md + ' retrying makes a 429 worse' }
            elseif ($wantsPull)   { $rh = 'same image, will likely fail again' }
            $opts += 'Retry now'; $hints += $rh; $map += 'retry'
        }
        if (-not $wantsPull) {
            $opts += 'Update image, then retry'
            $hints += 'unlikely to help with this one'
            $map += 'pullretry'
        }
        $opts += 'Back to menu'; $hints += ''; $map += 'menu'

        # default to the pull when it is the real fix, otherwise to backing out
        $default = if ($wantsPull) { '1' } else { [string]$opts.Count }

        Write-Host ''
        $sel = Read-Menu 'What now?' $opts $default $hints
        switch ($map[[int]$sel - 1]) {
            'pullretry' {
                Write-Host ("`n   " + $G.Dn + " pulling latest image...`n") -ForegroundColor Cyan
                docker pull $Image
                if ($LASTEXITCODE -eq 0) { Write-Ok 'Image updated - retrying.' }
                else { Write-Bad 'Pull failed - retrying with the current image anyway.' }
            }
            'retry' { Write-Host ("`n   " + $G.Dn + ' retrying...') -ForegroundColor Cyan }
            'menu'  { return }
        }
    }
}

# ---- main loop --------------------------------------------------------------
try { Ensure-Docker } catch { Write-Bad $_; Read-Host 'Enter to exit'; exit 1 }

while ($true) {
    Show-Banner
    $action = Read-Menu 'Menu:' `
        @('Download a URL','Change save folder','Update yt-dlp image','Info / about engine','Quit') '1' `
        @('','','pull latest release',('versions ' + $G.Md + ' paths ' + $G.Md + ' links'),'')
    switch ($action) {
        '2' { $p = Pick-Folder; if ($p) { $SaveDir = $p }; continue }
        '3' {
            Write-Host ("`n   " + $G.Dn + " pulling latest image...`n") -ForegroundColor Cyan
            docker pull $Image
            if ($LASTEXITCODE -eq 0) { Write-Ok 'Image up to date.' }
            else { Write-Bad 'Pull failed - check network / Docker Hub status.' }
            Read-Host "`n   Enter to continue"; continue
        }
        '4' { Show-Info; continue }
        '5' { Write-Host ("`n   Bye. " + $G.N1 + "`n") -ForegroundColor Magenta; break }
        default {
            Write-Host ('   ' + $G.Pr + ' ') -ForegroundColor Magenta -NoNewline
            $url = Read-Host 'paste YouTube URL'
            if ([string]::IsNullOrWhiteSpace($url)) { continue }
            $fmt = Get-FormatArgs
            Start-Download -Url $url -FmtArgs $fmt
            Read-Host "`n   Enter for menu"
        }
    }
    if ($action -eq '5') { break }
}
'@

Set-Content -Path $ScriptPath -Value $DownloaderScript -Encoding ASCII
Ok "written ($((Get-Item $ScriptPath).Length) bytes, pure ASCII)"

# ---- 5. Execution policy ------------------------------------------------------
Step '5/6 Execution policy'
$pol = Get-ExecutionPolicy -Scope CurrentUser
if ($pol -in @('RemoteSigned','Unrestricted','Bypass')) {
    Ok "already $pol"
} else {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Ok 'set to RemoteSigned (CurrentUser)'
}

# ---- 6. Profile function ------------------------------------------------------
Step "6/6 Add 'yt' command to profile"
# CurrentUserAllHosts covers the console, VS Code terminal, ISE, etc. (per edition)
$profilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $profilePath)) { New-Item -Path $profilePath -Type File -Force | Out-Null }
$funcLine = "function yt { & `"$ScriptPath`" }"
$existing = Get-Content $profilePath -ErrorAction SilentlyContinue
if ($existing -match 'function yt ') {
    # replace any old yt definition with the current path
    ($existing | Where-Object { $_ -notmatch 'function yt ' }) + $funcLine | Set-Content $profilePath
    Ok "updated existing 'yt' entry in $profilePath"
} else {
    Add-Content -Path $profilePath -Value $funcLine
    Ok "added to $profilePath"
}

# ---- done ---------------------------------------------------------------------
Write-Host ''
Write-Host '  Install complete.' -ForegroundColor Green
Write-Host '  ----------------' -ForegroundColor DarkGray
Write-Host "  Script:   $ScriptPath"
Write-Host "  Command:  yt   (open a NEW terminal, or run:  . `$PROFILE.CurrentUserAllHosts )"
Write-Host "  Optional: put an exported cookies.txt at $HOME\cookies.txt for authenticated mode"
Write-Host ''