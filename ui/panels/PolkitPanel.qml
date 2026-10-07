import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/services"
import "../widgets"

/**
 * PolkitPanel — the polkit authentication card, rendered as an island panel.
 *
 * Rather than living in its own window (like hyprpolkitagent), the prompt grows
 * straight out of the main island: shell.qml sets the island's `expanded` state
 * and selects this panel when `Polkit.requestStarted` fires, so the prompt is
 * the island — same fill, border, corner radius, fonts and accent. The panel
 * only draws the inner pieces: the icon + title header, the message card, the
 * password field and the Cancel / Authenticate buttons.
 *
 * The live `AuthFlow` (core/services/Polkit.qml) supplies the message, the action id,
 * the input prompt and any error text; a password is handed back with
 * `flow.submit()` and the request is dropped with `flow.cancelAuthenticationRequest()`.
 */
ColumnLayout {
    id: root

    readonly property var flow: Polkit.flow
    readonly property string message:
        (flow && flow.message && flow.message.length > 0)
            ? flow.message : "Authentication required"
    readonly property string actionId: (flow && flow.actionId) ? flow.actionId : ""
    readonly property string prompt: {
        var p = (flow && flow.inputPrompt) ? String(flow.inputPrompt) : "Password"
        // polkit sends prompts like "Password: "; the label reads cleaner
        // without the trailing punctuation.
        return p.replace(/[:\s]+$/, "") || "Password"
    }
    readonly property bool needsResponse: flow ? flow.isResponseRequired : false
    readonly property bool responseVisible: flow ? flow.responseVisible : false
    readonly property string errorText:
        (flow && flow.supplementaryIsError && flow.supplementaryMessage)
            ? flow.supplementaryMessage : ""
    readonly property bool hasError: errorText.length > 0

    /// True from the moment a password is submitted until polkit asks again or
    /// reports the result; the field and buttons are held while it is set.
    property bool busy: false

    spacing: Theme.gap

    // ── Actions ───────────────────────────────────────────────────────────────
    function authenticate() {
        if (!flow || root.busy || input.text.length === 0)
            return
        root.busy = true
        flow.submit(input.text)
        input.text = ""
    }

    function cancel() {
        root.busy = false
        if (flow)
            flow.cancelAuthenticationRequest()
    }

    // Esc cancels from anywhere in the prompt (the island is not collapsible
    // while a request is pending, so this is the keyboard way out).
    Shortcut {
        sequence: "Escape"
        onActivated: root.cancel()
    }

    // polkit re-prompts after a wrong password (same flow) and clears `busy` so
    // the user can try again; a hard failure ends the flow and the island
    // collapses, but reset anyway so a reused panel never stays stuck.
    Connections {
        target: root.flow
        function onIsResponseRequiredChanged() {
            if (root.flow && root.flow.isResponseRequired) {
                root.busy = false
                input.forceActiveFocus()
            }
        }
        function onSupplementaryMessageChanged() { root.busy = false }
        function onAuthenticationFailed() {
            root.busy = false
            input.forceActiveFocus()
        }
    }

    // Watchdog: never leave the buttons held if polkit goes quiet.
    Timer {
        interval: 10000
        running: root.busy
        onTriggered: root.busy = false
    }

    // ── Header: icon + title ─────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceMd

        Rectangle {
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            radius: width / 2
            color: Theme.accent

            Text {
                anchors.centerIn: parent
                text: "\uF023" // nf-fa-lock
                color: Theme.backgroundSolid
                font.family: Theme.iconFont
                font.pixelSize: 14
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: "Authentication required"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize + 2
            font.weight: Font.Medium
            elide: Text.ElideRight
        }
    }

    // ── Message card ─────────────────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: messageColumn.implicitHeight + Theme.cardPadding * 2
        radius: Theme.radiusInner
        color: "transparent"
        gradient: TileGlass {}
        border.width: 1
        border.color: Theme.border

        ColumnLayout {
            id: messageColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.cardPadding
            anchors.rightMargin: Theme.cardPadding
            spacing: Theme.spaceXs

            Text {
                Layout.fillWidth: true
                text: root.message
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Text {
                Layout.fillWidth: true
                visible: root.actionId.length > 0
                text: root.actionId
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                elide: Text.ElideRight
                maximumLineCount: 1
                textFormat: Text.PlainText
            }
        }
    }

    // ── Password field ───────────────────────────────────────────────────────
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: root.needsResponse ? implicitHeight : 0
        visible: root.needsResponse
        implicitHeight: promptLabel.implicitHeight + Theme.spaceXs + field.height

        Text {
            id: promptLabel
            anchors.left: parent.left
            text: root.prompt
            color: root.hasError ? Theme.danger : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.titleSize - 1
            Behavior on color { ColorAnimation { duration: Theme.motionFast } }
        }

        Rectangle {
            id: field
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: promptLabel.bottom
            anchors.topMargin: Theme.spaceXs
            height: 44
            radius: height / 2
            color: Theme.surfaceElevated
            border.width: 1
            border.color: root.hasError
                ? Theme.danger
                : (input.activeFocus ? Theme.accent : Theme.border)

            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            // A small shake on a rejected password.
            transform: Translate { id: fieldShift }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: fieldShift; property: "x"; to: -7; duration: 45 }
                NumberAnimation { target: fieldShift; property: "x"; to: 7;  duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: -5; duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: 5;  duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: 0;  duration: 60 }
            }
            Connections {
                target: root.flow
                function onAuthenticationFailed() { shake.restart() }
            }

            Rectangle {
                id: fieldIcon
                anchors.left: parent.left
                anchors.leftMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: width / 2
                color: Theme.accent

                Text {
                    anchors.centerIn: parent
                    text: "\uF023" // nf-fa-lock
                    color: Theme.backgroundSolid
                    font.family: Theme.iconFont
                    font.pixelSize: 13
                }
            }

            TextInput {
                id: input
                anchors.left: fieldIcon.right
                anchors.leftMargin: Theme.spaceMd
                anchors.right: parent.right
                anchors.rightMargin: Theme.padRow
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize + 1
                echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
                selectionColor: Theme.accent
                selectedTextColor: Theme.backgroundSolid
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                selectByMouse: true
                focus: true
                enabled: !root.busy
                onAccepted: root.authenticate()
                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // ── Error / status line ──────────────────────────────────────────────────
    Text {
        Layout.fillWidth: true
        visible: root.hasError
        text: root.errorText
        color: Theme.danger
        font.family: Theme.fontFamily
        font.pixelSize: Theme.subtitleSize
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
    }

    // ── Buttons ──────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceMd

        Item { Layout.fillWidth: true }

        // Cancel — a quiet, dark pill.
        Rectangle {
            Layout.preferredWidth: 96
            Layout.preferredHeight: 36
            radius: height / 2
            color: cancelHover.hovered ? Theme.surfaceHover : Theme.surface
            border.width: 1
            border.color: Theme.border

            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

            HoverHandler { id: cancelHover; cursorShape: Qt.PointingHandCursor }

            Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancel()
            }
        }

        // Authenticate — the accent-filled primary action.
        Rectangle {

            Layout.preferredWidth: 128
            Layout.preferredHeight: 36
            radius: height / 2
            color: !root.needsResponse || root.busy
                ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4)
                : (authHover.hovered ? Qt.lighter(Theme.accent, 1.08) : Theme.accent)

            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

            HoverHandler { id: authHover; cursorShape: Qt.PointingHandCursor }

            Text {
                anchors.centerIn: parent
                text: root.busy ? "Authenticating…" : "Authenticate"
                color: Theme.backgroundSolid
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.DemiBold
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: (root.needsResponse && !root.busy)
                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: root.needsResponse && !root.busy
                onClicked: root.authenticate()
            }
        }
    }
}
