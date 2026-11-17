// One square per card in the rating session.
// Each rated card is filled in its choice's color (like = accent, nope =
// error, skip = neutral); the current one has an outline.

import QtQuick

Row {
    id: prog
    required property var rating
    property int size: 10
    spacing: Theme.s1

    Repeater {
        model: prog.rating.queue.length
        Rectangle {
            required property int index
            readonly property string mark: index < prog.rating.marks.length ? prog.rating.marks[index] : ""
            readonly property bool isCurrent: index === prog.rating.index
            width: prog.size
            height: prog.size
            anchors.verticalCenter: parent.verticalCenter
            color: mark !== "" ? Theme.tone(mark) : "transparent"
            border.width: 1
            border.color: mark !== "" ? Theme.tone(mark) : (isCurrent ? Theme.text : Theme.outlineVariant)
        }
    }
}
