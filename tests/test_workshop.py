"""Offline macOS installer checks; no real downloads or installations."""
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest

KIT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt" and shutil.which("powershell.exe"),
                     "Windows PowerShell bootstrap tests")
class WindowsBootstrapTests(unittest.TestCase):
    def run_bootstrap(self, scenario):
        command = (KIT / "README.md").read_text(encoding="utf-8").split("```powershell\n", 1)[1].split("```", 1)[0]
        # Stub both downloaders; execute only a harmless locally generated batch file.
        mocks = r'''
function Write-MockDownload([string] $Path) {
    if ($env:BOOTSTRAP_SCENARIO -eq 'empty') { [IO.File]::WriteAllText($Path, ''); return }
    $exitCode = if ($env:BOOTSTRAP_SCENARIO -eq 'installer-fails') { 7 } else { 0 }
    $batch = "@echo off`r`necho ran>`"$env:BOOTSTRAP_LOG`"`r`nexit /b $exitCode`r`n"
    [IO.File]::WriteAllText($Path, $batch, [Text.Encoding]::ASCII)
}
function curl.exe {
    $outputIndex = [Array]::IndexOf($args, '--output')
    Write-MockDownload $args[$outputIndex + 1]
    $global:LASTEXITCODE = if ($env:BOOTSTRAP_SCENARIO -eq 'download-fails') { 22 } else { 0 }
}
function Invoke-WebRequest {
    param([switch] $UseBasicParsing, [string] $Uri, [string] $OutFile,
          [int] $TimeoutSec, [string] $ErrorAction)
    if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) {
        throw 'TLS 1.2 was not enabled.'
    }
    Write-MockDownload $OutFile
}
if ($env:BOOTSTRAP_SCENARIO -eq 'fallback') {
    function Get-Command { param($Name, $ErrorAction); return $null }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
}
'''
        with tempfile.TemporaryDirectory(prefix="bootstrap test ") as directory:
            root = Path(directory)
            log = root / "ran.txt"
            result = subprocess.run(
                ["powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
                 mocks + "\ntry {\n" + command + "\n} catch { Write-Output $_; exit 13 }"],
                env={**os.environ, "TEMP": directory, "BOOTSTRAP_SCENARIO": scenario,
                     "BOOTSTRAP_LOG": str(log)}, capture_output=True, text=True, timeout=30)
            return result, log.exists(), list(root.glob("*.bat"))

    def test_success_runs_and_cleans_up(self):
        result, ran, leftovers = self.run_bootstrap("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(ran)
        self.assertEqual(leftovers, [])

    def test_fallback_enables_tls_and_runs_without_curl(self):
        result, ran, leftovers = self.run_bootstrap("fallback")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(ran)
        self.assertEqual(leftovers, [])

    def test_failed_or_empty_download_never_runs(self):
        for scenario in ("download-fails", "empty"):
            with self.subTest(scenario=scenario):
                result, ran, leftovers = self.run_bootstrap(scenario)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(ran)
                self.assertEqual(leftovers, [])

    def test_installer_failure_is_reported_and_cleaned_up(self):
        result, ran, leftovers = self.run_bootstrap("installer-fails")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(ran)
        self.assertIn("exit code 7", result.stdout + result.stderr)
        self.assertEqual(leftovers, [])


@unittest.skipUnless(sys.platform == "darwin", "macOS shell installer tests")
class WorkshopTests(unittest.TestCase):
    def run_setup(self, *, missing=(), answers="n\nn\n", bad_checksum=False,
                  latex=False, missing_package=False, incomplete_tex=False):
        with tempfile.TemporaryDirectory(prefix="workshop test ") as directory:
            root = Path(directory)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            log = root / "calls"
            def stub(name, body):
                path = bin_dir / name
                if path.is_symlink():
                    path.unlink()
                path.write_text("#!/bin/bash\n" + body + "\n")
                path.chmod(0o755)
            stub("uname", 'if [[ "$1" == -m ]]; then echo arm64; else echo Darwin; fi')
            for name in ("git", "python3", "node", "npm", "codex"):
                if name not in missing:
                    stub(name, f'echo "{name} version"; echo {name} >> "$CALL_LOG"')
            if latex:
                stub("pdflatex", 'echo pdflatex >> "$CALL_LOG"')
                stub("kpsewhich", 'exit 1' if missing_package else 'echo found')
            if incomplete_tex:
                (root / "Library/TinyTeX").mkdir(parents=True)
            # Only expose explicitly allowed commands, never real installers.
            for name in ("mkdir", "chmod", "mktemp", "rm", "awk", "shasum"):
                (bin_dir / name).symlink_to(Path("/usr/bin" if name in ("mktemp", "awk", "shasum") else "/bin") / name)
            stub("curl", 'echo download >> "$CALL_LOG"; exit 97')
            stub("open", 'echo open >> "$CALL_LOG"; exit 98')
            stub("xcode-select", 'echo xcode >> "$CALL_LOG"; exit 0')
            if bad_checksum:
                stub("curl", 'echo download >> "$CALL_LOG"; exit 0')
                stub("shasum", 'echo "wrong-checksum  installer"')
            import pty
            master, slave = pty.openpty()
            try:
                process = subprocess.Popen(
                    ["/bin/bash", str(KIT / "install-workshop.sh")], stdin=slave,
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    env={**os.environ, "HOME": str(root), "PATH": str(bin_dir),
                         "CALL_LOG": str(log), "BASH_ENV": "/dev/null", "CODEX_INSTALL_DIR": str(bin_dir)})
                os.write(master, answers.encode())
                output, _ = process.communicate(timeout=10)
            finally:
                os.close(master)
                os.close(slave)
            return process.returncode, output.decode(), log.read_text() if log.exists() else ""

    def test_existing_tools_are_checked_without_downloads_and_latex_can_be_declined(self):
        code, output, calls = self.run_setup()
        self.assertEqual(code, 0, output)
        for tool in ("git", "python3", "node", "npm", "codex"):
            self.assertIn(tool, calls)
        self.assertNotIn("download", calls)
        self.assertIn("Skipping", output)

    def test_missing_git_requests_apple_tools_and_stops_if_not_completed(self):
        code, output, calls = self.run_setup(missing=("git",))
        self.assertNotEqual(code, 0, output)
        self.assertIn("xcode", calls)
        self.assertNotIn("download", calls)

    def test_missing_node_stops_on_checksum_mismatch_without_opening_installer(self):
        code, output, calls = self.run_setup(missing=("node", "npm"), bad_checksum=True)
        self.assertNotEqual(code, 0, output)
        self.assertIn("download", calls)
        self.assertIn("checksum", output.lower())
        self.assertNotIn("open", calls)

    def test_existing_latex_is_checked_without_installing_or_changing_packages(self):
        code, output, calls = self.run_setup(latex=True, answers="y\nn\n")
        self.assertEqual(code, 0, output)
        self.assertIn("pdflatex", calls)
        self.assertIn("template packages are ready", output)
        self.assertNotIn("download", calls)

    def test_existing_latex_with_missing_template_packages_is_not_reported_ready(self):
        code, output, calls = self.run_setup(latex=True, missing_package=True, answers="y\n")
        self.assertNotEqual(code, 0, output)
        self.assertIn("Missing LaTeX package", output)
        self.assertNotIn("download", calls)

    def test_incomplete_tinytex_is_not_overwritten(self):
        code, output, calls = self.run_setup(incomplete_tex=True, answers="y\n")
        self.assertNotEqual(code, 0, output)
        self.assertIn("not overwritten", output)
        self.assertNotIn("download", calls)

    def test_optional_latex_download_stops_before_extraction_on_checksum_mismatch(self):
        code, output, calls = self.run_setup(bad_checksum=True, answers="y\n")
        self.assertNotEqual(code, 0, output)
        self.assertIn("checksum", output.lower())
        self.assertIn("download", calls)


if __name__ == "__main__":
    unittest.main()
