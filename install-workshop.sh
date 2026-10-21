#!/usr/bin/env bash
# LearningSystem workshop setup for macOS: Git, Python, Node/npm, Codex; optional LaTeX.
set -Eeuo pipefail

fail() { printf '\nWorkshop setup stopped: %s\n' "$1" >&2; exit 1; }
version_ok() { "$1" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; }
workshop_tmp=''
cleanup() { [[ -z "$workshop_tmp" || ! -d "$workshop_tmp" ]] || rm -rf -- "$workshop_tmp"; }
trap cleanup EXIT

download_checked() {
  local url="$1" destination="$2" expected="$3" actual
  curl --fail --location --show-error --silent --proto '=https' --proto-redir '=https' \
    --connect-timeout 20 --max-time 600 --retry 2 "$url" -o "$destination" \
    || fail 'Download failed. Check your internet connection and retry.'
  actual=$(shasum -a 256 "$destination" | awk '{print $1}')
  [[ "$actual" == "$expected" ]] || fail 'Installer checksum mismatch. The file was not run.'
}

printf '\nLearningSystem workshop setup | macOS\n\n'
[[ "$(uname -s)" == Darwin ]] || fail 'This file is for macOS. Use install-workshop-linux.sh on Linux or install-workshop.bat on Windows.'
[[ "$(uname -m)" == arm64 || "$(uname -m)" == x86_64 ]] || fail 'Use a 64-bit Intel or Apple silicon Mac.'
[[ "$EUID" -ne 0 ]] || fail 'Run from your own account, without sudo.'
[[ -t 0 ]] || fail 'Run this script in Terminal so you can answer its prompts.'

printf '[1/5] Git\n'
if ! git --version 2>/dev/null; then
  printf 'Installing Apple Command Line Tools for Git. Complete the Apple installer.\n'
  xcode-select --install || fail 'Could not request Apple Command Line Tools. Ask a workshop volunteer for help.'
  read -r -p 'When installation finishes, press Enter here... ' _
  git --version || fail 'Git is not ready. Complete the Apple installer, then rerun setup.'
fi

printf '\n[2/5] Python 3.9+\n'
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

printf '\n[3/5] Node.js and npm\n'
if node --version 2>/dev/null && npm --version 2>/dev/null; then
  printf 'Keeping the existing Node.js and npm installation.\n'
else
  if [[ -z "$workshop_tmp" ]]; then workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/learning-system-setup.XXXXXXXX"); fi
  pkg="$workshop_tmp/node-v24.22.0.pkg"
  printf 'Downloading Node.js 24 LTS (includes npm) from nodejs.org...\n'
  download_checked 'https://nodejs.org/dist/v24.22.0/node-v24.22.0.pkg' "$pkg" \
    '905ddb9b5cd66fc537cdeb149fafbe526b95915781a588be96632c01a106bfa5'
  open "$pkg" || fail 'Could not open the Node.js installer.'
  read -r -p 'Complete the Node.js installer (administrator approval may be required), then press Enter... ' _
  export PATH="/usr/local/bin:$PATH"
  node --version && npm --version || fail 'Node.js/npm are not ready. Complete the installer, then rerun setup.'
fi

printf '\n[4/5] Codex\n'
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

printf '\n[5/5] Optional LaTeX for PDF generation\n'
printf 'TinyTeX is smaller than full TeX distributions, but needs extra download time and disk space.\n'
read -r -p 'Set up LaTeX for PDFs now? [y/N]: ' answer
case "$answer" in
  y|Y|yes|YES)
    tex_bin="$HOME/Library/TinyTeX/bin/universal-darwin"
    if ! command -v pdflatex >/dev/null 2>&1 && [[ -x "$tex_bin/pdflatex" ]]; then
      export PATH="$tex_bin:$PATH"
    fi
    if ! command -v pdflatex >/dev/null 2>&1; then
      [[ ! -e "$HOME/Library/TinyTeX" && ! -L "$HOME/Library/TinyTeX" ]] \
        || fail 'An existing TinyTeX folder is incomplete. Ask a volunteer to repair it; it was not overwritten.'
      if [[ -z "$workshop_tmp" ]]; then workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/learning-system-setup.XXXXXXXX"); fi
      archive="$workshop_tmp/tinytex.tar.xz"
      download_checked 'https://github.com/rstudio/tinytex-releases/releases/download/v2026.10/TinyTeX-1-darwin-v2026.10.tar.xz' \
        "$archive" 'e40c294efae81026d8cc8d12c09d2dd456d268efe7fe092410478bc1973fd40f'
      tar xf "$archive" -C "$workshop_tmp"
      mkdir -p -- "$HOME/Library"
      mv -- "$workshop_tmp/TinyTeX" "$HOME/Library/TinyTeX"
      export PATH="$tex_bin:$PATH"
    fi
    # Only manage our TinyTeX, never change packages in another TeX distribution.
    if [[ "$(command -v pdflatex)" == "$tex_bin/pdflatex" ]]; then
      "$tex_bin/tlmgr" update --self
      "$tex_bin/tlmgr" install latex-bin latex amsmath amsfonts mathtools geometry lm xcolor booktabs float microtype pgf fancyhdr hyperref
      for profile in "$HOME/.zprofile" "$HOME/.bash_profile"; do
        line='export PATH="$HOME/Library/TinyTeX/bin/universal-darwin:$PATH"'
        grep -qxF "$line" "$profile" 2>/dev/null || printf '\n%s\n' "$line" >> "$profile"
      done
    fi
    pdflatex --version || fail 'LaTeX cannot start.'
    for package in geometry.sty lmodern.sty fontenc.sty amsmath.sty amssymb.sty mathtools.sty xcolor.sty booktabs.sty float.sty microtype.sty tikz.sty fancyhdr.sty hyperref.sty; do
      kpsewhich "$package" >/dev/null || fail "Missing LaTeX package file: $package. Ask a volunteer to repair the TeX installation."
    done
    printf 'LaTeX and the template packages are ready.\n'
    ;;
  *) printf 'Skipping LaTeX. HTML lessons and the core study commands still work.\n' ;;
esac

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
printf '\nGit, Python, Node.js/npm and Codex are ready.\nWorkshop folder: %s\n' "$workshop_dir"
printf 'Reopen Terminal before using newly installed tools outside this setup.\n'
printf 'Open Codex later with: bash %q\n' "$launcher"
printf 'In Codex, sign in with ChatGPT and keep the default permissions.\n'
read -r -p 'Open Codex now? [Y/n]: ' answer
case "$answer" in n|N|no|NO) ;; *) cd -- "$workshop_dir"; "$codex_cmd" ;; esac
