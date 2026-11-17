// Search, as on the login screen: "search:" then plain text with a blinking
// block cursor; no box. Bound to app.searchText. Enter searches (or applies
// the selection if the text did not change); Down moves into the grid.

import QtQuick

Item {
    id: field

    required property var app
    property alias input: input
    signal downPressed()

    implicitHeight: 28

    Text {
        id: label
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        text: "search:"
        color: input.activeFocus ? Theme.text : Theme.textDim
        font { family: Theme.font; pointSize: Theme.fontSize }
    }

    TextInput {
        id: input
        anchors { left: label.right; leftMargin: Theme.s2; right: parent.right; verticalCenter: parent.verticalCenter }
        clip: true
        color: Theme.text
        selectionColor: Theme.primary
        selectedTextColor: Theme.textOnPrimary
        font { family: Theme.font; pointSize: Theme.fontSize }
        onTextEdited: field.app.searchText = text
        Keys.onReturnPressed: field.app.submitSearch()
        Keys.onDownPressed: field.downPressed()
        // Left/Right only move the text cursor when there is text to move in.
        Keys.onLeftPressed: event => { if (text === "") field.downPressed(); else event.accepted = false }
        Keys.onRightPressed: event => { if (text === "") field.downPressed(); else event.accepted = false }

        cursorDelegate: Rectangle {
            width: 7
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

        Text {
            visible: !parent.text && !parent.activeFocus
            text: "all of wallhaven"
            color: Theme.textDim
            font: parent.font
        }
    }

    Connections {
        target: field.app
        function onSearchTextChanged() { if (input.text !== field.app.searchText) input.text = field.app.searchText }
    }
}
