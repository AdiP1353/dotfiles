// Small square icon button (e.g. nope on a thumbnail). Same press and hover
// behavior as ActionButton.

import QtQuick

Rectangle {
    id: b

    property string icon: ""
    property int size: 28
    property bool active: false     // current choice: filled with `tone`
    property color tone: Theme.text
    property color onTone: Theme.surface
    signal clicked()

    width: size
    height: size
    color: active ? tone : Qt.alpha(hover.hovered ? Theme.surfaceContainerHigh : Theme.surface, Theme.overlayAlpha)
    border.width: 0   // minimal style: no outlines on the small tile buttons

    scale: tap.pressed && Theme.motion ? 0.96 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.pressMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    Text {
        anchors.centerIn: parent
        text: b.icon
        color: b.active ? b.onTone : Theme.text
        font { family: Theme.font; pointSize: Theme.fontSize - 1 }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: b.clicked() }
}
