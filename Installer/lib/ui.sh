#!/usr/bin/env bash
# ui.sh — a tiny true-colour ANSI TUI toolkit.
#
# The palette and shapes mirror the Karu island: OLED-dark surfaces, the
# Material-3 blue taken from the shell's own colour scheme, rounded pills and a
# three-dot workspace motif. Everything here is pure bash + ANSI escapes, so the
# installer needs no dialog / whiptail / gum.
#
# It is meant to be sourced, never executed:
#   source "$(dirname "$0")/lib/ui.sh"

# ── Palette (Material 3 dark, matching core/theme/Colors.qml) ────────────────
C_BG='17;20;24'          # #111418  surface
C_SURFACE='29;32;36'     # #1d2024  surface_container
C_SURFACE_HI='39;42;47'  # #272a2f  surface_container_high
C_SURFACE_LOW='25;28;32' # #191c20  surface_container_low
C_PRIMARY='162;201;254'  # #a2c9fe
C_SECONDARY='187;199;219'
C_TERTIARY='216;189;228'
C_OUTLINE='141;145;153'
C_TEXT='225;226;232'
C_DIM='124;128;136'
C_OK='166;227;161'
C_WARN='249;226;175'
C_ERR='255;180;171'

R=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'

# ── Output primitives ────────────────────────────────────────────────────────
fg()  { printf '\033[38;2;%sm' "$1"; }
bgc() { printf '\033[48;2;%sm' "$1"; }
clear_line() { printf '\r\033[K'; }
move_up() { printf '\033[%dA' "$1"; }
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Restore the terminal no matter how we exit.
ui_clean() {
    show_cursor
    printf '%s' "$R"
    stty echo 2>/dev/null || true
}
trap 'ui_clean' EXIT INT TERM

cols() { local c; c=$(tput cols 2>/dev/null || echo 80); [ "$c" -lt 60 ] && c=60; printf '%s' "$c"; }
rows() { local r; r=$(tput lines 2>/dev/null || echo 24); printf '%s' "$r"; }

# Repeat a single character n times.
rep() { local n=$1 ch=$2 out=''; while [ "$n" -gt 0 ]; do out+="$ch"; n=$((n-1)); done; printf '%s' "$out"; }

# Visual width of a string, ignoring ANSI SGR sequences and counting the
# multibyte glyphs we use as width 1.
vislen() {
    local s="$1"
    s=$(printf '%s' "$s" | sed -E 's/\x1b\[[0-9;]*m//g')
    printf '%s' "${#s}"
}

# Pad a (possibly coloured) string to a visible width, filling with spaces.
pad_to() {
    local s="$1" want="$2" len pad
    len=$(vislen "$s")
    pad=$(( want - len ))
    [ "$pad" -lt 0 ] && pad=0
    printf '%s%s' "$s" "$(rep "$pad" ' ')"
}

# ── Chrome ───────────────────────────────────────────────────────────────────
clear_screen() { printf '\033[2J\033[H'; }

# The header: a Karu-style pill with the workspace dots, the wordmark and a
# little status cluster, sized to the terminal (capped so it stays tidy).
banner() {
    local w total inner left word right
    w=$(cols)
    total=$(( w > 74 ? 74 : w - 3 ))
    [ "$total" -lt 46 ] && total=46
    inner=$(( total - 2 ))

    left="  ● ● ●"
    word="K A R U"
    right="installer  "

    local avail=$(( inner - ${#left} - ${#right} - ${#word} ))
    [ "$avail" -lt 2 ] && avail=2
    local lpad=$(( (avail) / 2 ))
    local rpad=$(( avail - lpad ))
    [ "$lpad" -lt 1 ] && lpad=1
    [ "$rpad" -lt 1 ] && rpad=1

    local content
    content="$(fg "$C_PRIMARY")${left}$(fg "$C_TEXT")${BOLD}$(rep "$lpad" ' ')${word}$(rep "$rpad" ' ')$(fg "$C_DIM")${right}${R}"

    printf '\n'
    printf '   %s╭%s╮%s\n' "$(fg "$C_OUTLINE")" "$(rep "$inner" '─')" "$R"
    printf '   %s│%s%s%s│%s\n' "$(fg "$C_OUTLINE")" "$content" "$R" "$(fg "$C_OUTLINE")" "$R"
    printf '   %s╰%s╯%s\n' "$(fg "$C_OUTLINE")" "$(rep "$inner" '─')" "$R"
}

# A dim subtitle line under the banner.
subtitle() { printf '   %s%s%s\n' "$(fg "$C_DIM")" "$1" "$R"; }

# A section heading with a short accent rule.
section() {
    printf '\n   %s%s%s\n' "$(fg "$C_PRIMARY")$BOLD" "$1" "$R"
    printf '   %s%s%s\n' "$(fg "$C_SURFACE_HI")" "$(rep 3 '─')" "$R"
}

# Message helpers — each indents to the content column and prefixes a glyph.
msg()     { printf '   %s%s%s %s\n' "$(fg "$2")" "$1" "$R" "$3"; }
msg_info(){ msg '·' "$C_SECONDARY" "$1"; }
msg_ok()  { msg '✓' "$C_OK" "$1"; }
msg_warn(){ msg '!' "$C_WARN" "$1"; }
msg_err() { msg '✗' "$C_ERR" "$1"; }
msg_dim() { printf '   %s%s%s\n' "$(fg "$C_DIM")" "$1" "$R"; }

# ── Input ────────────────────────────────────────────────────────────────────
# Read a single key from the controlling terminal. Arrow keys arrive as the
# three-byte ESC sequence and are returned whole ("\x1b[A" etc). Enter returns
# the empty string; Space returns " ".
read_key() {
    local k rest
    IFS= read -rsn1 k </dev/tty
    if [ "$k" = $'\x1b' ]; then
        IFS= read -rsn2 -t 0.01 rest </dev/tty || true
        printf '%s' "$k$rest"
    else
        printf '%s' "$k"
    fi
}

# One-line text prompt on the terminal.
ask() {
    local prompt="$1" default="${2:-}" answer
    printf '   %s%s%s' "$(fg "$C_TEXT")" "$prompt" "$R"
    [ -n "$default" ] && printf ' %s[%s]%s' "$(fg "$C_DIM")" "$default" "$R"
    printf ' '
    IFS= read -r answer </dev/tty || answer=""
    [ -z "$answer" ] && answer="$default"
    printf '%s' "$answer"
}

# Yes/No prompt. Defaults to No.
confirm() {
    local prompt="$1" answer
    printf '   %s?%s %s %s[y/N]%s ' "$(fg "$C_WARN")" "$R" "$prompt" "$(fg "$C_DIM")" "$R"
    IFS= read -r answer </dev/tty || answer=""
    printf '\n'
    case "$answer" in [yY]|[yY][eE][sS]) return 0 ;; *) return 1 ;; esac
}

pause() {
    if [ "${UI_ASSUME_YES:-0}" -eq 1 ]; then printf '\n'; return 0; fi
    printf '\n   %s%s%s' "$(fg "$C_DIM")" "${1:-Press any key to continue}" "$R"
    read_key >/dev/null
    printf '\n'
}

# ── Menus ────────────────────────────────────────────────────────────────────
# menu "Title" "opt1" "opt2" ...  →  sets REPLY to the chosen index.
# Arrow keys / j / k move, Enter selects.
menu() {
    local title="$1"; shift
    local -a items=("$@")
    local n=${#items[@]} sel=0 i line
    [ "$n" -eq 0 ] && { REPLY=0; return; }

    draw_menu() {
        local idx
        for idx in $(seq 0 $((n-1))); do
            clear_line
            if [ "$idx" -eq "$sel" ]; then
                printf '   %s▍%s %s%s%s%s\n' \
                    "$(fg "$C_PRIMARY")" "$R" \
                    "$(bgc "$C_SURFACE_HI")$(fg "$C_TEXT")$BOLD" "${items[$idx]}" "$R" ''
            else
                printf '   %s\n' "$(fg "$C_DIM")${items[$idx]}  $R"
            fi
        done
    }

    section "$title"
    printf '\n'
    draw_menu

    while true; do
        local key; key=$(read_key)
        case "$key" in
            $'\x1b[A'|k) sel=$(( (sel - 1 + n) % n )) ;;
            $'\x1b[B'|j) sel=$(( (sel + 1) % n )) ;;
            '') break ;;
            q|Q) sel=-1; break ;;
        esac
        move_up "$n"
        draw_menu
    done
    REPLY=$sel
}

# checkbox "Title" "on:label" ...  →  sets REPLY to the same list with the
# leading "on:" / "off:" toggled. Space flips, arrows move, Enter accepts.
checkbox() {
    local title="$1"; shift
    local -a items=("$@")
    local n=${#items[@]} sel=0 i
    [ "$n" -eq 0 ] && { REPLY=""; return; }

    draw_check() {
        local idx state label
        for idx in $(seq 0 $((n-1))); do
            clear_line
            state="${items[$idx]%%:*}"
            label="${items[$idx]#*:}"
            local box glyph color
            if [ "$state" = "on" ]; then box='◼'; color="$C_PRIMARY"; else box='◻'; color="$C_DIM"; fi
            if [ "$idx" -eq "$sel" ]; then
                printf '   %s▍%s %s%s%s %s%s%s\n' \
                    "$(fg "$C_PRIMARY")" "$R" \
                    "$(fg "$color")" "$box" "$R" \
                    "$(bgc "$C_SURFACE_HI")$(fg "$C_TEXT")$BOLD" "$label" "$R"
            else
                printf '   %s%s%s %s%s%s\n' \
                    "$(fg "$color")" "$box" "$R" \
                    "$(fg "$C_DIM")" "$label" "$R"
            fi
        done
    }

    section "$title"
    printf '   %s%s%s\n' "$(fg "$C_DIM")" 'space toggles · ↑/↓ move · enter to continue' "$R"
    printf '\n'
    draw_check

    while true; do
        local key; key=$(read_key)
        case "$key" in
            $'\x1b[A'|k) sel=$(( (sel - 1 + n) % n )) ;;
            $'\x1b[B'|j) sel=$(( (sel + 1) % n )) ;;
            ' ')
                local state="${items[$sel]%%:*}" label="${items[$sel]#*:}"
                if [ "$state" = "on" ]; then items[$sel]="off:$label"; else items[$sel]="on:$label"; fi
                ;;
            '') break ;;
        esac
        move_up "$n"
        draw_check
    done

    # Hand back a newline-delimited "on:.../off:..." list so labels may contain
    # spaces without the caller losing them to word splitting.
    REPLY="$(printf '%s\n' "${items[@]}")"
}

# ── Long-running steps ───────────────────────────────────────────────────────
# run_step "Label" cmd args...  →  runs the command with a spinner, appending
# its output to $LOG. Returns the command's exit status.
run_step() {
    local label="$1"; shift
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local pid idx=0 rc
    "$@" >>"$LOG" 2>&1 &
    pid=$!
    hide_cursor
    while kill -0 "$pid" 2>/dev/null; do
        printf '\r\033[K   %s%s%s %s' "$(fg "$C_PRIMARY")" "${frames:idx:1}" "$R" "$label"
        idx=$(( (idx + 1) % 10 ))
        sleep 0.07
    done
    wait "$pid"; rc=$?
    show_cursor
    if [ "$rc" -eq 0 ]; then
        printf '\r\033[K   %s✓%s %s\n' "$(fg "$C_OK")" "$R" "$label"
    else
        printf '\r\033[K   %s✗%s %s\n' "$(fg "$C_ERR")" "$R" "$label"
    fi
    return "$rc"
}
