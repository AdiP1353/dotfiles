// A wallpaper's palette as small squares.

import QtQuick

Row {
    id: sw
    property var colors: []
    property int size: 12
    spacing: Theme.s1

    Repeater {
        model: sw.colors
        Rectangle {
            required property string modelData
            width: sw.size
            height: sw.size
            anchors.verticalCenter: parent.verticalCenter
            color: modelData
            border.width: 1
            border.color: Theme.imageOutline
        }
    }
}
