import QtQuick

import "../../core/theme"
import "../widgets"

/**
 * SettingsGroupCard — one labelled sub-section of a Settings page.
 *
 * A heading sits above a rounded surface card that stacks the
 * group's rows, each separated by a hairline divider. The page lays several of
 * these out in a responsive two-column grid (see SettingsPage.qml).
 *
 * The row is data-driven (see Catalog.js) and addresses values in the `Settings`
 * singleton by the row's `key`. A `controllayout` group is drawn bare: it brings
 * its own chrome and must not be clipped by a card.
 */
Item {
    id: root

    /// The catalog group `{ label, rows }` to render.
    property var group: null

    /// Emitted when an `action` row is clicked; the page runs it.
    signal actionTriggered(string action)

    readonly property var rows: root.group ? root.group.rows : []
    readonly property string label: root.group ? (root.group.label || "") : ""

    // A group whose only row draws its own chrome (the Control Center editor).
    readonly property bool bare: rows.length === 1 && rows[0].type === "controllayout"

    implicitHeight: heading.height + card.implicitHeight

    // ── Section heading ──────────────────────────────────────────────────────
    Text {
        id: heading
        x: Theme.cardPadding
        width: parent.width - Theme.cardPadding * 2
        visible: root.label.length > 0
        height: visible ? implicitHeight + Theme.spaceSm : 0
        text: root.label
        color: Theme.textDim
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sectionSize
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    // ── Card ─────────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.top: heading.bottom
        width: parent.width
        implicitHeight: rowsColumn.implicitHeight
        radius: root.bare ? 0 : Theme.radiusCard
        color: "transparent"
        gradient: root.bare ? null : glass
        border.width: root.bare ? 0 : 1
        border.color: Theme.border
        clip: !root.bare

        // The frosted card fill; skipped for a bare group, which brings its own
        // chrome.
        TileGlass { id: glass }

        Column {
            id: rowsColumn
            width: parent.width

            Repeater {
                model: root.rows

                delegate: Item {
                    id: rowItem
                    required property var modelData
                    required property int index

                    width: rowsColumn.width
                    height: (rowLoader.item ? rowLoader.item.implicitHeight : 0)
                        + (divider.visible ? 1 : 0)

                    Loader {
                        id: rowLoader
                        width: parent.width
                        anchors.top: parent.top
                        sourceComponent: {
                            switch (rowItem.modelData.type) {
                                case "slider":  return sliderComp
                                case "switch":  return switchComp
                                case "text":    return textComp
                                case "action":  return actionComp
                                case "info":    return infoComp
                                case "theme":   return themeComp
                                case "accent":  return accentComp
                                case "gamemode": return gameModeComp
                                case "motionpreset": return motionPresetComp
                                case "controllayout": return layoutComp
                                default:        return null
                            }
                        }
                        onLoaded: root.configureRow(item, rowItem.modelData)
                    }

                    Rectangle {
                        id: divider
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        visible: rowItem.index < root.rows.length - 1
                        color: Theme.border
                    }
                }
            }
        }
    }

    /// Push a catalog row's fields onto the freshly-loaded row component.
    function configureRow(item, d) {
        if (!item || !d)
            return
        if (d.key !== undefined)
            item.rowKey = d.key
        if (d.title !== undefined)
            item.title = d.title
        if (d.subtitle !== undefined && item.subtitle !== undefined)
            item.subtitle = d.subtitle
        if (d.min !== undefined)
            item.min = d.min
        if (d.max !== undefined)
            item.max = d.max
        if (d.step !== undefined)
            item.step = d.step
        if (d.decimals !== undefined)
            item.decimals = d.decimals
        if (d.suffix !== undefined)
            item.suffix = d.suffix
        if (d.value !== undefined)
            item.value = d.value
        if (d.action !== undefined && item.action !== undefined)
            item.action = d.action
        if (d.action !== undefined && item.triggered !== undefined)
            item.triggered.connect(function (a) { root.actionTriggered(a) })
    }

    Component { id: sliderComp;   SettingSliderRow {} }
    Component { id: switchComp;   SettingSwitchRow {} }
    Component { id: textComp;     SettingTextRow {} }
    Component { id: actionComp;   SettingActionRow {} }
    Component { id: infoComp;     SettingInfoRow {} }
    Component { id: themeComp;    SettingThemePicker {} }
    Component { id: accentComp;   SettingAccentPicker {} }
    Component { id: gameModeComp; SettingGameModeRow {} }
    Component { id: motionPresetComp; SettingMotionPresetRow {} }
    Component { id: layoutComp;   ControlLayoutEditor {} }
}
