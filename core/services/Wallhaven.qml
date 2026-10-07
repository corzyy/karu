pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../theme"

/**
 * Wallhaven — a thin client for the Wallhaven search API.
 *
 * The Wallpapers panel's **Browse** tab lists results from
 * https://wallhaven.cc/help/api, filtered with the same knobs the website
 * exposes: the three categories (General / Anime / People) and the three
 * purities (SFW / Sketchy / NSFW), plus a sort mode. Picking a thumbnail
 * downloads the full image into the local wallpaper folder and hands it to
 * `Wallpaper`, which selects and applies it.
 *
 * Requests are made with `curl` (one `Process` for search, one for the
 * download) so no extra QML module or API key handling is needed. Upsetting
 * the settings re-runs the search; the page links walk `meta.last_page`.
 *
 * NSFW and Sketchy results are only returned by Wallhaven when the request
 * carries an API key. Export one and the shell picks it up:
 *
 *   KARU_WALLHAVEN_API_KEY=xxxxx
 *
 * Without it the purity chips still work but selecting Sketchy/NSFW reports
 * that a key is required instead of querying.
 *
 * NOTE: the root is an `Item`, not a `QtObject`, so the `Process` children can
 * be declared through the default `data` property. It is never shown.
 */
Item {
    id: root

    // ── Search settings ──────────────────────────────────────────────────────
    /// Free-text query (`q`). Empty means "everything".
    property string query: ""
    property bool categoryGeneral: true
    property bool categoryAnime: true
    property bool categoryPeople: false
    property bool puritySfw: true
    property bool puritySketchy: false
    property bool purityNsfw: false
    /// toplist | date_added | random | views | favorites
    property string sorting: "toplist"
    /// Only used by `toplist`: 1d | 3d | 1w | 1M | 3M | 6M | 1y
    property string topRange: "1M"
    /// Minimum resolution, e.g. "1920x1080". Empty disables the filter.
    property string atleast: ""

    // ── Results ──────────────────────────────────────────────────────────────
    /// [{ id, thumb, thumbLarge, full, resolution, category, purity }]
    property var results: []
    property int page: 1
    property int lastPage: 1
    property int total: 0
    property bool busy: false
    property bool downloading: false
    /// Id of the result currently downloading (so its tile can show a veil).
    property string pendingId: ""
    /// Human-readable status line; empty while everything is fine.
    property string status: ""
    /// True once a search has been attempted, so the tab can search lazily.
    property bool loadedOnce: false

    readonly property string apiKey: String(Quickshell.env("KARU_WALLHAVEN_API_KEY") || "")
    readonly property bool hasApiKey: apiKey.length > 0

    readonly property string categoryMask:
        (categoryGeneral ? "1" : "0") + (categoryAnime ? "1" : "0") + (categoryPeople ? "1" : "0")
    readonly property string purityMask:
        (puritySfw ? "1" : "0") + (puritySketchy ? "1" : "0") + (purityNsfw ? "1" : "0")
    /// Sketchy / NSFW both require a key on Wallhaven's side.
    readonly property bool needsKey: puritySketchy || purityNsfw

    /// Random sort seed, refreshed on every search so "Random" is random.
    property int seed: 1

    // ── Searching ────────────────────────────────────────────────────────────
    function buildUrl() {
        var parts = []
        if (String(query).length > 0)
            parts.push("q=" + encodeURIComponent(query))
        parts.push("categories=" + categoryMask)
        parts.push("purity=" + purityMask)
        parts.push("sorting=" + sorting)
        if (sorting === "toplist")
            parts.push("topRange=" + topRange)
        if (sorting === "random")
            parts.push("seed=" + seed)
        if (String(atleast).length > 0)
            parts.push("atleast=" + atleast)
        parts.push("page=" + page)
        if (hasApiKey)
            parts.push("apikey=" + encodeURIComponent(apiKey))
        return "https://wallhaven.cc/api/v1/search?" + parts.join("&")
    }

    /// Run a search. Pass `true` (or nothing) to reset to page 1; `false` keeps
    /// the current page (used by the prev/next links).
    function search(reset) {
        if (busy || downloading)
            return
        if (categoryMask === "000") {
            status = "Pick at least one category"
            return
        }
        if (purityMask === "000") {
            status = "Pick at least one purity"
            return
        }
        if (needsKey && !hasApiKey) {
            status = "Sketchy / NSFW need an API key — set KARU_WALLHAVEN_API_KEY"
            return
        }
        if (reset === true || reset === undefined)
            page = 1
        seed = Math.floor(Math.random() * 1000000) + 1
        busy = true
        status = ""
        searchProc.command = ["curl", "-fsSL", "--max-time", "20", buildUrl()]
        searchProc.running = false
        searchProc.running = true
    }

    /// Kick off the first search when the Browse tab is opened. Settings
    /// changes call `search(true)` directly, so this only fills the empty tab.
    function ensureLoaded() {
        if (!loadedOnce)
            search(true)
    }

    function nextPage() {
        if (busy || page >= lastPage)
            return
        page = page + 1
        search(false)
    }

    function prevPage() {
        if (busy || page <= 1)
            return
        page = page - 1
        search(false)
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            id: searchOut
            waitForEnd: true
        }
        onExited: function (code) {
            if (!root.busy)
                return
            root.busy = false
            root.loadedOnce = true
            if (code !== 0) {
                root.status = "Wallhaven is unreachable (network?)"
                return
            }
            root.handleSearch(searchOut.text)
        }
    }

    function handleSearch(text) {
        var parsed = null
        try { parsed = JSON.parse(String(text)) } catch (e) { parsed = null }
        if (!parsed || !parsed.data) {
            root.status = "Unexpected response from Wallhaven"
            return
        }

        var out = []
        for (var i = 0; i < parsed.data.length; i++) {
            var w = parsed.data[i]
            var thumbs = w.thumbs || {}
            out.push({
                id: w.id,
                thumb: thumbs.small || thumbs.large || "",
                thumbLarge: thumbs.large || thumbs.small || "",
                full: w.path || "",
                resolution: w.resolution || "",
                category: w.category || "",
                purity: w.purity || ""
            })
        }
        root.results = out

        var meta = parsed.meta || {}
        root.page = meta.current_page !== undefined ? meta.current_page : root.page
        root.lastPage = meta.last_page !== undefined ? meta.last_page : 1
        root.total = meta.total !== undefined ? meta.total : out.length
        root.status = out.length === 0 ? "No wallpapers match these settings" : ""
    }

    // ── Download + apply ─────────────────────────────────────────────────────
    function download(item) {
        if (downloading || !item || !item.full)
            return
        var dir = Wallpaper.wallpaperDir
        var url = String(item.full)

        var ext = url.substring(url.lastIndexOf(".") + 1).toLowerCase()
        if (["jpg", "jpeg", "png", "webp", "avif", "bmp"].indexOf(ext) < 0)
            ext = "jpg"

        var name = "wallhaven-" + item.id + "." + ext
        var out = dir + "/" + name

        downloading = true
        pendingId = item.id
        status = "Downloading " + name + "…"
        downloadProc.outPath = out
        // Fixed script; the folder, filename and URL arrive as positional
        // arguments so neither their contents nor the URL become shell syntax.
        // `mkdir -p` so the very first download also creates the folder.
        downloadProc.command = ["sh", "-c",
            "mkdir -p \"$1\" && curl -fsSL --retry 2 --max-time 180 -o \"$1/$2\" \"$3\"",
            "sh", dir, name, url]
        downloadProc.running = false
        downloadProc.running = true
    }

    Process {
        id: downloadProc
        property string outPath: ""
        onExited: function (code) {
            root.downloading = false
            root.pendingId = ""
            if (code === 0) {
                root.status = ""
                Wallpaper.rescanAndSelect(downloadProc.outPath)
            } else {
                root.status = "Download failed"
            }
        }
    }
}
