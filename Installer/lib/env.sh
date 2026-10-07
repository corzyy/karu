#!/usr/bin/env bash
# env.sh — environment detection and privilege helpers.

# Resolve the repository root (the installer lives in <repo>/Installer).
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$INSTALLER_DIR/.." && pwd)"

# Where the shell and its configs go (overridable, matching bin/karu).
KARU_DIR="${KARU_CONFIG:-$HOME/.config/karu}"
HYPR_DIR="$HOME/.config/hypr"
MATUGEN_DIR="$HOME/.config/matugen"
BIN_DIR="$HOME/.local/bin"
FONT_DIR="$HOME/.local/share/fonts"

# Sudo command prefix — filled in by setup_privileges.
SUDO=()

have() { command -v "$1" >/dev/null 2>&1; }

os_id() { . /etc/os-release 2>/dev/null; printf '%s' "${ID:-unknown}"; }
os_pretty() { . /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}"; }

# Populate SUDO, prompting up-front so the TUI is not interrupted mid-run.
setup_privileges() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=()
        return 0
    fi
    if ! have sudo; then
        msg_err "'sudo' not found and not running as root."
        return 1
    fi
    msg_dim "Authenticating (sudo)…"
    if ! sudo -v; then
        msg_err "sudo authentication failed."
        return 1
    fi
    SUDO=(sudo)
    # Keep the sudo timestamp alive for the duration of the install.
    ( while true; do sudo -n true >/dev/null 2>&1 || exit; sleep 50; done ) &
    SUDO_KEEPALIVE=$!
    return 0
}

# Run a command as root, echoing it into the log.
root_run() {
    { printf '\n$ %s\n' "$*"; } >>"$LOG" 2>&1
    "${SUDO[@]}" "$@" >>"$LOG" 2>&1
}

# Initialise the run log.
log_init() {
    LOG="$(mktemp -t karu-install.XXXXXX.log)"
    {
        printf 'Karu installer log\n'
        printf 'date:    %s\n' "$(date -Is)"
        printf 'os:      %s\n' "$(os_pretty)"
        printf 'user:    %s (uid %s)\n' "$(id -un)" "$(id -u)"
        printf 'repo:    %s\n' "$REPO_DIR"
        printf 'target:  %s\n' "$KARU_DIR"
    } >"$LOG"
}

# Disable the sudo keepalive if it was started.
stop_privileges() {
    [ -n "${SUDO_KEEPALIVE:-}" ] && kill "$SUDO_KEEPALIVE" 2>/dev/null || true
}
