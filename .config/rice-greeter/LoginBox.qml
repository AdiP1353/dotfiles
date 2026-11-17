// The Ly look: key hints top-left, and one bordered box with the hostname, a
// < session > switcher, login: and password:, over the wallpaper blurred
// heavily. Font: the wallhaven picker's (JetBrains Mono 12pt), so the two
// read as one system.
//
// Used by the login screen (shell.qml) and the lock screen (lock.qml). In
// lock mode there is no session switcher and the login is fixed to you.
//
// Keys: Up/Down/Tab move between rows, Left/Right change the session, Enter
// on login moves to password, Enter on password logs in / unlocks, F1/F2
// power, F3 shows/hides the password.

import QtQuick
import Quickshell
import QtQuick.Effects

FocusScope {
    id: box
    required property var app
    required property bool primary

    readonly property bool lockMode: !!app.lockMode
    readonly property int labelW: 11      // characters: "password: " plus a space
    readonly property int fieldChars: 34  // Ly's input_len
    readonly property real ch: metrics.advanceWidth   // one monospace cell
    property bool reveal: false           // show the password as text

    // Entrance (login screen only; the lock screen must cover the desktop
    // at once): clock, then box, then hints, 100ms apart, each fading in and
    // rising 12px over 300ms with the strong ease-out. Wallpaper comes with
    // the clock. Reduced motion: the same fades, no movement.
    property real e0: lockMode ? 1 : 0
    property real e1: lockMode ? 1 : 0
    property real e2: lockMode ? 1 : 0
    component Enter: NumberAnimation {
        target: box; from: 0; to: 1; duration: 300
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut
    }
    ParallelAnimation {
        running: !box.lockMode
        Enter { property: "e0" }
        SequentialAnimation { PauseAnimation { duration: 100 } Enter { property: "e1" } }
        SequentialAnimation { PauseAnimation { duration: 200 } Enter { property: "e2" } }
    }
    function rise(e) { return Theme.motion ? Math.round((1 - e) * 12) : 0 }

    TextMetrics { id: metrics; font.family: Theme.font; font.pointSize: Theme.fontSize; text: "M" }

    Connections {
        target: box.app
        function onFailed() { password.text = ""; password.forceActiveFocus() }
    }
    // Focus the field the moment the box shows, and again shortly after: a lock
    // surface can map late, and typing must never go nowhere.
    function grabFocus() { if (primary) (login.text === "" || box.lockMode ? (box.lockMode ? password : login) : password).forceActiveFocus() }
    Component.onCompleted: grabFocus()
    Timer { interval: 300; running: true; repeat: false; onTriggered: box.grabFocus() }
    onActiveFocusChanged: if (activeFocus && !login.activeFocus && !password.activeFocus && !session.activeFocus) grabFocus()

    function row(dir) {
        const rows = box.lockMode ? [password] : [session, login, password]
        let i = rows.findIndex(r => r.activeFocus)
        i = (i + dir + rows.length) % rows.length
        rows[i].forceActiveFocus()
    }

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_F1: box.app.power("poweroff"); break
        case Qt.Key_F2: box.app.power("reboot"); break
        case Qt.Key_F3: box.reveal = !box.reveal; break
        case Qt.Key_Down: case Qt.Key_Tab: row(1); break
        case Qt.Key_Up: case Qt.Key_Backtab: row(-1); break
        default: return
        }
        event.accepted = true
    }

    // Wallpaper: a small copy (sync-wallpaper.sh) decoded tiny and stretched,
    // so the smear does most of the blurring; drawn 96px past every edge so
    // the blur never pulls in empty space. Dimmed so the box stays readable.
    Image {
        id: wall
        anchors { fill: parent; margins: -96 }
        source: "file://" + Theme.dataDir + "/wallpaper.jpg"
        sourceSize.width: 128
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: true
        cache: false
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        visible: wall.status === Image.Ready
        opacity: box.e0
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        blurMultiplier: 1.5
        brightness: -0.35
        saturation: -0.15
    }

    Text {
        visible: box.primary
        x: Theme.s4 * 1.5; y: Theme.s4 * 1.5
        text: "F1 shutdown F2 reboot F3 show password"
        opacity: box.e2
        transform: Translate { y: box.rise(box.e2) }
        color: Theme.text
        font { family: Theme.font; pointSize: Theme.fontSize }
    }

    // A small clock above the box, in the same font (lock and login screens).
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        visible: box.primary
        anchors { horizontalCenter: frame.horizontalCenter; bottom: frame.top; bottomMargin: Theme.s4 }
        text: Qt.formatTime(clock.date, "HH:mm")
        opacity: box.e0
        transform: Translate { y: box.rise(box.e0) }
        color: Theme.text
        font { family: Theme.font; pointSize: Theme.fontSize + 6 }
    }

    Rectangle {
        id: frame
        visible: box.primary
        anchors.centerIn: parent
        width: (box.labelW + box.fieldChars + 6) * box.ch
        height: col.implicitHeight + Theme.s4 * 3
        color: "transparent"
        border.width: 2
        opacity: box.e1
        transform: Translate { y: box.rise(box.e1) }
        // Typing pulse: each keypress lights the border up, then it fades
        // back to the dim grey in 150ms. Subtle feedback, no extra element.
        property real pulse: 0
        border.color: Qt.tint(Theme.textDim, Qt.alpha(Theme.text, pulse))
        NumberAnimation on pulse { id: pulseAnim; running: false; from: 1; to: 0; duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: Theme.s4 * 1.5
                      leftMargin: box.ch * 3; rightMargin: box.ch * 3 }
            spacing: Theme.s4 * 1.4

            // hostname, centred
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: box.app.hostname
                color: Theme.text
                font { family: Theme.font; pointSize: Theme.fontSize }
            }

            // info / error line (only when there is something to say)
            Text {
                width: parent.width
                visible: box.app.status !== ""
                horizontalAlignment: Text.AlignHCenter
                text: box.app.status
                color: box.app.statusIsError ? Theme.error : Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }

            // < session >  (login screen only)
            Item {
                id: session
                visible: !box.lockMode
                width: parent.width
                height: sessionText.implicitHeight
                activeFocusOnTab: !box.lockMode
                Keys.onLeftPressed: box.app.cycleSession(-1)
                Keys.onRightPressed: box.app.cycleSession(1)
                Keys.onReturnPressed: box.row(1)
                Text {
                    id: sessionText
                    x: box.labelW * box.ch
                    text: "< " + box.app.sessionName
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
                Text {
                    anchors.right: parent.right
                    text: ">"
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
                // focus marker: a thin line under the session name
                Rectangle {
                    visible: session.activeFocus
                    x: sessionText.x; anchors.top: sessionText.bottom
                    width: parent.width - x; height: 1
                    color: Theme.textDim
                }
                TapHandler { onTapped: session.forceActiveFocus() }
            }

            Row {
                Text {
                    width: box.labelW * box.ch
                    text: "login:"
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
                Field {
                    id: login
                    width: box.fieldChars * box.ch
                    text: box.app.defaultUser
                    readOnly: box.lockMode
                    activeFocusOnTab: !box.lockMode
                    enabled: !box.app.busy
                    Keys.onReturnPressed: password.forceActiveFocus()
                    onTextChanged: box.app.user = text
                }
            }

            Row {
                Text {
                    width: box.labelW * box.ch
                    text: "password:"
                    color: Theme.text
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
                Field {
                    id: password
                    width: (box.fieldChars - 3) * box.ch
                    secret: !box.reveal
                    enabled: !box.app.busy
                    onTextEdited: pulseAnim.restart()
                    Keys.onReturnPressed: box.app.submit(text)
                    Keys.onEnterPressed: box.app.submit(text)
                }
                // Reveal toggle: eye / eye-slash (or F3). Bright while showing.
                Text {
                    width: 3 * box.ch
                    horizontalAlignment: Text.AlignRight
                    text: box.reveal ? "" : ""
                    color: box.reveal ? Theme.text : Theme.textDim
                    font { family: Theme.font; pointSize: Theme.fontSize }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { box.reveal = !box.reveal; password.forceActiveFocus() } }
                }
            }
        }
    }
}
