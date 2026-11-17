// A button as plain text, the login screen's (Ly's) minimal style: no fill,
// no border, lowercase label. Hover or keyboard focus brightens it and draws
// a 1px underline (the accent for keyboard focus); `lit` shows it bold in
// `tone` for a moment (e.g. the rating you just picked). Press scales to 0.96.

import QtQuick

Item {
    id: b

    property string icon: ""            // kept for compatibility; not drawn
    property string label: ""
    property string hint: ""
    property bool emphasized: false     // unused in the minimal style
    property bool focused: false        // keyboard focus (e.g. Tab on the done screen)
    property bool lit: false            // shown bold in `tone`
    property color tone: Theme.primary
    property color onTone: Theme.textOnPrimary
    property bool translucent: false    // unused: text needs no fill
    property int pad: Theme.s2
    signal clicked()

    readonly property bool highlighted: hover.hovered || focused

    implicitHeight: 28
    implicitWidth: textItem.implicitWidth + pad * 2

    opacity: enabled ? 1 : 0.4
    scale: tap.pressed && Theme.motion ? 0.96 : 1
    Behavior on scale {
        NumberAnimation { duration: Theme.pressMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
    }

    Text {
        id: textItem
        anchors.centerIn: parent
        text: b.label.toLowerCase() + (b.hint ? "  " + b.hint : "")
        color: b.lit ? b.tone : (b.highlighted ? Theme.text : Theme.textDim)
        font { family: Theme.font; pointSize: Theme.fontSize; bold: b.lit }
        Behavior on color { enabled: Theme.motion; ColorAnimation { duration: Theme.fadeMs } }
    }
    Rectangle {
        anchors { left: textItem.left; right: textItem.right; top: textItem.bottom; topMargin: 2 }
        height: 1
        visible: b.highlighted || b.lit
        color: b.lit ? b.tone : (b.focused ? Theme.primary : Theme.text)
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: b.clicked() }
}
