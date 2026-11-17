// Rice lock screen (SUPER + L): the same box as the login screen, in lock
// mode (no session switcher, login fixed to you). Locks with the Wayland
// session-lock protocol and unlocks only when PAM accepts your password
// (same rules as logging in: /etc/pam.d/system-local-login).
//
// Run:  qs -p ~/.config/rice-greeter/lock.qml      (lock.sh avoids doubles)
// Test only: RICE_LOCK_TEST_TIMEOUT=N unlocks by itself after N seconds.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    readonly property bool lockMode: true

    FileView { id: hostFile; path: "/etc/hostname"; blockLoading: true; printErrors: false }
    readonly property string hostname: hostFile.text().trim() || "linux"
    readonly property string defaultUser: Quickshell.env("USER")
    property string user: defaultUser
    readonly property string sessionName: ""
    function cycleSession(dir) {}

    property bool busy: false
    property string status: ""
    property bool statusIsError: false
    property string pending: ""
    signal failed()

    function submit(password) {
        if (busy) return
        busy = true; status = "checking..."; statusIsError = false
        pending = password
        if (!pam.start()) fail("could not start the password check")
    }
    function fail(message) {
        busy = false
        status = message || "incorrect password"
        statusIsError = true
        failed()
    }

    PamContext {
        id: pam
        config: "system-local-login"
        user: root.user
        onPamMessage: {
            if (responseRequired) { respond(root.pending); root.pending = "" }
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.unlock()
            else root.fail("incorrect password")
        }
        onError: error => root.fail("incorrect password")
    }

    function unlock() {
        status = ""; busy = false
        lock.locked = false
        quitProc.running = true
    }
    // Qt.quit() is not connected in Quickshell: end our own process.
    Process { id: quitProc; command: ["sh", "-c", "sleep 0.2; kill $PPID"] }

    function power(action) {
        powerProc.command = ["systemctl", action]
        powerProc.running = true
    }
    Process { id: powerProc }

    Timer {
        interval: Number(Quickshell.env("RICE_LOCK_TEST_TIMEOUT") || 0) * 1000
        running: interval > 0
        onTriggered: root.unlock()
    }

    // Test hooks, only with RICE_LOCK_TEST_TIMEOUT set (never in normal use).
    IpcHandler {
        target: "lock"
        enabled: Number(Quickshell.env("RICE_LOCK_TEST_TIMEOUT") || 0) > 0
        function submit(pw: string): void { root.submit(pw) }
        function state(): string { return root.status + " | busy=" + root.busy }
    }

    WlSessionLock {
        id: lock
        locked: true
        WlSessionLockSurface {
            id: surface
            color: Theme.surface
            LoginBox {
                anchors.fill: parent
                focus: true
                app: root
                primary: true      // the box on every screen; typing works on any
            }
        }
    }
}
