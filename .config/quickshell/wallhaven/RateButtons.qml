// Back / Nope / Skip / Like buttons for a RatingView, in a row or a column.
// Key hints are off by default; the keys still work (Up / Left / Down / Right).
// Whatever you pick (button, key or swipe) lights up in its color for a
// moment: like = accent, nope = error, skip = neutral.

import QtQuick

Grid {
    id: btns
    required property var rating
    property bool vertical: false
    property bool hints: false
    property int buttonWidth: 160
    property string flash: ""          // the choice being shown
    property bool translucent: false   // on top of the wallpaper

    columns: vertical ? 1 : 4
    spacing: Theme.s2

    Connections {
        target: btns.rating
        function onDecided(type) { btns.flash = type; flashTimer.restart() }
    }
    // Long enough to see while the card leaves (200ms), then it fades back.
    Timer { id: flashTimer; interval: 320; onTriggered: btns.flash = "" }

    ActionButton {
        translucent: btns.translucent
        width: btns.buttonWidth
        icon: ""; label: "Back"; hint: btns.hints ? "↑" : ""
        enabled: btns.rating.index > 0
        opacity: enabled ? 1 : 0.4
        onClicked: btns.rating.back()
    }
    ActionButton {
        translucent: btns.translucent
        width: btns.buttonWidth
        icon: ""; label: "Nope"; hint: btns.hints ? "←" : ""
        lit: btns.flash === "dislike"
        tone: Theme.tone("dislike"); onTone: Theme.onTone("dislike")
        onClicked: btns.rating.decide("dislike")
    }
    ActionButton {
        translucent: btns.translucent
        width: btns.buttonWidth
        icon: ""; label: "Skip"; hint: btns.hints ? "↓" : ""
        lit: btns.flash === "skip"
        tone: Theme.tone("skip"); onTone: Theme.onTone("skip")
        onClicked: btns.rating.decide("skip")
    }
    ActionButton {
        translucent: btns.translucent
        width: btns.buttonWidth
        emphasized: true
        icon: ""; label: "Like"; hint: btns.hints ? "→" : ""
        lit: btns.flash === "like"
        tone: Theme.tone("like"); onTone: Theme.onTone("like")
        onClicked: btns.rating.decide("like")
    }
}
