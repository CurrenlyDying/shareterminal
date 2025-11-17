#!/usr/bin/env bash
# ShareTerminal installer - Linux + macOS
# Installs:
#   - ~/bin/shareterminal
#   - ~/bin/detach
# and wires PATH for bash & zsh when possible.
# Also auto-installs tmux (with confirmation) on common Linux distros and macOS.

set -euo pipefail
IFS=$'\n\t'

BIN_DIR="$HOME/bin"
SCRIPT_NAME="shareterminal"
SCRIPT_PATH="$BIN_DIR/$SCRIPT_NAME"
DETACH_PATH="$BIN_DIR/detach"

BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"

info()  { printf '[INFO] %s\n' "$*"; }
warn()  { printf '[WARN] %s\n' "$*" >&2; }
error() { printf '[ERROR] %s\n' "$*" >&2; }

# Ask a yes/no question, defaulting to YES on empty input.
# Usage: if ask_yes_no "Prompt [Y/n]"; then ...; fi
ask_yes_no() {
  local prompt="$1"
  local default_yes="${2:-yes}"
  local ans=""

  if [[ -r /dev/tty ]]; then
    # Read from controlling terminal so it works even with curl | bash
    read -r -p "$prompt " ans </dev/tty || ans=""
  else
    ans=""
  fi

  ans=${ans,,}

  # Empty input -> use default
  if [[ -z "$ans" ]]; then
    [[ "$default_yes" == "yes" ]] && return 0 || return 1
  fi

  [[ "$ans" =~ ^(y|yes)$ ]]
}

echo "=== ShareTerminal installer ==="
echo
echo "This will:"
echo "  - Create $BIN_DIR (if needed)"
echo "  - Install 'shareterminal' and a 'detach' helper into that directory"
echo "  - Try to add $BIN_DIR to PATH in ~/.bashrc and ~/.zshrc"
echo "  - Optionally auto-install tmux using your package manager (Linux/macOS)"
echo
echo "You can safely re-run this script; it is idempotent."
echo

########################################
# Confirm install (Y/n), default = YES
########################################
if ! ask_yes_no "Proceed with installation? [Y/n]" yes; then
  info "Installation aborted by user."
  exit 0
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

# Make sure .bashrc exists so grep doesn't explode
if [[ ! -f "$BASHRC" ]]; then
  touch "$BASHRC"
fi

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
# Ensure tmux is installed (auto-install if you agree)
########################################
if ! command -v tmux >/dev/null 2>&1; then
  warn "tmux is not installed. shareterminal depends on tmux."

  if ! command -v sudo >/dev/null 2>&1; then
    warn "sudo is not available; cannot auto-install tmux."
    warn "Please install tmux manually using your package manager."
  else
    if ask_yes_no "Attempt to install tmux using sudo and your package manager? [Y/n]" yes; then
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
        warn "No supported package manager found. Please install tmux manually."
      else
        info "Detected package manager: $pm"

        case "$pm" in
          apt|apt-get)
            if ! sudo "$pm" update || ! sudo "$pm" install -y tmux; then
              warn "Failed to install tmux via $pm. Please install it manually."
            fi
            ;;
          dnf|yum|zypper)
            if ! sudo "$pm" install -y tmux; then
              warn "Failed to install tmux via $pm. Please install it manually."
            fi
            ;;
          pacman)
            if ! sudo "$pm" -Sy --noconfirm tmux; then
              warn "Failed to install tmux via pacman. Please install it manually."
            fi
            ;;
          apk)
            if ! sudo "$pm" add tmux; then
              warn "Failed to install tmux via apk. Please install it manually."
            fi
            ;;
          brew)
            # Homebrew usually does NOT use sudo
            if ! brew install tmux; then
              warn "Failed to install tmux via brew. Please install it manually."
            fi
            ;;
          *)
            warn "Installer does not know how to use $pm for tmux. Please install tmux manually."
            ;;
        esac

        if command -v tmux >/dev/null 2>&1; then
          info "tmux installed: $(tmux -V)"
        else
          warn "tmux still not found after attempted installation. shareterminal will not work until tmux is installed."
        fi
      fi
    else
      warn "Skipped tmux auto-install. You must install tmux manually before using shareterminal."
    fi
  fi
else
  info "tmux already installed: $(tmux -V)"
fi

########################################
# Install shareterminal runtime script
########################################
info "Installing $SCRIPT_NAME to $SCRIPT_PATH ..."

cat > "$SCRIPT_PATH" << 'EOF'
#!/usr/bin/env bash
# shareterminal: start/join a shared tmux session via a shared socket.
# Works with Linux + macOS as long as tmux is installed.

set -euo pipefail
IFS=$'\n\t'

SOCKET_PATH="/tmp/shared_tmux"

if ! command -v tmux >/dev/null 2>&1; then
  echo "[ERROR] tmux is not installed or not in PATH."
  echo "        Install tmux (e.g., with your package manager) and try again."
  exit 1
fi

printf "Enter tmux session name [default: naier]: "
read -r SESSION_NAME
if [[ -z "$SESSION_NAME" ]]; then
  SESSION_NAME="naier"
fi

echo "Using session name: '$SESSION_NAME'"
echo "Socket path: $SOCKET_PATH"

SOCKET_DIR="$(dirname "$SOCKET_PATH")"
if [[ ! -d "$SOCKET_DIR" ]]; then
  echo "[INFO] Creating socket directory: $SOCKET_DIR"
  mkdir -p "$SOCKET_DIR"
fi

# Warn when already in a tmux session
if [[ -n "${TMUX-}" ]]; then
  echo "[WARN] You are already inside a tmux session."
  echo "       Typing 'exit' in the LAST pane will kill the session for everyone."
  echo "       Use Ctrl-b then d, or type 'detach', to leave safely."
fi

session_exists=false
if tmux -S "$SOCKET_PATH" has-session -t "$SESSION_NAME" 2>/dev/null; then
  session_exists=true
fi

if [[ "$session_exists" == false ]]; then
  echo "[INFO] Session '$SESSION_NAME' does not exist — creating now..."
  tmux -S "$SOCKET_PATH" new -s "$SESSION_NAME" -d

  chmod 777 "$SOCKET_PATH"
  echo "[INFO] Socket permissions set to 777 (any user on this machine can join)."
  echo "[INFO] Session created."
else
  echo "[INFO] Session '$SESSION_NAME' already exists."
fi

# Force message display-time to 5s (5000 ms) for this tmux server and session.
tmux -S "$SOCKET_PATH" set-option -g display-time 5000 || true
tmux -S "$SOCKET_PATH" set-option -t "$SESSION_NAME" display-time 5000 2>/dev/null || true

# Broadcast JOIN to all *existing* clients (the new one isn't attached yet)
existing_clients="$(tmux -S "$SOCKET_PATH" list-clients -t "$SESSION_NAME" -F '#{client_name}' 2>/dev/null || true)"

if [[ -n "$existing_clients" ]]; then
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    tmux -S "$SOCKET_PATH" display-message -c "$c" "[JOIN] Another client is joining '$SESSION_NAME'"
  done <<< "$existing_clients"
fi

echo
echo "Inside tmux, remember:"
echo "  - To DETACH (leave session running):"
echo "        Ctrl-b then d      (native tmux detach)"
echo "        or: detach         (helper command installed by this script)"
echo "  - Avoid typing 'exit' in the last pane — that kills the shared session for everyone."
echo

echo "[INFO] Attaching to session '$SESSION_NAME'..."
tmux -S "$SOCKET_PATH" attach -t "$SESSION_NAME"
EOF

########################################
# Install 'detach' helper
########################################
info "Installing 'detach' helper to $DETACH_PATH ..."

cat > "$DETACH_PATH" << 'EOF'
#!/usr/bin/env bash
# detach: convenience wrapper to detach from current tmux session safely,
# and broadcast a LEAVE message to all attached clients.

set -euo pipefail
IFS=$'\n\t'

if ! command -v tmux >/dev/null 2>&1; then
  echo "[ERROR] tmux is not installed or not in PATH."
  exit 1
fi

if [[ -z "${TMUX-}" ]]; then
  echo "[WARN] You are not inside a tmux session; nothing to detach from."
  exit 0
fi

# Current session name
SESSION_NAME="$(tmux display-message -p '#S' 2>/dev/null || echo '?')"

# List all clients attached to this session
clients="$(tmux list-clients -t "$SESSION_NAME" -F '#{client_name}' 2>/dev/null || true)"

if [[ -n "$clients" ]]; then
  while IFS= read -r c; do
    [[ -z "$c" ]] && continue
    tmux display-message -c "$c" "[LEAVE] A client detached from '$SESSION_NAME'"
  done <<< "$clients"
fi

# Now actually detach this client
tmux detach
EOF

########################################
# Make scripts executable
########################################
chmod +x "$SCRIPT_PATH" "$DETACH_PATH"

########################################
# Final notes
########################################
cat << 'EONOTE'

==============================================
ShareTerminal installation complete ✅
==============================================

Commands installed:
  - shareterminal  → start/join a shared tmux session via /tmp/shared_tmux
  - detach         → detach from the current tmux session safely

To start sharing:
  1. Run:  shareterminal
  2. Press ENTER to accept default session "naier" or type another name.
  3. Give the same command + session name to your friend on the same host.

Join/leave announcements:
  - When someone joins, all existing clients see:
        [JOIN] Another client is joining 'SESSION'
  - When someone runs 'detach', all remaining clients see:
        [LEAVE] A client detached from 'SESSION'

Messages use:
  - display-time = 5000 ms (5 seconds), so notifications stick around long enough.

To leave without killing it for everyone:
  - Use Ctrl-b then d        (standard tmux detach)
  - Or run: detach

If you see "command not found" for shareterminal:
  - Close and reopen your terminal, OR
  - Run: source ~/.bashrc    (or: source ~/.zshrc)

Security note:
  - The socket /tmp/shared_tmux is chmod 777 so any user on this machine
    can join the shared session. Only use this on machines and accounts
    you trust.

EONOTE

info "All done."
