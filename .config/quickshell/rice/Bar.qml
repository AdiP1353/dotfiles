// The top bar, always on (THEME.md §3, minimal style): 28px of plain
// lowercase text on the surface, closed by the rice's 2px line.
//   left    workspaces (current one bright with an accent underline), now playing
//           (click: go to the app playing it; right-click: play / pause),
//           now playing (only while something plays: click to pause/play)
//   centre  time and date
//   right   tray icons, then  [usb nyx ·] [upd 3 ·] dnd · awake · wifi eduroam · vol 35% · bat 100%
//           (usb only while a drive is mounted: click opens it, right-click ejects;
//           upd only when updates wait: click to update; dnd / awake are toggles,
//           dim when off)
//           (dim lowercase label, bright value, dim dots between)
// Every part is clickable and opens its own page (noctalia):
//   workspace -> switch to it      (no window title: ALT + right-click a window or
//                                  SUPER + M for the window menu)
//   time/date -> calendar          net -> network      vol -> audio
//   bat -> power                   tray icon -> the app (right-click: its menu in the
//                                  rice's style, with "close <app>" at the bottom)
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
    property bool trayOpen: false        // the tray icons, behind "apps"

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
    ToggleMenu { id: toggles; screen: bar.screen }   // right-click the clock
    // right-click menu for tray icons (TrayMenu.qml), one per screen
    TrayMenu { id: trayMenu; screen: bar.screen }
    IpcHandler {   // for testing: qs -c rice ipc call tray_<screen> menu <n>
        target: "tray_" + bar.screen.name
        function menu(n: int): void {
            const it = SystemTray.items.values[n]
            if (it) trayMenu.show(it, bar.width - 200)
        }
        function list(): string { return SystemTray.items.values.map(i => i.id).join(", ") }
        function close(): void { trayMenu.close() }
        // dry run for testing: which window clicking "now playing" would go to
        function musicTarget(): string {
            const p = Mpris.players.values.find(p => p.isPlaying)
            if (!p) return "nothing playing"
            Hyprland.refreshToplevels()
            const entry = String(p.desktopEntry || p.identity || "").toLowerCase()
            const w = Hyprland.toplevels.values.filter(t => { const c = String((t.lastIpcObject && t.lastIpcObject.class) || "").toLowerCase(); return c === entry || c.endsWith("." + entry) || c.split(".").pop() === entry })
            return entry + " -> " + w.map(t => (t.lastIpcObject.class + " on " + t.lastIpcObject.workspace.name)).join(", ")
        }
    }
    // The window of the app behind a media player: its class matches the
    // player's desktop entry (spotify, firefox...); with several windows, the one
    // whose title mentions the song. A window hidden in a special workspace
    // (Spotify in the background) is brought out onto this workspace first.
    function goToPlayer(player) {
        Hyprland.refreshToplevels()
        const entry = String(player.desktopEntry || player.identity || "").toLowerCase()
        const song = String(player.trackTitle || "").toLowerCase()
        const wins = Hyprland.toplevels.values.filter(t => {
            const c = String((t.lastIpcObject && t.lastIpcObject.class) || "").toLowerCase()
            return entry && (c === entry || c.endsWith("." + entry) || c.split(".").pop() === entry)
        })
        const w = wins.find(t => song && String(t.title || "").toLowerCase().includes(song)) || wins[0]
        if (!w) { if (player.canRaise) player.raise(); return }
        const addr = String(w.address).startsWith("0x") ? w.address : "0x" + w.address
        const ws = w.lastIpcObject && w.lastIpcObject.workspace
        if (ws && String(ws.name).startsWith("special:"))
            Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + Hyprland.focusedWorkspace.name + '", window = "address:' + addr + '" })')
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })')
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
                // the song only; hovering shows "artist - song"
                text: !media.player ? "" : "\u266a " + ((mediaHit.containsMouse && media.player.trackArtist ? media.player.trackArtist + " - " : "")
                                     + (media.player.trackTitle || media.player.identity)).toLowerCase()
                color: Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Hit {
                id: mediaHit
                // click: go to the app that's playing; right-click: play / pause
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (!media.player) return
                    if (mouse.button === Qt.RightButton) { if (media.player.canTogglePlaying) media.player.togglePlaying() }
                    else bar.goToPlayer(media.player)
                }
            }
        }

        // a tiny visualiser after the song: 12 bars, 2px wide, 2px apart, in the
        // dim text colour; fades in and out with playback (150ms)
        Row {
            id: barViz
            readonly property var levels: Cava.grouped(12)
            anchors.verticalCenter: parent.verticalCenter
            height: 14
            spacing: 2
            visible: opacity > 0
            opacity: Cava.playing ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeOut } }
            Repeater {
                model: 12
                Item {
                    required property int index
                    width: 2; height: barViz.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: 2
                        // reduced motion / no data: a still 2px line
                        height: Math.max(2, Math.round((barViz.levels[parent.index] || 0) / 100 * parent.height))
                        color: Theme.textDim
                    }
                }
            }
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
            Val { text: Qt.formatTime(clock.date, "HH:mm") }          // 24-hour
            Key { visible: clockHit.containsMouse; text: Qt.formatDate(clock.date, "ddd d MMM").toLowerCase() }
        }
        Hit {   // click: calendar; hover: the date; right-click: dnd / awake
            id: clockHit
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) toggles.show(bar.width / 2)
                else bar.panel("calendar")
            }
        }
    }

    // ---- right: tray, net, vol, bat ----
    Row {
        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter; verticalCenterOffset: -1 }
        spacing: Theme.s4

        Row {   // the tray icons, shown only after clicking "apps"
            spacing: Theme.s2
            anchors.verticalCenter: parent.verticalCenter
            visible: bar.trayOpen
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
                            // right-click: the app's menu in the rice's style, with "close <app>"
                            if (mouse.button === Qt.RightButton && modelData.hasMenu)
                                trayMenu.show(modelData, bar.mapFromItem(parent, parent.width / 2, 0).x)
                            else modelData.activate()
                        }
                    }
                }
            }
        }
        Item {  // "apps": the tray, collapsed; click to show / hide the icons
            width: appsText.implicitWidth; height: appsText.implicitHeight
            visible: SystemTray.items.values.length > 0
            Text {
                id: appsText
                text: "apps"
                color: bar.trayOpen ? Theme.text : Theme.textDim
                font { family: Theme.font; pointSize: Theme.fontSize }
            }
            Hit { onClicked: bar.trayOpen = !bar.trayOpen }
        }
        Dot { visible: SystemTray.items.values.length > 0 }

        Item {  // usb: a mounted USB drive (udiskie mounts it); click opens it, right-click ejects
            id: usb
            property var drive: null        // { name, mount }
            visible: drive !== null
            width: usbRow.implicitWidth; height: usbRow.implicitHeight
            Row { id: usbRow; Label { text: "usb" } Val { text: usb.drive ? usb.drive.name : "" } }
            Hit {
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (!usb.drive) return
                    if (mouse.button === Qt.RightButton)   // eject: unmount and power the drive off
                        Quickshell.execDetached(["udiskie-umount", "--detach", usb.drive.mount])
                    else Quickshell.execDetached(["dolphin", usb.drive.mount])
                }
            }
            Process {
                id: usbScan
                command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT,HOTPLUG,TRAN,TYPE,SIZE"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        let found = null
                        try {
                            const walk = list => { for (const d of list || []) {
                                if (!found && d.mountpoint && (d.hotplug || d.tran === "usb")) found = d
                                walk(d.children) } }
                            const devs = JSON.parse(text).blockdevices
                            // children inherit "usb" from their disk
                            for (const disk of devs) if (disk.tran === "usb" || disk.hotplug) for (const c of disk.children || []) c.tran = "usb"
                            walk(devs)
                        } catch (e) {}
                        usb.drive = found ? { name: String(found.label || found.size || found.name).toLowerCase(), mount: found.mountpoint } : null
                    }
                }
            }
            Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: usbScan.running = true }
        }
        Dot { visible: usb.visible }

        Item {  // upd: waiting updates (pacman + AUR), only when there are some
            id: upd
            property int count: 0
            visible: count > 0
            width: updRow.implicitWidth; height: updRow.implicitHeight
            Row { id: updRow; Label { text: "upd" } Val { text: String(upd.count) } }
            Hit {   // click: update in a terminal (it says when a reboot is needed)
                onClicked: { Quickshell.execDetached(["kitty", "--class", "rice-update", "-e", Quickshell.env("HOME") + "/.config/rice/bin/rice-update"]); upd.count = 0 }
            }
            Process {
                id: updCheck
                command: ["sh", "-c", "{ checkupdates 2>/dev/null; command -v yay >/dev/null && yay -Qua 2>/dev/null; } | grep -c ."]
                stdout: StdioCollector { onStreamFinished: upd.count = parseInt(text) || 0 }
            }
            Timer { interval: 60 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: updCheck.running = true }
        }
        Dot { visible: upd.visible }

        // dnd / awake: only while on (SUPER + SHIFT + D / A, or right-click the clock)
        Item {
            visible: RiceStatus.dnd
            width: dndText.implicitWidth; height: dndText.implicitHeight
            Text { id: dndText; text: "dnd"; color: Theme.text; font { family: Theme.font; pointSize: Theme.fontSize } }
            Hit { onClicked: RiceStatus.toggleDnd() }
        }
        Dot { visible: RiceStatus.dnd }
        Item {
            visible: RiceStatus.awake
            width: awakeText.implicitWidth; height: awakeText.implicitHeight
            Text { id: awakeText; text: "awake"; color: Theme.text; font { family: Theme.font; pointSize: Theme.fontSize } }
            Hit { onClicked: RiceStatus.toggleAwake() }
        }
        Dot { visible: RiceStatus.awake }

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
