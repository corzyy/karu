import QtQuick
import Quickshell.Services.Pipewire

import "../../core/theme"
import "../../core/services"

/**
 * StatusIcons — monochrome network / do-not-disturb / volume glyphs.
 *
 * The volume glyph reflects the live default-sink state: a muted or silent
 * sink shows the crossed-out speaker, quiet levels show the single-wave
 * speaker, and louder levels show the full speaker. Scrolling the wheel over
 * that glyph nudges the sink by `volumeStep` per notch.
 *
 * The middle slot reflects Do Not Disturb at a glance: a moon while DND is on
 * and a bell while it is off. There is no Bluetooth glyph.
 *
 * TODO: bind network to Quickshell.Services.Network for live state.
 */
Row {
    id: root
    spacing: Theme.iconSpacing

    property color tint: Theme.accent
    property string networkIcon: "\uF1EB" // nf-fa-wifi
    property string dndIcon:     "\uF186" // nf-fa-moon_o  (DND on)
    property string dndOffIcon:  "\uF0A2" // nf-fa-bell_o  (DND off)

    /// Volume change applied per wheel notch over the volume glyph (5%).
    readonly property real volumeStep: 0.05

    // Track the default audio sink so its volume/mute params are delivered.
    // Without this the node exists but reports an empty `audio.volumes`.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinkAudio: (sink && sink.audio) ? sink.audio : null
    readonly property real volume: sinkAudio ? sinkAudio.volume : 0
    readonly property bool muted: sinkAudio ? sinkAudio.muted : false

    readonly property string volumeIcon: {
        if (!sinkAudio || muted || volume <= 0.001)
            return "\uF026" // nf-fa-volume_off
        if (volume < 0.5)
            return "\uF027" // nf-fa-volume_down
        return "\uF028"   // nf-fa-volume_up
    }

    // Each slot is drawn inside a fixed-width cell and centred, so swapping a
    // glyph (volume level) never changes the cluster's width — and with it the
    // pill's layout and the workspace row that is balanced against
    // `statusIcons.width` in shell.qml.
    readonly property real networkWidth: Math.ceil(netMetrics.advanceWidth)
    readonly property real dndWidth: Math.ceil(Math.max(
        dndMetrics.advanceWidth, dndOffMetrics.advanceWidth))
    readonly property real volumeWidth: Math.ceil(Math.max(
        volOffMetrics.advanceWidth, volDownMetrics.advanceWidth,
        volUpMetrics.advanceWidth))

    TextMetrics {
        id: netMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: root.networkIcon
    }
    TextMetrics {
        id: dndMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: root.dndIcon
    }
    TextMetrics {
        id: dndOffMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: root.dndOffIcon
    }
    TextMetrics {
        id: volOffMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: "\uF026" // nf-fa-volume_off
    }
    TextMetrics {
        id: volDownMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: "\uF027" // nf-fa-volume_down
    }
    TextMetrics {
        id: volUpMetrics
        font.family: Theme.iconFont
        font.pixelSize: Theme.iconSize
        text: "\uF028" // nf-fa-volume_up
    }

    /// Move the default sink's volume by `delta` (a 0..1 fraction), clamped to
    /// 0..1. Raising the volume clears mute, matching the Control Center slider.
    function adjustVolume(delta) {
        if (!sinkAudio)
            return
        var v = Math.max(0, Math.min(1, sinkAudio.volume + delta))
        sinkAudio.volume = v
        if (v > 0 && sinkAudio.muted)
            sinkAudio.muted = false
    }

    Repeater {
        // `volume` marks the glyph the wheel handler listens on, so scrolling
        // only changes the volume when the cursor is actually over it.
        model: [
            { glyph: root.networkIcon,   width: root.networkWidth, volume: false },
            // Moon while Do Not Disturb is on, bell while it is off.
            {
                glyph: Notifications.doNotDisturb ? root.dndIcon : root.dndOffIcon,
                width: root.dndWidth,
                volume: false
            },
            { glyph: root.volumeIcon,    width: root.volumeWidth,  volume: true  }
        ]

        delegate: Text {
            required property var modelData
            text: modelData.glyph
            // Fixed per-slot width keeps the cluster (and the balanced
            // workspace row) from shifting as the glyph changes.
            width: modelData.width
            horizontalAlignment: Text.AlignHCenter
            color: root.tint
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSize

            // Scroll over the volume glyph to change the sink volume in 5%
            // steps (wheel up is louder). Accepted on both mouse wheels and
            // trackpad scroll gestures.
            WheelHandler {
                enabled: modelData.volume
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: function(event) {
                    if (event.angleDelta.y === 0 && event.angleDelta.x === 0)
                        return
                    var up = event.angleDelta.y > 0 || event.angleDelta.x > 0
                    root.adjustVolume(up ? root.volumeStep : -root.volumeStep)
                }
            }
        }
    }
}
