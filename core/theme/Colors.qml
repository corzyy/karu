pragma Singleton

import QtQuick

/**
 * Colors — the active semantic palette.
 *
 * `Theme.qml` binds every colour it exposes to a property here, so writing a new
 * palette into this object re-themes the whole island at once. `Themes.qml` is
 * what normally writes it: it runs Matugen against a seed colour (or the current
 * wallpaper) and hands the resulting Material scheme to `applyMatugen()`.
 *
 * The values below are the fallback palette. They are used until a theme is
 * applied and if Matugen is missing or fails, so the shell always looks the same
 * out of the box.
 */
QtObject {
    id: colors

    // ── Base surfaces ────────────────────────────────────────────────────────
    // `background` is the island itself (and therefore every panel). It is
    // intentionally fully opaque so the expanded panels are solid, matching the
    // collapsed pill instead of letting the wallpaper bleed through.
    property color background:        "#0D0D0F"
    property color backgroundSolid:   "#0D0D0F"
    property color surface:           "#1A1A1C"
    property color surfaceElevated:   "#1C1C1E"
    property color surfaceHover:      "#242427"
    property color track:             "#2A2A2D"
    property color iconCircle:        "#26262A"

    // ── Borders ──────────────────────────────────────────────────────────────
    property color border:            Qt.rgba(1, 1, 1, 0.07)
    property color borderStrong:      Qt.rgba(1, 1, 1, 0.12)

    // ── Text ─────────────────────────────────────────────────────────────────
    property color textPrimary:       "#E8E8EA"
    property color textSecondary:     "#8A8A8E"
    property color textDim:           "#5A5A5E"

    // ── Accents ──────────────────────────────────────────────────────────────
    property color accent:            "#A8E6D8" // soft mint / teal
    property color sliderAccent:      "#E8B4D0" // soft pink / lavender
    property color danger:            "#E8A0A0"

    /**
     * Read one colour out of the `colors` object produced by
     * `matugen ... --json hex`. Each entry looks like
     * `{ primary: { dark: { color: "#..." }, light: {...}, default: {...} } }`.
     * Returns "" when the key or mode is missing so callers can skip it.
     */
    function pick(scheme, key, mode) {
        if (!scheme || !scheme[key])
            return ""
        var entry = scheme[key][mode] || scheme[key]["dark"] || scheme[key]["default"]
        return (entry && entry.color) ? entry.color : ""
    }

    /// Attach an alpha channel to a `#RRGGBB` string (returns it unchanged if it
    /// is not in that form, e.g. a QML colour literal).
    function withAlpha(hex, alpha) {
        if (typeof hex !== "string" || hex.length < 7 || hex.charAt(0) !== "#")
            return hex
        var r = parseInt(hex.substr(1, 2), 16) / 255
        var g = parseInt(hex.substr(3, 2), 16) / 255
        var b = parseInt(hex.substr(5, 2), 16) / 255
        return Qt.rgba(r, g, b, alpha)
    }

    /**
     * Map a Matugen Material scheme onto the island's semantic roles. Missing
     * roles are left untouched, so a partial scheme never blanks the UI.
     */
    function applyMatugen(scheme, mode) {
        mode = mode || "dark"
        var v = ""

        v = pick(scheme, "background", mode);          if (v) { backgroundSolid = v; background = v }
        v = pick(scheme, "surface_container", mode);   if (v) surface = v
        v = pick(scheme, "surface_container_high", mode);    if (v) surfaceElevated = v
        v = pick(scheme, "surface_container_highest", mode); if (v) surfaceHover = v
        v = pick(scheme, "surface_container_high", mode);    if (v) iconCircle = v
        v = pick(scheme, "surface_variant", mode);     if (v) track = v

        v = pick(scheme, "outline_variant", mode);     if (v) border = withAlpha(v, 0.55)
        v = pick(scheme, "outline", mode);             if (v) borderStrong = withAlpha(v, 0.9)

        v = pick(scheme, "on_surface", mode);          if (v) textPrimary = v
        v = pick(scheme, "on_surface_variant", mode);  if (v) textSecondary = v
        v = pick(scheme, "outline", mode);             if (v) textDim = v

        v = pick(scheme, "primary", mode);             if (v) accent = v
        v = pick(scheme, "tertiary", mode);            if (v) sliderAccent = v
        v = pick(scheme, "error", mode);               if (v) danger = v
    }
}
