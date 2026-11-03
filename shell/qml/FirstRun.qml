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
    function refresh() { st = system.netStatus(); build() }
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
        if (it.action === "done") { startSetup() }
        else if (it.action === "refresh") refresh()
        else if (it.action === "scan") { message = "Scanning..."; wifi = system.wifiList(); build(); message = wifi.length + " networks" }
        else if (it.action === "join") { if (it.security) { joinSsid = it.ssid; joinPass.text = ""; joinPanel.visible = true; joinPass.inputItem.forceActiveFocus() } else system.wifiJoin(it.ssid, "") }
    }
    Connections { target: system
        function onJoined(ok, text) { message = text; joinPanel.visible = false; refresh(); list.forceActiveFocus() }
        function onBusyChanged() { if (system.busyText.length) message = system.busyText + "..." }
    }
    Component.onCompleted: { refresh(); if (visible) list.forceActiveFocus() }     // initial visible=true never fires onVisibleChanged
    onVisibleChanged: if (visible) { refresh(); list.forceActiveFocus() }
    Text { text: page.setup ? "Setting up Ottoman" : "Welcome to Ottoman"; color: "#f2f2f2"; font.pixelSize: 44; font.bold: true; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text { text: page.setup ? "Installing the default apps from Flathub. This happens once." : "Connect this box to your network. Everything else lives in Settings."; color: "#8a8f98"; font.pixelSize: 22; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 118 } }
    OptionList { id: setupList; visible: page.setup; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { const it = items[i]; if (!it || !it.action) return; if (it.action === "retry") { page.setupRows = page.setupRows.map(function(x) { return {label: x.label, value: x.value === "failed" ? "waiting" : x.value} }); items = page.setupRows; apps.installDefaults() } else if (it.action === "finish") { system.markFirstRunDone(); page.done() } } }
    OptionList { id: list; visible: !page.setup; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { act(i) }
        onActiveFocusChanged: if (activeFocus && items[currentIndex]) system.log("firstrun focus " + currentIndex + " " + items[currentIndex].label)
        onCurrentIndexChanged: if (activeFocus && items[currentIndex]) system.log("firstrun option " + currentIndex + " " + items[currentIndex].label) }
    Text { text: page.message; color: "#d8dadf"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
    Rectangle { id: joinPanel; visible: false; anchors.fill: parent; color: "#e6101214"
        Column { anchors.centerIn: parent; spacing: 18
            Text { text: "Join " + page.joinSsid; color: "#f2f2f2"; font.pixelSize: 32; font.bold: true }
            Field { id: joinPass; label: "Password"; password: true; onAccepted: system.wifiJoin(page.joinSsid, joinPass.text) }
            Text { text: "Enter joins. Escape cancels."; color: "#8a8f98"; font.pixelSize: 18 }
        }
        Keys.onEscapePressed: { visible = false; list.forceActiveFocus() }
    }
}
