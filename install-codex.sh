#!/usr/bin/env bash
# CS Soc, Ashoka University. macOS / Linux / WSL.
# Downloads the official OpenAI installer; no Node.js or sudo needed.
# Run: bash install-codex.sh       Read-only check: bash install-codex.sh --check
set -Eeuo pipefail

workshop_tmp=''
cleanup() { if [[ -n "$workshop_tmp" && -d "$workshop_tmp" ]]; then rm -rf -- "$workshop_tmp"; fi; }
trap cleanup EXIT
fail() { printf '\nSetup stopped: %s\nAsk a workshop volunteer for help with the message above.\n' "$1" >&2; exit 1; }
trap 'fail "A command failed. You can rerun this installer after fixing the problem."' ERR
trap 'printf "\nSetup cancelled.\n"; exit 130' INT TERM

case "${1:-}" in
  '') workshop_check=0 ;;
  --check) workshop_check=1 ;;
  *) printf 'Usage: bash install-codex.sh [--check]\n'; exit 2 ;;
esac

printf '\nCodex setup | CS Soc, Ashoka University\n\n'
workshop_os=$(uname -s)
workshop_arch=$(uname -m)
case "$workshop_os" in Darwin|Linux) ;; *) fail 'Use install-codex.bat on Windows. This file is for macOS, Linux or WSL.' ;; esac
case "$workshop_arch" in x86_64|amd64|arm64|aarch64) ;; *) fail "This installer requires a 64-bit Intel/AMD or ARM computer. Found: $workshop_arch" ;; esac
printf 'Computer: %s (%s)\n' "$workshop_os" "$workshop_arch"

workshop_codex=$(command -v codex || true)
if [[ -z "$workshop_codex" && -x "${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex" ]]; then
  workshop_codex="${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex"
fi
if [[ -n "$workshop_codex" ]]; then
  if ! "$workshop_codex" --version; then
    fail 'An existing Codex installation cannot start. Ask a volunteer to repair it before rerunning.'
  fi
  printf 'Codex is already installed. This script will keep that version.\n'
fi
if [[ "$workshop_check" == 1 ]]; then
  if [[ -z "$workshop_codex" ]]; then
    printf 'Codex was not found. Run this file without --check to install it.\n'
    exit 1
  fi
  printf 'Installation check passed. Sign-in and workshop credits are separate.\n'
  exit 0
fi

[[ "$EUID" -ne 0 ]] || fail 'Run this from your own account, without sudo.'
[[ -t 0 ]] || fail 'Run this file in Terminal, rather than piping it into another command.'
printf '\nThis setup will:\n'
printf '  - Install Codex for your account if it is missing.\n'
printf '  - Let the official installer add Codex to your terminal command path.\n'
printf '  - Create a Codex-Workshop folder and a start launcher.\n'
printf '  - Offer to open Codex so you can sign in with ChatGPT.\n'
printf '\nInternet access is required for installation and sign-in.\n'
read -r -p 'Press Enter to continue, or type N to cancel: ' workshop_answer || exit 0
case "$workshop_answer" in n|N|no|NO) printf 'Cancelled.\n'; exit 0 ;; esac

if [[ -z "$workshop_codex" ]]; then
  printf '\n[1/3] Downloading the official OpenAI installer...\n'
  command -v tar >/dev/null 2>&1 || fail 'The tar utility is missing. Ask a volunteer to install it using your system package manager.'
  workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/codex-workshop.XXXXXXXX")
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' \
      --connect-timeout 20 --max-time 120 --retry 2 \
      https://chatgpt.com/codex/install.sh -o "$workshop_tmp/install.sh" || fail 'Download failed. Check Wi-Fi and any campus network restrictions, then rerun.'
  elif command -v wget >/dev/null 2>&1; then
    wget --https-only --timeout=30 --tries=3 -q -O "$workshop_tmp/install.sh" \
      https://chatgpt.com/codex/install.sh || fail 'Download failed. Check Wi-Fi, then rerun.'
  else
    fail 'curl or wget is required. Ask a volunteer to install either using your system package manager.'
  fi
  [[ -s "$workshop_tmp/install.sh" ]] || fail 'The installer download was empty.'
  sh -n "$workshop_tmp/install.sh" || fail 'The download was not a valid shell script. Check whether the network requires browser sign-in.'
  printf '\n[2/3] Installing Codex. This can take several minutes...\n'
  CODEX_NON_INTERACTIVE=1 sh "$workshop_tmp/install.sh" || fail 'The official installer failed. Read its error above. Do not rerun with sudo.'
  workshop_codex="${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex"
  [[ -x "$workshop_codex" ]] || fail 'Codex was not found at the expected install location.'
else
  printf '\n[1/3] Existing installation found.\n[2/3] No download needed.\n'
fi
printf '\n[3/3] Checking Codex and preparing your workshop folder...\n'
"$workshop_codex" --version || fail 'Codex installed but could not start on this computer.'
workshop_dir="$HOME/Codex-Workshop"
mkdir -p -- "$workshop_dir"
if [[ "$workshop_os" == Darwin ]]; then workshop_launcher="$workshop_dir/start-codex.command"; else workshop_launcher="$workshop_dir/start-codex.sh"; fi
# Do not overwrite a participant's existing launcher or project files.
if [[ ! -e "$workshop_launcher" && ! -L "$workshop_launcher" ]]; then
  {
    printf '#!/usr/bin/env bash\nset -e\n'
    printf 'cd -- %q\n' "$workshop_dir"
    printf 'exec %q "$@"\n' "$workshop_codex"
  } > "$workshop_launcher"
  chmod u+x "$workshop_launcher"
fi
printf '\nCodex is ready. Workshop folder: %s\n' "$workshop_dir"
printf 'To open it later, run:\n  bash %q\n' "$workshop_launcher"
printf '\nOn first use, choose Sign in with ChatGPT and use the account receiving workshop credits.\n'
printf 'If already signed in, check that it is the right account.\n'
printf 'Keep the default permissions. Email/calendar connections come later.\n'
read -r -p 'Open Codex now? [Y/n]: ' workshop_answer || exit 0
case "$workshop_answer" in n|N|no|NO) printf 'Done. You can open Codex later using the command above.\n' ;;
  *) cd -- "$workshop_dir"
     if ! "$workshop_codex"; then
       printf '\nCodex closed with an error. Installation is complete; show the error to a volunteer.\n' >&2
       exit 1
     fi ;;
esac
