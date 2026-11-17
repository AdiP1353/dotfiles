// Picker layout: wallpapers edge to edge with 2px seams, 16:9 tiles, and one
// command bar along the bottom (search, tabs, status). Minimal style, as on
// the login screen: one kind of box (LyBox, a plain 2px border), text-only
// buttons, a "search:" field with a block cursor, no shadows.
// Rating: the card fills the whole panel; progress, details, "Skip all" and
// the Nope / Skip / Like buttons sit on the image. After a batch, a short
// screen offers "Keep rating" (another 10) or "See picks". "Rate more" in the
// bar starts a batch from browsing. They stay put while the
// card is swiped away underneath them.

import QtQuick

Rectangle {
    id: layout
    required property var app

    readonly property int seam: 2
    readonly property int cellW: Math.floor((width - 4) / 4)   // the grid is width - 4 wide
    readonly property int cellH: Math.round(cellW * 9 / 16)
    // As a normal window the layout takes whatever size Hyprland gives it:
    // 4 columns across, as many rows as fit (the grid scrolls for the rest).
    readonly property int bodyH: Math.max(cellH, height - barH - 4)
    readonly property int barH: 48
    readonly property bool rating: app.mode === "rating" || app.mode === "done"
    // Which part has keyboard focus (for the IPC `current` check).
    readonly property string focusName: grid.activeFocus ? "grid"
        : search.input.activeFocus ? "search" : ratingView.activeFocus ? "rating"
        : activeFocus ? "panel" : "none"

    width: parent ? parent.width : 1240
    height: parent ? parent.height : 748
    color: Theme.surface
    // The window's own 2px Hyprland border is the frame now; no second one.
    border.width: 0
    focus: true

    MouseArea { anchors.fill: parent }   // keep clicks from closing the picker
    Keys.onPressed: event => app.handleKey(event)

    Connections {
        target: layout.app
        function onFocusRequested(what) {
            if (what === "rating") ratingView.forceActiveFocus()
            else if (what === "done") layout.forceActiveFocus()
            else if (what === "grid") grid.forceActiveFocus()
            else search.input.forceActiveFocus()
        }
        function onViewReset() { grid.positionViewAtBeginning() }
        function onCurrentIndexChanged() { if (grid.currentIndex !== layout.app.currentIndex) grid.currentIndex = layout.app.currentIndex }
    }
    Component.onCompleted: app.ratingView = ratingView

    // ---- Rating: fills the whole panel ----
    Item {
        id: rateArea
        x: 2; y: 2
        width: layout.width - 4
        height: layout.height - 4
        clip: true
        opacity: layout.rating ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        RatingView {
            id: ratingView
            anchors.fill: parent
            cardWidth: parent.width
            cardHeight: parent.height
            stampTop: 32 + Theme.s3 * 2      // below the info chip and Skip all
            onRated: (type, item) => layout.app.rateFromCard(type, item)
            onFinished: layout.app.batchDone()
        }

        // Controls on the image (above the cards, not part of them).
        LyBox {
            id: infoChip
            onImage: true
            anchors { left: parent.left; top: parent.top; margins: Theme.s3 }
            width: infoRow.implicitWidth + Theme.s3 * 2
            height: 32
            visible: layout.app.mode === "rating" && ratingView.current !== null
            Row {
                id: infoRow
                anchors.centerIn: parent
                spacing: Theme.s3
                RateProgress { rating: ratingView; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property var c: ratingView.current
                    text: c ? c.resolution + "  " + c.category + "   " + c.favorites : ""
                    color: Theme.textDim
                    font { family: Theme.font; pointSize: Theme.small }
                }
                Swatches {
                    anchors.verticalCenter: parent.verticalCenter
                    colors: ratingView.current ? (ratingView.current.colors || []) : []
                    size: 10
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: ratingView.current && ratingView.current.why ? ratingView.current.why : ""
                    color: Theme.textDim
                    font { family: Theme.font; pointSize: Theme.small; italic: true }
                }
            }
        }

        LyBox {
            visible: layout.app.mode === "rating"
            onImage: true
            anchors { right: parent.right; top: parent.top; margins: Theme.s3 }
            width: skipAll.implicitWidth + Theme.s2 * 2
            height: 32
            ActionButton { id: skipAll; anchors.centerIn: parent; label: "skip all"; onClicked: layout.app.finishRating() }
        }

        LyBox {
            visible: layout.app.mode === "rating"
            onImage: true
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.s4 }
            width: rateButtons.implicitWidth + Theme.s4 * 2
            height: 40
            RateButtons {
                id: rateButtons
                anchors.centerIn: parent
                rating: ratingView
                buttonWidth: 80
            }
        }

        // ---- Batch finished: keep rating or see the picks ----
        LyBox {
            anchors.centerIn: parent
            visible: layout.app.mode === "done"
            opacity: doneScreen.opacity
            width: doneScreen.implicitWidth + Theme.s4 * 4
            height: doneScreen.implicitHeight + Theme.s4 * 3
        }
        Column {
            id: doneScreen
            anchors.centerIn: parent
            spacing: Theme.s4
            visible: layout.app.mode === "done"
            // Infrequent moment: a short staged entrance (fade + 12px rise).
            opacity: visible ? 1 : 0
            transform: Translate { y: doneScreen.visible || !Theme.motion ? 0 : 12; Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } } }
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ratingView.queue.length + " rated"
                color: Theme.text
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.s4
                Repeater {
                    model: [
                        { type: "like",    icon: "\uf004", n: layout.app.lastBatch.like || 0, label: "liked" },
                        { type: "dislike", icon: "\uf00d", n: layout.app.lastBatch.dislike || 0, label: "nope" },
                        { type: "skip",    icon: "\uf063", n: layout.app.lastBatch.skip || 0, label: "skipped" }
                    ]
                    Row {
                        required property var modelData
                        spacing: Theme.s1
                        Text {   // icon in the choice's color
                            text: modelData.icon
                            color: Theme.tone(modelData.type)
                            font { family: Theme.font; pointSize: Theme.fontSize }
                        }
                        Text {
                            text: modelData.n + " " + modelData.label
                            color: Theme.textDim
                            font { family: Theme.font; pointSize: Theme.fontSize }
                        }
                    }
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "your picks now include these ratings"
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
            RateProgress { anchors.horizontalCenter: parent.horizontalCenter; rating: ratingView; size: 12 }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.s2
                ActionButton {
                    icon: "\uf0e2"; label: "back"
                    onClicked: layout.app.backToLastCard()
                }
                ActionButton {
                    icon: "\uf021"; label: "keep rating"
                    focused: layout.app.doneChoice === 0
                    onClicked: layout.app.keepRating()
                }
                ActionButton {
                    icon: "\uf005"; label: "see picks"
                    focused: layout.app.doneChoice === 1
                    onClicked: layout.app.finishRating()
                }
            }
        }
    }

    Text {
        visible: layout.app.mode === "loading"
        anchors.centerIn: parent
        text: "finding wallpapers to rate..."
        color: Theme.textDim
        font { family: Theme.font; pointSize: Theme.fontSize }
    }

    // ---- Browse: grid + command bar ----
    Item {
        anchors.fill: parent
        opacity: layout.app.mode === "browse" ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: Theme.fadeMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }

        Grid4 {
            id: grid
            x: 2; y: 2
            width: layout.width - 4
            height: layout.bodyH
            app: layout.app
            cellWidth: layout.cellW
            cellHeight: layout.cellH
            gap: layout.seam
            infoStrip: true
            onUpFromTop: search.input.forceActiveFocus()
            onTyped: ch => { layout.app.searchText += ch; search.input.forceActiveFocus() }
        }

        Rectangle {
            id: bar
            anchors { left: grid.left; right: grid.right; top: grid.bottom }
            height: layout.barH
            color: Theme.surface

            Rectangle {   // divider between images and bar: the box's 2px line
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 2
                color: Theme.textDim
            }

            SearchField {
                id: search
                app: layout.app
                anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                // Shrinks so the tabs never run into "rate more" in a narrow window.
                width: Math.max(140, Math.min(360, bar.width - tabs.implicitWidth - rateMore.implicitWidth - Theme.s4 * 3 - Theme.s3 * 2))
                height: 28
                onDownPressed: grid.forceActiveFocus()
            }
            TabBar {
                id: tabs
                app: layout.app
                anchors { left: search.right; leftMargin: Theme.s4; verticalCenter: parent.verticalCenter }
            }
            ActionButton {
                id: rateMore
                anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                implicitHeight: 28
                label: "rate more"
                onClicked: layout.app.keepRating()
            }
            Text {
                anchors { right: rateMore.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                visible: text !== ""
                text: layout.app.status
                color: layout.app.statusIsError ? Theme.error : Theme.textDim
                font { family: Theme.font; pointSize: Theme.small }
            }
        }
    }
}
