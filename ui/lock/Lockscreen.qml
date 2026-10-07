import QtQuick
import QtQuick.Effects
import Quickshell

import "../../core/theme"
import "../../core/services"

/**
 * Lockscreen — the visible lock surface, styled after the macOS lock screen.
 *
 * Layout, top to bottom:
 *   • blurred + dimmed wallpaper filling the screen
 *   • the date and a large, thin clock near the top centre
 *   • centred vertically: the account avatar, the user's name, and a rounded
 *     password field that authenticates through the shared `LockContext`
 *
 * One instance is created per monitor by `WlSessionLock`; all of them share the
 * same `LockContext`, so the typed password is mirrored across screens.
 */
Item {
    id: root

    required property LockContext context

    // Which output this lock surface belongs to. `shell.qml` binds it from the
    // enclosing WlSessionLockSurface, since one Lockscreen is created per screen.
    property var surfaceScreen: null

    // Only the monitor the bar lives on shows the clock and the login field, so
    // the other displays just get the blurred wallpaper (macOS-style). When no
    // screen is supplied (the lock-test.qml preview) we default to showing them.
    readonly property bool isMainScreen:
        surfaceScreen === null || surfaceScreen.name === Theme.barMonitor

    // The live wallpaper, unless the environment overrides it (used by the
    // lock-test.qml preview so it never re-applies a wallpaper).
    readonly property string wallpaperPath:
        Quickshell.env("KARU_LOCK_WALLPAPER") || Wallpaper.currentPath

    property var now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    readonly property string timeText: Qt.formatDateTime(root.now, "HH:mm")

    // Quickshell does not pick up the system locale for Qt.formatDateTime, so
    // resolve it from the environment ourselves (de_DE.UTF-8 -> de_DE).
    readonly property string localeName: {
        var l = Quickshell.env("LC_ALL") || Quickshell.env("LC_TIME") || Quickshell.env("LANG") || "";
        l = String(l).split(".")[0].split("@")[0];
        return (l === "" || l === "C" || l === "POSIX") ? "en" : l;
    }
    readonly property string dateText:
        Qt.locale(root.localeName).toString(root.now, "dddd, d. MMMM")

    // ── Entrance / dismissal motion ──────────────────────────────────────────
    // `reveal` runs 0 → 1 once the surface is up and `revealLogin` follows it a
    // beat later, so the clock and the login cluster settle into place one after
    // the other instead of snapping on. `leaving` runs 0 → 1 when the password
    // is accepted; the same elements then disperse (clock up, login down) and
    // the surface calls `exitDone()` so the shell can release the session lock
    // only once the transition has actually been seen.
    property real reveal: 0
    property real revealLogin: 0
    property real leaving: 0

    signal exitDone()

    NumberAnimation {
        id: revealAnim
        target: root
        property: "reveal"
        to: 1
        duration: Theme.lockRevealDuration
        easing.type: Theme.easeOut
    }

    SequentialAnimation {
        id: revealLoginAnim
        PauseAnimation { duration: Theme.lockRevealStagger }
        NumberAnimation {
            target: root
            property: "revealLogin"
            to: 1
            duration: Theme.lockRevealDuration
            easing.type: Theme.easeOut
        }
    }

    SequentialAnimation {
        id: leaveAnim
        NumberAnimation {
            target: root
            property: "leaving"
            to: 1
            duration: Theme.lockLeaveDuration
            easing.type: Theme.easeEmphasized
        }
        // Only now is it safe for the shell to drop the lock surface.
        onFinished: root.exitDone()
    }

    Component.onCompleted: {
        revealAnim.start()
        revealLoginAnim.start()
    }

    Connections {
        target: root.context
        // Animate from 0 → 1; setting `leaving` directly would snap the fade.
        function onUnlocked() { leaveAnim.start() }
    }

    // ── Background: blurred, dimmed wallpaper ────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#0B0B0E"
    }

    // The wallpaper, its blur and its dim live in one layer so the whole
    // backdrop fades as a unit. That matters: the blur effect is translucent
    // while it ramps, so if the sharp image under it kept full opacity the
    // opening frame — where blur and dim are still zero — would flash the raw,
    // bright wallpaper for a frame before the blur covers it.
    Item {
        anchors.fill: parent
        // Reach full opacity by ~two-thirds of the reveal, where the blur is
        // already ~64px and soft — so the backdrop is never both opaque and
        // sharp, and the dark gap stays short. It stays opaque on the way out
        // (reveal == 1), letting the blur fade out over a solid image.
        opacity: Math.min(1, root.reveal * 1.5)

        Image {
            id: wallpaper
            anchors.fill: parent
            // Slightly oversized so the blur never samples past the edges; it
            // eases back a touch on entry (a soft settle) and pushes in again on
            // the way out, so the backdrop breathes with the foreground.
            scale: 1.08 + (1 - root.reveal) * 0.06 + root.leaving * 0.05
            source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        // A heavy blur is what gives the macOS lock screen its soft backdrop.
        // It fades in with the reveal and back out on unlock, so the wallpaper
        // is sharp again as the lock lifts (matching the desktop it uncovers).
        MultiEffect {
            anchors.fill: parent
            source: wallpaper
            blurEnabled: true
            blur: root.reveal * (1 - root.leaving)
            blurMax: Theme.lockBlurMax
            autoPaddingEnabled: true
        }

        // Dims the blurred backdrop; darkens in with the reveal and lifts with
        // the blur on the way out.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: Theme.lockDim * (1 - root.leaving)
        }
    }

    // ── Clock ─────────────────────────────────────────────────────────────────
    Column {
        visible: root.isMainScreen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.085)
        spacing: -4
        opacity: root.reveal * (1 - root.leaving)
        // Enters from just above and lifts away on unlock.
        transform: Translate {
            y: (1 - root.reveal) * -20 + root.leaving * -28
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.dateText
            color: Qt.rgba(1, 1, 1, 0.94)
            font.family: Theme.lockFont
            font.weight: Font.DemiBold
            font.pixelSize: Theme.lockDateSize
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeText
            color: "white"
            font.family: Theme.lockFont
            font.weight: Font.Bold
            font.pixelSize: Theme.lockClockSize
            // The native renderer looks crisper at display sizes.
            renderType: Text.NativeRendering
        }
    }

    // ── Avatar · name · password ──────────────────────────────────────────────
    Column {
        visible: root.isMainScreen
        anchors.horizontalCenter: parent.horizontalCenter
        // macOS sits the avatar / password field low on the screen, well below
        // centre, so anchor to the bottom rather than the middle.
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(parent.height * 0.15)
        spacing: 20
        opacity: root.revealLogin * (1 - root.leaving)
        // Enters from just below (a beat after the clock) and sinks away on
        // unlock, mirroring the clock's lift.
        transform: Translate {
            y: (1 - root.revealLogin) * 24 + root.leaving * 30
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.lockAvatarSize
            height: Theme.lockAvatarSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.28)

                Image {
                    id: avatarImage
                    anchors.fill: parent
                    anchors.margins: 2
                    source: root.context.avatarPath ? "file://" + root.context.avatarPath : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !avatarImage.visible
                    text: "\uF007" // nf-fa-user
                    color: Qt.rgba(1, 1, 1, 0.82)
                    font.family: Theme.iconFont
                    font.pixelSize: 46
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.context.displayName
            color: "white"
            font.family: Theme.lockFont
            font.weight: Font.Medium
            font.pixelSize: 18
        }

        // Password field ──────────────────────────────────────────────────────
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter

            width: 236
            height: 34
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.16)
            // A small pop as the field arrives, so the pin box lands rather than
            // just fading in.
            scale: 0.94 + 0.06 * root.revealLogin
            transformOrigin: Item.Center
            border.width: 1
            border.color: root.context.showFailure
                ? Theme.danger
                : (input.activeFocus ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.28))
            Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

            // Small wobble on a failed attempt.
            transform: Translate { id: fieldShift }
            SequentialAnimation {
                id: shake
                NumberAnimation { target: fieldShift; property: "x"; to: -9; duration: 45 }
                NumberAnimation { target: fieldShift; property: "x"; to: 9;  duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: -6; duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: 6;  duration: 90 }
                NumberAnimation { target: fieldShift; property: "x"; to: 0;  duration: 60 }
            }
            Connections {
                target: root.context
                function onFailed() { shake.restart() }
            }

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 38
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter

                color: "white"
                selectionColor: Theme.accent
                selectedTextColor: Theme.backgroundSolid
                font.family: Theme.lockFont
                font.pixelSize: 14
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                selectByMouse: true
                focus: true
                enabled: !root.context.unlockInProgress && root.leaving < 0.01

                onTextChanged: {
                    if (root.context.currentText !== text)
                        root.context.currentText = text;
                }
                onAccepted: root.context.tryUnlock()

                // Keep every screen's field in sync with the shared text.
                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (input.text !== root.context.currentText)
                            input.text = root.context.currentText;
                    }
                }
            }

            // Placeholder / error text.
            Text {
                anchors.centerIn: parent
                visible: input.text.length === 0
                text: root.context.showFailure ? "Incorrect password" : "Enter Password"
                color: root.context.showFailure ? Theme.danger : Qt.rgba(1, 1, 1, 0.62)
                font.family: Theme.lockFont
                font.pixelSize: 14
            }

            // Submit affordance, macOS-style: appears once something is typed.
            Rectangle {
                visible: input.text.length > 0
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: 12
                color: root.context.unlockInProgress
                    ? Qt.rgba(1, 1, 1, 0.4)
                    : Qt.rgba(1, 1, 1, 0.92)

                Text {
                    anchors.centerIn: parent
                    text: "\uF105" // nf-fa-angle_right
                    color: "#111114"
                    font.family: Theme.iconFont
                    font.pixelSize: 15
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.context.unlockInProgress && root.leaving < 0.01
                    onClicked: root.context.tryUnlock()
                }
            }
        }
    }
}
