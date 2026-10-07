import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../widgets"

/**
 * PanelSwitcher — the right-click menu of every island panel.
 *
 * Right-clicking the island grows it into this panel: one rounded container of
 * evenly spaced icon+label tiles (the same look as the Session panel) listing
 * every panel the island can show. Choosing a tile switches the island straight
 * to it.
 *
 * Keyboard: ←/→/↑/↓ move the highlight, Enter activates, Esc closes. The shell
 * grants this panel exclusive keyboard focus while it is open (see shell.qml).
 */
Rectangle {
    id: root

    /// Bubbled up so the island can collapse after a choice / on Esc.
    signal requestClose()

    /// Bubbled up when a panel tile is chosen: the key matches PanelStack's
    /// panel names ("control", "themes", "wallpapers", "apps", "session",
    /// "overview").
    signal panelChosen(string key)

    /// The panel the island was showing before the switcher opened, so its tile
    /// starts highlighted.
    property string current: "control"

    readonly property var entries: [
        { key: "control",    icon: "\uF1DE", label: "Control Center" }, // nf-fa-sliders
        { key: "apps",       icon: "\uF00A", label: "Apps" },           // nf-fa-th
        { key: "wallpapers", icon: "\uF03E", label: "Wallpapers" },     // nf-fa-picture_o
        { key: "themes",     icon: "\uEFCC", label: "Themes" },         // nf-fa-palette
        { key: "session",    icon: "\uF011", label: "Session" },        // nf-fa-power_off
        { key: "overview",   icon: "\uF009", label: "Overview" }        // nf-fa-th_large
    ]

    readonly property int columns: 3
    readonly property int tileHeight: 56

    implicitHeight: Math.ceil(entries.length / columns) * tileHeight
        + (Math.ceil(entries.length / columns) - 1) * Theme.spaceSm
        + Theme.spaceSm * 2
    radius: Theme.radiusCard
    color: "transparent"

    /// Index of the highlighted tile.
    property int selected: 0
    Component.onCompleted: {
        for (var i = 0; i < entries.length; i++) {
            if (entries[i].key === current) {
                selected = i
                break
            }
        }
        forceActiveFocus()
    }

    // ── Keyboard ─────────────────────────────────────────────────────────────
    focus: true
    onVisibleChanged: if (visible) forceActiveFocus()

    function move(delta) {
        var n = root.entries.length
        if (n === 0)
            return
        root.selected = (root.selected + delta + n) % n
    }

    function activate(index) {
        var e = root.entries[index]
        if (!e)
            return
        root.panelChosen(e.key)
        root.requestClose()
    }

    Keys.onLeftPressed: move(-1)
    Keys.onRightPressed: move(1)
    Keys.onUpPressed: move(-root.columns)
    Keys.onDownPressed: move(root.columns)
    Keys.onReturnPressed: activate(root.selected)
    Keys.onEnterPressed: activate(root.selected)
    Keys.onEscapePressed: root.requestClose()

    GridLayout {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        columns: root.columns
        columnSpacing: Theme.spaceSm
        rowSpacing: Theme.spaceSm

        Repeater {
            model: root.entries

            delegate: Rectangle {
                required property var modelData
                required property int index

                readonly property bool isSelected: index === root.selected

                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.tileHeight
                radius: Theme.radiusInner

                HoverHandler {
                    id: btnHover
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: if (hovered) root.selected = index
                }

                color: isSelected
                    ? Theme.accent
                    : (btnHover.hovered ? Theme.surfaceHover : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.motionFast } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Theme.spaceXs

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.icon
                        color: isSelected ? Theme.backgroundSolid : Theme.textPrimary
                        font.family: Theme.iconFont
                        font.pixelSize: Theme.toggleIconSize
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.label
                        color: isSelected ? Theme.backgroundSolid : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.subtitleSize
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activate(index)
                }
            }
        }
    }
}
