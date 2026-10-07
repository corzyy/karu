import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Quickshell.Widgets

import "../../core/theme"
import "../../core/config"

/**
 * MediaIsland — the MPRIS companion to the main island.
 *
 * It sits just to the right of the main pill and mirrors the active player:
 *
 *   collapsed – a circle (a 40x40 round) showing the album art, or a music
 *               glyph when nothing is playing.
 *   opened    – a wide, horizontal "Now Playing" panel that morphs out of the
 *               circle and drops below the bar: square artwork on the left, the
 *               title / artist / album / player stacked on the right, a
 *               draggable progress scrubber with elapsed / total times, and
 *               large previous / play-pause / next controls. The card is a
 *               clean, solid panel — the cover is not used as a backdrop. The
 *               album art is a single shared element (`hero`) that glides and
 *               resizes from the circle into the panel's artwork slot, so the
 *               cover morphs in one continuous motion instead of cross-fading.
 *
 * `shell.qml` owns the placement (`x` follows the main island). Clicking the
 * circle opens the panel, clicking it again closes it; hovering only produces a
 * small scale-up. This component only describes the shape and its contents, and
 * exposes `gap` so the position binding can glide as the card detaches.
 */
Item {
    id: root

    /// Opened state, toggled by a click.
    property bool open: false

    /// True while a main-island panel (Control Center, Themes, …) is expanded.
    /// In Notch Mode that panel replaces the bar the companion is fused to, so
    /// the companion detaches and floats beside it instead of fusing.
    property bool panelOpen: false

    /// True while Notch Mode has fused this companion to the main bar: it sits
    /// flush against the bar (no gap), takes the same opaque fill and drops its
    /// rim, so the two read as a single slab. Its left corners stay square where
    /// they meet the bar and only the outer bottom-right corner is rounded,
    /// mirroring the notch bar's own shape. An open panel breaks the fusion.
    readonly property bool notchAttached:
        Settings.notchMode && !Theme.gameMode && !root.open && !root.panelOpen

    /// Space between the main island and this one. The card keeps a small gap
    /// so it reads as a floating iOS panel rather than merging into the bar.
    /// Notch Mode closes the gap so the companion fuses into the bar.
    property real gap: open ? 10 : (notchAttached ? 0 : 8)
    Behavior on gap {
        NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut }
    }

    /// The player to mirror: prefer whatever is actually playing, otherwise the
    /// first one that exists. Null when no MPRIS client is around.
    readonly property var player: {
        var list = Mpris.players.values
        for (var i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i]
        return list.length > 0 ? list[0] : null
    }
    readonly property bool hasPlayer: player !== null
    readonly property bool hasArt:
        hasPlayer && player.trackArtUrl && player.trackArtUrl.length > 0

    // ── Geometry ─────────────────────────────────────────────────────────────
    // Collapsed diameter matches the pill height, so the two islands line up.
    readonly property int collapsedSize: Theme.collapsedHeight
    readonly property int cardWidth:     384
    readonly property int cardHeight:    216
    readonly property int cardPad:       16
    readonly property int artSize:       140
    readonly property int artRadius:     12

    // The cover is a single shared element that morphs between the collapsed
    // circle and the panel's artwork slot (see `hero` below). The slot's
    // top-left is derived from the card padding and border, measured from the
    // shape's outer edge (the shape is a plain Rectangle, so it does not inset
    // its children).
    readonly property int  coverMargin:     3
    readonly property int  coverOpenBorder: 2
    readonly property real coverOpenX:      cardPad + coverOpenBorder
    readonly property real coverOpenY:
        cardPad + coverOpenBorder
        + (cardHeight - 2 * coverOpenBorder - 2 * cardPad - artSize) / 2

    width: open ? cardWidth : collapsedSize
    height: open ? cardHeight : collapsedSize

    // Fluid morph into the full player panel, on the same physics spring as the
    // main island so the two open alike. The card visibly overshoots its size
    // and settles back; Game Mode / Reduce Motion snaps it. (The small hover
    // scale still springs.)
    Behavior on width {
        enabled: !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }
    Behavior on height {
        enabled: !Theme.motionOff
        SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
    }

    // Hover reaction: matches the main island exactly — the same "Hover lift"
    // value (`Theme.hoverScale`, from the Motion ▸ Feel setting) as the pill,
    // suppressed under the same conditions (Game Mode, and while fused into the
    // notch bar, where a scale would pull it apart from the bar). A springy
    // scale-up anchored to the top, with the accent border and lifted fill
    // applied on `shape` below. Hovering never opens the card.
    transformOrigin: Item.Top
    scale: (!Theme.gameMode && !root.notchAttached && hover.hovered && !root.open)
        ? Theme.hoverScale : 1
    Behavior on scale {
        NumberAnimation {
            duration: Theme.motionFast
            easing.type: Theme.easeSpring
            easing.overshoot: Theme.springOvershoot
        }
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    // Click to toggle the card open/closed. This sits behind the content, so
    // the transport buttons and scrubber win while empty space toggles.
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: root.open = !root.open
    }

    // ── Progress ─────────────────────────────────────────────────────────────
    // MPRIS players are inconsistent about pushing position updates, so the
    // elapsed time is interpolated locally while playing and re-synced whenever
    // the player does report a change (or the user seeks).
    readonly property real trackLength:
        (hasPlayer && player.length > 0) ? player.length : 0
    readonly property real displayedPosition: scrubbing ? scrubPosition : livePosition
    readonly property real progress: trackLength > 0
        ? Math.max(0, Math.min(1, displayedPosition / trackLength))
        : 0

    property real livePosition: 0
    property real scrubPosition: 0
    property bool scrubbing: false

    Timer {
        interval: 250
        repeat: true
        running: root.open && root.hasPlayer && root.player.isPlaying
            && root.player.positionSupported
        onTriggered: {
            var next = root.livePosition + interval / 1000
            root.livePosition = root.trackLength > 0
                ? Math.min(next, root.trackLength) : next
        }
    }

    Connections {
        target: root.player
        function onPositionChanged() {
            if (!root.scrubbing)
                root.livePosition = root.player.position
        }
        function onTrackChanged() {
            root.livePosition = 0
            root.scrubPosition = 0
        }
        function onIsPlayingChanged() {
            // Re-sync when playback pauses so the bar does not keep creeping.
            if (root.hasPlayer && !root.player.isPlaying && root.player.positionSupported)
                root.livePosition = root.player.position
        }
    }

    /// Seconds -> "m:ss" (or "h:mm:ss" for long tracks).
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0
        var total = Math.floor(seconds)
        var h = Math.floor(total / 3600)
        var m = Math.floor((total % 3600) / 60)
        var s = total % 60
        var ss = (s < 10 ? "0" : "") + s
        if (h > 0) {
            var mm = (m < 10 ? "0" : "") + m
            return h + ":" + mm + ":" + ss
        }
        return m + ":" + ss
    }

    // ── Transport button used by the opened panel ────────────────────────────
    // A large, tappable glyph that dims when the action is unavailable and
    // scales down slightly while pressed (iOS-like feedback). `filled` adds the
    // subtle circular backing used behind the primary play / pause button.
    component TransportButton: Item {
        id: tb

        property string glyph
        property int glyphSize: 26
        property bool active: true
        property bool filled: false

        signal triggered()

        implicitWidth: filled ? 48 : 44
        implicitHeight: 46
        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.alignment: Qt.AlignVCenter

        Rectangle {
            anchors.centerIn: parent
            width: 42
            height: 42
            radius: width / 2
            color: Theme.surfaceHover
            opacity: tb.filled ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motionSnap } }
        }

        Text {
            anchors.centerIn: parent
            text: tb.glyph
            color: tb.active ? Theme.textPrimary : Theme.textDim
            font.family: Theme.iconFont
            font.pixelSize: tb.glyphSize
            Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
        }

        MouseArea {
            anchors.fill: parent
            enabled: tb.active
            cursorShape: tb.active ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: tb.scale = 0.86
            onReleased: tb.scale = 1
            onCanceled: tb.scale = 1
            onClicked: tb.triggered()
        }

        Behavior on scale {
            NumberAnimation { duration: Theme.motionSnap; easing.type: Theme.easeOut }
        }
    }

    // ── Shape: a circle at rest, a wide rounded panel when opened. A plain
    //    Rectangle — not a ClippingRectangle — so the rim is drawn as vector
    //    geometry that stays crisp through the hover scale. (A ClippingRectangle
    //    rasterises its border into a fixed-size texture, which resamples into a
    //    pixelated edge as the circle springs up.) The artwork is clipped by
    //    `hero` itself, so the shape only needs to draw the fill and the rim.
    Rectangle {
        anchors.fill: parent
        antialiasing: true
        // height/2: a circle at 40px wide; the theme's panel corner when open.
        readonly property real cornerAll: root.open ? Theme.radiusPanel : height / 2
        // Notch Mode: NotchBar draws the fused silhouette, so the tile keeps no
        // corner of its own; the artwork still rides on top of that fill.
        topLeftRadius:     root.notchAttached ? 0 : cornerAll
        topRightRadius:    root.notchAttached ? 0 : cornerAll
        bottomLeftRadius:  root.notchAttached ? 0 : cornerAll
        bottomRightRadius: root.notchAttached ? Theme.notchBottomRadius : cornerAll
        // Hover mirrors the main island: the fill lifts and the border thickens
        // and picks up the accent. While open the panel keeps its frosted rim.
        // Fused to the notch bar it paints no fill of its own — NotchBar draws
        // the fused silhouette (bar + this tile) as one path.
        color: root.notchAttached
            ? "transparent"
            : ((hover.hovered && !root.open) ? Theme.hoverSurface : Theme.background)
        border.width: root.notchAttached
            ? 0
            : (root.open
                ? root.coverOpenBorder
                : (hover.hovered ? Theme.hoverBorderWidth : 1))
        border.color: root.open
            ? Theme.borderMedia
            : (hover.hovered ? Theme.hoverBorder : Theme.border)
        Behavior on topLeftRadius {
            enabled: !Theme.motionOff
            SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
        }
        Behavior on topRightRadius {
            enabled: !Theme.motionOff
            SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
        }
        Behavior on bottomLeftRadius {
            enabled: !Theme.motionOff
            SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
        }
        Behavior on bottomRightRadius {
            enabled: !Theme.motionOff
            SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
        }
        Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }
        Behavior on border.width {
            NumberAnimation { duration: Theme.fadeDuration; easing.type: Theme.easeOut }
        }
        Behavior on border.color { ColorAnimation { duration: Theme.fadeDuration } }

        // The opened card is a clean, solid panel (the cover is not used as a
        // backdrop), so it matches the main island instead of smearing album
        // art behind the controls.

        // ── Cover: one shared album-art element for both states ──────────────
        // The circle's art and the panel's artwork are the *same* object, so it
        // morphs from the collapsed circle into the panel's artwork slot as the
        // card opens (and back on close) rather than cross-fading two images.
        // It is itself a ClippingRectangle so the cover follows the rounded
        // circle / artwork slot, and it rides the same curve/duration as the
        // panel.
        ClippingRectangle {

            // Rim the collapsed cover sits inside (matches the idle rim on
            // `shape`). Kept constant through hover so the artwork does not
            // drift while the tile springs; the open slot folds its own rim into
            // `coverOpenX` / `coverOpenY`.
            readonly property int collapsedRim: 1
            readonly property real collapsedCover:
                root.collapsedSize - 2 * collapsedRim - 2 * root.coverMargin

            x: root.open ? root.coverOpenX : (root.coverMargin + collapsedRim)
            y: root.open ? root.coverOpenY : (root.coverMargin + collapsedRim)
            width: root.open ? root.artSize : collapsedCover
            height: root.open ? root.artSize : collapsedCover
            radius: root.open ? root.artRadius : collapsedCover / 2
            // With no cover the tile itself lifts on hover, matching the
            // island's fill; with a cover the art covers the fill anyway.
            color: (!root.open && hover.hovered) ? Theme.hoverSurface : Theme.surfaceElevated

            Behavior on x {
                enabled: !Theme.motionOff
                SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
            }
            Behavior on y {
                enabled: !Theme.motionOff
                SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
            }
            Behavior on width {
                enabled: !Theme.motionOff
                SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
            }
            Behavior on height {
                enabled: !Theme.motionOff
                SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
            }
            Behavior on radius {
                enabled: !Theme.motionOff
                SpringAnimation { spring: Theme.panelSpring; damping: root.open ? Theme.panelDamping : Theme.panelCloseDamping; mass: Theme.panelMass; epsilon: Theme.panelEpsilon }
            }
            Behavior on color { ColorAnimation { duration: Theme.fadeDuration } }

            // The art itself (declared first so its `status` can be read by the
            // fallback below without a forward reference).
            Image {
                id: heroArt
                anchors.fill: parent
                // The collapsed circle can show the album art or a plain music
                // glyph (Settings ▸ Bar & Island). The opened panel always
                // shows the cover.
                source: (root.hasArt && (Settings.mediaArtCircle || root.open))
                    ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 320
                sourceSize.height: 320
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motionFast; easing.type: Theme.easeOut } }
            }

            // Themed gradient fallback, also shown while the art loads.
            Rectangle {
                anchors.fill: parent
                visible: heroArt.status !== Image.Ready
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.accentMuted }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: heroArt.status !== Image.Ready
                text: "\uF001" // nf-fa-music
                color: root.hasPlayer ? Theme.accent : Theme.textSecondary
                font.family: Theme.iconFont
                font.pixelSize: root.open ? 44 : 16
            }
        }

        // ── Opened face: the wide, horizontal "Now Playing" panel ────────────
        RowLayout {
            anchors.fill: parent
            anchors.margins: root.cardPad + root.coverOpenBorder
            spacing: 16
            opacity: root.open ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.fadeDuration } }

            // Artwork slot — the shared `hero` cover parks here when the card is
            // open; this item only reserves the space so the row lays out right.
            Item {
                Layout.preferredWidth: root.artSize
                Layout.preferredHeight: root.artSize
                Layout.alignment: Qt.AlignVCenter
            }

            // Metadata + scrubber + transport, stacked to the right of the art.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: (root.hasPlayer && root.player.trackTitle)
                        ? root.player.trackTitle : "Nothing Playing"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    visible: text.length > 0
                    text: root.hasPlayer ? (root.player.trackArtist || "") : ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    visible: text.length > 0
                    text: (root.hasPlayer && root.player.trackAlbum)
                        ? root.player.trackAlbum : ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    visible: text.length > 0
                    text: (root.hasPlayer && root.player.identity)
                        ? root.player.identity : ""
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Item { Layout.fillHeight: true }

                // Progress scrubber — a thin track; drag to seek.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14

                    Rectangle {
                        id: trackBg
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 5
                        radius: height / 2
                        color: Theme.track
                    }

                    Rectangle {
                        id: trackFill
                        anchors.verticalCenter: parent.verticalCenter
                        width: trackBg.width * root.progress
                        height: trackBg.height
                        radius: height / 2
                        color: Theme.accent
                        Behavior on width {
                            NumberAnimation {
                                duration: root.scrubbing ? 0 : Theme.motionSnap
                                easing.type: Theme.easeOut
                            }
                        }
                    }

                    // Grab handle, shown only while scrubbing (iOS reveals it on drag).
                    Rectangle {
                        visible: root.scrubbing
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, trackFill.width - width / 2))
                        width: 13
                        height: 13
                        radius: height / 2
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.hasPlayer && root.player.canSeek && root.trackLength > 0
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                        function positionAt(mx) {
                            return Math.max(0, Math.min(1, mx / width)) * root.trackLength
                        }

                        onPressed: function(mouse) {
                            root.scrubbing = true
                            root.scrubPosition = positionAt(mouse.x)
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                root.scrubPosition = positionAt(mouse.x)
                        }
                        onReleased: function(mouse) {
                            root.scrubPosition = positionAt(mouse.x)
                            root.livePosition = root.scrubPosition
                            if (root.hasPlayer)
                                root.player.position = root.scrubPosition
                            root.scrubbing = false
                        }
                        onCanceled: {
                            root.scrubbing = false
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: root.trackLength > 0

                    Text {
                        text: root.formatTime(root.displayedPosition)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: root.formatTime(root.trackLength)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                // Primary transport — centred under the metadata column.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 2

                    Item { Layout.fillWidth: true }

                    TransportButton {
                        glyph: "\uF048" // nf-fa-step_backward
                        glyphSize: 24
                        active: root.hasPlayer && root.player.canGoPrevious
                        onTriggered: if (root.hasPlayer) root.player.previous()
                    }

                    TransportButton {
                        glyph: root.hasPlayer && root.player.isPlaying
                            ? "\uF04C" // nf-fa-pause
                            : "\uF04B" // nf-fa-play
                        glyphSize: 32
                        filled: true
                        active: root.hasPlayer && root.player.canTogglePlaying
                        onTriggered: if (root.hasPlayer) root.player.togglePlaying()
                    }

                    TransportButton {
                        glyph: "\uF051" // nf-fa-step_forward
                        glyphSize: 24
                        active: root.hasPlayer && root.player.canGoNext
                        onTriggered: if (root.hasPlayer) root.player.next()
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }
    }
}
