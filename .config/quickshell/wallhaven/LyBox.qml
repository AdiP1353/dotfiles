// The one container of the minimal style, as on the login screen: a plain
// 2px border, no shadow. Over a wallpaper (onImage) it gets the slightly
// see-through surface fill so the text stays readable.

import QtQuick

Rectangle {
    property bool onImage: false
    color: onImage ? Qt.alpha(Theme.surface, Theme.overlayAlpha) : "transparent"
    border.width: 2
    border.color: Theme.textDim
}
