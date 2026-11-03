import QtQuick
// Settings page (DESIGN.md 4.10 #3): Network, Display, Audio, Updates, About. Left: sections. Right: options.
// Left/Right moves between the columns, Escape/Back leaves.
Rectangle {
    id: page
    signal done()
    anchors.fill: parent
    color: "#101214"
    property var sections: ["Network", "Display", "Audio", "Updates", "About"]
    property int section: 0
    property string message: ""
    property var pendingMode: null          // {output, mode, previous} while the 10 s revert runs
    property int revertLeft: 0
    function open() { section = 0; sections_.currentIndex = 0; sections_.forceActiveFocus(); reload() }
    function reload() {
        message = ""
        const items = []
        if (section === 0) {
            const st = system.netStatus()
            items.push({label: "Connection", value: st.kind === "none" ? "Not connected" : (st.kind === "ethernet" ? "Wired" : "Wi-Fi") + "  " + st.ip + (st.connection ? "  (" + st.connection + ")" : "")})
            if (!st.wifiAvailable) items.push({label: "Wi-Fi", value: "No Wi-Fi adapter"})
            else { items.push({label: "Scan for Wi-Fi networks", value: "", action: "scan"}); for (const w of (page.wifi || [])) items.push({label: (w.active ? "✓ " : "") + w.ssid, value: w.signal + "%  " + (w.security || "open"), action: "join", ssid: w.ssid, security: w.security}) }
        } else if (section === 1) {
            for (const o of system.outputs()) { items.push({label: o.name + "  " + o.make, value: o.current}); for (const m of o.modes) items.push({label: "    " + m, value: m === o.current ? "current" : "", action: "mode", output: o.name, mode: m, previous: o.current}) }
            if (items.length === 0) items.push({label: "No display found", value: ""})
        } else if (section === 2) {
            const s = system.sinks()
            if (s.length === 0) items.push({label: "No audio outputs found", value: ""})
            for (const k of s) items.push({label: k.name, value: k.isDefault ? "current" : "", action: "sink", id: k.id})
            items.push({label: "Passthrough (TrueHD, DTS-HD)", value: "set inside Jellyfin / Kodi for now"})
        } else if (section === 3) {
            const u = system.updateStatus()
            items.push({label: "Installed", value: u.booted})
            items.push({label: "Image", value: u.image})
            if (u.staged) items.push({label: "Ready on next restart", value: u.staged})
            if (u.rollback) items.push({label: "Previous version", value: u.rollback})
            items.push({label: "Check for updates", value: "", action: "check"})
            items.push({label: "Download and install update", value: "", action: "apply"})
            if (u.rollback) items.push({label: "Go back to the previous version", value: "", action: "rollback"})
            items.push({label: "Restart now", value: "", action: "reboot"})
        } else {
            const a = system.about()
            items.push({label: "Name", value: a.hostname}); items.push({label: "Kernel", value: a.kernel})
            items.push({label: "Up for", value: a.uptime}); items.push({label: "Storage free", value: a.diskFree + " of " + a.diskTotal})
            items.push({label: "Jellyfin", value: jellyfin.state === "connected" ? jellyfin.userName + " at " + jellyfin.serverUrl : "not signed in", action: jellyfin.state === "connected" ? "signout" : ""})
        }
        options.items = items
        if (options.currentIndex < 0) options.currentIndex = 0
    }
    property var wifi: []
    function act(i) {
        const it = options.items[i]; if (!it || !it.action) return
        if (it.action === "scan") { message = "Scanning..."; wifi = system.wifiList(); reload(); message = wifi.length + " networks" }
        else if (it.action === "join") { if (it.security) { joinSsid = it.ssid; joinPass.text = ""; joinPanel.visible = true; joinPass.inputItem.forceActiveFocus() } else system.wifiJoin(it.ssid, "") }
        else if (it.action === "mode") { pendingMode = {output: it.output, mode: it.mode, previous: it.previous}; if (system.setMode(it.output, it.mode)) { revertLeft = 10; revertTimer.start(); message = "Keeping this mode? Enter to keep, reverting in 10 s" } else message = "Could not set " + it.mode }
        else if (it.action === "sink") { system.setDefaultSink(it.id); reload() }
        else if (it.action === "check") system.updateCheck()
        else if (it.action === "apply") system.updateApply()
        else if (it.action === "rollback") system.rollback()
        else if (it.action === "reboot") system.reboot()
        else if (it.action === "signout") { jellyfin.signOut(); reload() }
    }
    Timer { id: revertTimer; interval: 1000; repeat: true
        onTriggered: { revertLeft--; message = "Keeping this mode? Enter to keep, reverting in " + revertLeft + " s"; if (revertLeft <= 0) { stop(); system.setMode(pendingMode.output, pendingMode.previous); pendingMode = null; message = "Reverted"; reload() } } }
    function keepMode() { if (!pendingMode) return false; revertTimer.stop(); system.saveMode(pendingMode.output, pendingMode.mode); pendingMode = null; message = "Mode saved"; reload(); return true }
    Connections { target: system
        function onUpdateResult(ok, text) { message = text; reload() }
        function onJoined(ok, text) { message = text; joinPanel.visible = false; wifi = system.wifiList(); reload() }
        function onBusyChanged() { if (system.busyText.length) message = system.busyText + "..." }
    }
    Keys.onEscapePressed: { if (joinPanel.visible) joinPanel.visible = false; else if (pendingMode) { revertTimer.stop(); system.setMode(pendingMode.output, pendingMode.previous); pendingMode = null; reload() } else done() }
    Keys.onBackPressed: done()
    Text { text: "SETTINGS"; color: "#8a8f98"; font.pixelSize: 28; font.letterSpacing: 6; anchors { left: parent.left; top: parent.top; margins: 48 } }
    ListView {
        id: sections_
        anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 130 } width: 300; height: 400; spacing: 8
        model: page.sections
        delegate: Rectangle { width: 300; height: 64; radius: 8; color: ListView.isCurrentItem ? (sections_.activeFocus ? "#ffffff" : "#2a2f38") : "transparent"
            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 } text: modelData; font.pixelSize: 26; font.bold: true; color: parent.ListView.isCurrentItem && sections_.activeFocus ? "#111" : "#e6e7ea" } }
        onCurrentIndexChanged: { page.section = currentIndex; options.currentIndex = 0; reload() }
        Keys.onRightPressed: options.forceActiveFocus()
        Keys.onReturnPressed: options.forceActiveFocus()
        Keys.onEnterPressed: options.forceActiveFocus()
    }
    OptionList {
        id: options
        anchors { left: sections_.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 40; rightMargin: 48; topMargin: 130; bottomMargin: 120 }
        onActivated: function(i) { if (!keepMode()) act(i) }
        Keys.onLeftPressed: sections_.forceActiveFocus()
    }
    Text { text: page.message; color: "#d8dadf"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
    // Wi-Fi password entry
    Rectangle { id: joinPanel; visible: false; anchors.fill: parent; color: "#e6101214"
        property string joinSsid: ""
        Column { anchors.centerIn: parent; spacing: 18
            Text { text: "Join " + page.joinSsid; color: "#f2f2f2"; font.pixelSize: 32; font.bold: true }
            Field { id: joinPass; label: "Password"; password: true; onAccepted: system.wifiJoin(page.joinSsid, joinPass.text) }
            Text { text: "Enter joins. Escape cancels."; color: "#8a8f98"; font.pixelSize: 18 }
        }
    }
    property string joinSsid: ""
}
