import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../core/theme"
import "../../core/services"

/**
 * WallhavenBrowse — the Wallpapers panel's **Browse** tab.
 *
 * A filter row (Wallhaven's three categories and three purities), a scrollable
 * grid of remote thumbnails, and a footer with a sort toggle + paging. Clicking
 * a thumbnail downloads the full image through `Wallhaven` into the local
 * wallpaper folder; once it lands, `Wallpaper` selects and applies it.
 *
 * Everything here is click-driven: Browse never asks for keyboard focus — the
 * Wallpapers panel only does so on its Local carousel — so the island stays out
 * of the way while the grid is browsed.
 */
ColumnLayout {
    id: root

    spacing: Theme.spaceMd

    readonly property var sortModes: [
        { key: "toplist",    label: "Top" },
        { key: "date_added", label: "New" },
        { key: "random",     label: "Random" },
        { key: "views",      label: "Views" },
        { key: "favorites",  label: "Favorites" }
    ]
    readonly property var topRanges: ["1d", "3d", "1w", "1M", "3M", "6M", "1y"]

    readonly property string sortLabel: {
        for (var i = 0; i < sortModes.length; i++)
            if (sortModes[i].key === Wallhaven.sorting)
                return sortModes[i].label
        return Wallhaven.sorting
    }

    // Search lazily, the first time the tab is shown.
    Component.onCompleted: Wallhaven.ensureLoaded()

    function cycleSort() {
        var idx = 0
        for (var i = 0; i < sortModes.length; i++)
            if (sortModes[i].key === Wallhaven.sorting)
                idx = i
        Wallhaven.sorting = sortModes[(idx + 1) % sortModes.length].key
        Wallhaven.search(true)
    }

    function cycleTopRange() {
        var idx = topRanges.indexOf(Wallhaven.topRange)
        Wallhaven.topRange = topRanges[(idx + 1) % topRanges.length]
        Wallhaven.search(true)
    }

    // ── Filters: category · purity ───────────────────────────────────────────
    // No captions: the six toggles sit in one row, with a little extra air
    // between the category trio and the purity trio.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceXs

        Chip {
            label: "General"
            active: Wallhaven.categoryGeneral
            onClicked: {
                Wallhaven.categoryGeneral = !Wallhaven.categoryGeneral
                Wallhaven.search(true)
            }
        }
        Chip {
            label: "Anime"
            active: Wallhaven.categoryAnime
            onClicked: {
                Wallhaven.categoryAnime = !Wallhaven.categoryAnime
                Wallhaven.search(true)
            }
        }
        Chip {
            label: "People"
            active: Wallhaven.categoryPeople
            onClicked: {
                Wallhaven.categoryPeople = !Wallhaven.categoryPeople
                Wallhaven.search(true)
            }
        }

        Item { Layout.preferredWidth: Theme.spaceMd }

        Chip {
            label: "SFW"
            active: Wallhaven.puritySfw
            onClicked: {
                Wallhaven.puritySfw = !Wallhaven.puritySfw
                Wallhaven.search(true)
            }
        }
        Chip {
            label: "Sketchy"
            active: Wallhaven.puritySketchy
            // Dimmed while there is no key to actually fetch it with.
            opacity: (Wallhaven.hasApiKey || active) ? 1 : 0.55
            onClicked: {
                Wallhaven.puritySketchy = !Wallhaven.puritySketchy
                Wallhaven.search(true)
            }
        }
        Chip {
            label: "NSFW"
            active: Wallhaven.purityNsfw
            opacity: (Wallhaven.hasApiKey || active) ? 1 : 0.55
            onClicked: {
                Wallhaven.purityNsfw = !Wallhaven.purityNsfw
                Wallhaven.search(true)
            }
        }

        Item { Layout.fillWidth: true }
    }

    // ── Results grid ─────────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.wallhavenThumbHeight * Theme.wallhavenGridRows + Theme.spaceSm

        GridView {
            id: grid

            anchors.fill: parent
            clip: true
            model: Wallhaven.results
            cellWidth: Math.floor(width / Theme.wallhavenColumns)
            cellHeight: Theme.wallhavenThumbHeight + Theme.spaceSm
            boundsBehavior: Flickable.StopAtBounds
            // Only scroll when there is actually more than the visible rows.
            interactive: contentHeight > height

            delegate: ClippingRectangle {
                id: cell

                required property var modelData
                required property int index

                readonly property bool isPending: Wallhaven.downloading
                    && Wallhaven.pendingId === modelData.id

                width: grid.cellWidth - Theme.spaceSm
                height: grid.cellHeight - Theme.spaceSm
                radius: Theme.radiusThumb
                color: Theme.surfaceElevated
                border.width: cellHover.hovered || cell.isPending ? 2 : 1
                border.color: cell.isPending ? Theme.accent
                            : cellHover.hovered ? Theme.accent : Theme.border

                Image {
                    id: thumbImg
                    anchors.fill: parent
                    source: cell.modelData.thumb
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width
                    sourceSize.height: height
                }

                // Shown until the remote thumbnail decodes.
                Text {
                    anchors.centerIn: parent
                    visible: thumbImg.status !== Image.Ready
                    text: "\uF03E" // nf-fa-picture_o
                    color: Theme.textDim
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                }

                // Resolution badge along the bottom edge.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: !cell.isPending && cell.modelData.resolution.length > 0
                    height: 16
                    color: Qt.rgba(0, 0, 0, 0.55)

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.resolution
                        color: "#FFFFFF"
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }
                }

                // Download veil: covers the tile while its full image is fetched.
                Rectangle {
                    anchors.fill: parent
                    visible: cell.isPending
                    radius: cell.radius
                    color: Qt.rgba(0, 0, 0, 0.6)

                    Text {
                        anchors.centerIn: parent
                        text: "Saving…"
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.subtitleSize
                    }
                }

                HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Wallhaven.downloading
                    onClicked: Wallhaven.download(cell.modelData)
                }
            }
        }

        // Empty / loading / error state, centred over the grid.
        Text {
            anchors.centerIn: parent
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: Wallhaven.results.length === 0
            text: Wallhaven.busy
                ? "Loading…"
                : (Wallhaven.status.length > 0 ? Wallhaven.status
                   : (Wallhaven.loadedOnce ? "No results" : "Loading…"))
            color: Wallhaven.status.length > 0 && !Wallhaven.busy
                ? Theme.danger : Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }
    }

    // ── Footer: sort / range / status / paging ───────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceSm

        Chip {
            label: root.sortLabel
            onClicked: root.cycleSort()
        }
        Chip {
            visible: Wallhaven.sorting === "toplist"
            label: Wallhaven.topRange
            onClicked: root.cycleTopRange()
        }

        Text {
            Layout.fillWidth: true
            visible: Wallhaven.status.length > 0 && Wallhaven.results.length > 0
            text: Wallhaven.status
            color: Theme.danger
            elide: Text.ElideRight
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }
        Item { Layout.fillWidth: !(Wallhaven.status.length > 0 && Wallhaven.results.length > 0) }

        Text {
            text: Wallhaven.busy ? "…" : (Wallhaven.page + "/" + Math.max(1, Wallhaven.lastPage))
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }

        NavButton {
            glyph: "\u2039" // ‹
            enabled: !Wallhaven.busy && Wallhaven.page > 1
            onClicked: Wallhaven.prevPage()
        }
        NavButton {
            glyph: "\u203A" // ›
            enabled: !Wallhaven.busy && Wallhaven.page < Wallhaven.lastPage
            onClicked: Wallhaven.nextPage()
        }
    }

    // ── Small building blocks ────────────────────────────────────────────────

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property bool active: false
        signal clicked()

        // Tight horizontal padding so all six filters fit on one row.
        implicitWidth: chipLabel.implicitWidth + Theme.spaceMd * 1.6
        implicitHeight: 26
        radius: Theme.radiusPill
        color: chip.active ? Theme.accentMuted
             : (chipHover.hovered ? Theme.surfaceHover : Theme.surfaceElevated)
        border.width: 1
        border.color: chip.active ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? Theme.accent : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }

        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component NavButton: Rectangle {
        id: nav

        property string glyph: ""
        signal clicked()

        implicitWidth: 26
        implicitHeight: 26
        radius: Theme.radiusPill
        color: navHover.hovered && nav.enabled ? Theme.surfaceHover : Theme.surfaceElevated
        border.width: 1
        border.color: Theme.border
        opacity: nav.enabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: nav.glyph
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: 16
        }

        HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: nav.enabled
            onClicked: nav.clicked()
        }
    }
}
