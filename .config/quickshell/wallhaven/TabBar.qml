// Tabs: the active one is shown by contrast and weight, not by the accent
// (THEME.md). While searching, none is active. Switching is instant.

import QtQuick

Row {
    id: bar
    required property var app
    spacing: Theme.s4

    Repeater {
        model: bar.app.tabs
        Text {
            required property var modelData
            required property int index
            readonly property bool active: !bar.app.searching && index === bar.app.tabIndex
            text: modelData.label
            color: active ? Theme.text : Theme.textDim
            font { family: Theme.font; pointSize: Theme.fontSize; bold: active }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -Theme.s1
                cursorShape: Qt.PointingHandCursor
                onClicked: bar.app.switchTab(index)
            }
        }
    }
}
