#!/usr/bin/env bash
# ShareTerminal installer - Linux + macOS
# Installs:
#   - ~/bin/shareterminal
#   - ~/bin/detach
# and wires PATH for bash & zsh when possible.

set -euo pipefail
IFS=$'\n\t'

BIN_DIR="$HOME/bin"
SCRIPT_NAME="shareterminal"
SCRIPT_PATH="$BIN_DIR/$SCRIPT_NAME"
DETACH_PATH="$BIN_DIR/detach"

info()  { printf '[INFO] %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

echo "=== ShareTerminal installer ==="
echo
echo "This will:"
echo "  - Create $BIN_DIR (if needed)"
echo "  - Install '$SCRIPT_NAME' and a 'detach' helper into that directory"
echo "  - Try to add $BIN_DIR to PATH in ~/.bashrc and ~/.zshrc"
echo "  - Optionally install tmux using sudo + your package manager"
echo
echo "You can safely re-run this script; it is idempotent."
echo

# Prompt: default YES on Enter. Read from /dev/tty so it works even when piped (curl | bash).
resp=""
if [[ -r /dev/tty ]]; then
  read -r -p "Proceed with installation? [Y/n] " resp </dev/tty || resp=""
  resp=${resp,,}
fi

# Only non-empty answers that are NOT y/yes abort.
if [[ -n "$resp" && ! "$resp" =~ ^(y|yes)$ ]]; then
  info "Installation aborted by user."
  exit 1
fi

########################################
# Ensure ~/bin exists
########################################
info "Ensuring $BIN_DIR exists..."
mkdir -p "$BIN_DIR"

########################################
# PATH wiring for bash / zsh
########################################
add_path_line='export PATH="$HOME/bin:$PATH"'
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

touch "$BASHRC"
if ! grep -Fq "$add_path_line" "$BASHRC"; then
  {
    echo ""
    echo "# Added by shareterminal installer"
    echo "$add_path_line"
  } >> "$BASHRC"
  info "Updated $BASHRC to include \$HOME/bin in PATH."
else
  info "$BASHRC already includes \$HOME/bin in PATH."
fi

if [[ -f "$ZSHRC" ]]; then
  if ! grep -Fq "$add_path_line" "$ZSHRC"; then
    {
      echo ""
      echo "# Added by shareterminal installer"
      echo "$add_path_line"
    } >> "$ZSHRC"
    info "Updated $ZSHRC to include \$HOME/bin in PATH."
  else
    info "$ZSHRC already includes \$HOME/bin in PATH."
  fi
fi

# Make sure this process sees it too
export PATH="$HOME/bin:$PATH"

########################################
# Ensure tmux is installed (Linux + macOS)
########################################
have_tmux=true
if ! command -v tmux >/dev/null 2>&1; then
  have_tmux=false
  warn "tmux is not installed. shareterminal depends on tmux."

  if command -v sudo >/dev/null 2>&1; then
    tmux_resp=""
    if [[ -r /dev/tty ]]; then
      read -r -p "Attempt to install tmux using sudo and your package manager? [Y/n] " tmux_resp </dev/tty || tmux_resp=""
      tmux_resp=${tmux_resp,,}
    fi

    # Default YES (Enter). Only explicit non-empty n/no/etc. means "no".
    if [[ -z "$tmux_resp" || "$tmux_resp" =~ ^(y|yes)$ ]]; then
      os="$(uname -s || echo unknown)"
      pm=""

      if   command -v apt-get >/dev/null 2>&1; then pm="apt-get"
      elif command -v apt     >/dev/null 2>&1; then pm="apt"
      elif command -v dnf     >/dev/null 2>&1; then pm="dnf"
      elif command -v yum     >/dev/null 2>&1; then pm="yum"
      elif command -v pacman  >/dev/null 2>&1; then pm="pacman"
      elif command -v apk     >/dev/null 2>&1; then pm="apk"
      elif command -v zypper  >/dev/null 2>&1; then pm="zypper"
      elif [[ "$os" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then pm="brew"
      fi

      if [[ -z "$pm" ]]; then
        warn "No known package manager found. Please install tmux manually."
      else
        info "Detected package manager: $pm"
        case "$pm" in
          apt|apt-get)
            sudo "$pm" update
            sudo "$pm" install -y tmux
            ;;
          dnf|yum|zypper)
            sudo "$pm" install -y tmux
            ;;
          pacman)
            sudo "$pm" -Sy --noconfirm tmux
            ;;
          apk)
            sudo "$pm" add tmux
            ;;
          brew)
            # Homebrew usually does NOT use sudo
            brew install tmux
            ;;
          *)
            warn "Installer does not know how to use $pm for tmux. Please install tmux manually."
            ;;
        esac

        if command -v tmux >/dev/null 2>&1; then
          have_tmux=true
          info "tmux installed: $(tmux -V)"
        else
          warn "tmux still not found after attempted installation."
        fi
      fi
    else
      warn "Skipped tmux installation. You must install tmux manually before using shareterminal."
    fi
  else
    warn "sudo not available; please install tmux manually using your OS package manager."
  fi
else
  info "tmux already installed: $(tmux -V)"
fi

########################################
# Install shareterminal runtime script
########################################
info "Installing $SCRIPT_NAME to $SCRIPT_PATH ..."

cat > "$SCRIPT_PATH" <<'EOF'
#!/usr/bin/env bash
# shareterminal: start/join a shared tmux session via a shared socket.
# Works with Linux + macOS as long as tmux is installed.

set -euo p
