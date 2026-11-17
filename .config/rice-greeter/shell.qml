// Rice login screen (greetd greeter) in the style of Ly: a plain box with
// the hostname, a < session > switcher, login: and password:.
//
// Runs inside noctalia's greeter session: greetd starts
// noctalia-greeter-session, whose compositor runs this through
// NOCTALIA_GREETER_BIN (see install.sh). Any user can log in: greetd checks
// the login and password through PAM as usual.
//
// Preview on the desktop (no real login; password "wrong" fails):
//   RICE_GREETER_PREVIEW=1 RICE_GREETER_DATA=/var/lib/rice-greeter qs -p ~/.config/rice-greeter/shell.qml

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: root

    readonly property bool preview: Quickshell.env("RICE_GREETER_PREVIEW") === "1" || !Greetd.available

    // ---- Host and default user ----
    FileView { id: hostFile; path: "/etc/hostname"; blockLoading: true; printErrors: false }
    readonly property string hostname: hostFile.text().trim() || "linux"

    FileView { id: passwd; path: "/etc/passwd"; blockLoading: true; printErrors: false }
    readonly property string defaultUser: {
        for (const line of passwd.text().split("\n")) {
            const f = line.split(":")
            const uid = Number(f[2])
            if (uid >= 1000 && uid < 60000 && f[6] && !/nologin|false$/.test(f[6])) return f[0]
        }
        return ""
    }
    property string user: defaultUser

    // ---- Sessions: every Wayland session installed; Hyprland (uwsm) first ----
    property var sessions: [{ name: "Hyprland (uwsm-managed)", exec: ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"] }]
    property int sessionIndex: 0
    readonly property string sessionName: sessions[sessionIndex] ? sessions[sessionIndex].name : ""
    function cycleSession(dir) { sessionIndex = (sessionIndex + dir + sessions.length) % sessions.length }

    Process {
        running: true
        command: ["sh", "-c", "for f in /usr/share/wayland-sessions/*.desktop; do "
                 + "n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); "
                 + "printf '%s\\t%s\\n' \"$n\" \"$e\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = []
                for (const line of text.split("\n")) {
                    const [name, exec] = line.split("\t")
                    if (!name || !exec) continue
                    list.push({ name: name, exec: exec.replace(/ %[a-zA-Z]/g, "").trim().split(/\s+/) })
                }
                if (list.length === 0) return
                // uwsm-managed Hyprland first: it is how this desktop starts
                list.sort((a, b) => (b.exec[0] === "uwsm") - (a.exec[0] === "uwsm"))
                root.sessions = list
                root.sessionIndex = 0
            }
        }
    }

    // ---- Login ----
    property bool busy: false
    property string status: ""
    property bool statusIsError: false
    property string pending: ""
    signal failed()

    function submit(password) {
        if (busy || user === "") return
        busy = true; status = "authenticating..."; statusIsError = false
        if (preview) { previewTimer.password = password; previewTimer.restart(); return }
        pending = password
        Greetd.createSession(user)
    }

    // Short messages only: greetd's own errors can be long ("os error 111").
    // No cancelSession() after a failure: Quickshell has already reset the
    // session, and cancelling again is what produced "connection refused".
    function fail(message) {
        busy = false
        status = message || "incorrect password"
        statusIsError = true
        failed()
    }

    Connections {
        target: Greetd
        enabled: !root.preview
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending)
                root.pending = ""
            } else if (error) {
                root.fail("incorrect password")
            }
        }
        function onAuthFailure(message) { root.fail("incorrect password") }
        function onReadyToLaunch() {
            root.status = "logging in..."; root.statusIsError = false
            Greetd.launch(root.sessions[root.sessionIndex].exec, [], true)
        }
        function onError(error) {
            console.warn("greetd: " + error)
            // An error while checking a password is, for the person typing, a
            // failed login; anything else gets a short generic line.
            root.fail(root.busy ? "incorrect password" : "login error, try again")
        }
    }

    // ---- Power (F1 / F2) ----
    function power(action) {
        if (preview) { status = "(preview) would " + action; statusIsError = false; return }
        powerProc.command = ["systemctl", action]
        powerProc.running = true
    }
    Process { id: powerProc }

    // ---- Preview: fake login ----
    Timer {
        id: previewTimer
        property string password: ""
        interval: 500
        onTriggered: {
            if (password === "wrong") { root.fail("incorrect password"); return }
            root.busy = false; root.status = "(preview) would start " + root.sessionName; root.statusIsError = false
        }
    }
    Process { id: quitProc; command: ["sh", "-c", "kill $PPID"] }
    IpcHandler {
        target: "greeter"
        function submit(pw: string): void { root.submit(pw) }
        function session(dir: int): void { root.cycleSession(dir) }
        function close(): void { quitProc.running = true }
    }

    // ---- Windows: one per screen; the box only on the first ----
    // Under greetd the compositor gives each output one ordinary window; on
    // the desktop (preview) it is a full-screen overlay instead.
    Variants {
        model: root.preview ? [] : Quickshell.screens
        FloatingWindow {
            required property var modelData
            screen: modelData
            color: Theme.surface
            LoginBox { anchors.fill: parent; focus: true; app: root; primary: modelData === Quickshell.screens[0] }
        }
    }
    Variants {
        model: root.preview ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            color: Theme.surface
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: modelData === Quickshell.screens[0] ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "rice-greeter-preview"
            LoginBox { anchors.fill: parent; focus: true; app: root; primary: modelData === Quickshell.screens[0] }
        }
    }
}
