# Graphite by Sumr — one-line installer
#   irm https://raw.githubusercontent.com/sumrzao/graphite/main/install.ps1 | iex
#
# Downloads Graphite, installs it to %LOCALAPPDATA%\Graphite\app, adds a Start menu
# shortcut and starts it (Windows shows the usual administrator prompt).
# Run it again any time to update to the latest version.

& {
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'   # the progress bar makes downloads ~10x slower in Windows PowerShell

    # ---- where the release lives: the newest GitHub release's Graphite-win-x64.zip ----
    $Url = 'https://github.com/sumrzao/graphite/releases/latest/download/Graphite-win-x64.zip'
    if ($env:GRAPHITE_URL) { $Url = $env:GRAPHITE_URL }
    $Dir = if ($env:GRAPHITE_DIR) { $env:GRAPHITE_DIR } else { Join-Path $env:LOCALAPPDATA 'Graphite\app' }

    function Say($text, $color = 'Gray') { Write-Host "  $text" -ForegroundColor $color }

    Write-Host ''
    Write-Host '  graphite' -ForegroundColor White -NoNewline
    Write-Host '  by Sumr' -ForegroundColor DarkGray
    Write-Host ''

    # ---- requirements ----
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Graphite needs 64-bit Windows 10 or 11.' }
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
    if ($build -lt 17763) { throw "Graphite needs Windows 10 (1809) or newer. This PC is on build $build." }
    $net = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -ErrorAction SilentlyContinue).Release
    if (-not $net -or $net -lt 528040) { throw '.NET Framework 4.8 is missing. Run Windows Update once, then try again.' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    # ---- download ----
    $zip = Join-Path $env:TEMP ("graphite-" + [guid]::NewGuid().ToString('N') + '.zip')
    Say 'Downloading Graphite...'
    try { Invoke-WebRequest -Uri $Url -OutFile $zip -UseBasicParsing }
    catch { throw "Couldn't download Graphite from $Url`n  $($_.Exception.Message)" }
    if ((Get-Item $zip).Length -lt 100KB) { Remove-Item $zip -Force; throw 'The download looks wrong (too small). Check that the link is shared publicly.' }

    # ---- install (replaces an older version) ----
    $running = Get-Process -Name 'Graphite' -ErrorAction SilentlyContinue | Where-Object { $_.Path -and $_.Path.StartsWith($Dir, [StringComparison]::OrdinalIgnoreCase) }
    if ($running) { Say 'Closing the running copy of Graphite to update it...'; $running | Stop-Process -Force; Start-Sleep -Milliseconds 800 }
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    Expand-Archive -Path $zip -DestinationPath $Dir -Force
    Remove-Item $zip -Force
    $exe = Join-Path $Dir 'Graphite.exe'
    if (-not (Test-Path $exe)) { throw 'Graphite.exe was not found in the download.' }
    Get-ChildItem $Dir -File | Unblock-File
    $version = (Get-Item $exe).VersionInfo.ProductVersion
    Say "Installed Graphite $version to $Dir" 'White'

    # ---- Start menu shortcut ----
    if (-not $env:GRAPHITE_NOSHORTCUT) {
        $lnk = Join-Path ([Environment]::GetFolderPath('Programs')) 'Graphite.lnk'
        $sc = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
        $sc.TargetPath = $exe
        $sc.WorkingDirectory = $Dir
        $sc.Description = 'Graphite by Sumr - PC optimizer for gaming'
        $sc.Save()
        Say 'Added Graphite to the Start menu'
    }

    # ---- launch ----
    if (-not $env:GRAPHITE_NOLAUNCH) {
        Say 'Starting Graphite - accept the administrator prompt.' 'White'
        Start-Process -FilePath $exe
    }
    Write-Host ''
}
