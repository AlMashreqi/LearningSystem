#!/usr/bin/env bash
# LearningSystem workshop setup for Linux: Git, Python, Node/npm, Codex; optional LaTeX.
set -Eeuo pipefail

fail() { printf '\nWorkshop setup stopped: %s\n' "$1" >&2; exit 1; }
version_ok() { "$1" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; }
[[ "$(uname -s)" == Linux ]] || fail 'This file is for Linux. Use install-workshop.sh on macOS or install-workshop.bat on Windows.'
[[ "$EUID" -ne 0 ]] || fail 'Run from your own account, without sudo.'
[[ -t 0 ]] || fail 'Run this script in a terminal so you can answer its prompts.'

package_manager=''
for manager in apt-get dnf pacman zypper; do
  if command -v "$manager" >/dev/null 2>&1; then package_manager="$manager"; break; fi
done
[[ -n "$package_manager" ]] || fail 'Supported package managers are apt, dnf, pacman and zypper. Install Git, Python 3.9+, Node.js and npm manually, then rerun.'

install_packages() {
  command -v sudo >/dev/null 2>&1 || fail 'sudo is required to install missing system packages. Install the missing tools manually or ask your administrator.'
  case "$package_manager" in
    apt-get) sudo apt-get update && sudo apt-get install -y "$@" ;;
    dnf) sudo dnf install -y "$@" ;;
    pacman) sudo pacman -S --needed --noconfirm "$@" ;;
    zypper) sudo zypper --non-interactive install "$@" ;;
  esac
}

printf '\nLearningSystem workshop setup | Linux (%s)\n\n' "$package_manager"
printf '[1/4] Git, Python 3.9+, Node.js and npm\n'
python_cmd=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && version_ok "$candidate"; then python_cmd=$(command -v "$candidate"); break; fi
done
if ! git --version >/dev/null 2>&1 || [[ -z "$python_cmd" ]] || ! node --version >/dev/null 2>&1 || ! npm --version >/dev/null 2>&1; then
  case "$package_manager" in
    apt-get) install_packages curl git python3 nodejs npm ;;
    dnf) install_packages curl git python3 nodejs npm ;;
    pacman) install_packages curl git python nodejs npm ;;
    zypper) install_packages curl git python3 nodejs npm ;;
  esac
fi
git --version || fail 'Git is not ready.'
python_cmd=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && version_ok "$candidate"; then python_cmd=$(command -v "$candidate"); break; fi
done
[[ -n "$python_cmd" ]] || fail 'Python 3.9+ is required. Your distribution may provide an older Python; install a newer Python 3 and rerun setup.'
"$python_cmd" --version
node --version && npm --version || fail 'Node.js/npm are not ready. Check your distribution packages and rerun setup.'

printf '\n[2/4] Codex\n'
codex_cmd=$(command -v codex || true)
if [[ -z "$codex_cmd" && -x "${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex" ]]; then
  codex_cmd="${CODEX_INSTALL_DIR:-$HOME/.local/bin}/codex"
fi
if [[ -n "$codex_cmd" ]]; then
  "$codex_cmd" --version || fail 'The existing Codex installation cannot start.'
  printf 'Keeping the existing Codex installation.\n'
else
  command -v curl >/dev/null 2>&1 || fail 'curl is required to download Codex.'
  workshop_tmp=$(mktemp -d "${TMPDIR:-/tmp}/codex-workshop.XXXXXXXX")
  trap 'rm -rf -- "$workshop_tmp"' EXIT
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
  [[ -n "$codex_cmd" ]] || fail 'Codex was not found after installation. Reopen the terminal and rerun setup.'
  "$codex_cmd" --version || fail 'Codex installed but could not start.'
fi

printf '\n[3/4] Optional LaTeX for PDF generation\n'
printf 'A TeX Live installation can use substantial disk space.\n'
read -r -p 'Set up LaTeX for PDFs now? [y/N]: ' answer
case "$answer" in
  y|Y|yes|YES)
    if ! command -v pdflatex >/dev/null 2>&1; then
      case "$package_manager" in
        apt-get) install_packages texlive-latex-base texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-pictures ;;
        dnf) install_packages texlive-scheme-medium ;;
        pacman) install_packages texlive-basic texlive-latex texlive-latexrecommended texlive-latexextra texlive-fontsrecommended texlive-pictures ;;
        zypper) install_packages texlive-latex texlive-latex-recommended texlive-latex-extra texlive-fonts-recommended texlive-pictures ;;
      esac
    fi
    pdflatex --version >/dev/null || fail 'LaTeX cannot start.'
    for package in geometry.sty lmodern.sty fontenc.sty amsmath.sty amssymb.sty mathtools.sty xcolor.sty booktabs.sty float.sty microtype.sty tikz.sty fancyhdr.sty hyperref.sty; do
      kpsewhich "$package" >/dev/null || fail "Missing LaTeX package file: $package. Install the distribution package that provides it, then rerun setup."
    done
    printf 'LaTeX and the template packages are ready.\n'
    ;;
  *) printf 'Skipping LaTeX. HTML lessons and the core study commands still work.\n' ;;
esac

printf '\n[4/4] Workshop folder\n'
workshop_dir="$HOME/Codex-Workshop"
mkdir -p -- "$workshop_dir"
launcher="$workshop_dir/start-codex.sh"
if [[ ! -e "$launcher" && ! -L "$launcher" ]]; then
  {
    printf '#!/usr/bin/env bash\nset -e\n'
    printf 'cd -- %q\n' "$workshop_dir"
    printf 'exec %q "$@"\n' "$codex_cmd"
  } > "$launcher"
  chmod u+x "$launcher"
fi
printf '\nGit, Python, Node.js/npm and Codex are ready.\nWorkshop folder: %s\n' "$workshop_dir"
printf 'Reopen your terminal before using newly installed tools outside this setup.\n'
printf 'Open Codex later with: %q\n' "$launcher"
printf 'In Codex, sign in with ChatGPT and keep the default permissions.\n'
read -r -p 'Open Codex now? [Y/n]: ' answer
case "$answer" in n|N|no|NO) ;; *) cd -- "$workshop_dir"; "$codex_cmd" ;; esac
