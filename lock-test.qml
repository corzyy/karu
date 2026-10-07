import QtQuick
import Quickshell

import "ui/lock"

/**
 * lock-test.qml — preview the lockscreen as an ordinary window.
 *
 * Run it with:
 *   KARU_LOCK_WALLPAPER=/path/to/wallpaper.png qs -p lock-test.qml
 *
 * This never engages the real session lock, so it is safe to iterate on the
 * looks. `KARU_LOCK_WALLPAPER` keeps the preview from instantiating (and thus
 * re-applying) the Wallpaper singleton.
 */
ShellRoot {
    LockContext {
        id: lockContext
    }

    FloatingWindow {
        implicitWidth: 1280
        implicitHeight: 720
        color: "#000000"

        Lockscreen {
            anchors.fill: parent
            context: lockContext
            // Quit only after the dismissal animation, so the preview shows the
            // same unlock transition as the real session lock.
            onExitDone: Qt.quit()
        }
    }

    Connections {
        target: Quickshell
        function onLastWindowClosed() { Qt.quit() }
    }
}
