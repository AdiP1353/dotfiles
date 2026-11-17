// Results grid shared by every layout.
// Selection and keyboard movement are instant (they happen constantly).
// When a tile is removed (nope), it fades and shrinks to 0.96 in 150ms and
// the tiles after it slide into the gap in 200ms (strong ease-in-out).

import QtQuick

GridView {
    id: grid

    required property var app
    property int gap: Theme.s2
    property bool infoStrip: false
    signal upFromTop()
    signal typed(string ch)

    clip: true
    model: app.results
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0
    cacheBuffer: 800
    currentIndex: 0

    onCurrentIndexChanged: {
        if (app.currentIndex !== currentIndex) app.currentIndex = currentIndex
        if (currentIndex >= count - 4) app.loadMore()
    }
    onAtYEndChanged: if (atYEnd) app.loadMore()

    Keys.onReturnPressed: app.applyCurrent()
    Keys.onUpPressed: event => {
        if (currentIndex < Math.round(width / cellWidth)) upFromTop()
        else moveCurrentIndexUp()
    }
    // Typing a letter jumps back to the search box.
    Keys.onPressed: event => {
        if (event.text.length === 1 && event.text.trim() !== "" && !(event.modifiers & Qt.ControlModifier)) {
            typed(event.text)
            event.accepted = true
        }
    }

    remove: Transition {
        enabled: Theme.motion
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            NumberAnimation { property: "scale"; to: 0.96; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        }
    }
    displaced: Transition {
        enabled: Theme.motion
        NumberAnimation { properties: "x,y"; duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeInOut }
        // A displaced tile that was mid-removal must end fully visible.
        NumberAnimation { properties: "opacity,scale"; to: 1; duration: 0 }
    }

    delegate: Thumb {
        app: grid.app
        gap: grid.gap
        infoStrip: grid.infoStrip
        rateMode: !grid.app.searching && grid.app.tabs[grid.app.tabIndex].id === "rated"
    }
}
