// Heart toggle. Outline when not liked, filled when liked (neutral color:
// state is shown by the glyph, not the accent). The two glyphs cross-fade:
// scale 0.25 -> 1, opacity, 300ms cubic-bezier(0.2, 0, 0, 1).

import QtQuick

Rectangle {
    id: b

    property bool liked: false
    property int size: 28
    signal clicked()

    width: size
    height: size
    color: Qt.alpha(hover.hovered ? Theme.surfaceContainerHigh : Theme.surface, Theme.overlayAlpha)
    border.width: 0   // minimal style: no outlines on the small tile buttons

    scale: tap.pressed && Theme.motion ? 0.96 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.pressMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    component Glyph: Text {
        property bool shown: false
        anchors.centerIn: parent
        color: Theme.text
        font { family: Theme.font; pointSize: Theme.fontSize - 1 }
        opacity: shown ? 1 : 0
        scale: shown || !Theme.motion ? 1 : 0.25
        Behavior on opacity {
            NumberAnimation { duration: Theme.motion ? Theme.iconMs : Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeIcon }
        }
        Behavior on scale {
            NumberAnimation { duration: Theme.iconMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeIcon }
        }
    }

    Glyph { text: ""; shown: !b.liked }   // heart outline
    Glyph { text: ""; shown: b.liked }    // heart filled

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: b.clicked() }
}
