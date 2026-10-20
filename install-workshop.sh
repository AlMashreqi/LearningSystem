#!/usr/bin/env bash
# LearningSystem workshop setup for macOS: Python 3.9+, then Codex.
set -Eeuo pipefail

fail() { printf '\nWorkshop setup stopped: %s\n' "$1" >&2; exit 1; }
version_ok() { "$1" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; }
workshop_tmp=''
cleanup() { [[ -z "$workshop_tmp" || ! -d "$workshop_tmp" ]] || rm -rf -- "$workshop_tmp"; }
trap cleanup EXIT

printf '\nLearningSystem workshop setup | macOS\n\n'
[[ "$(uname -s)" == Darwin ]] || fail 'This file is for macOS. Use install-workshop.bat on Windows.'
[[ "$(uname -m)" == arm64 || "$(uname -m)" == x86_64 ]] || fail 'Use a 64-bit Intel or Apple silicon Mac.'
[[ "$EUID" -ne 0 ]] || fail 'Run from your own account, without sudo.'
[[ -t 0 ]] || fail 'Run this script in Terminal so you can answer its prompts.'

printf '[1/2] Python 3.9+\n'
python_cmd=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && version_ok "$candidate"; then python_cmd=$(command -v "$candidate"); break; fi
done
if [[ -n "$python_cmd" ]]; then
  "$python_cmd" --version
else
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download Python.'
  workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/learning-system-setup.XXXXXXXX")
  pkg="$workshop_tmp/python-3.13.16-macos11.pkg"
  printf 'Downloading Python 3.13.16 from python.org...\n'
  curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' \
    --connect-timeout 20 --max-time 180 \
    https://www.python.org/ftp/python/3.13.16/python-3.13.16-macos11.pkg -o "$pkg" \
    || fail 'Python download failed. Check your internet connection and retry.'
  expected='30666509020b4da0dd8bc2e773255f34d76b7bb80b66960a928d5f6daa0192d7'
  actual=$(shasum -a 256 "$pkg" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || fail 'Python installer checksum mismatch. The file was not opened.'
  open "$pkg" || fail 'Could not open the Python installer.'
  read -r -p 'Complete the Python installer, then press Enter here... ' _
  for candidate in python3.13 python3; do
    if command -v "$candidate" >/dev/null 2>&1 && version_ok "$candidate"; then python_cmd=$(command -v "$candidate"); break; fi
  done
  [[ -n "$python_cmd" ]] || fail 'Python 3.9+ was not found. Close and reopen Terminal, then rerun setup.'
  "$python_cmd" --version
fi

printf '\n[2/2] Codex\n'
codex_cmd=$(command -v codex || true)
if [[ -z "$codex_cmd" && -x "${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex" ]]; then
  codex_cmd="${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex"
fi
if [[ -n "$codex_cmd" ]]; then
  "$codex_cmd" --version || fail 'The existing Codex installation cannot start.'
  printf 'Keeping the existing Codex installation.\n'
else
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download Codex.'
  if [[ -z "$workshop_tmp" ]]; then workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/codex-workshop.XXXXXXXX"); fi
  installer="$workshop_tmp/openai-install.sh"
  curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' \
    --connect-timeout 20 --max-time 120 --retry 2 \
    https://chatgpt.com/codex/install.sh -o "$installer" \
    || fail 'Codex download failed. Check your internet connection and retry.'
  [[ -s "$installer" ]] || fail 'Codex installer download was empty.'
  sh -n "$installer" || fail 'The downloaded Codex installer was not a valid shell script.'
  CODEX_NON_INTERACTIVE=1 sh "$installer" || fail 'The official Codex installer failed.'
  codex_cmd="${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex"
  [[ -x "$codex_cmd" ]] || codex_cmd=$(command -v codex || true)
  [[ -n "$codex_cmd" ]] || fail 'Codex was not found after installation. Reopen Terminal and rerun setup.'
  "$codex_cmd" --version || fail 'Codex installed but could not start.'
fi

workshop_dir="$HOME/Codex-Workshop"
mkdir -p -- "$workshop_dir"
launcher="$workshop_dir/start-codex.command"
if [[ ! -e "$launcher" && ! -L "$launcher" ]]; then
  {
    printf '#!/usr/bin/env bash\nset -e\n'
    printf 'cd -- %q\n' "$workshop_dir"
    printf 'exec %q "$@"\n' "$codex_cmd"
  } > "$launcher"
  chmod u+x "$launcher"
fi
printf '\nPython and Codex are ready.\nWorkshop folder: %s\n' "$workshop_dir"
printf 'Open Codex later with: bash %q\n' "$launcher"
printf 'In Codex, sign in with ChatGPT and keep the default permissions.\n'
read -r -p 'Open Codex now? [Y/n]: ' answer
case "$answer" in n|N|no|NO) ;; *) cd -- "$workshop_dir"; "$codex_cmd" ;; esac
