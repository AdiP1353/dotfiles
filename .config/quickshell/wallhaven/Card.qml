// One wallpaper card in the rating stack: thumbnail at once, full image
// fading in over it, LIKE / NOPE stamps that follow how far you lean it.

import QtQuick

Rectangle {
    id: card

    property var item: null
    property real lean: 0            // -1 nope .. 1 like
    property bool stamps: false
    property bool infoStrip: false
    property int stampTop: Theme.s4 + Theme.s2   // push down when controls sit on the image

    color: Theme.surfaceContainer

    Image {
        anchors.fill: parent
        source: card.item ? card.item.thumb : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Image {
        anchors.fill: parent
        source: card.item ? card.item.full : ""
        sourceSize.width: 1280
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }

    // Image outline, inset 1px.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "transparent"
        border.width: 1
        border.color: Theme.imageOutline
    }

    component Stamp: Rectangle {
        property alias label: t.text
        property color tone
        width: t.implicitWidth + Theme.s4 * 2
        height: 40
        color: Theme.surface
        border.width: 2
        border.color: tone
        Text {
            id: t
            anchors.centerIn: parent
            color: parent.tone
            font { family: Theme.font; pointSize: Theme.fontSize + 4; bold: true }
        }
    }

    Stamp {
        visible: card.stamps
        anchors { left: parent.left; leftMargin: Theme.s4 + Theme.s2; top: parent.top; topMargin: card.stampTop }
        label: " LIKE"
        tone: Theme.primary
        opacity: Math.max(0, card.lean)
    }
    Stamp {
        visible: card.stamps
        anchors { right: parent.right; rightMargin: Theme.s4 + Theme.s2; top: parent.top; topMargin: card.stampTop }
        label: " NOPE"
        tone: Theme.error
        opacity: Math.max(0, -card.lean)
    }

    Rectangle {
        visible: card.infoStrip && card.item !== null
        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.s3 }
        width: info.implicitWidth + Theme.s3 * 2
        height: 28
        color: Theme.surface
        Row {
            id: info
            anchors.centerIn: parent
            spacing: Theme.s2
            Text {
                text: card.item ? card.item.resolution + "  " + card.item.category + "   " + card.item.favorites : ""
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
            Swatches { colors: card.item ? (card.item.colors || []) : []; size: 10 }
            Text {
                visible: !!(card.item && card.item.why)
                text: card.item && card.item.why ? card.item.why : ""
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small; italic: true }
            }
        }
    }
}
