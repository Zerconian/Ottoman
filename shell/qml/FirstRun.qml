import QtQuick
// First run (DESIGN.md 4.10 #8, "network only"): shown until ~/.config/ottoman/firstrun-done exists.
// Wired and connected: one Continue. No connection: scan and join Wi-Fi (same calls as Settings).
Rectangle {
    id: page
    signal done()
    anchors.fill: parent
    color: "#101214"
    property var st: ({kind: "none", ip: "", wifiAvailable: false})
    property var wifi: []
    property string message: ""
    property string joinSsid: ""
    // Prefetch (zerc, 2026-11-03): as soon as a connection is up, the default apps start downloading in the background while
    // the welcome screen is still showing. Wired: at boot. Wi-Fi: after the join, never before.
    property bool prefetching: false
    property int prefetchDone: 0
    property bool prefetchFinished: false
    function refresh() { st = system.netStatus(); build(); if (st.kind !== "none" && !prefetching && !prefetchFinished) { prefetching = true; setupRows = apps.defaults().map(function(d) { return {label: d.name, value: d.installed ? "already installed" : "waiting"} }); system.log("firstrun prefetch start"); apps.installDefaults() } }
    function build() {
        const items = []
        if (st.kind !== "none") items.push({label: "Continue", value: (st.kind === "ethernet" ? "Wired" : "Wi-Fi") + "  " + st.ip, action: "done"})
        else items.push({label: "Not connected", value: st.wifiAvailable ? "" : "plug in a network cable"})
        if (st.wifiAvailable) { items.push({label: "Scan for Wi-Fi networks", value: "", action: "scan"}); for (const w of wifi) items.push({label: (w.active ? "✓ " : "") + w.ssid, value: w.signal + "%  " + (w.security || "open"), action: "join", ssid: w.ssid, security: w.security}) }
        items.push({label: "Refresh", value: "", action: "refresh"})
        list.items = items; if (list.currentIndex < 0) list.currentIndex = 0
    }
    function act(i) {
        const it = list.items[i]; if (!it || !it.action) return
        if (it.action === "done") { page.startSetup() }
        else if (it.action === "refresh") refresh()
        else if (it.action === "scan") { message = "Scanning..."; wifi = system.wifiList(); build(); message = wifi.length + " networks" }
        else if (it.action === "join") { if (it.security) { joinSsid = it.ssid; joinPass.text = ""; joinPanel.visible = true; joinPass.inputItem.forceActiveFocus() } else system.wifiJoin(it.ssid, "") }
    }
    Connections { target: system
        function onJoined(ok, text) { message = text; joinPanel.visible = false; refresh(); list.forceActiveFocus() }
        function onBusyChanged() { if (system.busyText.length) message = system.busyText + "..." }
    }
    // Step 2: install the default apps one by one with visible status, then the launcher (zerc, 2026-11-03).
    // Step 0 (zerc, 2026-11-03): language first, English (US) preselected, applied system-wide for the apps.
    property bool languageDone: false
    property var languages: [["en_US.UTF-8", "English (US)"], ["en_GB.UTF-8", "English (UK)"], ["de_DE.UTF-8", "Deutsch"], ["es_ES.UTF-8", "Español"], ["fr_FR.UTF-8", "Français"], ["it_IT.UTF-8", "Italiano"], ["nl_NL.UTF-8", "Nederlands"], ["pt_BR.UTF-8", "Português (Brasil)"], ["pl_PL.UTF-8", "Polski"], ["sv_SE.UTF-8", "Svenska"], ["ja_JP.UTF-8", "日本語"]]
    function chooseLanguage(i) { const l = languages[i]; system.log("firstrun language " + l[0]); if (l[0] !== "en_US.UTF-8") system.setLocale(l[0]); languageDone = true; refresh(); list.forceActiveFocus() }
    property bool setup: false
    property var setupRows: []
    property int setupFailed: -1
    function startSetup() {
        if (prefetchFinished && setupFailed === 0) { system.markFirstRunDone(); done(); return }     // everything landed while they read the welcome
        setup = true; if (setupRows.length === 0) setupRows = apps.defaults().map(function(d) { return {label: d.name, value: d.installed ? "already installed" : "waiting"} })
        setupList.items = setupRows; setupList.currentIndex = 0; setupList.forceActiveFocus(); system.log("firstrun setup start"); apps.installDefaults()
    }
    function setRow(name, state) { const r = setupRows.slice(); for (const x of r) if (x.label === name) x.value = state === "installing" ? "installing..." : state === "skipped" ? "already installed" : state; setupRows = r; setupList.items = r; if (state === "done" || state === "skipped") prefetchDone++ }
    Connections { target: apps
        function onSetupProgress(name, state) { setRow(name, state) }
        function onSetupDone(failed) { setupFailed = failed; prefetchFinished = true; prefetching = false; system.log("firstrun setup done, failed " + failed); if (!page.setup) { message = failed === 0 ? "Default apps are ready." : failed + " app(s) failed to install, Continue shows which."; return } if (failed === 0) { system.markFirstRunDone(); done() } else { setupList.items = setupRows.concat([{label: "Retry the failed ones", value: "", action: "retry"}, {label: "Continue anyway", value: "", action: "finish"}]); setupList.currentIndex = setupList.items.length - 2 } }
    }
    // First run is never "idle": the setup screen vanished behind the 5-minute screensaver on the ISO rehearsal (2026-11-03).
    function holdIdle(on) { sway.command("[app_id=\"ottoman-shell\"] inhibit_idle " + (on ? "open" : "none")); system.log("firstrun idle inhibit " + (on ? "on" : "off")) }
    Component.onCompleted: { refresh(); if (visible) { langList.forceActiveFocus(); holdIdle(true) } }     // initial visible=true never fires onVisibleChanged
    onVisibleChanged: { holdIdle(visible); if (visible) { refresh(); (languageDone ? list : langList).forceActiveFocus() } }
    Text { text: page.setup ? "Setting up Ottoman" : "Welcome to Ottoman"; color: "#f2f2f2"; font.pixelSize: 44; font.bold: true; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text { text: page.setup ? "Installing the default apps from Flathub. This happens once." : (page.languageDone ? "Connect this box to your network. Everything else lives in Settings." : "Choose your language."); color: "#8a8f98"; font.pixelSize: 22; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 118 } }
    OptionList { id: langList; visible: !page.languageDone && !page.setup; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        items: page.languages.map(function(l) { return {label: l[1], value: l[0] === "en_US.UTF-8" ? "default" : ""} })
        onActivated: function(i) { page.chooseLanguage(i) }
        onCurrentIndexChanged: if (activeFocus) system.log("firstrun language option " + currentIndex) }
    OptionList { id: setupList; visible: page.setup; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { const it = items[i]; if (!it || !it.action) return; if (it.action === "retry") { page.setupRows = page.setupRows.map(function(x) { return {label: x.label, value: x.value === "failed" ? "waiting" : x.value} }); items = page.setupRows; apps.installDefaults() } else if (it.action === "finish") { system.markFirstRunDone(); page.done() } } }
    OptionList { id: list; visible: page.languageDone && !page.setup; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { act(i) }
        onActiveFocusChanged: if (activeFocus && items[currentIndex]) system.log("firstrun focus " + currentIndex + " " + items[currentIndex].label)
        onCurrentIndexChanged: if (activeFocus && items[currentIndex]) system.log("firstrun option " + currentIndex + " " + items[currentIndex].label) }
    Text { text: page.message.length ? page.message : (page.prefetching && !page.setup ? "Downloading the default apps in the background (" + page.prefetchDone + " of " + page.setupRows.length + " done). Continue whenever you like." : ""); color: "#d8dadf"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
    Item { id: joinPanel; visible: false; anchors.fill: parent
        Dialog { title: "Join " + page.joinSsid; hint: "Menu on the remote opens the keyboard. Enter joins, Back cancels."
            Field { id: joinPass; label: "Password"; password: true; onAccepted: system.wifiJoin(page.joinSsid, joinPass.text) } }
        Keys.onEscapePressed: { visible = false; list.forceActiveFocus() }
    }
}
