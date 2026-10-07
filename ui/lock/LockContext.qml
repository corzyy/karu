import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

/**
 * LockContext — everything the lock surfaces share.
 *
 * One LockContext lives in `shell.qml`; every monitor's `Lockscreen` is handed
 * the same object, so the password typed on one screen appears on the others
 * and a single PAM conversation authenticates the whole session.
 *
 * Authentication goes through `Quickshell.Services.Pam` using the private
 * config in `ui/lock/pam/password.conf` (password only). On success the
 * `unlocked()` signal tells the shell to release the session lock.
 */
Scope {
    id: root

    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false

    property string userName: Quickshell.env("USER") || "user"
    property string fullName: ""
    property string avatarPath: ""

    /// Name shown under the avatar: the passwd GECOS name, else the login name
    /// with a capital first letter.
    readonly property string displayName: fullName.length > 0 ? fullName : capitalize(userName)

    function capitalize(s) {
        return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : s
    }

    /// Clear the field and any error state (called when the lock is engaged).
    function reset() {
        currentText = ""
        showFailure = false
        unlockInProgress = false
    }

    // Clear the error as soon as the user starts typing again.
    onCurrentTextChanged: if (showFailure) showFailure = false

    function tryUnlock() {
        if (currentText === "" || unlockInProgress)
            return
        unlockInProgress = true
        pam.start()
    }

    PamContext {
        id: pam

        // Directory is resolved relative to this file, so the config stays
        // inside the Karu folder instead of /etc/pam.d.
        configDirectory: "pam"
        config: "password.conf"

        // pam_unix prompts for the password and expects it as the response.
        onPamMessage: if (this.responseRequired) this.respond(root.currentText)

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlocked()
            } else {
                root.currentText = ""
                root.showFailure = true
                root.failed()
            }
            root.unlockInProgress = false
        }
    }

    // ── User presentation data ───────────────────────────────────────────────
    // Full name from the passwd GECOS field (falls back to $USER).
    Process {
        id: gecos
        command: ["sh", "-c", "getent passwd \"$1\" | cut -d: -f5 | cut -d, -f1", "sh", root.userName]
        stdout: StdioCollector {
            id: gecosOut
            waitForEnd: true
            onStreamFinished: root.fullName = String(gecosOut.text).trim()
        }
    }

    // First existing avatar among the usual locations; empty means "use the
    // placeholder glyph".
    Process {
        id: avatarFinder
        command: ["sh", "-c",
            "for f in \"$HOME/.face\" \"$HOME/.face.icon\" \"/var/lib/AccountsService/icons/$1\"; do " +
            "if [ -f \"$f\" ]; then printf '%s' \"$f\"; break; fi; done",
            "sh", root.userName]
        stdout: StdioCollector {
            id: avatarOut
            waitForEnd: true
            onStreamFinished: root.avatarPath = String(avatarOut.text).trim()
        }
    }

    Component.onCompleted: {
        gecos.running = true
        avatarFinder.running = true
    }
}
