pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../config"

/**
 * Wallpaper — discovers the available wallpapers and tracks the current one.
 *
 * The Wallpapers tab lists these; the dynamic Wallpaper theme asks Matugen to
 * pull a colour scheme out of `currentPath`. The selected path is persisted to
 * the shell state directory and restored on the next launch.
 *
 * Discovery scans a single folder — `/home/jakob/Bilder/wallpapers` by default,
 * overridable with $KARU_WALLPAPER_DIR — so the catalogue lists exactly the
 * images kept there. The folder is passed to the scanner as a positional
 * argument, never interpolated into the shell source.
 *
 * Setting the wallpaper is best-effort: whichever of awww / swww / hyprpaper /
 * swaybg / wbg is installed is used (the awww/swww daemons are started on
 * demand). With none of them the selection still drives the theme; only the
 * picture itself is left alone.
 *
 * NOTE: the root is an `Item`, not a `QtObject`, so the `Process` / `FileView`
 * children below can be declared through the default `data` property. It is
 * never shown — it only hosts the scanning and wallpaper-setting helpers.
 */
Item {
    id: root

    property var wallpapers: []   // [{ path, name }]
    property int current: -1
    property bool loaded: false
    property string status: ""
    /// A path to select as soon as the next scan finds it. Used by the
    /// Wallhaven Browse tab: it downloads a file, then asks for a rescan with
    /// that file as the target so it is applied without racing the scan.
    property string pendingSelect: ""
    /// Folder scanned for wallpapers when Settings leaves it empty. Overridable
    /// with $KARU_WALLPAPER_DIR.
    readonly property string defaultWallpaperDir:
        String(Quickshell.env("KARU_WALLPAPER_DIR") || "/home/jakob/Bilder/wallpapers")
    /// Folder scanned for wallpapers: the Settings value (`Settings ▸ Appearance
    /// ▸ Wallpaper ▸ Wallpaper folder`), or the built-in default when empty.
    readonly property string wallpaperDir:
        Settings.wallpaperDir.length > 0 ? Settings.wallpaperDir : defaultWallpaperDir

    // Rescan as soon as the configured folder changes.
    Connections {
        target: Settings
        function onWallpaperDirChanged() { root.rescan() }
    }

    readonly property string currentPath:
        (current >= 0 && current < wallpapers.length) ? wallpapers[current].path : ""
    readonly property int count: wallpapers.length

    // ── Discovery ────────────────────────────────────────────────────────────
    // One `find` over the wallpaper folder. The path is passed as $1 so its
    // contents are never treated as shell syntax. Sub-directories up to three
    // levels deep are included; a missing folder makes the scan a no-op rather
    // than an error, so the tab simply shows its empty state.
    readonly property string scanScript:
        "d=\"$1\"\n" +
        "[ -n \"$d\" ] && [ -d \"$d\" ] || exit 0\n" +
        "find \"$d\" -maxdepth 3 -type f \\( " +
        "  -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o " +
        "  -iname '*.webp' -o -iname '*.avif' -o -iname '*.bmp' \\)"

    function rescan() {
        scan.running = false
        scan.running = true
    }

    /// Rescan, then select `path` once the scan has picked it up. Used after a
    /// Browse download so the new file becomes the active wallpaper.
    function rescanAndSelect(path) {
        pendingSelect = String(path)
        rescan()
    }

    Process {
        id: scan
        command: ["sh", "-c", root.scanScript, "sh", root.wallpaperDir]
        stdout: StdioCollector {
            id: scanOut
            waitForEnd: true
            onStreamFinished: root.handleScan(scanOut.text)
        }
    }

    function handleScan(text) {
        var lines = String(text).split("\n")
        var out = []
        var seen = ({})
        var firstLoad = !loaded

        for (var i = 0; i < lines.length; i++) {
            var path = lines[i].trim()
            if (path.length === 0 || seen[path])
                continue
            seen[path] = true
            out.push({ path: path, name: path.substring(path.lastIndexOf("/") + 1) })
        }
        out.sort(function (a, b) { return String(a.name).localeCompare(String(b.name)) })

        wallpapers = out
        loaded = true
        restoreSelection()
        status = out.length === 0 ? "No wallpapers found" : ""

        // A download (or similar) asked for this exact file to be selected once
        // it exists. Do that now and apply it, then clear the request.
        if (pendingSelect.length > 0) {
            var target = pendingSelect
            pendingSelect = ""
            for (var j = 0; j < wallpapers.length; j++) {
                if (wallpapers[j].path === target) {
                    select(j)
                    break
                }
            }
        }

        // Re-apply the remembered wallpaper once, on first scan, so the desktop
        // still shows the choice made last session. Later rescans (e.g. when the
        // tab is reopened) only refresh the list.
        if (firstLoad && currentPath.length > 0)
            setWallpaper(currentPath)
    }

    // ── Selection ────────────────────────────────────────────────────────────
    function restoreSelection() {
        var saved = ""
        try { saved = String(stateFile.text()).trim() } catch (e) { saved = "" }

        var index = -1
        if (saved.length > 0) {
            for (var i = 0; i < wallpapers.length; i++) {
                if (wallpapers[i].path === saved) { index = i; break }
            }
        }
        if (index < 0 && wallpapers.length > 0)
            index = 0

        if (index >= 0) {
            current = index
            persist()
        }
    }

    /// Select a wallpaper by index and set it on the desktop.
    function select(index, applyWallpaper) {
        if (index < 0 || index >= wallpapers.length)
            return
        current = index
        persist()
        if (applyWallpaper !== false)
            setWallpaper(wallpapers[index].path)
    }

    // ── Setting the wallpaper (best effort) ──────────────────────────────────
    // Tries the common Wayland setters. awww (swww's successor) and swww need
    // their daemon running, so it is started on demand. The image path is passed
    // as a positional argument, never interpolated into the shell source.
    readonly property string setScript:
        "img=\"$1\"\n" +
        "start_daemon() {\n" +
        "  pgrep -x \"$1\" >/dev/null 2>&1 && return 0\n" +
        "  setsid \"$1\" >/dev/null 2>&1 &\n" +
        "  i=0; while [ $i -lt 20 ]; do pgrep -x \"$1\" >/dev/null 2>&1 && break; sleep 0.1; i=$((i+1)); done\n" +
        "  sleep 0.2\n" +
        "}\n" +
        "if command -v awww >/dev/null 2>&1; then\n" +
        "  start_daemon awww-daemon\n" +
        "  awww img \"$img\" >/dev/null 2>&1\n" +
        "elif command -v swww >/dev/null 2>&1; then\n" +
        "  start_daemon swww-daemon\n" +
        "  swww img \"$img\" >/dev/null 2>&1\n" +
        "elif command -v hyprpaper >/dev/null 2>&1; then\n" +
        "  hyprctl hyprpaper preload \"$img\" >/dev/null 2>&1\n" +
        "  hyprctl hyprpaper wallpaper \",$img\" >/dev/null 2>&1\n" +
        "elif command -v swaybg >/dev/null 2>&1; then\n" +
        "  pkill -x swaybg >/dev/null 2>&1\n" +
        "  setsid swaybg -i \"$img\" -m fill >/dev/null 2>&1 &\n" +
        "elif command -v wbg >/dev/null 2>&1; then\n" +
        "  pkill -x wbg >/dev/null 2>&1\n" +
        "  setsid wbg \"$img\" >/dev/null 2>&1 &\n" +
        "fi"

    function setWallpaper(path) {
        setter.command = ["sh", "-c", setScript, "sh", path]
        setter.running = false
        setter.running = true
    }

    Process { id: setter }

    // ── Persistence ──────────────────────────────────────────────────────────
    FileView {
        id: stateFile
        path: Quickshell.statePath("wallpaper")
        blockLoading: true
        blockWrites: false
        printErrors: false
    }

    function persist() {
        if (currentPath.length === 0)
            return
        try { stateFile.setText(currentPath) } catch (e) { /* best effort */ }
    }

    Component.onCompleted: root.rescan()
}
