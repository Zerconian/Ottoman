import QtQuick
// Jellyfin sign-in overlay: server + user/password, or Quick Connect (code shown, approve on a phone).
Rectangle {
    id: panel
    signal done()
    anchors.fill: parent
    color: "#e6101214"
    focus: true
    Keys.onEscapePressed: { jellyfin.quickConnectCancel(); panel.done() }
    Connections { target: jellyfin; function onChanged() { if (jellyfin.state === "connected") panel.done() } }
    Column {
        anchors.centerIn: parent; spacing: 18
        Text { text: "Sign in to Jellyfin"; color: "#f2f2f2"; font.pixelSize: 36; font.bold: true }
        Field { id: server; label: "Server address"; text: jellyfin.serverUrl.length ? jellyfin.serverUrl : ""; inputItem.focus: true
                inputItem.KeyNavigation.down: user.inputItem; inputItem.onAccepted: user.inputItem.forceActiveFocus() }
        Field { id: user; label: "User name"; inputItem.KeyNavigation.up: server.inputItem; inputItem.KeyNavigation.down: pass.inputItem; inputItem.onAccepted: pass.inputItem.forceActiveFocus() }
        Field { id: pass; label: "Password"; password: true; inputItem.KeyNavigation.up: user.inputItem; inputItem.KeyNavigation.down: qc
                inputItem.onAccepted: jellyfin.signIn(server.text, user.text, pass.text) }
        Rectangle {
            id: qc; width: 520; height: 64; radius: 8; color: activeFocus ? "#2a2f38" : "#1c2026"; border.width: activeFocus ? 3 : 1; border.color: activeFocus ? "#ffffff" : "#3a3f47"
            KeyNavigation.up: pass.inputItem
            Keys.onReturnPressed: jellyfin.quickConnectStart(server.text)
            Keys.onEnterPressed: jellyfin.quickConnectStart(server.text)
            Text { anchors.centerIn: parent; color: "#f2f2f2"; font.pixelSize: 22
                   text: jellyfin.quickConnectCode.length ? "Quick Connect code  " + jellyfin.quickConnectCode + "   (approve in the Jellyfin app on your phone)" : "Use Quick Connect instead" }
        }
        Text { text: jellyfin.state === "connecting" ? "Connecting..." : jellyfin.state === "error" ? jellyfin.errorText : "Enter signs in. Esc cancels."
               color: jellyfin.state === "error" ? "#ff6b6b" : "#8a8f98"; font.pixelSize: 18 }
    }
}
