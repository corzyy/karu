pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

/**
 * Polkit — the shell's polkit authentication agent.
 *
 * One `PolkitAgent` registers this shell as the session's
 * org.freedesktop.PolicyKit1.AuthenticationAgent, so when an application asks
 * polkit to authorize a privileged action the request lands here instead of in
 * a separate agent window. `flow` is the live `AuthFlow` while a request is
 * pending and null otherwise; the UI (ui/panels/PolkitPanel.qml) reads
 * its message/prompt and answers the flow directly.
 *
 * The prompt is not a standalone window: shell.qml listens for `requestStarted`
 * and grows the main island into the authentication card, so the prompt merges
 * with the rest of the shell instead of floating on its own.
 *
 * Registering here means any other authentication agent (hyprpolkitagent,
 * polkit-gnome, …) must not also be running for the session, or the two will
 * race for the DBus name.
 */
Singleton {
    id: root

    // ── The agent ────────────────────────────────────────────────────────────
    /// The current authentication flow, or null when nothing is pending.
    readonly property var flow: agent.flow
    /// True while an authentication request is in progress.
    readonly property bool active: agent.isActive

    /// A new authentication request has begun: grow the island into the prompt.
    signal requestStarted()
    /// The request finished (succeeded, failed or was cancelled): put the island
    /// back the way it was.
    signal requestEnded()

    PolkitAgent {
        id: agent
        path: "/org/quickshell/karu/Polkit"
        onAuthenticationRequestStarted: root.requestStarted()
        onIsActiveChanged: if (!root.active) root.requestEnded()
    }
}
