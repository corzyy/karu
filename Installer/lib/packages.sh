#!/usr/bin/env bash
# packages.sh — Fedora dependency installation.

# COPR repositories that ship parts of the stack.
COPR_HYPRLAND="lionheartp/Hyprland"   # hyprland, quickshell, awww, hyprshot
COPR_NERDFONT="che/nerd-fonts"        # Symbols Nerd Font

# Everything the shell and the Hyprland session need that is not bundled.
# Keybind applications (terminal / file manager / browser) are intentionally
# left out — the binds still work once those are installed.
CORE_PKGS=(
    # Quickshell "Dynamic Island" runtime
    quickshell
    # Theme generation (Karu theme picker, matugen templates)
    matugen
    # Wallpaper daemon used by the Wallpapers tab
    awww
    # External-monitor brightness (ddcutil) + laptop backlight
    ddcutil
    brightnessctl
    # MPRIS media keys + Now Playing
    playerctl
    # Screenshots from the default keybinds
    hyprshot
    # The compositor itself
    hyprland
    # Audio for the Control Center + volume OSD
    pipewire
    pipewire-pulseaudio
    wireplumber
    # HTTP downloads for the Wallhaven browser
    curl
)

# Symbols Nerd Font (status icons, lock glyphs).
FONT_PKGS=(nerd-fonts)

pkg_ensure_plugins() {
    root_run dnf install -y dnf-plugins-core
}

pkg_enable_copr() {
    root_run dnf copr enable -y "$1"
}

pkg_install_core() {
    root_run dnf install -y --refresh "${CORE_PKGS[@]}"
}

pkg_install_fonts() {
    root_run dnf install -y --refresh "${FONT_PKGS[@]}"
    # Refresh the font cache so the symbols are immediately usable.
    root_run fc-cache -f
}

# True when every core package is already installed.
pkg_core_present() {
    local p
    for p in "${CORE_PKGS[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || return 1
    done
    return 0
}
