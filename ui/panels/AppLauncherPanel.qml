import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

import "../../core/theme"
import "../../core/config"
import "../widgets"

/**
 * AppLauncherPanel — a working application launcher.
 *
 * The Apps tab: a live search field over every installed desktop entry. Type to
 * filter, ↑/↓ (or hover) to move the selection, Enter / click to launch, Esc to
 * clear the query (or dismiss the island when the query is already empty).
 *
 * Entries come from Quickshell's `DesktopEntries` singleton, so the list is
 * always in sync with the applications actually installed on the system.
 */
ColumnLayout {
    id: root
    spacing: Theme.spaceSm

    /// Emitted when the launcher wants the island to collapse (after launching
    /// an app, or on Esc with an empty query). PanelStack forwards this up.
    signal requestClose()

    /// While a query is being edited we ask the island not to collapse even if
    /// the pointer drifts off, so typing is not interrupted (see shell.qml).
    readonly property bool keepOpen: searchField.activeFocus && searchField.text.length > 0

    property string query: ""
    property int selected: 0

    readonly property int visibleRows: Settings.launcherRows

    // Compact metrics for the launcher's single-line rows.
    readonly property int rowHeight: Settings.launcherRowHeight
    readonly property int rowIconSize: Settings.launcherIconSize

    // ── Model ────────────────────────────────────────────────────────────────
    // Every launchable desktop entry, sorted by name. `noDisplay` entries are
    // hidden as they are not meant to appear in menus.
    readonly property var allApps: {
        var list = DesktopEntries.applications.values.slice()
        list = list.filter(function(app) {
            return app && !app.noDisplay && app.name && app.name.length > 0
        })
        list.sort(function(a, b) {
            return String(a.name).localeCompare(String(b.name))
        })
        return list
    }

    // Filtered by the current query (case-insensitive, across name / generic
    // name / comment / keywords / categories).
    readonly property var results: {
        var q = root.query.trim().toLowerCase()
        if (q === "")
            return root.allApps

        var out = []
        for (var i = 0; i < root.allApps.length; i++) {
            var app = root.allApps[i]
            var haystack = [
                app.name,
                app.genericName,
                app.comment,
                (app.keywords || []).join(" "),
                (app.categories || []).join(" ")
            ].join(" ").toLowerCase()

            if (haystack.indexOf(q) !== -1)
                out.push(app)
        }
        return out
    }

    onQueryChanged: root.selected = 0
    onResultsChanged: {
        if (root.selected >= root.results.length)
            root.selected = Math.max(0, root.results.length - 1)
    }
    onSelectedChanged: if (listView) listView.positionViewAtIndex(root.selected, ListView.Contain)

    function move(delta) {
        if (root.results.length === 0)
            return
        root.selected = (root.selected + delta + root.results.length) % root.results.length
    }

    function launch(index) {
        var app = root.results[index]
        if (!app)
            return
        app.execute()
        searchField.text = ""
        root.query = ""
        root.requestClose()
    }

    function handleEscape() {
        if (searchField.text.length > 0) {
            searchField.text = ""
            root.query = ""
            searchField.forceActiveFocus()
        } else {
            root.requestClose()
        }
    }

    // ── Search field ─────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.tabHeight
        radius: Theme.radiusInner
        color: Theme.surfaceElevated
        border.width: 1
        border.color: searchField.activeFocus ? Theme.accent : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        // Clicking anywhere in the field (icon, padding) focuses the input.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: searchField.forceActiveFocus()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padRow
            anchors.rightMargin: Theme.padRow
            spacing: Theme.spaceMd

            Text {
                text: "\uF002" // nf-fa-search
                color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                font.family: Theme.iconFont
                font.pixelSize: 14
            }

            // TextInput + placeholder share one cell so the placeholder
            // overlays the (empty) input rather than sitting beside it.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: searchField.implicitHeight

                TextInput {
                    id: searchField

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.backgroundSolid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    clip: true
                    focus: true

                    // Claim the keyboard the moment the launcher opens so the
                    // user can type immediately (same pattern as the Themes
                    // carousel). The shell grants the surface keyboard focus
                    // while this tab is open — see shell.qml.
                    Component.onCompleted: forceActiveFocus()
                    onVisibleChanged: if (visible) forceActiveFocus()

                    onTextChanged: root.query = text
                    onActiveFocusChanged: if (activeFocus) root.selected = 0

                    Keys.onUpPressed: root.move(-1)
                    Keys.onDownPressed: root.move(1)
                    Keys.onReturnPressed: root.launch(root.selected)
                    Keys.onEnterPressed: root.launch(root.selected)
                    Keys.onEscapePressed: root.handleEscape()
                    Keys.onPressed: function(event) {
                        // Ctrl+P / Ctrl+N behave like ↑ / ↓.
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_P) { root.move(-1); event.accepted = true }
                            else if (event.key === Qt.Key_N) { root.move(1); event.accepted = true }
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length === 0
                    text: "Search applications…"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    enabled: false
                }
            }

            Text {
                text: root.results.length + (root.results.length === 1 ? " result" : " results")
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }
        }
    }

    // ── Result list ──────────────────────────────────────────────────────────
    Rectangle {
        id: list
        readonly property int rowSpacing: Theme.spaceXs

        Layout.fillWidth: true
        // Height derives from the actual rows so it can never desync:
        //   padding top+bottom + rows + gaps between rows.
        implicitHeight: Theme.spaceXs * 2
            + root.visibleRows * root.rowHeight
            + (root.visibleRows - 1) * rowSpacing
        radius: Theme.radiusCard
        color: "transparent"
        gradient: TileGlass {}
        border.width: 1
        border.color: Theme.border
        clip: true

        // Keyboard navigation should keep the selection on screen.
        onVisibleChanged: if (visible) listView.positionViewAtIndex(root.selected, ListView.Contain)

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: Theme.spaceXs
            clip: true
            spacing: list.rowSpacing
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            delegate: Rectangle {
                id: row

                required property var modelData
                required property int index

                readonly property var app: modelData
                readonly property bool isSelected: index === root.selected

                width: listView.width
                height: root.rowHeight
                radius: Theme.radiusInner
                color: isSelected
                    ? Theme.surfaceElevated
                    : (rowHover.hovered ? Theme.surfaceHover : "transparent")
                border.width: 1
                border.color: isSelected ? Theme.accent : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                HoverHandler {
                    id: rowHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selected = row.index
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceSm
                    anchors.rightMargin: Theme.spaceSm
                    spacing: Theme.spaceSm

                    Rectangle {
                        Layout.preferredWidth: root.rowIconSize
                        Layout.preferredHeight: root.rowIconSize
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.radiusInner
                        color: Theme.iconCircle

                        IconImage {
                            id: appIcon
                            anchors.fill: parent
                            anchors.margins: 3
                            source: row.app && row.app.icon
                                ? Quickshell.iconPath(row.app.icon)
                                : ""
                            visible: status === Image.Ready
                        }

                        // Fallback glyph when the theme has no icon for the entry.
                        Text {
                            anchors.centerIn: parent
                            visible: !appIcon.visible
                            text: "\uF2DB" // nf-linux-generic / generic app
                            color: row.isSelected ? Theme.accent : Theme.textPrimary
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: row.app ? row.app.name : ""
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleSize
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }

                TapHandler {
                    onTapped: root.launch(row.index)
                }
            }
        }

        // Empty state.
        Text {
            anchors.centerIn: parent
            visible: root.results.length === 0
            text: "No applications found"
            color: Theme.textDim
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize
        }
    }
}
