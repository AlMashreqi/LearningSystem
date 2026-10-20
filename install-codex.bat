@echo off
setlocal DisableDelayedExpansion
title Codex Workshop Setup
rem Self-contained BAT launcher. PowerShell code follows the marker below.
rem Uses Windows PowerShell; does not permanently change execution policy.
set "WORKSHOP_SETUP_SELF=%~f0"
where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo Windows PowerShell is missing. Ask a workshop volunteer for help.
  pause
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -Command "$ErrorActionPreference='Stop'; try { $text=[IO.File]::ReadAllText($env:WORKSHOP_SETUP_SELF); $marker='# '+'WORKSHOP_POWERSHELL'; $offset=$text.IndexOf($marker); if($offset -lt 0){throw 'Setup file is incomplete. Download it again.'}; & ([scriptblock]::Create($text.Substring($offset))) } catch { Write-Host ('Setup stopped: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }"
set "WORKSHOP_SETUP_RESULT=%ERRORLEVEL%"
echo.
if not "%WORKSHOP_SETUP_RESULT%"=="0" echo Ask a volunteer for help with the error above. Do not disable security settings.
pause
exit /b %WORKSHOP_SETUP_RESULT%
# WORKSHOP_POWERSHELL
$ErrorActionPreference = 'Stop'
$workshopTemp = $null
try {
    Write-Host ''
    Write-Host 'Codex setup | CS Soc, Ashoka University'
    Write-Host ''
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw 'Codex requires 64-bit Windows. Ask a volunteer about another workshop computer.'
    }
    $workshopPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ($workshopPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Close this window and double-click the file normally. Do not use Run as administrator.'
    }
    $workshopCommand = Get-Command codex.exe,codex.cmd -ErrorAction SilentlyContinue | Select-Object -First 1
    $workshopBin = if ([string]::IsNullOrWhiteSpace($env:CODEX_INSTALL_DIR)) {
        Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin'
    } else { $env:CODEX_INSTALL_DIR }
    $workshopCodex = if ($workshopCommand) { $workshopCommand.Source } else { Join-Path $workshopBin 'codex.exe' }
    $workshopExisting = Test-Path -LiteralPath $workshopCodex -PathType Leaf
    if ($workshopExisting) {
        & $workshopCodex --version
        if ($LASTEXITCODE -ne 0) { throw 'Existing Codex cannot start. Ask a volunteer to repair it.' }
        Write-Host 'Codex is already installed. This script will keep that version.'
    }
    Write-Host 'This setup installs Codex for your account if needed.'
    Write-Host 'The official installer may add Codex to your user command path.'
    Write-Host 'It also creates a Codex-Workshop folder and a start launcher.'
    Write-Host 'Internet access is required. Node.js and npm are not needed.'
    $workshopReply = Read-Host 'Press Enter to continue, or type N to cancel'
    if ($workshopReply -match '^(n|no)$') { Write-Host 'Cancelled.'; exit 0 }
    if (-not $workshopExisting) {
        Write-Host "`n[1/3] Downloading the official OpenAI installer..."
        $workshopTemp = Join-Path ([IO.Path]::GetTempPath()) ('codex-workshop-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $workshopTemp | Out-Null
        $workshopInstaller = Join-Path $workshopTemp 'openai-install.ps1'
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -UseBasicParsing -Uri 'https://chatgpt.com/codex/install.ps1' -OutFile $workshopInstaller -TimeoutSec 120
        if ((Get-Item -LiteralPath $workshopInstaller).Length -eq 0) { throw 'The installer download was empty.' }
        $workshopTokens = $null
        $workshopErrors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($workshopInstaller, [ref]$workshopTokens, [ref]$workshopErrors)
        if ($workshopErrors.Count -gt 0) { throw 'The download was not a valid PowerShell installer. Check campus Wi-Fi sign-in.' }
        Write-Host "`n[2/3] Installing Codex. This can take several minutes..."
        $env:CODEX_NON_INTERACTIVE = '1'
        # Process-only policy, as in OpenAI's documented standalone install command.
        # Managed Group Policy can still block this; ask IT rather than overriding it.
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $workshopInstaller
        if ($LASTEXITCODE -ne 0) { throw 'The official installer failed. Read the error above and ask a volunteer.' }
        $workshopCodex = Join-Path $workshopBin 'codex.exe'
    } else {
        Write-Host "`n[1/3] Existing installation found."
        Write-Host '[2/3] No download needed.'
    }
    Write-Host "`n[3/3] Checking Codex and preparing your workshop folder..."
    if (-not (Test-Path -LiteralPath $workshopCodex -PathType Leaf)) { throw 'Codex was not found at the expected installation location.' }
    & $workshopCodex --version
    if ($LASTEXITCODE -ne 0) { throw 'Codex installed but could not start on this computer.' }
    $workshopDir = Join-Path $env:USERPROFILE 'Codex-Workshop'
    New-Item -ItemType Directory -Force -Path $workshopDir | Out-Null
    $workshopLauncher = Join-Path $workshopDir 'start-codex.bat'
    if (-not (Test-Path -LiteralPath $workshopLauncher)) {
        # Resolve paths at launch with PowerShell so spaces, Unicode and % in names are safe.
        $workshopEscapedCodex = $workshopCodex.Replace("'", "''")
        $workshopLaunchCommand = "Set-Location -LiteralPath (Join-Path `$env:USERPROFILE 'Codex-Workshop'); & '$workshopEscapedCodex'; exit `$LASTEXITCODE"
        $workshopEncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($workshopLaunchCommand))
        $workshopLauncherText = "@echo off`r`nsetlocal DisableDelayedExpansion`r`npowershell.exe -NoLogo -NoProfile -EncodedCommand $workshopEncodedCommand`r`nif errorlevel 1 pause`r`n"
        [IO.File]::WriteAllText($workshopLauncher, $workshopLauncherText, [Text.Encoding]::ASCII)
    }
    Write-Host "`nCodex is ready. Workshop folder: $workshopDir" -ForegroundColor Green
    Write-Host 'To open it later, double-click start-codex.bat in that folder.'
    Write-Host 'Choose Sign in with ChatGPT and use the account receiving workshop credits.'
    Write-Host 'If already signed in, check that it is the right account.'
    Write-Host 'Keep the default permissions. Email/calendar connections come later.'
    $workshopReply = Read-Host 'Open Codex now? [Y/n]'
    if ($workshopReply -notmatch '^(n|no)$') {
        Set-Location -LiteralPath $workshopDir
        & $workshopCodex
        if ($LASTEXITCODE -ne 0) { throw 'Codex closed with an error. Installation is complete; show the error to a volunteer.' }
    }
} catch {
    Write-Host "`nSetup stopped: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Check your internet connection. If your university blocks installation, ask IT.'
    exit 1
} finally {
    if ($workshopTemp -and (Test-Path -LiteralPath $workshopTemp)) {
        Remove-Item -LiteralPath $workshopTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
