// The top bar, always on (THEME.md §3, minimal style): 28px of plain
// lowercase text on the surface, closed by the rice's 2px line.
//   left    workspaces (current one bright with an accent underline), window title,
//           now playing (only while something plays: click to pause/play)
//   centre  time and date
//   right   tray icons, then  wifi eduroam · vol 35% · bat 100%
//           (dim lowercase label, bright value, dim dots between)
// Every part is clickable and opens its own page (noctalia):
//   workspace -> switch to it      window title -> window switcher (ALT + Tab),
//                                  right-click: window menu (move, float, close...)
//   time/date -> calendar          net -> network      vol -> audio
//   bat -> power                   tray icon -> the app (right-click: its menu)
// vol also: scroll to change the volume, right-click to mute.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Widgets

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: 28 + 2
    color: Theme.surface
    exclusiveZone: implicitHeight

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screen.name)

    component Key: Text {
        color: Theme.textDim
        font { family: Theme.font; pointSize: Theme.fontSize }
    }
    // A dim lowercase label before a value ("vol 35%"), and the dim dot
    // between status items.
    component Label: Text {
        color: Theme.textDim
        rightPadding: Theme.s2
        font { family: Theme.font; pointSize: Theme.fontSize }
    }
    component Dot: Text {
        text: "\u00b7"
        color: Theme.textDim
        opacity: 0.6
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        font { family: Theme.font; pointSize: Theme.fontSize }
    }
    component Val: Text {
        color: Theme.text
        font { family: Theme.font; pointSize: Theme.fontSize }
    }
    // A clickable bar item: hover brightens nothing loud, just a 1px underline
    // like every text button in the rice.
    component Hit: MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle {
            visible: hit.containsMouse
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: -2 }
            height: 1
            color: Theme.text
        }
    }
    function panel(page) { Quickshell.execDetached(["noctalia", "msg", "panel-toggle", "control-center", page]) }

    // ---- left: workspaces + window title ----
    Row {
        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }
        spacing: Theme.s3

        Row {
            spacing: Theme.s2
            Repeater {
                model: Hyprland.workspaces.values.filter(w => w.id > 0 && (!bar.monitor || w.monitor === bar.monitor))
                Item {
                    required property var modelData
                    readonly property bool current: modelData.active && modelData.monitor === bar.monitor
                    width: label.implicitWidth + Theme.s1 * 2
                    height: 22
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.name
                        color: parent.current ? Theme.text : (modelData.urgent ? Theme.error : Theme.textDim)
                        font { family: Theme.font; pointSize: Theme.fontSize }
                    }
                    Rectangle {   // accent underline on the current workspace
                        visible: parent.current
                        anchors { left: label.left; right: label.right; top: label.bottom; topMargin: 1 }
                        height: 1
                        color: Theme.primary
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: modelData.activate() }
                }
            }
        }

        Text {
            // title + now playing must never reach the centred clock
            width: Math.min(implicitWidth, bar.width * 0.2)
            elide: Text.ElideRight
            text: Hyprland.activeToplevel && Hyprland.activeToplevel.title ? Hyprland.activeToplevel.title.toLowerCase() : ""
            color: Theme.textDim
            font { family: Theme.font; pointSize: Theme.fontSize }
            Hit {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)   // window menu: move to a workspace, float, close...
                        Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "windowmenu", "openAt",
                                                 String(Math.round(parent.mapToItem(null, 0, 0).x))])
                    else Quickshell.execDetached(["qs", "-c", "rice", "ipc", "call", "switcher", "open"])
                }
            }
        }

        // now playing: "♪ artist - title", only while a player is playing
        Item {
            id: media
            readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
            visible: player !== null
            width: mediaText.width; height: mediaText.implicitHeight
            Text {
                id: mediaText
                width: Math.min(implicitWidth, bar.width * 0.12)
                elide: Text.ElideRight
                text: media.player ? "\u266a " + ((media.player.trackArtist ? media.player.trackArtist + " - " : "")
                                     + (media.player.trackTitle || media.player.identity)).toLowerCase() : ""
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Hit { onClicked: if (media.player && media.player.canTogglePlaying) media.player.togglePlaying() }
        }
    }

    // ---- centre: time and date ----
    Item {
        anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }
        width: clockRow.implicitWidth; height: clockRow.implicitHeight
        Row {
            id: clockRow
            spacing: Theme.s3
            SystemClock { id: clock; precision: SystemClock.Minutes }
            Val { text: Qt.formatTime(clock.date, "HH:mm") }
            Key { text: Qt.formatDate(clock.date, "ddd d MMM").toLowerCase() }
        }
        Hit { onClicked: bar.panel("calendar") }
    }

    // ---- right: tray, net, vol, bat ----
    Row {
        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }
        spacing: Theme.s4

        Row {
            spacing: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: SystemTray.items
                IconImage {
                    required property var modelData
                    implicitSize: 16
                    // Vesktop shows as Discord everywhere (launcher, switcher, here)
                    source: String(modelData.id).startsWith("vesktop") ? Quickshell.iconPath("discord", modelData.icon) : modelData.icon
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton && modelData.hasMenu)
                                modelData.display(bar, bar.mapFromItem(parent, 0, parent.height).x, bar.implicitHeight)
                            else modelData.activate()
                        }
                    }
                }
            }
        }

        Item {  // net
            id: netItem
            readonly property var wifi: Networking.devices.values.find(d => d.connected && d.networks && d.networks.values.some(n => n.connected))
            readonly property var net: wifi ? wifi.networks.values.find(n => n.connected) : null
            readonly property var wired: Networking.devices.values.find(d => d.connected)
            width: netRow.implicitWidth; height: netRow.implicitHeight
            Row {
                id: netRow
                // "wifi eduroam" / "wired" / "offline"
                Label {
                    visible: !!(netItem.net || netItem.wired)
                    text: netItem.net ? "wifi" : "wired"
                }
                Val {
                    text: netItem.net ? netItem.net.name.toLowerCase() : (netItem.wired ? "" : "offline")
                    color: netItem.net || netItem.wired ? Theme.text : Theme.textDim
                }
            }
            Hit { onClicked: bar.panel("network") }
        }

        Dot {}
        Item {  // vol
            id: vol
            readonly property var sink: Pipewire.defaultAudioSink
            PwObjectTracker { objects: [vol.sink] }
            width: volRow.implicitWidth; height: volRow.implicitHeight
            Row {
                id: volRow
                Label { text: "vol" }
                Val {
                    text: !vol.sink || !vol.sink.audio ? "-" : (vol.sink.audio.muted ? "muted" : Math.round(vol.sink.audio.volume * 100) + "%")
                    color: vol.sink && vol.sink.audio && vol.sink.audio.muted ? Theme.textDim : Theme.text
                }
            }
            Hit {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton) bar.panel("audio")
                    else if (vol.sink && vol.sink.audio) vol.sink.audio.muted = !vol.sink.audio.muted
                }
                onWheel: wheel => {
                    if (!vol.sink || !vol.sink.audio) return
                    vol.sink.audio.volume = Math.max(0, Math.min(1, vol.sink.audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05)))
                }
            }
        }

        Dot { visible: bat.visible }
        Item {  // bat
            id: bat
            readonly property var dev: UPower.displayDevice
            visible: dev && dev.isLaptopBattery
            width: batRow.implicitWidth; height: batRow.implicitHeight
            Row {
                id: batRow
                Label { text: "bat" }
                Val {
                    text: bat.dev ? Math.round(bat.dev.percentage * 100) + "%" : ""
                    color: bat.dev && UPower.onBattery && bat.dev.percentage < 0.15 ? Theme.error : Theme.text
                }
                Text {
                    visible: bat.dev && bat.dev.state === UPowerDeviceState.Charging
                    leftPadding: Theme.s2
                    text: "charging"
                    color: Theme.textDim
                    font { family: Theme.font; pointSize: Theme.fontSize }
                }
            }
            Hit { onClicked: bar.panel("power") }
        }
    }

    // the rice's 2px line closing the bar
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 2
        color: Theme.textDim
    }
}
