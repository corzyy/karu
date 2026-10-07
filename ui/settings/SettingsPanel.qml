import QtQuick

import "../../core/theme"

/**
 * SettingsPanel — the Settings app docked inside the island.
 *
 * The same macOS-style UI as the floating `SettingsWindow` (a searchable
 * category sidebar on the left, the selected category on the right), but drawn
 * as an island panel: shell.qml opens it like the Control Center (grow out of
 * the pill) when `Settings.settingsDocked` is on, and `PanelStack` hosts it.
 *
 * It edits the `Settings` singleton live, exactly like the window, so dragging
 * a slider re-themes the running shell as you move it. The island provides the
 * rounded, bordered surface and clips it; this component only lays out the two
 * columns and scrolls a category that is taller than the panel.
 */
Item {
    id: root

    /// Screen of the island (injected by PanelStack) — used to cap the height so
    /// a tall page scrolls instead of growing the panel off-screen.
    property var screen: null

    /// The selected category (matches a key in Catalog.pages).
    property string category: "bar"

    /// The × / Esc asked the shell to close the docked settings.
    signal requestClose()

    readonly property int sidebarWidth: 232
    readonly property int preferredHeight: 560

    /// Grow to the preferred height, but never past the bottom of the screen.
    readonly property int maxHeight: Math.max(280,
        (root.screen ? root.screen.height : 900)
            - Theme.topMargin - Theme.panelPadding * 2 - Theme.spaceLg)
    implicitHeight: Math.min(root.preferredHeight, root.maxHeight)

    // The panel owns the keyboard while docked (shell.qml grabs exclusive
    // focus), so the sidebar search field can be typed into and Esc closes it.
    focus: true
    Component.onCompleted: forceActiveFocus()
    onVisibleChanged: if (visible) forceActiveFocus()
    Keys.onEscapePressed: root.requestClose()

    // ── Sidebar ──────────────────────────────────────────────────────────────
    SettingsSidebar {
        id: sidebar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.sidebarWidth
        currentKey: root.category
        onSelected: function (key) { root.category = key }
    }

    Rectangle {
        x: root.sidebarWidth
        width: 1
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        color: Theme.border
    }

    // ── Detail pane ──────────────────────────────────────────────────────────
    Item {
        anchors.left: sidebar.right
        anchors.leftMargin: 1
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        // Scrollable page (docked mode has no toolbar: the island's own
        // dismissal handles closing, and the header card titles the page).
        Flickable {
            id: flick
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: page.implicitHeight + Theme.spaceXl * 2
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            SettingsPage {
                id: page
                x: Theme.spaceXl
                width: Math.max(0, flick.width - Theme.spaceXl * 2)
                pageKey: root.category
                query: sidebar.query
            }
        }
    }
}
