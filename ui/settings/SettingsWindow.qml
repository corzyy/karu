import QtQuick
import Quickshell

import "../../core/theme"

/**
 * SettingsWindow — the standalone macOS-style Settings app.
 *
 * A real floating window (an xdg toplevel, not a layer-shell panel), so it
 * behaves like a normal application. It opens on SUPER + comma (through the
 * `karu` IPC), shows a searchable category sidebar on the left and the selected
 * category on the right, and edits the `Settings` singleton live — dragging a
 * slider re-themes the running shell as you move it.
 */
FloatingWindow {
    id: win

    title: "Karu Settings"
    color: "transparent"
    implicitWidth: 1000
    implicitHeight: 680
    visible: false

    /// The window chrome's close button / Escape asked the shell to hide it.
    signal closeRequested()

    property string category: "bar"

    onClosed: win.closeRequested()

    Shortcut {
        sequence: "Escape"
        onActivated: win.closeRequested()
    }

    // The app surface: a big rounded, bordered card.
    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Theme.backgroundSolid
        border.width: 1
        border.color: Theme.borderStrong
        clip: true

        SettingsSidebar {
            id: sidebar
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 236
            currentKey: win.category
            onSelected: function(key) { win.category = key }
        }

        Rectangle {
            x: sidebar.width
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            color: Theme.border
        }

        Item {
            anchors.left: sidebar.right
            anchors.leftMargin: 1
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // ── Toolbar ──────────────────────────────────────────────────────
            // Just the close button; the category name is in the page header.
            Item {
                id: toolbar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 54

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                    width: 28
                    height: 28
                    radius: width / 2
                    color: closeHover.hovered ? Theme.surfaceHover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uF00D" // nf-fa-times
                        color: closeHover.hovered ? Theme.textPrimary : Theme.textSecondary
                        font.family: Theme.iconFont
                        font.pixelSize: 12
                    }

                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.closeRequested()
                    }
                }
            }

            // ── Scrollable page ─────────────────────────────────────────────
            Flickable {
                id: flick
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: toolbar.bottom
                anchors.bottom: parent.bottom
                contentWidth: width
                contentHeight: page.implicitHeight + 40
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                SettingsPage {
                    id: page
                    x: 28
                    width: Math.max(0, flick.width - 56)
                    pageKey: win.category
                    query: sidebar.query
                }
            }
        }
    }
}
