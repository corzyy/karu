import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

import "../../core/theme"

/**
 * VolumePanel — the volume OSD, shown *as the island*.
 *
 * When the default sink's volume or mute changes (hardware/media keys, a
 * keyboard volume slider, the status-icon wheel, …) shell.qml grows the island
 * into this panel exactly like the Control Center / Session panels do, holds it
 * for `Theme.volumeOsdTimeout`, then collapses it back into the pill. So the OSD
 * replaces the island for a period and morphs in and out of it, rather than
 * floating beside or below it.
 *
 * It reads the live default sink for the glyph, the track fill and the readout,
 * and its track is draggable, so the OSD is also usable directly. shell.qml owns
 * the trigger and the dismiss timer; this component only describes the panel and
 * writes the sink.
 */
ColumnLayout {
    id: root
    spacing: Theme.gap

    // Track the default sink so its volume/mute params are delivered. Without
    // this the node exists but reports an empty `audio.volumes`.
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

    /// Set the sink volume (0..1). Raising it clears mute, matching the Control
    /// Center slider.
    function setVolume(v) {
        if (!sinkAudio)
            return
        sinkAudio.volume = Math.max(0, Math.min(1, v))
        if (sinkAudio.volume > 0 && sinkAudio.muted)
            sinkAudio.muted = false
    }

    // ── Glyph + track + readout, in one compact row ──────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spaceMd

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.volumeIcon
            color: root.muted ? Theme.textDim : Theme.accent
            font.family: Theme.iconFont
            font.pixelSize: 22
            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 8
            radius: height / 2
            color: Theme.track

            Rectangle {
                width: Math.round(track.width * Math.max(0, Math.min(1, root.volume)))
                height: parent.height
                radius: height / 2
                color: root.muted ? Theme.textDim : Theme.sliderAccent
                Behavior on width { NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut } }
                Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function commit(mx) {
                    root.setVolume(mx / width)
                }

                onClicked: function(mouse) { commit(mouse.x) }
                onPositionChanged: function(mouse) { if (pressed) commit(mouse.x) }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
            color: root.muted ? Theme.textDim : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.subtitleSize
        }
    }
}
