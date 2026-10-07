import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../core/theme"
import "../../core/services"
import "../widgets"

/**
 * WallpaperPanel — the Wallpapers tab.
 *
 * Two sub-tabs:
 *
 *   Local   a centred carousel of real wallpaper thumbnails discovered by
 *           `Wallpaper.qml` (the configured wallpaper folder —
 *           `/home/jakob/Bilder/wallpapers` by default, or $KARU_WALLPAPER_DIR).
 *           The highlighted wallpaper sits in the middle at its full width,
 *           framed by the accent border, while the ones either side are
 *           narrower and squeeze into their visible slice as they slide off the
 *           panel. ←/→ move the highlight, Enter applies it, and clicking a
 *           thumbnail highlights and sets it; if the dynamic Wallpaper theme is
 *           active, the island immediately re-colours itself from the new image.
 *
 *   Browse  a Wallhaven search (see `Wallhaven.qml` + `WallhavenBrowse.qml`):
 *           filter by category / purity / sort, then click a thumbnail to
 *           download it into the local folder and apply it.
 *
 * The catalogue is rescanned whenever the tab becomes visible, so images added
 * while the shell is running show up without a restart.
 *
 * Thumbnails are clipped with `ClippingRectangle` so they follow the panel's
 * rounded corners.
 */
Rectangle {
    id: root

    implicitHeight: layout.implicitHeight + Theme.cardPadding * 2
    radius: Theme.radiusCard
    color: "transparent"

    /// Which sub-tab is showing: "local" or "browse".
    property string tab: "local"

    /// Game Mode removes the Wallhaven "Browse" sub-tab: it is the one part of
    /// the panel that reaches the network and decodes remote thumbnails, so it
    /// is the piece to drop when the shell is meant to stay light.
    readonly property bool gameMode: Theme.gameMode

    readonly property var wallpapers: Wallpaper.wallpapers
    readonly property int count: Wallpaper.count

    /// Index of the highlighted (centred) wallpaper. ←/→ move it, Enter applies
    /// it; clicking a thumbnail moves the highlight and applies it directly.
    /// It starts on the wallpaper in use and is clamped into range as the
    /// catalogue rescans or downloads land.
    property int highlight: -1

    /// Whether the panel wants the island's exclusive keyboard focus. Only the
    /// Local carousel is keyboard-driven — Browse is click-only — so the shell
    /// stays out of the way while the grid is browsed (see shell.qml).
    readonly property bool wantsKeyboard: enabled && tab === "local" && count > 0

    // Keep the list fresh: the panel is recreated each time the tab is opened,
    // so pick up wallpapers added since startup without needing a restart. The
    // initial scan is kicked off by Wallpaper itself.
    Component.onCompleted: {
        Wallpaper.rescan()
        if (highlight < 0)
            highlight = Wallpaper.current
    }

    // The Wallhaven results are fetched lazily — only once Browse is shown, and
    // never while Game Mode has the sub-tab removed.
    onTabChanged: if (tab === "browse" && !gameMode) Wallhaven.ensureLoaded()

    // Engaging Game Mode yanks the Browse sub-tab out from under the user; fall
    // back to Local so the panel is never left showing a removed view.
    onGameModeChanged: if (gameMode && tab === "browse") tab = "local"

    // Always open on Local, never Browse. This panel instance is kept alive
    // while the island is collapsed, so a collapse/reopen would otherwise
    // resurrect the sub-tab left over from last time. PanelStack disables its
    // content while the island is collapsed, so the false→true edge marks a
    // fresh opening and snaps the sub-tab back to Local, with the highlight on
    // the wallpaper currently in use.
    onEnabledChanged: if (enabled) {
        tab = "local"
        highlight = Wallpaper.current
    }

    // The catalogue can change under us (first scan, a Browse download, a
    // rescan when the tab reopens). Keep the highlight pointing at a real row.
    onCountChanged: ensureHighlight()
    Connections {
        target: Wallpaper
        function onWallpapersChanged() { root.ensureHighlight() }
    }

    /// The highlighted catalogue entry (or null when the list is empty). Used by
    /// the Local view's footer.
    readonly property var highlighted: (highlight >= 0 && highlight < count)
        ? wallpapers[highlight] : null

    function ensureHighlight() {
        if (root.count === 0) {
            highlight = -1
            return
        }
        if (highlight >= 0 && highlight < root.count)
            return
        highlight = (Wallpaper.current >= 0 && Wallpaper.current < root.count)
            ? Wallpaper.current : 0
    }

    /// Move the highlight by `delta`, clamped to the catalogue. The carousel
    /// glides to centre it.
    function stepBy(delta) {
        if (root.count === 0)
            return
        var next = Math.max(0, Math.min(root.count - 1, highlight + delta))
        if (next !== highlight)
            highlight = next
    }

    /// Apply the highlighted wallpaper. With the dynamic Wallpaper theme active
    /// the island re-colours from it straight away.
    function applyHighlight() {
        if (highlight >= 0 && highlight < root.count)
            Wallpaper.select(highlight)
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.cardPadding
        spacing: Theme.spaceLg

        // ── Header: title + count + Local / Browse switch ────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            Text {
                text: "Wallpaper"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sectionSize
                font.weight: Font.Medium
            }

            Text {
                text: root.tab === "browse"
                    ? (Wallhaven.busy ? "…" : Wallhaven.total + " found")
                    : (root.count > 0 && root.highlight >= 0
                        ? (root.highlight + 1) + "/" + root.count : "none found")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }

            Item { Layout.fillWidth: true }

            TabButton {
                label: "Local"
                active: root.tab === "local"
                onClicked: root.tab = "local"
            }
            TabButton {
                label: "Browse"
                active: root.tab === "browse"
                visible: !root.gameMode
                onClicked: root.tab = "browse"
            }
        }

        // ── Body: the selected sub-tab ───────────────────────────────────────
        Loader {
            Layout.fillWidth: true
            sourceComponent: root.tab === "browse" ? browseView : localView
        }
    }

    // ── Local catalogue ──────────────────────────────────────────────────────
    // A centred carousel: the highlighted wallpaper sits in the middle at its
    // full (wider) size, framed by the accent border, with the ones either side
    // narrower. As a thumbnail slides off the panel it is squeezed into its
    // visible slice instead of being hard-clipped, so the strip reads as one
    // continuous flow (the effect from the reference strip). ←/→ move the
    // highlight and the whole row glides to centre it; Enter applies it. The
    // shell takes keyboard focus while this tab is open (see shell.qml).
    Component {
        id: localView

        ColumnLayout {
            spacing: Theme.spaceLg

            // ── Centred carousel ─────────────────────────────────────────────
            Item {
                id: carousel

                Layout.fillWidth: true
                implicitHeight: Theme.wallpaperThumbHeight + Theme.wallpaperCardHeadroom
                clip: true
                focus: true
                visible: root.count > 0

                readonly property real gap: Theme.spaceMd
                readonly property real selWidth: Theme.wallpaperSelectedWidth
                readonly property real plainWidth: Theme.wallpaperThumbWidth
                // Centre offset of the neighbour one slot out: half the selected
                // card + the gap + half the neighbour. Deeper neighbours carry on
                // at the plain centre-to-centre pace, so the selected card's
                // extra width only ever opens a single gap beside itself.
                readonly property real halfSpan: selWidth / 2 + gap + plainWidth / 2
                readonly property real pairStep: plainWidth + gap

                // Fractional centre index, bound to the highlight and given a
                // Behavior, so changing it makes the whole row glide.
                property real position: root.highlight < 0 ? 0 : root.highlight
                Behavior on position {
                    NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
                }

                function centerOffset(dist) {
                    var a = Math.abs(dist)
                    if (a <= 1)
                        return a * halfSpan
                    return halfSpan + (a - 1) * pairStep
                }

                Component.onCompleted: forceActiveFocus()
                onVisibleChanged: if (visible) forceActiveFocus()

                Keys.onLeftPressed: root.stepBy(-1)
                Keys.onRightPressed: root.stepBy(1)
                Keys.onReturnPressed: root.applyHighlight()
                Keys.onEnterPressed: root.applyHighlight()

                Repeater {
                    model: root.wallpapers

                    delegate: Item {
                        id: thumb

                        required property var modelData
                        required property int index

                        readonly property bool isHighlight: index === root.highlight
                        readonly property real dist: index - carousel.position
                        readonly property real closeness: Math.max(0, 1 - Math.abs(dist))

                        // The horizontal slice of the card actually inside the
                        // panel. When it overflows an edge the drawn card shrinks
                        // to this width and is anchored to the visible edge, so
                        // the image squashes rather than being cut off — the
                        // "message.qml" effect.
                        readonly property real visLeft: Math.max(0, x)
                        readonly property real visRight: Math.min(carousel.width, x + width)
                        readonly property real visWidth: Math.max(0, visRight - visLeft)
                        // Anchored to the right when it overflows the left edge,
                        // to the left otherwise (0 when it is fully inside).
                        readonly property real cardX: x < 0 ? width - visWidth : 0

                        width: isHighlight ? carousel.selWidth : carousel.plainWidth
                        height: Theme.wallpaperThumbHeight
                        x: {
                            var s = dist > 0 ? 1 : (dist < 0 ? -1 : 0)
                            return carousel.width / 2 + s * carousel.centerOffset(dist) - width / 2
                        }
                        y: (carousel.height - height) / 2 - closeness * Theme.wallpaperCardLift
                        z: -Math.abs(dist)
                        opacity: Math.max(0, Math.min(1, 2.2 - Math.abs(dist)))
                        Behavior on width {
                            NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
                        }
                        Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                        ClippingRectangle {

                            x: thumb.cardX
                            width: thumb.visWidth
                            height: thumb.height
                            radius: Theme.radiusThumb
                            color: Theme.surfaceElevated
                            border.width: thumb.isHighlight ? 2 : 1
                            border.color: thumb.isHighlight ? Theme.accent : Theme.border
                            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                            Image {
                                id: preview
                                anchors.fill: parent
                                source: "file://" + thumb.modelData.path
                                asynchronous: true
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: carousel.selWidth
                                sourceSize.height: thumb.height
                            }

                            // Shown until the image decodes (or if it cannot be read).
                            Text {
                                anchors.centerIn: parent
                                visible: preview.status !== Image.Ready
                                text: "\uF03E" // nf-fa-picture_o
                                color: Theme.textDim
                                font.family: Theme.iconFont
                                font.pixelSize: 22
                            }
                        }

                        // The click target follows the visible slice too, so an
                        // edge card is only clickable where it is actually drawn.
                        MouseArea {
                            x: thumb.cardX
                            width: thumb.visWidth
                            height: thumb.height
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.highlight = thumb.index
                                Wallpaper.select(thumb.index)
                            }
                        }
                    }
                }

                // The wheel steps the highlight, like the Themes carousel.
                WheelHandler {
                    onWheel: function(event) {
                        if (event.angleDelta.y > 0 || event.angleDelta.x > 0)
                            root.stepBy(1)
                        else if (event.angleDelta.y < 0 || event.angleDelta.x < 0)
                            root.stepBy(-1)
                    }
                }
            }

            // Empty state
            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.wallpaperThumbHeight
                visible: root.count === 0
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap
                text: Wallpaper.status + "\nAdd images to "
                      + Wallpaper.wallpaperDir + " or set KARU_WALLPAPER_DIR"
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }

            // Footer
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.highlighted ? root.highlighted.name : "—"
                    color: root.highlighted && root.highlight === Wallpaper.current
                        ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.count === 0 ? ""
                        : (root.highlight === Wallpaper.current ? "Applied \u2713"
                                                                : "Enter to set")
                    color: root.count > 0 && root.highlight === Wallpaper.current
                        ? Theme.accent : Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                }
            }
        }
    }

    // ── Wallhaven browse ─────────────────────────────────────────────────────
    Component {
        id: browseView

        WallhavenBrowse {}
    }

    // ── Small building blocks ────────────────────────────────────────────────
    component TabButton: Rectangle {
        id: tab

        property string label: ""
        property bool active: false
        signal clicked()

        implicitWidth: tabLabel.implicitWidth + Theme.spaceLg * 1.4
        implicitHeight: 26
        radius: Theme.radiusPill
        color: tab.active ? Theme.accentMuted
             : (tabHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated)
        border.width: 1
        border.color: tab.active ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        Text {
            id: tabLabel
            anchors.centerIn: parent
            text: tab.label
            color: tab.active ? Theme.accent : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }

        HoverHandler { id: tabHover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tab.clicked()
        }
    }
}
