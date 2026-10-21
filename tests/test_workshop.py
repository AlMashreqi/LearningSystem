"""Offline macOS installer checks; no real downloads or installations."""
import os
from pathlib import Path
import shutil
import sys
import subprocess
import tempfile
import unittest

KIT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "nt", "requires Windows Command Prompt/PowerShell")
class WindowsWorkshopTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which("curl.exe"), "requires Windows curl.exe")
    def test_cmd_download_gate_and_installer_exit_code(self):
        command = (KIT / "README.md").read_text(encoding="utf-8").split("```cmd\n", 1)[1].split("```", 1)[0].strip()
        url = "https://raw.githubusercontent.com/AlMashreqi/LearningSystem/refs/heads/master/install-workshop.bat"
        for scenario in ("success", "download-fails", "installer-fails"):
            with self.subTest(scenario=scenario), tempfile.TemporaryDirectory(prefix="cmd test ") as directory:
                root = Path(directory)
                log = root / "ran.txt"
                source = root / "source.bat"
                code = 7 if scenario == "installer-fails" else 0
                if scenario != "download-fails":
                    source.write_bytes(f'@echo off\r\necho ran>"%WORKSHOP_TEST_LOG%"\r\nexit /b {code}\r\n'.encode("ascii"))
                # Even a leftover installer must not run after a failed download.
                (root / "install-workshop.bat").write_bytes(b'@echo off\r\necho stale>"%WORKSHOP_TEST_LOG%"\r\n')
                result = subprocess.run(
                    'cmd.exe /d /s /c "' + command.replace(url, source.as_uri()) + '"',
                    env={**os.environ, "TEMP": directory, "WORKSHOP_TEST_LOG": str(log)},
                    capture_output=True, timeout=30)
                if scenario == "download-fails":
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(log.exists())
                else:
                    self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                    self.assertEqual(log.read_text().strip(), "ran")

    @unittest.skipUnless(shutil.which("powershell.exe"), "requires Windows PowerShell")
    def test_codex_child_enables_tls_and_propagates_failure(self):
        for exit_code in (0, 7):
            with self.subTest(exit_code=exit_code), tempfile.TemporaryDirectory(prefix="TLS test ") as directory:
                installer = Path(directory) / "installer's mock.ps1"
                installer.write_text(
                    "if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) { throw 'TLS missing' }; "
                    f"Write-Output 'TLS_OK'; exit {exit_code}", encoding="ascii")
                # Load only the helper's AST, never the actual installer's main body.
                harness = r'''
$tokens = $null; $errors = $null
$text = [IO.File]::ReadAllText($env:SETUP_SOURCE)
$ast = [Management.Automation.Language.Parser]::ParseInput($text.Substring($text.IndexOf('# WORKSHOP_POWERSHELL')), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Installer syntax error' }
$helper = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Invoke-CodexInstaller' }, $true)
if (-not $helper) { throw 'Missing Codex launch helper' }
. ([scriptblock]::Create($helper.Extent.Text))
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls
try { Invoke-CodexInstaller $env:MOCK_INSTALLER; exit 0 } catch { Write-Output $_; exit 1 }
'''
                result = subprocess.run(
                    ["powershell.exe", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", harness],
                    env={**os.environ, "SETUP_SOURCE": str(KIT / "install-workshop.bat"),
                         "MOCK_INSTALLER": str(installer)}, capture_output=True, text=True, timeout=30)
                self.assertIn("TLS_OK", result.stdout, result.stderr)
                self.assertEqual(result.returncode, 0 if exit_code == 0 else 1, result.stdout + result.stderr)
                if exit_code:
                    self.assertIn("exit code 7", result.stdout)


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
