import QtQuick
// Settings page (DESIGN.md 4.10 #3): Network, Display, Audio, Updates, About. Left: sections. Right: options.
// Left/Right moves between the columns, Escape/Back leaves. Display > Resolution opens a sub-list of modes
// (the mode dump used to push the screensaver rows off the page, UI pass 2026-11-04).
Rectangle {
    id: page
    signal done()
    signal previewRequested()   // Main keeps this page open when the window comes back from the preview
    anchors.fill: parent
    color: "#101214"
    property var sections: ["Network", "Display", "Audio", "Updates", "About"]
    property var blurbs: ["Wired or Wi-Fi", "Resolution and screensaver", "Where sound goes", "Keep this box current", "This box"]
    property int section: 0
    property string sub: ""                 // "" or "modes": a second-level list inside a section
    property string subOutput: ""
    property string message: ""
    property var remoteInfo: ({})           // {ip, url, localUrl, qr} from system.remote(), Network section
    property var pendingMode: null          // {output, mode, previous} while the 10 s revert runs
    property int revertLeft: 0
    function open() { section = 0; sub = ""; sections_.currentIndex = 0; sections_.forceActiveFocus(); reload(); system.log("settings open") }
    function reload() {
        message = ""
        const items = []
        if (section === 0) {
            const st = system.netStatus()
            items.push({label: "Connection", value: st.kind === "none" ? "Not connected" : (st.kind === "ethernet" ? "Wired" : "Wi-Fi") + "  " + st.ip + (st.connection ? "  (" + st.connection + ")" : "")})
            const rm = system.remote(); page.remoteInfo = rm
            if (rm.url) { items.push({label: "Phone remote", value: rm.localUrl}); items.push({label: "Phone remote by address", value: rm.url}) }
            if (!st.wifiAvailable) items.push({label: "Wi-Fi", value: "No Wi-Fi adapter"})
            else { items.push({label: "Scan for Wi-Fi networks", value: "", action: "scan"}); for (const w of (page.wifi || [])) items.push({label: (w.active ? "✓ " : "") + w.ssid, value: w.signal + "%  " + (w.security || "open"), action: "join", ssid: w.ssid, security: w.security}) }
        } else if (section === 1 && sub === "modes") {
            const seen = {}
            for (const o of system.outputs()) { if (o.name !== subOutput) continue
                for (const m of o.modes) { if (seen[m.label]) continue; seen[m.label] = true; items.push({label: m.label, value: m.value === o.current ? "current" : "", action: "mode", output: o.name, mode: m.value, previous: o.current}) } }
            if (items.length === 0) items.push({label: "No modes reported", value: ""})
        } else if (section === 1) {
            const outs = system.outputs()
            for (const o of outs) { items.push({label: outs.length > 1 ? o.name : "Display", value: o.make}); items.push({label: "Resolution", value: o.currentLabel, action: "modes", output: o.name}) }
            if (outs.length === 0) items.push({label: "No display found", value: ""})
            const sv = system.saverConfig(); const after = function(s) { return s === 0 ? "never" : (s / 60) + " min" }
            items.push({label: "Screensaver", value: {clock: "Clock", aurora: "Aurora (animated)", stars: "Stars (animated)"}[sv.mode] || sv.mode, action: "savermode", mode: sv.mode})
            items.push({label: "Screensaver after", value: after(sv.saverSecs), action: "saverafter", secs: sv.saverSecs, off: sv.offSecs})
            items.push({label: "Display off after", value: after(sv.offSecs), action: "offafter", secs: sv.saverSecs, off: sv.offSecs})
            items.push({label: "Preview screensaver", value: "any key ends it", action: "preview"})
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
            items.push({label: "Name", value: a.hostname}); items.push({label: "Build", value: a.build}); items.push({label: "Kernel", value: a.kernel})
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
        else if (it.action === "modes") { sub = "modes"; subOutput = it.output; reload(); let c = 0; for (let k = 0; k < options.items.length; k++) if (options.items[k].value === "current") c = k; options.currentIndex = c; options.positionViewAtIndex(c, ListView.Center); system.log("settings modes open") }
        else if (it.action === "mode") { if (it.mode === it.previous) return; if (system.setMode(it.output, it.mode)) { pendingMode = {output: it.output, mode: it.mode, previous: it.previous}; revertLeft = 10; revertTimer.start(); message = "Keeping this mode? Enter to keep, reverting in 10 s" } else { pendingMode = null; message = "Could not set " + it.label.trim() } }
        else if (it.action === "sink") { system.setDefaultSink(it.id); reload() }
        else if (it.action === "savermode") { const m = ["clock", "aurora", "stars"]; system.setSaverMode(m[(m.indexOf(it.mode) + 1) % m.length]); reload() }
        else if (it.action === "saverafter") { const c = [300, 600, 1800, 0]; system.setIdle(c[(c.indexOf(it.secs) + 1) % c.length], it.off); reload() }
        else if (it.action === "offafter") { const c = [1800, 3600, 0]; system.setIdle(it.secs, c[(c.indexOf(it.off) + 1) % c.length]); reload() }
        else if (it.action === "preview") { previewRequested(); system.previewSaver() }
        else if (it.action === "check") system.updateCheck()
        else if (it.action === "apply") system.updateApply()
        else if (it.action === "rollback") system.rollback()
        else if (it.action === "reboot") system.reboot()
        else if (it.action === "signout") { jellyfin.signOut(); reload() }
    }
    function closeSub() { sub = ""; reload(); for (let k = 0; k < options.items.length; k++) if (options.items[k].action === "modes") options.currentIndex = k; system.log("settings modes close") }
    Timer { id: revertTimer; interval: 1000; repeat: true
        onTriggered: { revertLeft--; message = "Keeping this mode? Enter to keep, reverting in " + revertLeft + " s"; if (revertLeft <= 0) { stop(); system.setMode(pendingMode.output, pendingMode.previous); pendingMode = null; message = "Reverted"; reload() } } }
    function keepMode() { if (!pendingMode || section !== 1) return false; revertTimer.stop(); system.saveMode(pendingMode.output, pendingMode.mode); pendingMode = null; message = "Mode saved"; reload(); return true }
    Connections { target: system
        function onUpdateResult(ok, text) { message = text; reload() }
        function onJoined(ok, text) { message = text; joinPanel.visible = false; wifi = system.wifiList(); reload() }
        function onBusyChanged() { if (system.busyText.length) message = system.busyText + "..." }
    }
    Keys.onEscapePressed: { if (joinPanel.visible) joinPanel.visible = false; else if (pendingMode) { revertTimer.stop(); system.setMode(pendingMode.output, pendingMode.previous); pendingMode = null; reload() } else if (sub.length) closeSub(); else done() }
    Keys.onBackPressed: done()
    onDone: system.log("settings close")
    Text { text: "Settings"; color: "#f2f2f2"; font.pixelSize: 44; font.bold: true; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text { text: page.sub === "modes" ? "Resolution. Enter tries a mode for 10 seconds, Enter again keeps it, Back returns." : page.blurbs[page.section]
           color: "#8a8f98"; font.pixelSize: 22; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 118 } }
    ListView {
        id: sections_
        anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 180 } width: 300; height: 400; spacing: 8
        model: page.sections
        delegate: Rectangle { width: 300; height: 64; radius: 8; color: ListView.isCurrentItem ? (sections_.activeFocus ? "#ffffff" : "#2a2f38") : "transparent"
            Text { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 } text: modelData; font.pixelSize: 26; font.bold: true; color: parent.ListView.isCurrentItem && sections_.activeFocus ? "#111" : "#e6e7ea" } }
        onCurrentIndexChanged: { page.section = currentIndex; page.sub = ""; options.currentIndex = 0; reload(); system.log("settings section " + page.sections[currentIndex]) }
        onActiveFocusChanged: if (activeFocus) system.log("settings focus sections " + page.sections[currentIndex])
        Keys.onRightPressed: options.forceActiveFocus()
        Keys.onReturnPressed: options.forceActiveFocus()
        Keys.onEnterPressed: options.forceActiveFocus()
    }
    OptionList {
        id: options
        anchors { left: sections_.right; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 40; rightMargin: page.qrShown ? 268 : 48; topMargin: 180; bottomMargin: 120 }
        onActivated: function(i) { system.log("settings activate " + (items[i] ? items[i].label : i)); if (!keepMode()) act(i) }
        onCurrentIndexChanged: if (activeFocus && items[currentIndex]) system.log("settings option " + currentIndex + " " + items[currentIndex].label)
        onActiveFocusChanged: if (activeFocus && items[currentIndex]) system.log("settings focus options " + currentIndex + " " + items[currentIndex].label)
        Keys.onLeftPressed: if (page.sub.length) page.closeSub(); else sections_.forceActiveFocus()
    }
    // Phone remote QR (Network section): scan it with the phone's camera, no app to install.
    Column { visible: page.section === 0 && page.sub === "" && !!page.remoteInfo.qr; spacing: 10
             anchors { right: parent.right; top: parent.top; rightMargin: 48; topMargin: 40 }
        Image { source: page.remoteInfo.qr || ""; width: 168; height: 168; smooth: false; anchors.horizontalCenter: parent.horizontalCenter }
        Text { text: "Scan for the phone remote"; color: "#8a8f98"; font.pixelSize: 16; anchors.horizontalCenter: parent.horizontalCenter } }
    property bool qrShown: section === 0 && sub === "" && !!remoteInfo.qr   // the option list leaves room for the QR column
    Text { text: page.message; color: "#d8dadf"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
    Text { text: page.sub.length ? "Back returns to Display" : "Back returns home"; color: "#555a63"; font.pixelSize: 18; anchors { right: parent.right; bottom: parent.bottom; margins: 48 } }
    // Wi-Fi password entry
    Item { id: joinPanel; visible: false; anchors.fill: parent
        Dialog { title: "Join " + page.joinSsid; hint: "Menu on the remote opens the keyboard. Enter joins, Back cancels."
            Field { id: joinPass; label: "Password"; password: true; onAccepted: system.wifiJoin(page.joinSsid, joinPass.text) } }
    }
    property string joinSsid: ""
}
