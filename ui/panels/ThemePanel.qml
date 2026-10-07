import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

import "../../core/theme"
import "../widgets"

/**
 * ThemePanel — the Themes tab.
 *
 * A centred carousel of palette cards. ←/→ (or the wheel) move the highlight;
 * Enter (or clicking a card) applies it. Applying runs Matugen in the background
 * (see Themes.qml) and re-themes the whole island; the card in use is named in
 * the accent colour and flagged in the footer.
 *
 * The carousel holds every theme in `Themes.qml`: the dynamic "Wallpaper" theme
 * (its swatches and the palette it applies are pulled straight out of the
 * current wallpaper) plus the static themes.
 */
Rectangle {
    id: root

    implicitHeight: layout.implicitHeight + Theme.cardPadding * 2
    radius: Theme.radiusCard
    color: "transparent"

    readonly property var themes: Themes.themes
    readonly property var selected: themes.length > 0 ? themes[Themes.current] : null

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.cardPadding
        spacing: Theme.spaceLg

        // ── Search / status field ────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.searchHeight
            radius: Theme.radiusInner
            color: Theme.surfaceElevated
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padRow
                anchors.rightMargin: Theme.padRow
                spacing: Theme.spaceMd

                Text {
                    text: "\uEFCC" // nf-fa-palette
                    color: Theme.textSecondary
                    font.family: Theme.iconFont
                    font.pixelSize: 14
                }
                Text {
                    Layout.fillWidth: true
                    text: root.selected ? root.selected.name : "Themes"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                }
                Text {
                    text: (Themes.current + 1) + "/" + root.themes.length
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.subtitleSize
                }
            }
        }

        // ── Palette cards (centred carousel) ─────────────────────────────────
        // The selected theme sits in the middle at its full (wider) size while
        // its neighbours are narrower and squeeze into their visible slice as
        // they slide off the panel — the same carousel effect as the Wallpapers
        // panel. ←/→ step the selection and the row glides to centre it (the
        // layer surface takes keyboard focus while the island is open — see
        // shell.qml). The wheel also steps through themes.
        Item {
            id: carousel

            Layout.fillWidth: true
            implicitHeight: Theme.themeCardHeight + Theme.themeCardHeadroom
            clip: true
            focus: true

            readonly property int count: root.themes.length
            readonly property real gap: Theme.spaceMd
            readonly property real selWidth: Theme.themeCardWidth
            readonly property real plainWidth: Theme.themeCardPlainWidth
            // Centre offset of the neighbour one slot out: half the selected
            // card + the gap + half the neighbour. Deeper neighbours carry on at
            // the plain centre-to-centre pace, so the selected card's extra width
            // only ever opens a single gap beside itself.
            readonly property real halfSpan: selWidth / 2 + gap + plainWidth / 2
            readonly property real pairStep: plainWidth + gap

            // Fractional centre index. Bound to the manager's selection and
            // given a Behavior, so changing it makes the whole row glide.
            property real position: Themes.current
            Behavior on position {
                NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
            }

            function centerOffset(dist) {
                var a = Math.abs(dist)
                if (a <= 1)
                    return a * halfSpan
                return halfSpan + (a - 1) * pairStep
            }

            function stepBy(delta) {
                Themes.select(Math.max(0, Math.min(count - 1, Themes.current + delta)))
            }

            Component.onCompleted: forceActiveFocus()
            onVisibleChanged: if (visible) forceActiveFocus()

            Keys.onLeftPressed: carousel.stepBy(-1)
            Keys.onRightPressed: carousel.stepBy(1)
            Keys.onReturnPressed: Themes.applyCurrent()
            Keys.onEnterPressed: Themes.applyCurrent()

            Repeater {
                model: root.themes

                delegate: Item {
                    id: card

                    required property var modelData
                    required property int index

                    readonly property bool isSelected: index === Themes.current
                    readonly property bool isApplied: modelData.id === Themes.appliedId

                    // Distance from the animated centre, in card widths. Drives
                    // position, size, lift and stacking so the centre card stands
                    // out.
                    readonly property real dist: index - carousel.position
                    readonly property real closeness: Math.max(0, 1 - Math.abs(dist))

                    // The horizontal slice of the card actually inside the
                    // panel. When it overflows an edge the drawn card shrinks to
                    // this width and is anchored to the visible edge, so a
                    // neighbour squeezes into its slice rather than being cut
                    // off — the "message.qml" effect from the Wallpapers panel.
                    readonly property real visLeft: Math.max(0, x)
                    readonly property real visRight: Math.min(carousel.width, x + width)
                    readonly property real visWidth: Math.max(0, visRight - visLeft)
                    // Anchored to the right when it overflows the left edge, to
                    // the left otherwise (0 when it is fully inside).
                    readonly property real cardX: x < 0 ? width - visWidth : 0

                    width: isSelected ? carousel.selWidth : carousel.plainWidth
                    height: Theme.themeCardHeight
                    x: {
                        var s = dist > 0 ? 1 : (dist < 0 ? -1 : 0)
                        return carousel.width / 2 + s * carousel.centerOffset(dist) - width / 2
                    }
                    y: (carousel.height - height) / 2 - closeness * Theme.themeCardLift
                    z: -Math.abs(dist)
                    opacity: Math.max(0, Math.min(1, 2.2 - Math.abs(dist)))
                    Behavior on width {
                        NumberAnimation { duration: Theme.motionMedium; easing.type: Theme.easeEmphasized }
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.motionFast } }

                    ClippingRectangle {
                        x: card.cardX
                        width: card.visWidth
                        height: card.height
                        radius: Theme.radiusInner
                        // The theme's own background; the selected card is lifted
                        // a shade and keeps the accent border.
                        color: card.isSelected ? Qt.lighter(card.modelData.bg, 1.3) : card.modelData.bg
                        border.width: card.isSelected ? 2 : 1
                        border.color: card.isSelected ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.motionFast } }
                        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: Theme.spaceSm

                            Row {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: Theme.themeDotSpacing

                                Repeater {
                                    model: card.modelData.colors

                                    delegate: Rectangle {
                                        required property string modelData
                                        width: Theme.themeDotSize
                                        height: Theme.themeDotSize
                                        radius: width / 2
                                        color: modelData
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: card.modelData.name
                                color: card.isApplied ? Theme.accent
                                     : card.isSelected ? Theme.textPrimary
                                     : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.subtitleSize
                            }
                        }
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }

                    // Selecting a card applies it directly; the keyboard can
                    // still browse with ←/→ and confirm with Enter. The click
                    // target follows the visible slice, like the Wallpapers
                    // carousel.
                    MouseArea {
                        x: card.cardX
                        width: card.visWidth
                        height: card.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Themes.apply(card.modelData.id)
                    }
                }
            }

            WheelHandler {
                onWheel: function(event) {
                    if (event.angleDelta.y > 0 || event.angleDelta.x > 0)
                        carousel.stepBy(1)
                    else if (event.angleDelta.y < 0 || event.angleDelta.x < 0)
                        carousel.stepBy(-1)
                }
            }
        }

        // ── Footer ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Text {
                text: Themes.busy
                    ? "Applying…"
                    : Themes.status.length > 0
                        ? Themes.status
                        : (Themes.appliedId === (root.selected ? root.selected.id : "")
                            ? "Applied \u2713"
                            : "Enter to apply")
                color: Themes.status.length > 0 ? Theme.danger : Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }
        }
    }
}
