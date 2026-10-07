import QtQuick
import QtQuick.Layouts

import "../../core/theme"
import "Catalog.js" as Catalog

/**
 * SettingsSidebar — the search field and sectioned category list on the left of
 * the Settings window (mirrors the reference screenshot).
 *
 * Categories are grouped under the section headings from `Catalog.sections`
 * (Appearance, Features, System). While a search query is active, only pages
 * that match and the sections containing them are listed.
 */
Item {
    id: root

    property string currentKey: "bar"
    property alias query: searchField.text

    signal selected(string key)

    /// The catalog's sections, each carrying the pages that match the current
    /// query. Sections with no matching page are dropped, so searching collapses
    /// the list to just the relevant groups.
    readonly property var sections: {
        var q = root.query.trim().toLowerCase()
        var out = []
        for (var s = 0; s < Catalog.sections.length; s++) {
            var sec = Catalog.sections[s]
            var hits = []
            for (var p = 0; p < Catalog.pages.length; p++) {
                var pg = Catalog.pages[p]
                if (pg.section === sec.key && Catalog.pageMatches(pg, q))
                    hits.push(pg)
            }
            if (hits.length > 0)
                out.push({ label: sec.label, pages: hits })
        }
        return out
    }

    // Search field
    Rectangle {
        id: searchBox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.spaceMd
        anchors.rightMargin: Theme.spaceMd
        anchors.topMargin: Theme.spaceMd
        height: 36
        radius: Theme.radiusInner
        color: Theme.surfaceElevated
        border.width: 1
        border.color: searchField.activeFocus ? Theme.accent : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.motionFast } }

        // Behind the content so the icon/padding focus the field while the
        // TextInput keeps its own clicks for the cursor.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: searchField.forceActiveFocus()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.padRow
            anchors.rightMargin: Theme.padRow
            spacing: Theme.spaceSm

            Text {
                text: "\uF002" // nf-fa-search
                color: searchField.activeFocus ? Theme.accent : Theme.textSecondary
                font.family: Theme.iconFont
                font.pixelSize: 13
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: searchField.implicitHeight

                TextInput {
                    id: searchField
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.textPrimary
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.backgroundSolid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    clip: true

                    Keys.onEscapePressed: text = ""
                }

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length === 0
                    text: "Search Settings"
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.titleSize
                    enabled: false
                }
            }
        }
    }

    // Category list
    Column {
        id: nav
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: searchBox.bottom
        anchors.topMargin: Theme.spaceMd
        spacing: Theme.spaceLg

        Repeater {
            model: root.sections

            delegate: Column {
                id: sectionCol

                required property var modelData

                width: nav.width
                spacing: 2

                Text {
                    x: Theme.spaceMd + Theme.padRow
                    visible: sectionCol.modelData.label.length > 0
                    height: visible ? implicitHeight + Theme.spaceSm : 0
                    text: sectionCol.modelData.label
                    color: Theme.textDim
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sectionSize
                    font.weight: Font.Medium
                }

                Repeater {
                    model: sectionCol.modelData.pages

                    delegate: Rectangle {
                        id: item

                        required property var modelData
                        readonly property bool active: modelData.key === root.currentKey

                        width: nav.width - Theme.spaceMd * 2
                        x: Theme.spaceMd
                        height: 40
                        radius: Theme.radiusInner
                        color: item.active
                            ? Theme.surfaceElevated
                            : (itemHover.hovered ? Theme.surfaceHover : "transparent")
                        Behavior on color { ColorAnimation { duration: Theme.motionSnap } }

                        HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.padRow
                            anchors.rightMargin: Theme.padRow
                            spacing: Theme.spaceMd

                            Text {
                                Layout.alignment: Qt.AlignVCenter
                                text: item.modelData.icon
                                color: item.active ? Theme.accent : Theme.textSecondary
                                font.family: Theme.iconFont
                                font.pixelSize: 15
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: item.modelData.name
                                color: item.active ? Theme.textPrimary : Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.titleSize
                                font.weight: item.active ? Font.Medium : Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selected(item.modelData.key)
                        }
                    }
                }
            }
        }
    }
}
