// Wallhaven wallpaper picker with a taste model: the logic.
//
// Opening it: rate 10 wallpapers (swipe like / nope, or skip), then land on
// "For you": wallpapers picked from what you liked. taste.py does the
// learning and the wallhaven searching. The look lives in Layout.qml.
//
// Run:   qs -c wallhaven        (toggle.sh opens/closes it, SUPER + W)
// Keys:  rating: Left nope, Right like, Down skip, Up/Backspace back, Tab skip all
//        batch done: Tab / arrows choose Keep rating or See picks, Enter picks it,
//                    Up/Backspace back
// Only SFW wallpapers of the screen's shape, at its resolution or larger.
//        browse: type to search all of wallhaven, Enter apply, arrows move,
//                Tab / Shift+Tab switch tab, Esc close
// Apps always stay dark: apply.sh keeps noctalia in dark mode for every wallpaper.
// It is a normal window (tiles like any app); opening and closing are instant.

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string taste: Quickshell.shellDir + "/taste.py"
    // Same folder taste.py uses.
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
                                       + "/rice/wallhaven"

    readonly property var tabs: [
        { id: "foryou",     label: "For you", local: true },
        { id: "liked",      label: "Liked",   local: true },
        { id: "rated",      label: "Rated",   local: true },
        { id: "toplist",    label: "Toplist" },
        { id: "hot",        label: "Hot" },
        { id: "random",     label: "Random" },
        { id: "date_added", label: "Latest" }
    ]

    // ---- State shared with the layout --------------------------------------
    property string mode: "loading"      // loading | rating | done | browse
    property var lastBatch: ({ like: 0, dislike: 0, skip: 0 })   // tally shown on the "done" screen
    property bool wantSession: false     // start a rating batch once pending events are written
    property int doneChoice: 1           // done screen: 0 = Keep rating, 1 = See picks (focused option)
    property int tabIndex: 0
    property string searchText: ""       // what is typed in the search box
    property string query: ""            // what was last searched; non-empty = all of wallhaven
    readonly property bool searching: query.trim() !== ""
    property int currentIndex: 0
    property bool loading: false
    property bool applying: false
    property bool closing: false
    property string status: ""
    property bool statusIsError: false
    property var likedIds: ({})          // id -> true
    property var ratingView: null        // set by the layout
    property var lastPointer: null       // last real pointer position (see Thumb.qml)
    readonly property alias results: resultsModel
    readonly property var currentRow: (results.count, currentIndex >= 0 && currentIndex < results.count)
                                      ? results.get(currentIndex) : null

    signal focusRequested(string what)   // "search" | "grid" | "rating"
    signal viewReset()

    // ---- Screen: only SFW wallpapers of the screen's shape, at its size or larger ----
    property int screenW: 1920
    property int screenH: 1080
    readonly property string screenRatio: {
        const r = screenW / screenH
        const named = { "16x9": 16 / 9, "16x10": 16 / 10, "21x9": 21 / 9, "32x9": 32 / 9, "4x3": 4 / 3, "3x2": 3 / 2, "5x4": 5 / 4 }
        for (const k in named) if (Math.abs(r - named[k]) < 0.01) return k
        return screenW + "x" + screenH
    }
    function fits(w) {
        if (w.purity && w.purity !== "sfw") return false
        const p = (w.resolution || "").split("x").map(Number)
        return p.length === 2 && p[0] >= screenW && p[1] >= screenH
            && Math.abs(p[0] / p[1] - screenW / screenH) < 0.01
    }
    Process {
        id: screenProc
        running: true
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const mons = JSON.parse(text)
                    const m = mons.find(m => m.focused) || mons[0]
                    root.screenW = m.width; root.screenH = m.height
                } catch (e) {}
            }
        }
    }

    // ---- Internal state -------------------------------------------------
    property int page: 0
    property int lastPage: 1
    property string seed: ""
    property int requestId: 0
    property var itemsById: ({})         // id -> item object (sent with events)
    property bool refreshStarted: false

    ListModel { id: resultsModel }

    function setStatus(text, isError) { status = text; statusIsError = isError }

    function colorsOf(row) {
        if (!row) return []
        if (row.colors && row.colors.length !== undefined && typeof row.colors !== "string") return row.colors
        return row.swatches ? row.swatches.split(",") : []
    }

    // Ids known to be blurry at full size (taste.py blurry): hidden everywhere.
    property var blurryIds: ({})
    Process {
        id: blurryProc
        running: true
        command: ["python3", root.taste, "blurry"]
        stdout: StdioCollector {
            onStreamFinished: {
                const set = {}
                try { for (const id of JSON.parse(text)) set[id] = true } catch (e) {}
                root.blurryIds = set
            }
        }
    }

    function addItem(it) {
        if (blurryIds[it.id]) return
        itemsById[it.id] = it
        resultsModel.append({
            wid: it.id,
            thumb: it.thumb,
            full: it.full,
            resolution: it.resolution || "",
            category: it.category || "",
            favorites: it.favorites || 0,
            swatches: (it.colors || []).join(","),
            why: it.why || "",
            rating: it.rating || ""
        })
    }

    function fromApi(w) {
        return { id: w.id, thumb: w.thumbs.large, full: w.path, resolution: w.resolution, purity: w.purity,
                 category: w.category, favorites: w.favorites, colors: w.colors.slice(0, 5) }
    }

    // ---- Keys shared by all layouts ----------------------------------------
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) { close(); event.accepted = true }
        else if (mode === "done") {
            // Tab / Shift+Tab / Left / Right move between the two options;
            // Enter or Space picks the focused one.
            switch (event.key) {
            case Qt.Key_Tab: case Qt.Key_Backtab: case Qt.Key_Left: case Qt.Key_Right:
            case Qt.Key_H: case Qt.Key_L:
                doneChoice = 1 - doneChoice; break
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space:
                if (doneChoice === 0) keepRating(); else finishRating(); break
            case Qt.Key_Backspace: case Qt.Key_Up: case Qt.Key_K: backToLastCard(); break
            default: return
            }
            event.accepted = true
        }
        else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            if (mode === "rating") finishRating()
            else if (mode === "browse") switchTab(tabIndex + (event.key === Qt.Key_Backtab ? -1 : 1))
            event.accepted = true
        }
    }

    // ---- Loading results ------------------------------------------------
    function load() {
        resultsModel.clear()
        page = 0; lastPage = 1; seed = ""
        loading = false
        requestId++
        currentIndex = 0
        viewReset()
        const tab = tabs[tabIndex]
        if (!searching && tab.local) loadLocal(tab.id, false)
        else loadMore()
    }

    function submitSearch() {
        if (searchText !== query) { query = searchText; load() }
        else applyCurrent()
    }

    function loadLocal(id, quiet) {
        loading = true
        setStatus("Loading…", false)
        localProc.kind = id
        localProc.keepSelection = quiet
        localProc.command = id === "foryou"
            ? ["python3", taste, "curated", "48"].concat(quiet ? ["quiet"] : [])
            : ["python3", taste, id === "rated" ? "history" : "liked"]
        localProc.running = true
    }

    Process {
        id: localProc
        property string kind: ""
        property bool keepSelection: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false
                // The user may have switched away while this ran.
                if (root.searching || root.tabs[root.tabIndex].id !== localProc.kind) return
                let list = []
                try { list = JSON.parse(text) } catch (e) { root.setStatus("taste.py failed", true); return }
                const keepId = localProc.keepSelection && root.currentRow ? root.currentRow.wid : ""
                resultsModel.clear()
                for (const it of list) root.addItem(it)
                root.currentIndex = 0
                if (keepId) {
                    for (let i = 0; i < resultsModel.count; i++)
                        if (resultsModel.get(i).wid === keepId) { root.currentIndex = i; break }
                }
                if (list.length > 0) root.setStatus("", false)
                else if (localProc.kind === "liked") root.setStatus("Nothing liked yet: use  on a thumbnail or rate some wallpapers", false)
                else if (localProc.kind === "rated") root.setStatus("Nothing rated yet", false)
                else root.setStatus("No picks yet: rate a few wallpapers (new picks are being searched in the background)", false)
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("taste.py: " + text) }
    }

    function buildUrl(p) {
        let u = "https://wallhaven.cc/api/v1/search?categories=111&purity=100"
              + "&atleast=" + screenW + "x" + screenH + "&ratios=" + screenRatio + "&page=" + p
        if (searching) {
            // Search everything on wallhaven, best matches first, any date.
            u += "&sorting=relevance&q=" + encodeURIComponent(query.trim())
        } else {
            const sort = tabs[tabIndex].id
            u += "&sorting=" + sort + "&order=desc"
            if (sort === "toplist") u += "&topRange=1M"
            if (sort === "random" && seed !== "") u += "&seed=" + seed
        }
        return u
    }

    function loadMore() {
        if (loading || page >= lastPage) return
        if (!searching && tabs[tabIndex].local) return
        loading = true
        setStatus("Loading…", false)
        const id = requestId
        const xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || id !== requestId) return
            loading = false
            if (xhr.status === 429) { setStatus("Wallhaven rate limit hit, wait a minute", true); return }
            if (xhr.status !== 200) { setStatus("Wallhaven error " + xhr.status, true); return }
            let r
            try { r = JSON.parse(xhr.responseText) } catch (e) { setStatus("Bad response from wallhaven", true); return }
            page = r.meta.current_page
            lastPage = r.meta.last_page
            if (r.meta.seed) seed = r.meta.seed
            for (const w of r.data) { const it = fromApi(w); if (fits(it)) addItem(it) }
            setStatus(resultsModel.count === 0 ? "No results" : "", false)
        }
        xhr.open("GET", buildUrl(page + 1))
        xhr.send()
    }

    function switchTab(i) {
        tabIndex = (i + tabs.length) % tabs.length
        if (searching || searchText !== "") { searchText = ""; query = "" }
        load()
    }

    // ---- Rating session ---------------------------------------------------
    Process {
        id: sessionProc
        command: ["python3", root.taste, "session", "10"]
        stdout: StdioCollector {
            onStreamFinished: {
                let r = { queue: [] }
                try { r = JSON.parse(text) } catch (e) {}
                root.wantSession = false
                if (r.queue.length > 0 && root.ratingView) {
                    for (const it of r.queue) root.itemsById[it.id] = it
                    root.ratingView.start(r.queue)
                    root.mode = "rating"
                    root.focusRequested("rating")
                } else {
                    root.finishRating()
                    if (r.queue.length === 0 && root.ratingSessions > 0)
                        root.setStatus("Nothing new to rate right now; more arrive after the background search", false)
                }
            }
        }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("taste.py: " + text) }
    }

    property int ratingSessions: 0

    // All cards in a batch rated: offer to keep going or see the picks.
    function batchDone() {
        const t = { like: 0, dislike: 0, skip: 0 }
        for (const m of ratingView.marks) t[m] = (t[m] || 0) + 1
        lastBatch = t
        ratingSessions++
        doneChoice = 1
        mode = "done"
        focusRequested("done")
        startRefresh()
    }

    // Another batch of 10. Waits for this batch's events to be written so
    // taste.py does not hand the same wallpapers back.
    function keepRating() {
        mode = "loading"
        setStatus("", false)
        wantSession = true
        pumpEvents()
    }

    // Ratings from the card stack. A card can be revisited with Back; if its
    // new rating is "skip", the earlier like/nope is cleared ("reset").
    property var sessionRated: ({})
    function rateFromCard(type, item) {
        const again = sessionRated[item.id] !== undefined
        sessionRated[item.id] = type
        logEvent(again && type === "skip" ? "reset" : type, item.id)
    }
    function backToLastCard() {
        if (!ratingView || ratingView.index === 0) return
        mode = "rating"
        ratingView.back()
        focusRequested("rating")
    }

    function finishRating() {
        if (mode === "browse") return
        mode = "browse"
        tabIndex = 0
        load()
        focusRequested("grid")   // arrows work at once; typing a letter jumps to search
        startRefresh()
    }

    // Background search for new picks. Detached, so it keeps going if the
    // picker closes; last_refresh.json tells us when it is done.
    property bool refreshRunning: false
    function startRefresh() {
        if (refreshRunning) return
        refreshStarted = true
        refreshRunning = true
        refreshProc.running = true
    }
    Process {
        id: refreshProc
        command: ["setsid", "-f", "python3", root.taste, "refresh"]
    }
    FileView {
        path: root.stateDir + "/last_refresh.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            root.refreshRunning = false
            if (root.refreshStarted && root.mode === "browse" && !root.searching
                    && root.tabs[root.tabIndex].id === "foryou" && !root.loading)
                root.loadLocal("foryou", true)
        }
    }

    // ---- Events (like, dislike, skip, apply, unlike) -----------------------
    // Run one at a time through a small queue; closing waits for it to drain.
    property var pendingEvents: []

    function logEvent(type, id) {
        const it = itemsById[id]
        pendingEvents.push(["python3", taste, "event", type, id, it ? JSON.stringify(it) : ""])
        const liked = Object.assign({}, likedIds)
        if (type === "like" || type === "apply") liked[id] = true
        if (type === "dislike" || type === "unlike" || type === "reset") delete liked[id]
        likedIds = liked
        pumpEvents()
    }

    function pumpEvents() {
        if (eventProc.running) return
        if (pendingEvents.length === 0) {
            if (closing && !applying) quitProc.running = true
            else if (wantSession && !sessionProc.running) sessionProc.running = true
            return
        }
        eventProc.command = pendingEvents.shift()
        eventProc.running = true
    }

    Process {
        id: eventProc
        stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn("taste.py: " + text) }
        onExited: root.pumpEvents()
    }

    Process {
        id: likedProc
        command: ["python3", root.taste, "liked"]
        stdout: StdioCollector {
            onStreamFinished: {
                const liked = Object.assign({}, root.likedIds)
                try { for (const it of JSON.parse(text)) liked[it.id] = true } catch (e) {}
                root.likedIds = liked
            }
        }
    }

    function toggleLike(index) {
        const w = resultsModel.get(index)
        if (likedIds[w.wid]) {
            logEvent("unlike", w.wid)
            if (!searching && tabs[tabIndex].id === "liked") resultsModel.remove(index)
        } else {
            logEvent("like", w.wid)
        }
    }

    // Rated tab: change an earlier rating in place.
    function setRating(index, type) {
        const w = resultsModel.get(index)
        if (w.rating === type) return
        logEvent(type === "skip" ? "reset" : type, w.wid)
        resultsModel.setProperty(index, "rating", type)
        resultsModel.setProperty(index, "why", { like: "liked", dislike: "nope", skip: "skipped" }[type])
    }

    function dislike(index) {
        const w = resultsModel.get(index)
        logEvent(!searching && tabs[tabIndex].id === "liked" ? "unlike" : "dislike", w.wid)
        resultsModel.remove(index)
    }

    // ---- Apply / close ------------------------------------------------------
    function applyCurrent() {
        if (applying || currentIndex < 0 || currentIndex >= resultsModel.count) return
        const w = resultsModel.get(currentIndex)
        applying = true
        applyProc.wid = w.wid
        applyProc.index = currentIndex
        setStatus("downloading " + w.wid + "...", false)
        applyProc.command = ["bash", Quickshell.shellDir + "/apply.sh", w.full, w.wid]
        applyProc.running = true
    }

    Process {
        id: applyProc
        property string wid: ""
        property int index: -1
        stderr: StdioCollector { id: applyErr }
        onExited: (code, exitStatus) => {
            root.applying = false
            if (code === 0) {
                root.logEvent("apply", applyProc.wid)   // only a wallpaper that was really set counts
                root.close()
            } else if (code === 3) {
                // Blurry at full size: not applied, and hidden from now on.
                const set = Object.assign({}, root.blurryIds); set[applyProc.wid] = true; root.blurryIds = set
                if (applyProc.index >= 0 && applyProc.index < resultsModel.count
                        && resultsModel.get(applyProc.index).wid === applyProc.wid)
                    resultsModel.remove(applyProc.index)
                root.setStatus("blurry at full size, skipped", true)
            } else {
                root.setStatus(applyErr.text.trim() || "applying failed", true)
            }
        }
    }

    // Qt.quit() is not connected in Quickshell, so the picker ends its own
    // process (the shell's parent is quickshell).
    Process { id: quitProc; command: ["sh", "-c", "kill $PPID"] }

    function close() {
        win.visible = false
        closing = true
        pumpEvents()   // quits once pending events are written
    }

    Component.onCompleted: {
        likedProc.running = true
        sessionProc.running = true
    }

    // Command-line control, e.g.  qs -c wallhaven ipc call wallhaven state
    IpcHandler {
        target: "wallhaven"
        function close(): void { root.close() }
        function search(text: string): void { root.searchText = text; root.query = text; root.load() }
        function apply(index: int): void { root.currentIndex = index; root.applyCurrent() }
        function count(): int { return resultsModel.count }
        function tab(index: int): void { root.switchTab(index) }
        function rate(type: string): void { if (root.ratingView) root.ratingView.decide(type) }
        function skip(): void { root.finishRating() }
        function keep(): void { root.keepRating() }
        function back(): void { root.backToLastCard() }
        function key(name: string): void {
            const k = { tab: Qt.Key_Tab, backtab: Qt.Key_Backtab, enter: Qt.Key_Return, left: Qt.Key_Left, right: Qt.Key_Right }[name]
            root.handleKey({ key: k, accepted: false })
        }
        function doneChoice(): int { return root.doneChoice }
        function setRating(index: int, type: string): void { root.setRating(index, type) }
        function row(index: int): string { const w = resultsModel.get(index); return w ? w.wid + " " + w.rating + " " + w.resolution : "" }
        function like(index: int): void { root.toggleLike(index) }
        function nope(index: int): void { root.dislike(index) }
        function select(index: int): void { root.currentIndex = index }
        function current(): string {
            return root.currentIndex + " focus:" + (layoutLoader.item ? layoutLoader.item.focusName : "?")
        }
        function state(): string {
            const r = root.ratingView
            return root.mode + " " + root.tabs[root.tabIndex].id
                 + (r ? " rated:" + r.index + "/" + r.queue.length : "") + " status:" + root.status
        }
    }

    // ---- Window -------------------------------------------------------------
    // A normal window: Hyprland tiles it like any app (move it, resize it, put
    // it on a workspace or float it). Its 2px border is Hyprland's, like every
    // other window. Closing it (Esc, SUPER + Q) ends the picker.
    FloatingWindow {
        id: win
        title: "wallpapers"
        implicitWidth: 1240
        implicitHeight: 748
        color: Theme.surface
        onVisibleChanged: if (!visible && !root.closing) root.close()

        Loader {
            id: layoutLoader
            anchors.fill: parent
            focus: true
            Component.onCompleted: setSource("Layout.qml", { app: root })
        }
    }
}
