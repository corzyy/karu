import QtQuick
import QtQuick.Layouts
import Quickshell

import "../../core/theme"
import "Catalog.js" as Catalog

/**
 * SettingsPage — renders one category as a responsive grid of labelled setting
 * cards (or global search results).
 *
 * A page's groups are its sub-sections. Each becomes a `SettingsGroupCard`; the
 * page places them two to a row when the pane is wide enough, and stacks them in
 * one column otherwise (docked mode, search). Full-width groups — the theme and
 * accent carousels, the motion preset picker and the Control Center layout
 * editor — always span the whole pane and break the grid.
 *
 * The rows are data-driven (see Catalog.js) and address values in the `Settings`
 * singleton by name.
 */
Column {
    id: root

    property string pageKey: "bar"
    property string query: ""

    readonly property var page: Catalog.pageByKey(pageKey)
    readonly property bool searching: query.trim().length > 0

    /// Use two columns only when there is room for two comfortable cards.
    readonly property bool twoColumn: !root.searching && root.width >= 620

    /// Groups to draw: the current page's, or search hits grouped by page.
    readonly property var visibleGroups: {
        var q = query.trim().toLowerCase()
        if (q === "")
            return root.page.groups

        var out = []
        for (var p = 0; p < Catalog.pages.length; p++) {
            var pg = Catalog.pages[p]
            if (!Catalog.pageMatches(pg, q))
                continue
            // A hit on the page name shows all of its rows; otherwise only the
            // rows whose title/subtitle contain the query.
            var nameHit = pg.name.toLowerCase().indexOf(q) !== -1
            var rows = []
            for (var g = 0; g < pg.groups.length; g++) {
                var grp = pg.groups[g]
                for (var r = 0; r < grp.rows.length; r++) {
                    var row = grp.rows[r]
                    var hay = (row.title + " " + (row.subtitle || "")).toLowerCase()
                    if (nameHit || hay.indexOf(q) !== -1)
                        rows.push(row)
                }
            }
            if (rows.length > 0)
                out.push({ label: pg.name, rows: rows })
        }
        return out
    }

    /// The layout plan: an ordered list of blocks. A block is either one
    /// full-width group, or a pair of groups shown side by side.
    readonly property var blocks: root.buildBlocks(root.visibleGroups)

    spacing: Theme.spaceLg

    // ── Layout plan ──────────────────────────────────────────────────────────
    /// A group needs the full pane when it holds a carousel or the editor.
    function isWideGroup(g) {
        for (var i = 0; i < g.rows.length; i++) {
            var t = g.rows[i].type
            if (t === "theme" || t === "accent" || t === "controllayout" || t === "motionpreset")
                return true
        }
        return false
    }

    /// Split a run of card groups into blocks: pairs side by side when the pane
    /// is wide, otherwise one card per block. Reading order (left-to-right, then
    /// next row) is preserved, and a trailing odd group spans the full pane.
    function pairBlocks(pending) {
        var out = []
        if (pending.length === 0)
            return out
        if (!root.twoColumn) {
            for (var i = 0; i < pending.length; i++)
                out.push({ wide: false, cols: 1, left: [pending[i]], right: [] })
            return out
        }
        for (var j = 0; j < pending.length; j += 2) {
            if (j + 1 < pending.length)
                out.push({ wide: false, cols: 2, left: [pending[j]], right: [pending[j + 1]] })
            else
                out.push({ wide: false, cols: 1, left: [pending[j]], right: [] })
        }
        return out
    }

    function buildBlocks(groups) {
        var out = []
        var pending = []
        for (var i = 0; i < groups.length; i++) {
            var g = groups[i]
            if (root.isWideGroup(g)) {
                var cards = root.pairBlocks(pending)
                for (var k = 0; k < cards.length; k++)
                    out.push(cards[k])
                pending = []
                out.push({ wide: true, cols: 1, left: [g], right: [] })
            } else {
                pending.push(g)
            }
        }
        var tail = root.pairBlocks(pending)
        for (var t = 0; t < tail.length; t++)
            out.push(tail[t])
        return out
    }

    function runAction(action) {
        if (action === "restart")
            Quickshell.execDetached(["karu", "restart"])
        else if (action === "update")
            Quickshell.execDetached(["karu", "update"])
        else if (action === "openconfig")
            Quickshell.execDetached(["xdg-open", Quickshell.shellDir])
    }

    // ── Header ───────────────────────────────────────────────────────────────
    // A flush page header: the category icon in a tinted tile beside its name
    // and one-line description. Search replaces it with result groups.
    RowLayout {
        width: parent.width
        visible: !root.searching
        spacing: Theme.spaceLg

        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            Layout.alignment: Qt.AlignTop
            radius: Theme.radiusInner
            color: Theme.accentMuted

            Text {
                anchors.centerIn: parent
                text: root.page.icon
                color: Theme.accent
                font.family: Theme.iconFont
                font.pixelSize: 22
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.page.name
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.page.desc
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                wrapMode: Text.WordWrap
            }
        }
    }

    // ── Search hint ──────────────────────────────────────────────────────────
    Text {
        width: parent.width
        visible: root.searching && root.visibleGroups.length === 0
        topPadding: Theme.spaceLg
        bottomPadding: Theme.spaceLg
        text: "No settings match \u201C" + root.query + "\u201D"
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.titleSize
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Cards ────────────────────────────────────────────────────────────────
    Repeater {
        model: root.blocks

        delegate: Item {
            id: block

            required property var modelData
            readonly property bool wide: modelData.wide
            readonly property int cols: modelData.cols

            width: root.width
            implicitHeight: wide
                ? wideCard.implicitHeight
                : (cols > 1 ? Math.max(colLeft.implicitHeight, colRight.implicitHeight)
                            : colLeft.implicitHeight)
            height: implicitHeight

            SettingsGroupCard {
                id: wideCard
                width: parent.width
                visible: block.wide
                group: block.wide ? block.modelData.left[0] : null
                onActionTriggered: function (a) { root.runAction(a) }
            }

            Row {
                id: gridRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: !block.wide
                spacing: Theme.spaceLg

                readonly property real colW: block.cols > 1 ? (width - spacing) / 2 : width

                Column {
                    id: colLeft
                    width: gridRow.colW
                    spacing: Theme.spaceLg

                    Repeater {
                        model: block.wide ? [] : block.modelData.left

                        delegate: SettingsGroupCard {
                            required property var modelData

                            width: colLeft.width
                            group: modelData
                            onActionTriggered: function (a) { root.runAction(a) }
                        }
                    }
                }

                Column {
                    id: colRight
                    visible: block.cols > 1
                    width: visible ? gridRow.colW : 0
                    spacing: Theme.spaceLg

                    Repeater {
                        model: block.wide ? [] : block.modelData.right

                        delegate: SettingsGroupCard {
                            required property var modelData

                            width: colRight.width
                            group: modelData
                            onActionTriggered: function (a) { root.runAction(a) }
                        }
                    }
                }
            }
        }
    }
}
