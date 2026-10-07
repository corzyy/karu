import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

import "../../core/theme"
import "../../core/config"
import "../../core/config/ControlCatalog.js" as ControlCatalog
import "../../core/services"
import "../widgets"

/**
 * ControlItem — one live Control Center control.
 *
 * It renders whichever control `type` names (see ControlCatalog.js) and is the
 * single implementation shared by the real panel (ui/panels/ControlCenterPanel)
 * and the Settings layout editor (ui/settings/ControlPreviewTile), so the editor
 * preview is pixel-for-pixel the panel's own tile.
 *
 * `interactive` is false in the editor: the inner control is disabled so its
 * own mouse handling never fires there, while its look is untouched.
 */
Item {
    id: root

    /// The control type from ControlCatalog (e.g. "network", "sound").
    property string type: ""
    /// When false the control is display-only (the Settings editor).
    property bool interactive: true
    /// Which detail dialog is open over the panel ("" when none); the matching
    /// tile hides itself while its card has taken its place.
    property string activeDetail: ""

    signal detailRequested(string which, var tile)
    signal lockRequested()
    signal mediaRequested()
    /// The System Tray control asked to open a tray item's own menu (Karu-styled,
    /// rendered by shell.qml): `item` is the SystemTrayItem and `rect` the icon's
    /// scene rectangle.
    signal trayMenuRequested(var item, var rect)

    readonly property var info: ControlCatalog.info(type)
    readonly property string kind: info ? info.kind : "toggle"

    /// A Sound / Display slider taller than it is wide draws vertically; a wide
    /// one draws as the usual horizontal row.
    readonly property bool vertical: kind === "slider" && height > width

    // ── Live state ───────────────────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter

    readonly property var wifiDevice: {
        var list = Networking.devices.values
        for (var i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wifi)
                return list[i]
        return null
    }
    readonly property var wiredDevice: {
        var list = Networking.devices.values
        for (var i = 0; i < list.length; i++)
            if (list[i].type === DeviceType.Wired)
                return list[i]
        return null
    }
    readonly property bool wiredConnected: wiredDevice ? wiredDevice.connected : false

    readonly property bool networkConnected: {
        if (wifiDevice) {
            var list = wifiDevice.networks.values
            for (var i = 0; i < list.length; i++)
                if (list[i].connected)
                    return true
        }
        return wiredConnected
    }

    readonly property string networkSubtitle: {
        if (wifiDevice) {
            var list = wifiDevice.networks.values
            for (var i = 0; i < list.length; i++)
                if (list[i].connected)
                    return list[i].name || "Connected"
        }
        if (wiredConnected)
            return wiredDevice.address || "LAN"
        if (!wifiDevice && !wiredDevice)
            return "Unavailable"
        if (wiredDevice && wiredDevice.hasLink)
            return "LAN"
        return Networking.wifiEnabled ? "Not connected" : "Off"
    }

    function toggleWired() {
        if (!wiredDevice)
            return
        if (wiredDevice.connected)
            wiredDevice.disconnect()
        else if (wiredDevice.network)
            wiredDevice.network.connect()
    }

    readonly property string btSubtitle: {
        if (!btAdapter)
            return "Unavailable"
        if (!btAdapter.enabled)
            return "Off"
        var list = btAdapter.devices.values
        for (var i = 0; i < list.length; i++)
            if (list[i].connected)
                return list[i].name || list[i].deviceName || "Connected"
        return "On"
    }

    // Sound (default PipeWire sink). Tracking the sink keeps its volume/mute
    // params delivered, so the slider reads live.
    PwObjectTracker {
        objects: root.kind === "slider" && root.type === "sound"
            ? [Pipewire.defaultAudioSink] : []
    }
    readonly property var soundSink: Pipewire.defaultAudioSink
    readonly property var soundAudio: (soundSink && soundSink.audio) ? soundSink.audio : null
    readonly property real soundValue: soundAudio ? soundAudio.volume : 0

    function setSound(v) {
        if (!soundAudio)
            return
        soundAudio.volume = v
        if (v > 0 && soundAudio.muted)
            soundAudio.muted = false
    }

    // Media (MPRIS) for the Now Playing tile.
    readonly property var player: {
        var list = Mpris.players.values
        for (var i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i]
        return list.length > 0 ? list[0] : null
    }

    Component.onCompleted: if (root.type === "display") Brightness.ensure()

    Loader {
        anchors.fill: parent
        sourceComponent: root.kind === "notifications" ? notifComp
            : root.kind === "slider" ? (root.vertical ? verticalSliderComp : sliderComp)
            : (root.kind === "small" || root.kind === "action") ? smallComp
            : root.kind === "media" ? mediaComp
            : root.kind === "tray" ? trayComp
            : toggleComp
    }

    // ── Toggle tile (Wi-Fi / Bluetooth / Focus / Game Mode) ──────────────────
    Component {
        id: toggleComp
        ToggleButton {
            enabled: root.interactive
            icon: root.type === "network" ? "\uF0AC"     // nf-fa-globe
                : root.type === "bluetooth" ? "\uF293"   // nf-fa-bluetooth_b
                : root.type === "gamemode" ? "\uF11B"    // nf-fa-gamepad
                : "\uF186"                               // nf-fa-moon_o
            title: root.type === "network" ? "Wi-Fi"
                : root.type === "bluetooth" ? "Bluetooth"
                : root.type === "gamemode" ? "Game Mode"
                : "Focus"
            subtitle: root.type === "network" ? root.networkSubtitle
                : root.type === "bluetooth" ? root.btSubtitle
                : root.type === "gamemode" ? (Theme.gameMode ? "On" : "Off")
                : (Notifications.doNotDisturb ? "On" : "Off")
            active: root.type === "network" ? root.networkConnected
                : root.type === "bluetooth" ? (root.btAdapter ? root.btAdapter.enabled : false)
                : root.type === "gamemode" ? Theme.gameMode
                : Notifications.doNotDisturb
            openable: root.type === "network" || root.type === "bluetooth" || root.type === "gamemode"
            suppressed: (root.type === "network" && root.activeDetail === "network")
                || (root.type === "bluetooth" && root.activeDetail === "bluetooth")
                || (root.type === "gamemode" && root.activeDetail === "gamemode")

            onToggled: {
                if (root.type === "network") {
                    if (root.wifiDevice)
                        Networking.wifiEnabled = !Networking.wifiEnabled
                    else
                        root.toggleWired()
                } else if (root.type === "bluetooth") {
                    if (root.btAdapter)
                        root.btAdapter.enabled = !root.btAdapter.enabled
                } else if (root.type === "gamemode") {
                    openRequested(tileGeometry())
                } else {
                    Notifications.doNotDisturb = !Notifications.doNotDisturb
                }
            }
            onOpenRequested: function(tile) { root.detailRequested(root.type, tile) }
        }
    }

    // ── Small button (Lock / Do Not Disturb) ─────────────────────────────────
    Component {
        id: smallComp
        IconButton {
            enabled: root.interactive
            icon: root.type === "lock" ? "\uF023" : "\uF186"
            active: root.type === "dnd" ? Notifications.doNotDisturb : false
            onTriggered: {
                if (root.type === "lock")
                    root.lockRequested()
                else
                    Notifications.doNotDisturb = !Notifications.doNotDisturb
            }
        }
    }

    // ── Slider (Sound / Display) ─────────────────────────────────────────────
    Component {
        id: sliderComp
        SliderRow {
            enabled: root.interactive
            compact: true
            icon: root.type === "sound" ? "\uF028" : "\uF185"
            title: root.type === "sound" ? "Sound" : "Display"
            showValue: root.type === "sound"
            openable: root.type === "display"
            suppressed: root.type === "display" && root.activeDetail === "brightness"
            value: root.type === "sound" ? root.soundValue : Brightness.syncedValue
            onMoved: function(v) {
                if (root.type === "sound")
                    root.setSound(v)
                else
                    Brightness.setSynced(v)
            }
            onDetailRequested: function(tile) { root.detailRequested("brightness", tile) }
        }
    }

    // ── Vertical slider (Sound / Display in a tall, narrow slot) ─────────────
    Component {
        id: verticalSliderComp
        VerticalSlider {
            enabled: root.interactive
            icon: root.type === "sound" ? "\uF028" : "\uF185"
            showValue: root.type === "sound"
            openable: root.type === "display"
            suppressed: root.type === "display" && root.activeDetail === "brightness"
            fillColor: root.type === "sound" ? Theme.sliderAccent : Theme.accent
            iconColor: Theme.accent
            value: root.type === "sound" ? root.soundValue : Brightness.syncedValue
            onMoved: function(v) {
                if (root.type === "sound")
                    root.setSound(v)
                else
                    Brightness.setSynced(v)
            }
            onDetailRequested: function(tile) { root.detailRequested("brightness", tile) }
        }
    }

    // ── Notifications list ───────────────────────────────────────────────────
    Component {
        id: notifComp
        ControlNotificationsCard {
            enabled: root.interactive
        }
    }

    // ── System Tray ──────────────────────────────────────────────────────────
    // Every StatusNotifierItem on the session as a row of clickable icons
    // (ui/panels/ControlTrayCard.qml). The card owns its own activate /
    // menu / scroll handling; `enabled` makes it a preview in the editor.
    Component {
        id: trayComp
        ControlTrayCard {
            enabled: root.interactive
            onMenuRequested: function (item, rect) { root.trayMenuRequested(item, rect) }
        }
    }

    // ── Now Playing ──────────────────────────────────────────────────────────
    // A live MPRIS player, styled after the iOS media controls. One card adapts
    // to whatever grid slot it is given — a single-row mini player, a narrow
    // vertical stack, or the full artwork-and-transport card — by switching
    // layout on its real pixel size, so the editor can drag it to any w×h and
    // it stays composed. Everything but the transport buttons opens the full
    // media companion (ui/media/MediaIsland.qml).
    Component {
        id: mediaComp
        Rectangle {
            id: mediaCard

            readonly property var player: root.player
            readonly property bool hasPlayer: player !== null
            readonly property bool playing: hasPlayer && player.isPlaying
            readonly property bool canPlay: hasPlayer && player.canTogglePlaying
            readonly property bool canPrev: hasPlayer && player.canGoPrevious
            readonly property bool canNext: hasPlayer && player.canGoNext
            readonly property bool hasArt: hasPlayer
                && player.trackArtUrl !== undefined && player.trackArtUrl.length > 0
            readonly property string artSource: hasArt ? player.trackArtUrl : ""
            readonly property real trackLength:
                (hasPlayer && player.length > 0) ? player.length : 0
            readonly property real progress: trackLength > 0
                ? Math.max(0, Math.min(1, livePosition / trackLength))
                : 0
            readonly property string titleText:
                (hasPlayer && player.trackTitle) ? player.trackTitle : "Nothing Playing"
            readonly property string artistText:
                hasPlayer ? (player.trackArtist || "") : ""

            // MPRIS position updates are unreliable, so the elapsed time is
            // interpolated locally while playing and re-synced whenever the
            // player does report a change (or a new track starts).
            property real livePosition: 0

            // ── Responsive metrics ───────────────────────────────────────────
            // Everything keys off the tile's real pixel size (not its grid span)
            // so the same control reads well in every slot the editor permits.
            readonly property int pad: Theme.padRow
            readonly property real availW: Math.max(0, width - pad * 2)
            readonly property real availH: Math.max(0, height - pad * 2)
            readonly property string mode: height < 84 ? "mini"
                : (width < 140 ? "tall" : "standard")
            readonly property real miniArt:
                Math.max(20, Math.min(availH, availW * 0.42))
            readonly property bool miniArtist: availH >= 40
            readonly property bool tallArtist: availH >= 130
            readonly property bool stdArtist: availH >= 88
            readonly property bool stdTimes: availH >= 130
            readonly property bool stdSkips: width >= 250
            readonly property real stdArt:
                Math.max(36, Math.min(availH, Math.min(76, availW * 0.5)))

            function formatTime(seconds) {
                if (!isFinite(seconds) || seconds < 0)
                    seconds = 0
                var total = Math.floor(seconds)
                var h = Math.floor(total / 3600)
                var m = Math.floor((total % 3600) / 60)
                var s = total % 60
                var ss = (s < 10 ? "0" : "") + s
                if (h > 0)
                    return h + ":" + (m < 10 ? "0" : "") + m + ":" + ss
                return m + ":" + ss
            }

            function togglePlay() { if (canPlay) player.togglePlaying() }
            function goPrev() { if (canPrev) player.previous() }
            function goNext() { if (canNext) player.next() }

            radius: Theme.radiusCard
            color: "transparent"
            gradient: TileGlass { hovered: mediaHover.hovered && root.interactive }
            border.width: 1
            border.color: mediaHover.hovered && root.interactive ? Theme.borderStrong : Theme.border
            clip: true
            Behavior on border.color { ColorAnimation { duration: Theme.motionSnap } }

            Timer {
                interval: 250
                repeat: true
                running: mediaCard.visible && root.interactive && mediaCard.hasPlayer
                    && mediaCard.playing && mediaCard.player.positionSupported
                onTriggered: mediaCard.livePosition += interval / 1000
            }
            Connections {
                target: mediaCard.hasPlayer ? mediaCard.player : null
                function onPositionChanged() { mediaCard.livePosition = mediaCard.player.position }
                function onTrackChanged() { mediaCard.livePosition = 0 }
            }

            // Behind the content, so the transport buttons win their own clicks
            // while empty space still opens the companion.
            MouseArea {
                anchors.fill: parent
                enabled: root.interactive
                cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.mediaRequested()
            }

            Loader {
                anchors.fill: parent
                sourceComponent: mediaCard.mode === "mini" ? miniLayout
                    : (mediaCard.mode === "tall" ? tallLayout : standardLayout)
            }

            // The compact layouts carry their progress as a thin line pinned to
            // the card's bottom edge (the standard card draws its own scrubber).
            Rectangle {
                visible: mediaCard.mode !== "standard" && mediaCard.trackLength > 0
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: mediaCard.pad
                anchors.rightMargin: mediaCard.pad
                anchors.bottomMargin: 4
                height: 3
                radius: height / 2
                color: Theme.track

                Rectangle {
                    width: parent.width * mediaCard.progress
                    height: parent.height
                    radius: height / 2
                    color: Theme.accent
                    Behavior on width {
                        NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut }
                    }
                }
            }

            HoverHandler {
                id: mediaHover
                enabled: root.interactive
                cursorShape: Qt.PointingHandCursor
            }

            // ── Mini: a single row (one grid row tall) ───────────────────────
            Component {
                id: miniLayout
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: mediaCard.pad
                    spacing: Theme.spaceMd

                    MediaArt {
                        Layout.preferredWidth: mediaCard.miniArt
                        Layout.preferredHeight: mediaCard.miniArt
                        Layout.alignment: Qt.AlignVCenter
                        visible: mediaCard.availW >= 60
                        source: mediaCard.artSource
                        accented: mediaCard.hasPlayer
                        glyphSize: Math.round(mediaCard.miniArt * 0.5)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.titleText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleSize
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: mediaCard.miniArtist && text.length > 0
                            text: mediaCard.artistText
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    MediaButton {
                        Layout.alignment: Qt.AlignVCenter
                        visible: mediaCard.canPlay && mediaCard.availW >= 96
                        interactive: root.interactive
                        filled: true
                        glyphSize: 15
                        glyph: mediaCard.playing ? "\uF04C" : "\uF04B"
                        onTriggered: mediaCard.togglePlay()
                    }
                }
            }

            // ── Tall: a narrow vertical stack (one column wide) ──────────────
            Component {
                id: tallLayout
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: mediaCard.pad
                    spacing: Theme.spaceSm

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        MediaArt {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height)
                            height: width
                            source: mediaCard.artSource
                            accented: mediaCard.hasPlayer
                            glyphSize: Math.round(width * 0.34)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: mediaCard.titleText
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleSize
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        visible: mediaCard.tallArtist && text.length > 0
                        text: mediaCard.artistText
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.subtitleSize
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    MediaButton {
                        Layout.alignment: Qt.AlignHCenter
                        visible: mediaCard.canPlay
                        interactive: root.interactive
                        filled: true
                        glyphSize: 16
                        glyph: mediaCard.playing ? "\uF04C" : "\uF04B"
                        onTriggered: mediaCard.togglePlay()
                    }
                }
            }

            // ── Standard: artwork beside metadata, scrubber and transport ────
            Component {
                id: standardLayout
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: mediaCard.pad
                    spacing: Theme.spaceMd

                    MediaArt {
                        Layout.preferredWidth: mediaCard.stdArt
                        Layout.preferredHeight: mediaCard.stdArt
                        Layout.alignment: Qt.AlignVCenter
                        source: mediaCard.artSource
                        accented: mediaCard.hasPlayer
                        glyphSize: Math.round(mediaCard.stdArt * 0.32)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: mediaCard.titleText
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.titleSize
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: mediaCard.stdArtist && text.length > 0
                            text: mediaCard.artistText
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.subtitleSize
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }

                        Item { Layout.fillHeight: true }

                        // Scrubber (display only; the companion handles seeking).
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            visible: mediaCard.trackLength > 0

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 3
                                radius: height / 2
                                color: Theme.track
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * mediaCard.progress
                                height: 3
                                radius: height / 2
                                color: Theme.accent
                                Behavior on width {
                                    NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: mediaCard.stdTimes && mediaCard.trackLength > 0

                            Text {
                                text: mediaCard.formatTime(Math.min(mediaCard.livePosition, mediaCard.trackLength))
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.subtitleSize
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: mediaCard.formatTime(mediaCard.trackLength)
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.subtitleSize
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            spacing: 2

                            Item { Layout.fillWidth: true }
                            MediaButton {
                                visible: mediaCard.stdSkips
                                active: mediaCard.canPrev
                                interactive: root.interactive
                                glyph: "\uF048" // nf-fa-step_backward
                                onTriggered: mediaCard.goPrev()
                            }
                            MediaButton {
                                filled: true
                                active: mediaCard.canPlay
                                interactive: root.interactive
                                glyphSize: 16
                                glyph: mediaCard.playing ? "\uF04C" : "\uF04B"
                                onTriggered: mediaCard.togglePlay()
                            }
                            MediaButton {
                                visible: mediaCard.stdSkips
                                active: mediaCard.canNext
                                interactive: root.interactive
                                glyph: "\uF051" // nf-fa-step_forward
                                onTriggered: mediaCard.goNext()
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    // ── Artwork shared by every Now Playing layout ───────────────────────────
    // Album cover with the themed gradient/glyph fallback while it loads (or
    // when nothing is playing), matching the hero art on the media companion.
    component MediaArt: Rectangle {
        id: art

        property string source: ""
        property bool accented: false
        property real glyphSize: 18

        radius: Theme.radiusInner
        color: Theme.iconCircle
        clip: true

        Image {
            id: artImage
            anchors.fill: parent
            source: art.source
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 256
            sourceSize.height: 256
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: artImage.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.accentMuted }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: "\uF001" // nf-fa-music
            color: art.accented ? Theme.accent : Theme.textSecondary
            font.family: Theme.iconFont
            font.pixelSize: art.glyphSize
        }
    }

    // ── Transport button used by the Now Playing tile ────────────────────────
    // iOS-style: the primary play / pause is a filled accent disc, the skip
    // buttons are plain glyphs that dim when unavailable. Works inside a Row or
    // Column layout via the Layout attached properties.
    component MediaButton: Item {
        id: mb

        property string glyph: ""
        property int glyphSize: 16
        property bool active: true
        property bool filled: false
        property bool interactive: true

        signal triggered()

        implicitWidth: filled ? 34 : 32
        implicitHeight: 34
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        Rectangle {
            anchors.centerIn: parent
            width: 32
            height: 32
            radius: width / 2
            color: Theme.accent
            opacity: mb.filled ? (mb.active ? 1 : 0.35) : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: Theme.motionSnap } }
        }
        Text {
            anchors.centerIn: parent
            text: mb.glyph
            color: mb.active
                ? (mb.filled ? Theme.backgroundSolid : Theme.textPrimary)
                : Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: mb.glyphSize
            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: mb.active && mb.interactive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: mb.scale = 0.85
            onReleased: mb.scale = 1
            onCanceled: mb.scale = 1
            onClicked: mb.triggered()
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut }
        }
    }
}
