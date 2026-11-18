pragma Singleton

// The bar's two toggles, shared by every bar, the clock menu and the keys:
//   dnd     Do Not Disturb (noctalia holds notifications)       SUPER + SHIFT + D
//   awake   keep the screen on (noctalia's caffeine inhibitor)  SUPER + SHIFT + A
// Toggled with `qs -c rice ipc call status toggleDnd / toggleAwake`.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: st
    property bool dnd: false
    property bool awake: false

    function toggleDnd() { dnd = !dnd; Quickshell.execDetached(["noctalia", "msg", "notification-dnd-set", dnd ? "on" : "off"]); poll.restart() }
    function toggleAwake() { awake = !awake; Quickshell.execDetached(["noctalia", "msg", awake ? "caffeine-enable" : "caffeine-disable"]) }

    // Do Not Disturb can also be changed in noctalia's control centre: follow it
    Process {
        id: dndState
        command: ["noctalia", "msg", "notification-dnd-status"]
        stdout: StdioCollector { onStreamFinished: st.dnd = /^\s*(on|true|enabled)/i.test(text) }
    }
    Timer { id: poll; interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: dndState.running = true }
}
