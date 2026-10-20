@echo off
setlocal DisableDelayedExpansion
title LearningSystem Workshop Setup
rem Git, Python, Node/npm, Codex; optional LaTeX. Extract the ZIP first; no prerequisites to install manually.
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
$temporaryFiles = New-Object 'System.Collections.Generic.List[string]'

function Get-CheckedInstaller([string] $Url, [string] $Hash, [string] $Extension) {
    $file = Join-Path ([IO.Path]::GetTempPath()) ('workshop-' + [guid]::NewGuid().ToString('N') + $Extension)
    $temporaryFiles.Add($file)
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $file -TimeoutSec 600
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash) {
        throw 'Installer checksum mismatch. The file was not run.'
    }
    return $file
}

function Refresh-Path {
    $env:PATH = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
        [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + $env:PATH
}

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
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Refresh-Path
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $arm64 = $architecture -eq 'ARM64'

    Write-Host '[1/5] Git'
    $gitDir = Join-Path $env:LOCALAPPDATA 'Programs\Git'
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath "$gitDir\cmd\git.exe")) {
        $env:PATH = "$gitDir\cmd;" + $env:PATH
    }
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        $gitAsset = if ($arm64) { 'Git-2.56.0.2-arm64.exe' } else { 'Git-2.56.0.2-64-bit.exe' }
        $gitHash = if ($arm64) { 'b9ced78ce371577dc966f50ae571909d6731e36d31065d35c8efa21544c58bf0' } else { '52188f917b378f00c70ec136bcf090005f30d44fbc4eba0bce759cc6592d60f6' }
        Write-Host 'Installing Git for this Windows user...'
        $gitInstaller = Get-CheckedInstaller "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.2/$gitAsset" $gitHash '.exe'
        $process = Start-Process -FilePath $gitInstaller -ArgumentList @('/CURRENTUSER', '/VERYSILENT', '/NORESTART', '/SP-', "/DIR=`"$gitDir`"") -Wait -PassThru
        if ($process.ExitCode -ne 0) { throw "Git installer returned exit code $($process.ExitCode)." }
        Refresh-Path
        $env:PATH = "$gitDir\cmd;" + $env:PATH
    }
    & git.exe --version
    if ($LASTEXITCODE -ne 0) { throw 'Git cannot start.' }

    Write-Host "`n[2/5] Python 3.9+"
    $pythonReady = $false
    foreach ($name in @('py', 'python', 'python3')) {
        if (Test-Python39 $name) { $pyCommand = Get-Command $name; & $pyCommand.Source --version; $pythonReady = $true; break }
    }
    if (-not $pythonReady) {
        Write-Host 'Downloading Python 3.13.16 from python.org...'
        $pythonInstaller = Join-Path ([IO.Path]::GetTempPath()) ('python-workshop-' + [guid]::NewGuid().ToString('N') + '.exe')
        $temporaryFiles.Add($pythonInstaller)
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

    Write-Host "`n[3/5] Node.js and npm"
    $nodeReady = $false
    if ((Get-Command node.exe -ErrorAction SilentlyContinue) -and (Get-Command npm.cmd -ErrorAction SilentlyContinue)) {
        & node.exe --version
        if ($LASTEXITCODE -eq 0) { & npm.cmd --version; $nodeReady = $LASTEXITCODE -eq 0 }
    }
    if (-not $nodeReady) {
        $nodeAsset = if ($arm64) { 'node-v24.22.0-arm64.msi' } else { 'node-v24.22.0-x64.msi' }
        $nodeHash = if ($arm64) { '3161e384f52d95e80bbc85c7ec6fe675528790647b7a3ec71e6ea6d53ce66b29' } else { '97ebad47ad35da4b59182a5fbe9fad2b1a1836f1042b4833ff5b4b9571175088' }
        $nodeInstaller = Get-CheckedInstaller "https://nodejs.org/dist/v24.22.0/$nodeAsset" $nodeHash '.msi'
        Write-Host 'Complete the Node.js installer (includes npm). Administrator approval may be required.'
        $process = Start-Process -FilePath msiexec.exe -ArgumentList @('/i', "`"$nodeInstaller`"", '/norestart') -Wait -PassThru
        if ($process.ExitCode -notin @(0, 3010)) { throw "Node.js installer returned exit code $($process.ExitCode)." }
        Refresh-Path
        & node.exe --version
        if ($LASTEXITCODE -ne 0) { throw 'Node.js cannot start. Reopen the terminal and rerun setup.' }
        & npm.cmd --version
        if ($LASTEXITCODE -ne 0) { throw 'npm cannot start. Reopen the terminal and rerun setup.' }
    } else { Write-Host 'Keeping the existing Node.js and npm installation.' }

    Write-Host "`n[4/5] Codex"
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
        $temporaryFiles.Add($codexInstaller)
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

    Write-Host "`n[5/5] Optional LaTeX for PDF generation"
    Write-Host 'TinyTeX is smaller than full TeX distributions, but needs extra download time and disk space.'
    $answer = Read-Host 'Set up LaTeX for PDFs now? [y/N]'
    if ($answer -match '^(y|yes)$') {
        $texDir = Join-Path $env:APPDATA 'TinyTeX'
        $texBin = Join-Path $texDir 'bin\windows'
        if (-not (Get-Command pdflatex.exe -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath "$texBin\pdflatex.exe")) {
            $env:PATH = "$texBin;" + $env:PATH
        }
        if (-not (Get-Command pdflatex.exe -ErrorAction SilentlyContinue)) {
            if (Get-Item -LiteralPath $texDir -Force -ErrorAction SilentlyContinue) { throw 'An existing TinyTeX folder is incomplete. Ask a volunteer to repair it; it was not overwritten.' }
            $texInstaller = Get-CheckedInstaller 'https://github.com/rstudio/tinytex-releases/releases/download/v2026.10/TinyTeX-1-windows-v2026.10.exe' '36c329c644683d981a668419d13c8804696e2816ae4d287ad755788fee231a31' '.exe'
            $texStage = Join-Path ([IO.Path]::GetTempPath()) ('workshop-tex-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $texStage | Out-Null
            $temporaryFiles.Add($texStage)
            $process = Start-Process -FilePath $texInstaller -ArgumentList @('-y', "-o`"$texStage`"") -Wait -PassThru
            if ($process.ExitCode -ne 0) { throw "TinyTeX extraction returned exit code $($process.ExitCode)." }
            Move-Item -LiteralPath (Join-Path $texStage 'TinyTeX') -Destination $texDir
            $env:PATH = "$texBin;" + $env:PATH
        }
        # Only manage our TinyTeX, never change packages in another TeX distribution.
        if ((Get-Command pdflatex.exe).Source -eq "$texBin\pdflatex.exe") {
            & "$texBin\tlmgr.bat" path add
            if ($LASTEXITCODE -ne 0) { throw 'Could not add TinyTeX to PATH.' }
            & "$texBin\tlmgr.bat" update --self
            if ($LASTEXITCODE -ne 0) { throw 'Could not update the TinyTeX package manager.' }
            & "$texBin\tlmgr.bat" install latex-bin latex amsmath amsfonts mathtools geometry lm xcolor booktabs float microtype pgf fancyhdr hyperref
            if ($LASTEXITCODE -ne 0) { throw 'Could not install the LaTeX template packages.' }
        }
        & pdflatex.exe --version
        if ($LASTEXITCODE -ne 0) { throw 'LaTeX cannot start.' }
        foreach ($package in @('geometry.sty', 'lmodern.sty', 'fontenc.sty', 'amsmath.sty', 'amssymb.sty', 'mathtools.sty', 'xcolor.sty', 'booktabs.sty', 'float.sty', 'microtype.sty', 'tikz.sty', 'fancyhdr.sty', 'hyperref.sty')) {
            & kpsewhich.exe $package | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "Missing LaTeX package file: $package. Ask a volunteer to repair the TeX installation." }
        }
        Write-Host 'LaTeX and the template packages are ready.'
    } else { Write-Host 'Skipping LaTeX. HTML lessons and the core study commands still work.' }

    $workshopDir = Join-Path $env:USERPROFILE 'Codex-Workshop'
    New-Item -ItemType Directory -Force -Path $workshopDir | Out-Null
    $launcher = Join-Path $workshopDir 'start-codex.bat'
    if (-not (Test-Path -LiteralPath $launcher)) {
        $escapedCodex = $codexPath.Replace("'", "''")
        $launchCommand = "Set-Location -LiteralPath (Join-Path `$env:USERPROFILE 'Codex-Workshop'); & '$escapedCodex'; exit `$LASTEXITCODE"
        $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($launchCommand))
        [IO.File]::WriteAllText($launcher, "@echo off`r`nsetlocal DisableDelayedExpansion`r`npowershell.exe -NoLogo -NoProfile -EncodedCommand $encoded`r`nif errorlevel 1 pause`r`n", [Text.Encoding]::ASCII)
    }
    Write-Host "`nGit, Python, Node.js/npm and Codex are ready. Workshop folder: $workshopDir" -ForegroundColor Green
    Write-Host 'Reopen your terminal before using newly installed tools outside this setup.'
    Write-Host 'Choose Sign in with ChatGPT on first use and keep the default permissions.'
    $answer = Read-Host 'Open Codex now? [Y/n]'
    if ($answer -notmatch '^(n|no)$') { Set-Location -LiteralPath $workshopDir; & $codexPath; if ($LASTEXITCODE -ne 0) { throw 'Codex closed with an error.' } }
} finally {
    foreach ($file in $temporaryFiles) { if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Recurse -Force -ErrorAction SilentlyContinue } }
}
