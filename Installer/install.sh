#!/usr/bin/env bash
#
# Karu installer — a small true-colour TUI that sets up the Karu Quickshell
# "Dynamic Island" together with the Hyprland + matugen desktop it is built for.
#
#   ./install.sh            interactive TUI
#   ./install.sh --yes      accept defaults and run unattended
#   ./install.sh --help     show usage
#
# The script is intentionally dependency-free: everything is plain bash and
# ANSI escapes, styled to match the shell it installs.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# ── Bootstrap (curl … | bash) ────────────────────────────────────────────────
# The installer needs the scripts in lib/ and the bundled configs next to it.
# When this file is piped in on its own (the one-line curl install), fetch the
# repository into a temp dir and re-run the full installer from there.
if [ ! -f "$HERE/lib/ui.sh" ]; then
    _tarball="${KARU_INSTALL_TARBALL:-https://github.com/corzyy/karu/archive/refs/heads/main.tar.gz}"
    _tmp="$(mktemp -d)"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$_tarball" | tar -xz -C "$_tmp" || { printf 'karu: download failed\n' >&2; exit 1; }
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$_tarball" | tar -xz -C "$_tmp" || { printf 'karu: download failed\n' >&2; exit 1; }
    else
        printf 'karu: curl or wget is required\n' >&2
        exit 1
    fi
    exec bash "$_tmp/karu-main/Installer/install.sh" "$@"
fi

# shellcheck source=lib/ui.sh
source "$HERE/lib/ui.sh"
# shellcheck source=lib/env.sh
source "$HERE/lib/env.sh"
# shellcheck source=lib/packages.sh
source "$HERE/lib/packages.sh"
# shellcheck source=lib/files.sh
source "$HERE/lib/files.sh"

ASSUME_YES=0
FAILED=0

usage() {
    cat <<'EOF'
Karu installer

Usage:
  ./install.sh [options]

Options:
  -y, --yes     Run unattended: install every component to the defaults.
  -h, --help    Show this help.

Components (chosen in the TUI):
  · dependencies  quickshell, hyprland, matugen, awww, ddcutil,
                  brightnessctl, playerctl, hyprshot, Nerd Font symbols …
  · the Karu shell (installed to ~/.config/karu, driver on ~/.local/bin)
  · the Hyprland config (installed to ~/.config/hypr, existing one backed up)
  · matugen templates (installed to ~/.config/matugen)
  · SF Pro Display (copied from your Downloads if present)

Logs are written to a temp file; the path is printed at the end.
EOF
}

need_tty() {
    if [ ! -e /dev/tty ] && [ "$ASSUME_YES" -eq 0 ]; then
        msg_err 'No terminal available. Re-run with --yes for unattended mode.'
        exit 1
    fi
}

# ── Screens ──────────────────────────────────────────────────────────────────
splash() {
    clear_screen
    banner
    subtitle "$(os_pretty)  ·  $(id -un)  ·  $(date '+%Y-%m-%d')"

    section "Welcome"
    msg_dim "This will set up the Karu Dynamic Island and the Hyprland desktop"
    msg_dim "it was designed for — configs, dependencies and theming."

    section "Environment"
    if [ "$(os_id)" = "fedora" ]; then
        msg_ok "Fedora detected"
    else
        msg_warn "Not Fedora ($(os_id)) — package steps may not work"
    fi
    have qs         && msg_ok "quickshell already installed"       || msg_info "quickshell will be installed"
    have Hyprland   && msg_ok "Hyprland already installed"         || msg_info "Hyprland will be installed"
    have matugen    && msg_ok "matugen already installed"          || msg_info "matugen will be installed"
    [ -n "${WAYLAND_DISPLAY:-}" ] && msg_ok "Wayland session active" || msg_info "No Wayland session right now"

    printf '\n'
    msg_dim "log: $LOG"
    pause "Press any key to begin…"
}

choose_components() {
    clear_screen
    banner
    subtitle "step 1 of 2  ·  choose what to install"

    local choices=(
        "on:Dependencies  ·  dnf + COPR"
        "on:The Karu shell"
        "on:Hyprland config"
        "on:matugen theme templates"
        "on:Nerd Font symbols"
        "on:SF Pro Display (copy if found)"
    )

    if [ "$ASSUME_YES" -eq 1 ]; then
        REPLY="$(printf '%s\n' "${choices[@]}")"
    else
        checkbox "Components" "${choices[@]}"
    fi

    # Default everything on, then apply the returned states.
    WANT_DEPS=1; WANT_SHELL=1; WANT_HYPR=1; WANT_MATUGEN=1; WANT_NERD=1; WANT_SFPRO=1
    local i=0 line state
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        state="${line%%:*}"
        [ "$state" = "off" ] || { i=$((i+1)); continue; }
        case "$i" in
            0) WANT_DEPS=0 ;;
            1) WANT_SHELL=0 ;;
            2) WANT_HYPR=0 ;;
            3) WANT_MATUGEN=0 ;;
            4) WANT_NERD=0 ;;
            5) WANT_SFPRO=0 ;;
        esac
        i=$((i+1))
    done <<<"$REPLY"
}

confirm_run() {
    clear_screen
    banner
    subtitle "step 2 of 2  ·  confirm"

    section "Summary"
    [ "$WANT_DEPS"   -eq 1 ] && msg_ok "Install dependencies (dnf + COPR)" || msg_dim "· skip dependencies"
    [ "$WANT_NERD"   -eq 1 ] && msg_ok "Install Nerd Font symbols"         || msg_dim "· skip Nerd Font"
    if [ "$WANT_SHELL" -eq 1 ]; then msg_ok "Install Karu shell  →  $KARU_DIR"; else msg_dim "· skip shell"; fi
    if [ "$WANT_HYPR"  -eq 1 ]; then msg_ok "Install Hyprland    →  $HYPR_DIR"; elif [ "$WANT_SHELL" -eq 1 ]; then msg_warn "Hyprland config not selected"; fi
    if [ "$WANT_MATUGEN" -eq 1 ]; then msg_ok "Install matugen     →  $MATUGEN_DIR"; fi
    [ "$WANT_SFPRO" -eq 1 ] && msg_info "SF Pro Display: copy if found"

    printf '\n'
    msg_dim "Existing ~/.config/karu, ~/.config/hypr and ~/.config/matugen are"
    msg_dim "moved aside (…bak.<timestamp>) before anything is written."
    printf '\n'

    if [ "$WANT_DEPS" -eq 1 ]; then
        msg_dim "Dependencies are installed system-wide and will ask for sudo."
        printf '\n'
    fi

    if [ "$ASSUME_YES" -eq 1 ]; then return 0; fi
    confirm "Proceed with the installation?" || { msg_warn "Cancelled."; exit 0; }
}

# ── Installation ─────────────────────────────────────────────────────────────
run_install() {
    clear_screen
    banner
    subtitle "installing…"

    if [ "$WANT_DEPS" -eq 1 ] || [ "$WANT_NERD" -eq 1 ]; then
        section "Privileges"
        setup_privileges || { msg_err "Cannot continue without root."; exit 1; }
        msg_ok "Ready"
    fi

    if [ "$WANT_DEPS" -eq 1 ]; then
        section "Dependencies"
        run_step "Installing dnf plugins"        pkg_ensure_plugins                    || FAILED=$((FAILED+1))
        run_step "Enabling $COPR_HYPRLAND"       pkg_enable_copr "$COPR_HYPRLAND"      || FAILED=$((FAILED+1))
        run_step "Installing core packages"      pkg_install_core                      || FAILED=$((FAILED+1))
    fi

    if [ "$WANT_NERD" -eq 1 ]; then
        section "Fonts"
        run_step "Enabling $COPR_NERDFONT"       pkg_enable_copr "$COPR_NERDFONT"      || FAILED=$((FAILED+1))
        run_step "Installing Symbols Nerd Font"  pkg_install_fonts                     || FAILED=$((FAILED+1))
    fi

    if [ "$WANT_SHELL" -eq 1 ] || [ "$WANT_HYPR" -eq 1 ] || [ "$WANT_MATUGEN" -eq 1 ]; then
        section "Configuration"
    fi

    if [ "$WANT_SHELL" -eq 1 ]; then
        if [ "$REPO_DIR" = "$KARU_DIR" ]; then
            msg_info "Karu already lives at $KARU_DIR"
            run_step "Linking the karu command" deploy_bin || FAILED=$((FAILED+1))
        else
            run_step "Installing Karu shell"      deploy_shell                          || FAILED=$((FAILED+1))
            run_step "Linking the karu command"   deploy_bin                            || FAILED=$((FAILED+1))
        fi
    fi

    if [ "$WANT_HYPR" -eq 1 ]; then
        run_step "Installing Hyprland config"     deploy_hypr                           || FAILED=$((FAILED+1))
    fi

    if [ "$WANT_MATUGEN" -eq 1 ]; then
        run_step "Installing matugen templates"   deploy_matugen                        || FAILED=$((FAILED+1))
    fi

    if [ "$WANT_SFPRO" -eq 1 ]; then
        section "SF Pro Display"
        if sfpro_installed; then
            msg_ok "Already installed"
        elif deploy_sfpro; then
            msg_ok "Installed"
        else
            msg_warn "Not found — the shell will fall back to your system font"
            msg_dim "Drop the SF Pro Display OTFs into $FONT_DIR and run 'fc-cache -f'"
        fi
    fi
}

summary() {
    printf '\n'
    if [ "$FAILED" -eq 0 ]; then
        section "Done"
        msg_ok "Everything installed successfully."
    else
        section "Finished with $FAILED problem(s)"
        msg_warn "Some steps failed — see the log:"
        msg_dim "$LOG"
        printf '\n'
        msg_dim "Last lines:"
        tail -n 12 "$LOG" 2>/dev/null | sed 's/^/     /'
    fi

    section "Next steps"
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) msg_warn "$BIN_DIR is not on your PATH — add it to use the 'karu' command" ;;
    esac
    if [ "$WANT_HYPR" -eq 1 ] && have Hyprland && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        msg_info "Reload the running Hyprland session:   hyprctl reload"
    fi
    msg_info "Start the shell:                       karu start"
    msg_info "Open the launcher (SUPER + Space) once the shell is up"
    if [ "$WANT_HYPR" -eq 1 ]; then
        msg_info "Log out and back in to load the Hyprland config if it was not running"
    fi

    printf '\n'
    msg_dim "Full log: $LOG"
    printf '\n'
    pause "Press any key to exit…"
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes) ASSUME_YES=1 ;;
            -h|--help) usage; exit 0 ;;
            *) msg_err "Unknown option: $1"; usage; exit 1 ;;
        esac
        shift
    done

    log_init
    UI_ASSUME_YES=$ASSUME_YES
    need_tty
    splash
    choose_components
    confirm_run
    run_install
    stop_privileges
    summary
}

main "$@"
