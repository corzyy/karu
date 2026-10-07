import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "../../core/config"

/**
 * SettingMotionPresetRow — the Motion page's preset picker.
 *
 * Instead of a bank of timing sliders, motion is chosen from a handful of named
 * feels (see `Settings.motionPresets`). Each chip applies its whole bundle of
 * values at once, and a live preview beneath the chips animates with the
 * selected values — the mock island springs open and closed on the preset's
 * spring/damping, its rows cascade in on the preset's stagger, and a small dot
 * lifts with the preset's hover overshoot. Under Game Mode / Reduce Motion the
 * preview collapses to instant snaps, exactly like the shell.
 */
Item {
    id: root

    property string title: ""
    property string subtitle: ""

    readonly property var presets: Settings.motionPresets
    readonly property string current: Settings.motionPreset

    implicitHeight: inner.implicitHeight + Theme.cardPadding * 2

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.cardPadding
        anchors.rightMargin: Theme.cardPadding
        spacing: 12

        // ── Header ───────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.title.length > 0 || root.subtitle.length > 0

            Text {
                Layout.fillWidth: true
                visible: root.title.length > 0
                text: root.title
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.titleSize
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                wrapMode: Text.WordWrap
            }
        }

        // ── Preset chips ─────────────────────────────────────────────────────
        Flow {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            Repeater {
                model: root.presets

                delegate: Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool applied: modelData.id === root.current

                    width: chipLabel.implicitWidth + 30
                    height: 34
                    radius: height / 2
                    color: applied ? Theme.accentMuted : Theme.surfaceHover
                    border.width: 1
                    border.color: applied ? Theme.accent : Theme.border

                    Behavior on color { ColorAnimation { duration: Theme.motionSnap } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionSnap } }

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData.name
                        color: chip.applied ? Theme.accent : Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.titleSize
                        font.weight: Font.Medium
                    }

                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Settings.applyMotionPreset(chip.modelData.id) }
                }
            }
        }

        // ── Live preview ─────────────────────────────────────────────────────
        Rectangle {
            id: stage

            Layout.fillWidth: true
            Layout.preferredHeight: 132
            radius: Theme.radiusInner
            color: Theme.track
            clip: true

            /// True while the island is in its open state.
            property bool expanded: false
            /// Game Mode / Reduce Motion — collapse the preview to hard snaps.
            readonly property bool off: Theme.motionOff
            readonly property int pad: 18

            function reset() {
                expanded = false
                loop.restart()
            }

            Timer {
                id: loop
                interval: 1700
                running: true
                repeat: true
                onTriggered: stage.expanded = !stage.expanded
            }

            // The mock island: springs between a collapsed pill and a panel.
            Rectangle {
                id: island
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: stage.expanded ? Math.min(stage.width - stage.pad * 2, 260) : 92
                height: stage.expanded ? 92 : 32
                radius: Math.min(height / 2, 30)
                color: Theme.surfaceElevated
                border.width: 1
                border.color: Theme.border
                clip: true

                Behavior on width {
                    enabled: !stage.off
                    SpringAnimation {
                        spring: Settings.panelSpring
                        damping: Settings.panelDamping
                        mass: 1.0
                        epsilon: 0.25
                    }
                }

                Behavior on height {
                    enabled: !stage.off
                    SpringAnimation {
                        spring: Settings.panelSpring
                        damping: Settings.panelDamping
                        mass: 1.0
                        epsilon: 0.25
                    }
                }

                // Staggered rows, revealed a beat apart as the panel opens.
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    scale: stage.expanded ? 1.0 : Settings.contentScaleFrom

                    Behavior on scale {
                        enabled: !stage.off
                        NumberAnimation {
                            duration: Theme.motionMedium
                            easing.type: Theme.easeOut
                        }
                    }

                    Repeater {
                        model: 3

                        delegate: Rectangle {
                            id: rowRect
                            required property int index
                            width: 120
                            height: 9
                            radius: height / 2
                            color: Theme.textDim
                            opacity: 0

                            SequentialAnimation {
                                id: enterAnim
                                PauseAnimation {
                                    duration: Theme.contentRevealDelay + rowRect.index * Theme.contentStagger
                                }
                                NumberAnimation {
                                    target: rowRect
                                    property: "opacity"
                                    to: 1
                                    duration: Theme.motionMedium
                                    easing.type: Theme.easeOut
                                }
                            }

                            NumberAnimation {
                                id: leaveAnim
                                target: rowRect
                                property: "opacity"
                                to: 0
                                duration: Theme.motionSnap
                            }

                            Connections {
                                target: stage
                                function onExpandedChanged() {
                                    if (stage.expanded) {
                                        leaveAnim.stop()
                                        enterAnim.restart()
                                    } else {
                                        enterAnim.stop()
                                        leaveAnim.restart()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // The hover cue: a dot that lifts with the preset's overshoot.
            Rectangle {
                id: hoverDot
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: width / 2
                color: Theme.accent

                SequentialAnimation {
                    loops: Animation.Infinite
                    running: !stage.off

                    NumberAnimation { target: hoverDot; property: "scale"; to: 1.0; duration: Theme.motionSnap }
                    PauseAnimation { duration: 480 }
                    NumberAnimation {
                        target: hoverDot
                        property: "scale"
                        to: Settings.hoverScale
                        duration: Theme.motionFast
                        easing.type: Easing.OutBack
                        easing.overshoot: Settings.springOvershoot
                    }
                    PauseAnimation { duration: 480 }
                }
            }

            // Preset name, so the preview is readable at a glance.
            Text {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10
                text: {
                    for (var i = 0; i < root.presets.length; i++)
                        if (root.presets[i].id === root.current)
                            return root.presets[i].name
                    return ""
                }
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
            }

            // The selected preset's one-line feel, on the right.
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: Math.max(0, parent.width - 130)
                text: {
                    for (var j = 0; j < root.presets.length; j++)
                        if (root.presets[j].id === root.current)
                            return root.presets[j].desc || ""
                    return ""
                }
                color: Theme.textDim
                font.family: Theme.fontFamily
                font.pixelSize: Theme.subtitleSize
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
            }
        }
    }

    // Re-run the preview from the start whenever a new preset is chosen.
    onCurrentChanged: stage.reset()
}
