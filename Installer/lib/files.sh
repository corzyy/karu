#!/usr/bin/env bash
# files.sh — deploy the shell, Hyprland config, matugen templates and fonts.

# Move an existing directory aside, returning the backup path on stdout.
backup_dir() {
    local dir="$1"
    [ -e "$dir" ] || return 0
    local bak="${dir}.bak.$(date +%Y%m%d-%H%M%S)"
    mv "$dir" "$bak"
    printf '%s' "$bak"
}

# Copy a text file, rewriting the author's hard-coded home for the target user.
copy_subst() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    case "$src" in
        *.lua|*.conf|*.toml|*.css|*.sh|*.json|*.qml|*.js)
            sed "s|/home/jakob|$HOME|g" "$src" >"$dst"
            ;;
        *)
            cp -a "$src" "$dst"
            ;;
    esac
}

# Copy a directory tree of config files with home substitution.
copy_tree_subst() {
    local src="$1" dst="$2" f rel
    [ -d "$src" ] || return 0
    while IFS= read -r -d '' f; do
        rel="${f#"$src"/}"
        copy_subst "$f" "$dst/$rel"
    done < <(find "$src" -type f -print0)
}

# ── Karu shell ───────────────────────────────────────────────────────────────
deploy_shell() {
    if [ "$REPO_DIR" = "$KARU_DIR" ]; then
        return 0   # already installed in place
    fi
    [ -e "$KARU_DIR" ] && backup_dir "$KARU_DIR" >/dev/null
    mkdir -p "$KARU_DIR"
    cp -a "$REPO_DIR/." "$KARU_DIR/"
    rm -rf "$KARU_DIR/.git"
}

# Put the `karu` driver on PATH (symlink so a single source of truth remains).
deploy_bin() {
    local bin="$KARU_DIR/bin/karu"
    [ -f "$bin" ] || return 1
    chmod +x "$bin"
    mkdir -p "$BIN_DIR"
    ln -sfn "$bin" "$BIN_DIR/karu"
}

# ── Hyprland ─────────────────────────────────────────────────────────────────
deploy_hypr() {
    local src="$INSTALLER_DIR/hypr"
    [ -d "$src" ] || return 1
    [ -e "$HYPR_DIR" ] && backup_dir "$HYPR_DIR" >/dev/null
    mkdir -p "$HYPR_DIR"
    copy_tree_subst "$src" "$HYPR_DIR"
}

# ── Matugen (theming bridge) ─────────────────────────────────────────────────
deploy_matugen() {
    local src="$INSTALLER_DIR/matugen"
    [ -d "$src" ] || return 1
    [ -e "$MATUGEN_DIR" ] && backup_dir "$MATUGEN_DIR" >/dev/null
    mkdir -p "$MATUGEN_DIR"
    copy_tree_subst "$src" "$MATUGEN_DIR"
    chmod +x "$MATUGEN_DIR/post-hook-scripts/"*.sh 2>/dev/null || true
}

# ── Fonts ────────────────────────────────────────────────────────────────────
sfpro_installed() { fc-list 2>/dev/null | grep -qi 'SF Pro Display'; }

# Copy any SF Pro Display files the user already has lying around into the
# user font directory. The font is proprietary, so it is never bundled.
deploy_sfpro() {
    sfpro_installed && return 0
    mkdir -p "$FONT_DIR"
    local found=0 f
    for d in "$HOME/Downloads" "$FONT_DIR" "$HOME/.fonts"; do
        [ -d "$d" ] || continue
        while IFS= read -r -d '' f; do
            cp -f "$f" "$FONT_DIR/"
            found=1
        done < <(find "$d" -maxdepth 3 -type f \
            \( -iname 'SFPro*' -o -iname 'SF-Pro*' -o -iname 'SFPRO*' \) -print0 2>/dev/null)
    done
    if [ "$found" -eq 1 ]; then
        fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true
        sfpro_installed
    else
        return 1
    fi
}
