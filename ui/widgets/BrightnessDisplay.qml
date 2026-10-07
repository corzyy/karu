import QtQuick
import Quickshell.Io

/**
 * BrightnessDisplay — one DDC/CI monitor, driven with `ddcutil`.
 *
 * Owns the two processes that talk to a single I2C bus: a `getvcp 10` read of
 * the monitor's current brightness and a debounced `setvcp 10` write. The
 * `Brightness` singleton creates one of these per detected display and exposes
 * them to the UI, so each screen can be set independently.
 *
 * `value` is kept as local state rather than a live hardware binding: the
 * monitor is slow to answer, and pinning the slider to a read would make it
 * stutter while dragging. The value is re-synced from hardware by `refresh()`
 * (on discovery, and whenever the shell wants to reconcile).
 *
 * Never shown — it exists only to host the `Process` children.
 */
Item {
    id: root

    visible: false

    /// I2C bus number (`/dev/i2c-N`) and DRM connector, as ddcutil reports them.
    property int bus: -1
    property string connector: ""

    /// Friendly name: the connector without its `cardN-` prefix ("DP-1", …).
    readonly property string label: {
        if (connector.length === 0)
            return bus > 0 ? "Bus " + bus : "Display"
        var i = connector.indexOf("-")
        return i >= 0 ? connector.substring(i + 1) : connector
    }

    /// Hardware brightness range and last value read from / written to it.
    property int rawMax: 100
    property int rawValue: 0

    /// Normalised 0..1 brightness the UI binds to.
    property real value: 0.5

    /// True once a successful `getvcp` proves the monitor is reachable.
    property bool available: false

    /// Raw target queued by the debounce timer (0..rawMax).
    property int pendingRaw: -1

    function refresh() {
        if (bus <= 0)
            return
        getter.command = ["ddcutil", "--bus", String(bus), "getvcp", "10", "--terse"]
        getter.running = false
        getter.running = true
    }

    /// Set the brightness (0..1). Updates `value` immediately so a drag stays
    /// smooth, then writes to the monitor after a short idle.
    function setValue(v) {
        var val = Math.max(0, Math.min(1, v))
        value = val
        if (!available || bus <= 0)
            return
        pendingRaw = Math.round(val * rawMax)
        debounce.restart()
    }

    function commit() {
        if (bus <= 0 || !available || pendingRaw < 0)
            return
        var raw = pendingRaw
        pendingRaw = -1
        if (raw === rawValue)
            return
        rawValue = raw
        setter.command = ["ddcutil", "--bus", String(bus), "setvcp", "10", String(raw)]
        setter.running = false
        setter.running = true
    }

    // Coalesce a drag into a single write.
    Timer {
        id: debounce
        interval: 120
        repeat: false
        onTriggered: root.commit()
    }

    Process {
        id: getter
        stdout: StdioCollector {
            id: getOut
            waitForEnd: true
            onStreamFinished: {
                // Don't clobber a value the user is (or just finished) setting.
                if (root.pendingRaw >= 0 || setter.running)
                    return
                // Machine-readable: "VCP 10 C <current> <max>".
                var m = String(getOut.text).match(/VCP\s+[0-9A-Fa-f]+\s+C\s+(\d+)\s+(\d+)/)
                if (!m)
                    return
                var max = Number(m[2])
                if (max <= 0)
                    max = 100
                root.rawMax = max
                root.rawValue = Number(m[1])
                root.value = root.rawValue / max
                root.available = true
            }
        }
    }

    Process {
        id: setter
    }
}
