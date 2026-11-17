// Swipe-to-rate stack.
//
// Two cards swap roles: the front card is the one you rate, the back card
// is the next wallpaper, already loaded and waiting at scale 0.95. As the
// front card leaves, the back card grows to 1, so the next one is simply
// there when the swap happens (no reload, no pop).
//
// Motion (gated by Theme.motion; off = opacity cross-fade only):
//   drag      card follows the pointer 1:1, tilts with it
//   release   past 25% of the card, or a flick, decides; else springs back
//   like/nope card leaves the way it leans, 200ms strong ease-out
//   skip      card drops 24px and fades, 150ms strong ease-out
// Keys: Left/H nope, Right/L like, Down/J/Space skip, Up/K/Backspace back.
// Back brings the previous card in again from the way it left.

import QtQuick

Item {
    id: view

    property var queue: []
    property int index: 0
    property var marks: []                 // decision per rated card, for progress displays
    property real cardWidth: 924
    property real cardHeight: 520
    property bool centerVertically: false
    property bool infoStrip: false
    property int stampTop: Theme.s4 + Theme.s2

    readonly property var current: index < queue.length ? queue[index] : null
    readonly property var upcoming: index + 1 < queue.length ? queue[index + 1] : null

    signal rated(string type, var item)
    signal decided(string type)            // a choice was made; the card is leaving
    signal finished()

    function start(list) {
        queue = list
        marks = []
        index = 0
        reset()
    }

    // ---- motion state ----
    property bool busy: false
    property string pendingType: ""
    property real offsetX: 0
    property real offsetY: 0
    property real frontOpacity: 1
    property real skipT: 0                 // 0..1 while a skip runs
    property real flickVx: 0

    readonly property real dragX: drag.active ? drag.activeTranslation.x : offsetX
    readonly property real lean: Math.max(-1, Math.min(1, dragX / (cardWidth * 0.25)))
    // How far the front card has gone: drives the back card's scale.
    readonly property real progress: Math.max(skipT, Math.min(1, Math.abs(dragX) / (cardWidth * 0.75)))

    function reset() {
        offsetX = 0; offsetY = 0; frontOpacity = 1; skipT = 0
        busy = false
    }

    function exitDistance() { return (view.width + cardWidth) / 2 + 80 }

    // A new press while a card is still moving finishes that move at once,
    // so fast key presses are never dropped.
    function finishPending() {
        if (!busy) return
        if (exitAnim.running || skipAnim.running || fadeOnly.running) {
            exitAnim.stop(); skipAnim.stop(); fadeOnly.stop()   // stop() does not emit finished
            advance()
        } else {
            returnAnim.stop(); returnSkip.stop(); returnFade.stop()
            offsetX = 0; offsetY = 0; frontOpacity = 1; skipT = 0
            busy = false
        }
    }

    // Bring the previous card back, from the way it left, to rate it again.
    function back() {
        finishPending()
        if (busy || index === 0) return
        const m = marks.slice()
        const prev = m.pop()
        marks = m
        springBack.stop()
        index -= 1
        busy = true
        if (!Theme.motion) {
            frontOpacity = 0; offsetX = 0; offsetY = 0; skipT = 0
            returnFade.start()
        } else if (prev === "skip") {
            offsetY = 24; frontOpacity = 0; skipT = 1
            returnSkip.start()
        } else {
            offsetX = (prev === "like" ? 1 : -1) * exitDistance()
            returnAnim.start()
        }
    }

    function decide(type) {
        finishPending()
        if (busy || !current) return
        if (type === "pass") type = "skip"
        pendingType = type
        busy = true
        decided(type)
        springBack.stop()
        if (!Theme.motion) {
            fadeOnly.start()
        } else if (type === "skip") {
            skipAnim.start()
        } else {
            // Just far enough to clear the view, plus room for the tilt.
            exitAnim.to = (type === "like" ? 1 : -1) * exitDistance()
            exitAnim.start()
        }
    }

    function advance() {
        const it = current
        const m = marks.slice(); m.push(pendingType); marks = m
        rated(pendingType, it)
        index += 1      // the back card becomes the front card here
        reset()
        if (index >= queue.length) finished()
    }

    NumberAnimation {
        id: exitAnim
        target: view; property: "offsetX"
        duration: Theme.exitMs
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut
        onFinished: view.advance()
    }
    ParallelAnimation {
        id: skipAnim
        NumberAnimation { target: view; property: "offsetY"; to: 24; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: view; property: "frontOpacity"; to: 0; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: view; property: "skipT"; to: 1; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        onFinished: view.advance()
    }
    ParallelAnimation {
        id: fadeOnly
        NumberAnimation { target: view; property: "frontOpacity"; to: 0; duration: Theme.fadeMs }
        NumberAnimation { target: view; property: "skipT"; to: 1; duration: Theme.fadeMs }
        onFinished: view.advance()
    }
    // Returning cards: the reverse of how they left.
    NumberAnimation {
        id: returnAnim
        target: view; property: "offsetX"; to: 0
        duration: Theme.exitMs
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut
        onFinished: view.busy = false
    }
    ParallelAnimation {
        id: returnSkip
        NumberAnimation { target: view; property: "offsetY"; to: 0; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: view; property: "frontOpacity"; to: 1; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        NumberAnimation { target: view; property: "skipT"; to: 0; duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
        onFinished: view.busy = false
    }
    NumberAnimation {
        id: returnFade
        target: view; property: "frontOpacity"; to: 1; duration: Theme.fadeMs
        onFinished: view.busy = false
    }

    // Springs carry the release velocity and can be interrupted by a new drag.
    SpringAnimation {
        id: springBack
        target: view; property: "offsetX"
        to: 0; spring: 5; damping: 0.45; epsilon: 0.5
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Left: case Qt.Key_H: decide("dislike"); break
        case Qt.Key_Right: case Qt.Key_L: decide("like"); break
        case Qt.Key_Down: case Qt.Key_J: case Qt.Key_Space: decide("skip"); break
        case Qt.Key_Up: case Qt.Key_K: case Qt.Key_Backspace: back(); break
        default: return
        }
        event.accepted = true
    }

    // ---- the two cards ----
    Item {
        id: stage
        width: view.cardWidth
        height: view.cardHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: view.centerVertically ? (view.height - height) / 2 : 0

        Repeater {
            model: 2
            Card {
                id: card
                required property int index
                readonly property bool isFront: index === view.index % 2
                width: view.cardWidth
                height: view.cardHeight
                z: isFront ? 1 : 0
                visible: item !== null
                item: isFront ? view.current : view.upcoming
                stamps: isFront
                lean: isFront ? view.lean : 0
                infoStrip: view.infoStrip && isFront
                stampTop: view.stampTop

                opacity: isFront ? view.frontOpacity : 1
                scale: isFront || !Theme.motion ? 1 : 0.95 + 0.05 * view.progress
                transform: [
                    Rotation {
                        origin.x: card.width / 2
                        origin.y: card.height * 1.6
                        angle: card.isFront && Theme.motion ? view.dragX * 0.025 : 0
                    },
                    Translate {
                        x: card.isFront ? view.dragX : 0
                        y: card.isFront ? view.offsetY : 0
                    }
                ]
            }
        }

        DragHandler {
            id: drag
            target: null
            yAxis.enabled: false
            enabled: !view.busy && view.current !== null
            onCentroidChanged: if (active) view.flickVx = centroid.velocity.x
            onActiveChanged: {
                if (active) { springBack.stop(); view.flickVx = 0; return }
                const dx = activeTranslation.x
                view.offsetX = dx
                const flick = Math.abs(view.flickVx) > 900 && Math.sign(view.flickVx) === Math.sign(dx)
                if (dx > view.cardWidth * 0.25 || (flick && dx > 0)) view.decide("like")
                else if (dx < -view.cardWidth * 0.25 || (flick && dx < 0)) view.decide("dislike")
                else if (Theme.motion) springBack.start()
                else view.offsetX = 0
            }
        }
    }

    // Warm the cache for the card after next.
    Image {
        visible: false
        source: view.index + 2 < view.queue.length ? view.queue[view.index + 2].full : ""
        sourceSize.width: 1280
        asynchronous: true
    }
}
