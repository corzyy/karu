pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

import "../theme"

/**
 * Notifications — the shell's notification hub.
 *
 * One `NotificationServer` owns the org.freedesktop.Notifications DBus name, so
 * every application's notifications arrive here. Two newest-first models are
 * kept:
 *
 *   toasts   banners currently dropping out of the island (capped, auto-expire)
 *   history  everything still tracked, listed in the Control Center
 *
 * The models deliberately store plain copies of the fields the UI needs (id +
 * display text) rather than the live `Notification` objects: those are destroyed
 * the moment a notification is dismissed, and all the UI needs to act on one is
 * its id. Each new notification's `closed` signal removes its entries, so the
 * models follow the server without ever reading a possibly-stale snapshot of
 * `trackedNotifications`.
 *
 * Tune the banner stack from the Notification block in Theme.qml; the
 * "Do Not Disturb" toggle in the Control Center silences banners (the
 * notification is still kept in the history).
 */
Singleton {
    id: root

    // ── The server ────────────────────────────────────────────────────────────
    /// The freedesktop notification server. Only the capabilities the UI
    /// actually uses are advertised (plain body text and background
    /// persistence); `keepOnReload` re-emits pending notifications across a
    /// shell reload (marked `lastGeneration`).
    NotificationServer {
        id: server
        keepOnReload: true
        bodySupported: true
        persistenceSupported: true

        onNotification: function (n) { root.push(n) }
    }

    // ── Do Not Disturb ────────────────────────────────────────────────────────
    // Silences the banners only; notifications are still collected in `history`.
    property bool doNotDisturb: false

    // ── Models ────────────────────────────────────────────────────────────────
    /// Banners currently dropping out of the island, newest first.
    readonly property ListModel toasts: ListModel {}
    /// Every tracked notification, newest first, for the Control Center.
    readonly property ListModel history: ListModel {}

    property int maxToasts: Theme.notificationMaxVisible
    property int maxHistory: Theme.notificationMaxHistory
    /// Fallback banner lifetime (seconds) when an app asks for none.
    property real defaultTimeout: Theme.notificationTimeout

    // ── Ingest ────────────────────────────────────────────────────────────────
    /// Track a freshly received notification and, if allowed, raise its banner.
    function push(n) {
        if (!n)
            return

        // Transient notifications are explicitly not persisted, so they are
        // shown for their lifetime and then expire; everything else is tracked
        // so it survives in the history until dismissed.
        var durable = !n.transient
        if (durable)
            n.tracked = true

        var nid = n.id
        var entry = {
            nid: nid,
            appName: n.appName || "",
            appIcon: n.appIcon || "",
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            resident: n.resident === true,
            durable: durable,
            timeout: (n.expireTimeout && n.expireTimeout > 0)
                ? n.expireTimeout : root.defaultTimeout,
            // Set by the model to ask the banner to animate itself out before
            // it is dropped (see NotificationToast.qml). A Positioner has no
            // `remove` transition, so removals are deferred until the card has
            // finished leaving.
            leaving: false
        }

        if (durable) {
            history.insert(0, entry)
            while (history.count > root.maxHistory)
                history.remove(history.count - 1)
        }

        // A banner, unless silenced or carried over from the previous reload.
        if (!root.doNotDisturb && !n.lastGeneration)
            root.showToast(entry)

        // Dismissed, expired or replaced: drop the entries with it. Capture the
        // id, not the object — the notification is destroyed as this fires.
        n.closed.connect(function () { root.forget(nid) })
    }

    function showToast(entry) {
        toasts.insert(0, entry)
        // Keep only the newest few; the older ones still live in the history.
        // Pushing one past the cap asks it to animate out rather than dropping
        // it mid-frame, so the stack reflows smoothly.
        root.pruneToasts()
    }

    /// Enforce `maxToasts` by starting an exit on the oldest banner. A banner
    /// already leaving (its exit animation is mid-flight) is removed outright so
    /// a burst of notifications can never pile up unseen.
    function pruneToasts() {
        while (toasts.count > root.maxToasts) {
            var last = toasts.count - 1
            if (toasts.get(last).leaving)
                toasts.remove(last)
            else {
                toasts.setProperty(last, "leaving", true)
                break
            }
        }
    }

    /// Ask the banner for `id` to animate itself out (auto-expiry and the
    /// overflow prune both go through here). The toast removes it once the
    /// animation has played.
    function beginLeave(id) {
        for (var i = 0; i < toasts.count; i++)
            if (toasts.get(i).nid === id)
                toasts.setProperty(i, "leaving", true)
    }

    // ── Actions ───────────────────────────────────────────────────────────────
    /// Find the live Notification behind an id, or null.
    function notificationById(id) {
        var list = server.trackedNotifications.values
        for (var i = 0; i < list.length; i++)
            if (list[i].id === id)
                return list[i]
        return null
    }

    /// Dismiss a notification (banner + history). Used by clicks and "Clear".
    function dismissById(id) {
        var n = notificationById(id)
        if (n)
            n.dismiss()
        else
            root.forget(id)
    }

    /// Forget an id, e.g. an already-destroyed transient notification.
    function forget(id) {
        for (var i = toasts.count - 1; i >= 0; i--)
            if (toasts.get(i).nid === id)
                toasts.remove(i)
        for (var j = history.count - 1; j >= 0; j--)
            if (history.get(j).nid === id)
                history.remove(j)
    }

    /// Hide a banner without touching its notification (it stays in history).
    function expireToast(id) {
        for (var i = toasts.count - 1; i >= 0; i--)
            if (toasts.get(i).nid === id)
                toasts.remove(i)
    }

    /// Dismiss everything currently known.
    function clearAll() {
        var ids = []
        for (var i = 0; i < history.count; i++)
            ids.push(history.get(i).nid)
        for (var j = 0; j < toasts.count; j++)
            ids.push(toasts.get(j).nid)
        for (var k = 0; k < ids.length; k++) {
            var n = notificationById(ids[k])
            if (n)
                n.dismiss()
            else
                root.forget(ids[k])
        }
    }

    /// Resolve an app icon (a themed name or a file path) to an image URL, or "".
    function iconSource(icon) {
        if (!icon || icon.length === 0)
            return ""
        if (icon.charAt(0) === "/")
            return "file://" + icon
        return Quickshell.iconPath(icon, "")
    }
}
