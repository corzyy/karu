pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "../../ui/widgets"

/**
 * Brightness — every DDC/CI monitor, driven with `ddcutil`.
 *
 * On first use it runs `ddcutil detect --brief`, turns each detected display
 * into a `BrightnessDisplay` (one per I2C bus) and reads its current
 * brightness. The Control Center's Display slider shows `syncedValue` and
 * `setSynced()` moves every screen together; the Display detail panel
 * (`ui/panels/BrightnessPanel.qml`) exposes the per-screen objects so they can
 * be tuned independently.
 *
 * Target selection: by default every detected display is used. Set
 * `KARU_DDC_BUS` (I2C bus number) or `KARU_DDC_CONNECTOR` (a DRM connector
 * suffix such as "DP-1") to restrict it to specific screens.
 *
 * ddcutil needs read/write access to `/dev/i2c-*`. Without it detection finds
 * nothing and `status` explains why; the UI stays a harmless placeholder.
 *
 * NOTE: the root is an `Item`, not a `QtObject`, so the `Process` child and the
 * dynamically-created `BrightnessDisplay` items can be declared/parented below.
 * It is never shown.
 */
Item {
    id: root

    /// One `BrightnessDisplay` per usable monitor (a QObject list).
    property var displays: []

    /// What the main slider falls back to while no monitor is reachable (so it
    /// is still draggable as a placeholder instead of frozen at one value).
    property real fallbackValue: 0.6

    /// Average of the live per-display values — what the main slider shows.
    /// With no displays at all it defers to `fallbackValue`.
    readonly property real syncedValue: {
        if (displays.length === 0)
            return fallbackValue
        var sum = 0
        var n = 0
        for (var i = 0; i < displays.length; i++) {
            if (displays[i].available) {
                sum += displays[i].value
                n++
            }
        }
        return n > 0 ? sum / n : 0.5
    }

    /// Human-readable reason the slider is inert, or "" when all is well.
    property string status: ""

    /// Optional target overrides (see the file comment).
    readonly property int wantBus: {
        var b = parseInt(String(Quickshell.env("KARU_DDC_BUS") || ""), 10)
        return isNaN(b) ? -1 : b
    }
    readonly property string wantConnector: String(Quickshell.env("KARU_DDC_CONNECTOR") || "")

    Component { id: displayComp; BrightnessDisplay {} }

    /// Find the monitors and read their brightness (no-op while already busy).
    function discover() {
        if (detect.running)
            return
        detect.running = true
    }

    /// Discover the monitors if none are known yet, otherwise re-read them.
    /// Called whenever the Control Center opens, so access granted after launch
    /// starts working without restarting the shell.
    function ensure() {
        if (displays.length === 0)
            discover()
        else
            refresh()
    }

    /// Re-read every display's brightness from hardware.
    function refresh() {
        for (var i = 0; i < displays.length; i++)
            displays[i].refresh()
    }

    /// Move every screen to the same 0..1 level.
    function setSynced(v) {
        if (displays.length === 0) {
            fallbackValue = v
            return
        }
        for (var i = 0; i < displays.length; i++)
            displays[i].setValue(v)
    }

    Process {
        id: detect
        command: ["ddcutil", "detect", "--brief"]
        // Parse from the stdout collector's own completion — `onExited` can fire
        // before the collector has the text, which would look like "no displays".
        stdout: StdioCollector {
            id: detectOut
            waitForEnd: true
            onStreamFinished: root.handleDetect(detectOut.text, detectErr.text)
        }
        stderr: StdioCollector {
            id: detectErr
            waitForEnd: true
            // stderr may finish after stdout; make sure the access hint lands
            // whichever collector completes last.
            onStreamFinished: {
                if (root.displays.length === 0
                        && String(detectErr.text).indexOf("Permission denied") >= 0)
                    root.status = "ddcutil cannot access /dev/i2c-* — add your user or a udev rule"
            }
        }
    }

    function handleDetect(text, errText) {
        // Parse the brief report into { bus, connector } entries. Each display
        // block starts at "Display N" and lists its I2C bus then DRM connector.
        var lines = String(text).split("\n")
        var entries = []
        var cur = null
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            if (/^\s*Display\s+\d+\s*$/.test(line)) {
                if (cur)
                    entries.push(cur)
                cur = { bus: -1, connector: "" }
                continue
            }
            if (!cur)
                continue
            var bm = line.match(/\/dev\/i2c-(\d+)/)
            if (bm) {
                cur.bus = parseInt(bm[1], 10)
                continue
            }
            var cm = line.match(/DRM connector:\s*(\S+)/)
            if (cm)
                cur.connector = cm[1]
        }
        if (cur)
            entries.push(cur)

        // Keep only usable entries, then apply the optional overrides.
        var usable = []
        var seenBus = ({})
        for (i = 0; i < entries.length; i++) {
            var e = entries[i]
            if (e.bus <= 0 || seenBus[e.bus])
                continue
            seenBus[e.bus] = true
            usable.push(e)
        }

        var chosen = usable
        var busFilter = wantBus
        var connectorFilter = wantConnector
        if (busFilter > 0) {
            chosen = usable.filter(function(d) { return d.bus === busFilter })
            // Honour an explicit bus even if detection could not list it.
            if (chosen.length === 0 && !seenBus[busFilter])
                chosen = [{ bus: busFilter, connector: "" }]
        } else if (connectorFilter.length > 0) {
            chosen = usable.filter(function(d) {
                return d.connector.indexOf(connectorFilter) >= 0
            })
            if (chosen.length === 0)
                chosen = usable
        }

        var list = []
        for (i = 0; i < chosen.length; i++) {
            var d = displayComp.createObject(root, {
                "bus": chosen[i].bus,
                "connector": chosen[i].connector
            })
            if (d)
                list.push(d)
        }
        // Drop any previous controllers before swapping in the new set.
        for (var k = 0; k < displays.length; k++)
            displays[k].destroy()
        displays = list

        if (list.length === 0) {
            var err = String(errText)
            if (err.indexOf("Permission denied") >= 0 || err.indexOf("EACCES") >= 0)
                status = "ddcutil cannot access /dev/i2c-* — add your user or a udev rule"
            else
                status = "No DDC/CI displays detected"
        } else {
            status = ""
            refresh()
        }
    }

    Component.onCompleted: discover()
}
