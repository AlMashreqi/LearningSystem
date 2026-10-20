@echo off
setlocal DisableDelayedExpansion
title LearningSystem Workshop Setup
rem Combined setup: Python 3.9+, then Codex. Install Git and clone the repo first.
set "WORKSHOP_SETUP_SELF=%~f0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo Windows PowerShell is required. Ask a workshop volunteer for help.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $text=[IO.File]::ReadAllText($env:WORKSHOP_SETUP_SELF); $marker='# '+'WORKSHOP_POWERSHELL'; $offset=$text.IndexOf($marker); if($offset -lt 0){throw 'Setup file is incomplete.'}; & ([scriptblock]::Create($text.Substring($offset))) } catch { Write-Host ('Workshop setup stopped: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
set "WORKSHOP_SETUP_RESULT=%ERRORLEVEL%"
echo.
if not "%WORKSHOP_SETUP_RESULT%"=="0" echo Ask a workshop volunteer for help with the error above.
pause
exit /b %WORKSHOP_SETUP_RESULT%
# WORKSHOP_POWERSHELL
$ErrorActionPreference = 'Stop'
$temporaryFiles = @()

function Test-Python39([string] $Name) {
    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command -or -not $command.Source) { return $false }
    if ($command.Source -match '\\WindowsApps\\') { return $false }
    & $command.Source -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' 2>$null
    return $LASTEXITCODE -eq 0
}

try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'This setup requires 64-bit Windows.' }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Close this window and run setup from your normal user account, not as administrator.'
    }
    Write-Host "`nLearningSystem workshop setup | Windows`n"

    Write-Host '[1/2] Python 3.9+'
    $pythonReady = $false
    foreach ($name in @('py', 'python', 'python3')) {
        if (Test-Python39 $name) { $pyCommand = Get-Command $name; & $pyCommand.Source --version; $pythonReady = $true; break }
    }
    if (-not $pythonReady) {
        Write-Host 'Downloading Python 3.13.16 from python.org...'
        $pythonInstaller = Join-Path ([IO.Path]::GetTempPath()) ('python-workshop-' + [guid]::NewGuid().ToString('N') + '.exe')
        $temporaryFiles += $pythonInstaller
        Invoke-WebRequest -UseBasicParsing -Uri 'https://www.python.org/ftp/python/3.13.16/python-3.13.16-amd64.exe' -OutFile $pythonInstaller -TimeoutSec 180
        $expectedHash = 'fb4f9f5d438b2396da0086dc70b935c530cb578e37adc6d354f7ad2037fee83b'
        $actualHash = (Get-FileHash -LiteralPath $pythonInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) { throw 'Python installer checksum mismatch. The file was not run.' }
        Write-Host 'Installing Python for this Windows user...'
        $process = Start-Process -FilePath $pythonInstaller -ArgumentList @('/quiet', 'InstallAllUsers=0', 'PrependPath=1', 'Include_launcher=1') -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Python installer returned exit code $($process.ExitCode)." }
        $installedPython = Join-Path $env:LocalAppData 'Programs\Python\Python313\python.exe'
        if (-not (Test-Path -LiteralPath $installedPython)) { throw 'Python was not found at the expected per-user install location.' }
        & $installedPython --version
        if ($LASTEXITCODE -ne 0) { throw 'Python installed but could not start.' }
        $env:PATH = (Split-Path $installedPython) + ';' + $env:PATH
    }

    Write-Host "`n[2/2] Codex"
    $codexCommand = Get-Command codex.exe,codex.cmd,codex -ErrorAction SilentlyContinue | Select-Object -First 1
    $codexBin = if ([string]::IsNullOrWhiteSpace($env:CODEX_INSTALL_DIR)) { Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin' } else { $env:CODEX_INSTALL_DIR }
    $codexPath = if ($codexCommand) { $codexCommand.Source } else { Join-Path $codexBin 'codex.exe' }
    if (Test-Path -LiteralPath $codexPath -PathType Leaf) {
        & $codexPath --version
        if ($LASTEXITCODE -ne 0) { throw 'Existing Codex cannot start.' }
        Write-Host 'Keeping the existing Codex installation.'
    } else {
        Write-Host 'Downloading the official OpenAI Codex installer...'
        $codexInstaller = Join-Path ([IO.Path]::GetTempPath()) ('codex-workshop-' + [guid]::NewGuid().ToString('N') + '.ps1')
        $temporaryFiles += $codexInstaller
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri 'https://chatgpt.com/codex/install.ps1' -OutFile $codexInstaller -TimeoutSec 180
        $tokens = $null; $parseErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($codexInstaller, [ref]$tokens, [ref]$parseErrors)
        if ($parseErrors.Count -gt 0) { throw 'The downloaded Codex installer is not valid PowerShell.' }
        $env:CODEX_NON_INTERACTIVE = '1'
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $codexInstaller
        if ($LASTEXITCODE -ne 0) { throw 'The official Codex installer failed.' }
        $codexPath = Join-Path $codexBin 'codex.exe'
        if (-not (Test-Path -LiteralPath $codexPath -PathType Leaf)) { throw 'Codex was not found after installation. Reopen this terminal and rerun setup.' }
        & $codexPath --version
        if ($LASTEXITCODE -ne 0) { throw 'Codex installed but could not start.' }
    }

    $workshopDir = Join-Path $env:USERPROFILE 'Codex-Workshop'
    New-Item -ItemType Directory -Force -Path $workshopDir | Out-Null
    $launcher = Join-Path $workshopDir 'start-codex.bat'
    if (-not (Test-Path -LiteralPath $launcher)) {
        $escapedCodex = $codexPath.Replace("'", "''")
        $launchCommand = "Set-Location -LiteralPath (Join-Path `$env:USERPROFILE 'Codex-Workshop'); & '$escapedCodex'; exit `$LASTEXITCODE"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchCommand))
        [IO.File]::WriteAllText($launcher, "@echo off`r`nsetlocal DisableDelayedExpansion`r`npowershell.exe -NoLogo -NoProfile -EncodedCommand $encoded`r`nif errorlevel 1 pause`r`n", [Text.Encoding]::ASCII)
    }
    Write-Host "`nPython and Codex are ready. Workshop folder: $workshopDir" -ForegroundColor Green
    Write-Host 'Choose Sign in with ChatGPT on first use and keep the default permissions.'
    $answer = Read-Host 'Open Codex now? [Y/n]'
    if ($answer -notmatch '^(n|no)$') { Set-Location -LiteralPath $workshopDir; & $codexPath; if ($LASTEXITCODE -ne 0) { throw 'Codex closed with an error.' } }
} finally {
    foreach ($file in $temporaryFiles) { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue } }
}
