import QtQuick

import "../../core/theme"

/**
 * Switch — a small iOS-style on/off pill.
 *
 * Purely presentational: it renders `checked` and emits `toggled` on click; the
 * owner decides what that means (e.g. flip a Bluetooth adapter's `enabled`).
 */
Rectangle {
    id: root

    property bool checked: false

    signal toggled()

    implicitWidth: 42
    implicitHeight: 24
    radius: height / 2
    color: checked ? Theme.accent : Theme.track
    border.width: 1
    border.color: checked ? Theme.accent : Theme.border

    Behavior on color { ColorAnimation { duration: Theme.motionFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

    Rectangle {
        width: 18
        height: 18
        radius: height / 2
        y: (parent.height - height) / 2
        x: root.checked ? parent.width - width - 3 : 3
        color: Theme.textPrimary

        Behavior on x { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
