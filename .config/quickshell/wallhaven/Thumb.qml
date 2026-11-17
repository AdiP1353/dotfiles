// One grid thumbnail (used as the GridView delegate in every layout).
// - fades in when its image arrives (150ms), instead of popping in
// - 1px pure black/white outline at 10% so edges never fringe
// - selection: 2px accent border, plus like / nope buttons (instant: these
//   change tens of times a minute while browsing)
// - infoStrip: solid strip with resolution and reason on the selected tile

import QtQuick

Item {
    id: cell

    required property int index
    required property string wid
    required property string thumb
    required property string resolution
    required property string why
    required property string rating     // Rated tab: like | dislike | skip

    property var app
    property int gap: Theme.s2
    property bool infoStrip: false
    property bool rateMode: false       // Rated tab: show and change the rating
    readonly property string ratingIcon: ({ like: "\uf004", dislike: "\uf00d", skip: "\uf063" })[rating] || ""

    readonly property GridView view: GridView.view
    readonly property bool selected: GridView.isCurrentItem
    readonly property bool liked: !!app.likedIds[wid]

    width: view.cellWidth
    height: view.cellHeight

    Rectangle {
        id: frame
        anchors.fill: parent
        anchors.margins: cell.gap / 2
        color: Theme.surfaceContainer

        Image {
            anchors.fill: parent
            source: cell.thumb
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 432
            opacity: status === Image.Ready ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut }
            }
        }

        // Image outline, inset 1px.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.width: 1
            border.color: Theme.imageOutline
        }

        // Liked marker on tiles that are not selected (selected ones show the buttons).
        Rectangle {
            visible: !cell.selected && (cell.rateMode ? cell.ratingIcon !== "" : cell.liked)
            anchors { right: parent.right; top: parent.top; margins: Theme.s2 }
            width: 24; height: 24
            color: Theme.surface
            Text {
                anchors.centerIn: parent
                text: cell.rateMode ? cell.ratingIcon : "\uf004"
                color: cell.rateMode ? Theme.tone(cell.rating) : Theme.text
                font { family: Theme.font; pointSize: Theme.small }
            }
        }

        // Reason / size strip on the selected tile.
        Rectangle {
            visible: cell.infoStrip && cell.selected
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 24
            color: Theme.surface
            Text {
                anchors { left: parent.left; leftMargin: Theme.s2; right: parent.right; rightMargin: Theme.s2; verticalCenter: parent.verticalCenter }
                text: cell.resolution + (cell.why ? "  " + cell.why : "")
                elide: Text.ElideRight
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
        }

        // Accent: selection / hover only.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: cell.selected ? Theme.primary : "transparent"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Follow real mouse movement only. When the grid scrolls under a
        // parked pointer (arrow keys), Qt sends the tile now under it a
        // synthetic hover move at the same screen position; ignoring those
        // keeps the keyboard selection where the keys put it.
        onPositionChanged: mouse => {
            const p = mapToGlobal(mouse.x, mouse.y)
            const last = cell.app.lastPointer
            if (last && Math.abs(p.x - last.x) < 1 && Math.abs(p.y - last.y) < 1) return
            cell.app.lastPointer = Qt.point(p.x, p.y)
            if (cell.app.currentIndex !== cell.index) cell.app.currentIndex = cell.index
        }
        onClicked: { cell.app.currentIndex = cell.index; cell.app.applyCurrent() }
    }

    Row {
        visible: cell.selected && !cell.rateMode
        anchors { right: parent.right; top: parent.top; margins: cell.gap / 2 + Theme.s2 }
        spacing: Theme.s1
        LikeButton { liked: cell.liked; onClicked: cell.app.toggleLike(cell.index) }
        IconButton { icon: "\uf00d"; onClicked: cell.app.dislike(cell.index) }
    }

    // Rated tab: the current rating is the inverted button; pick another to change it.
    Row {
        visible: cell.selected && cell.rateMode
        anchors { right: parent.right; top: parent.top; margins: cell.gap / 2 + Theme.s2 }
        spacing: Theme.s1
        IconButton { icon: "\uf004"; active: cell.rating === "like";    tone: Theme.tone("like");    onTone: Theme.onTone("like");    onClicked: cell.app.setRating(cell.index, "like") }
        IconButton { icon: "\uf063"; active: cell.rating === "skip";    tone: Theme.tone("skip");    onTone: Theme.onTone("skip");    onClicked: cell.app.setRating(cell.index, "skip") }
        IconButton { icon: "\uf00d"; active: cell.rating === "dislike"; tone: Theme.tone("dislike"); onTone: Theme.onTone("dislike"); onClicked: cell.app.setRating(cell.index, "dislike") }
    }
}
