// One Ly-style text field: plain text with a blinking block cursor while it
// has focus. `secret` shows asterisks, as Ly does.

import QtQuick

TextInput {
    id: input
    property bool secret: false

    color: Theme.text
    font { family: Theme.font; pointSize: Theme.fontSize }
    echoMode: secret ? TextInput.Password : TextInput.Normal
    passwordCharacter: "*"
    selectByMouse: false
    clip: true

    cursorDelegate: Rectangle {
        width: input.font.pixelSize > 0 ? input.font.pixelSize * 0.6 : 9
        color: Theme.text
        visible: input.activeFocus && blink.on
        Timer {
            id: blink
            property bool on: true
            interval: 530; running: input.activeFocus; repeat: true
            onTriggered: on = !on
            onRunningChanged: on = true
        }
    }
}
