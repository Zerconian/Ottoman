import QtQuick
// Jellyfin sign-in overlay: server + user/password, or Quick Connect (code shown, approve on a phone).
Item {
    id: panel
    signal done()
    anchors.fill: parent
    // The panel itself must not take focus: typing has to land in the server field (first VM test typed into nothing).
    function focusFirst() { server.inputItem.forceActiveFocus() }
    onVisibleChanged: if (visible) focusFirst()
    Keys.onEscapePressed: { jellyfin.quickConnectCancel(); panel.done() }
    Connections { target: jellyfin; function onChanged() { if (jellyfin.state === "connected") panel.done() } }
    Dialog {
        title: "Sign in to Jellyfin"; panelWidth: 640
        hint: jellyfin.state === "connecting" ? "Connecting..." : jellyfin.state === "error" ? jellyfin.errorText : "Menu on the remote opens the keyboard. Enter signs in, Back cancels."
        hintColor: jellyfin.state === "error" ? "#ff6b6b" : "#8a8f98"
        Field { id: server; label: "Server address"; text: jellyfin.serverUrl.length ? jellyfin.serverUrl : ""
                inputItem.KeyNavigation.down: user.inputItem; onAccepted: user.inputItem.forceActiveFocus() }
        Field { id: user; label: "User name"; inputItem.KeyNavigation.up: server.inputItem; inputItem.KeyNavigation.down: pass.inputItem; onAccepted: pass.inputItem.forceActiveFocus() }
        Field { id: pass; label: "Password"; password: true; inputItem.KeyNavigation.up: user.inputItem; inputItem.KeyNavigation.down: qc
                onAccepted: jellyfin.signIn(server.text, user.text, pass.text) }
        Rectangle {
            id: qc; width: parent.width; height: 64; radius: 8; color: activeFocus ? "#2a2f38" : "#1c2026"; border.width: activeFocus ? 3 : 1; border.color: activeFocus ? "#ffffff" : "#3a3f47"
            KeyNavigation.up: pass.inputItem
            Keys.onReturnPressed: jellyfin.quickConnectStart(server.text)
            Keys.onEnterPressed: jellyfin.quickConnectStart(server.text)
            Text { anchors.centerIn: parent; color: "#f2f2f2"; font.pixelSize: 22; width: parent.width - 32; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                   text: jellyfin.quickConnectCode.length ? "Quick Connect code  " + jellyfin.quickConnectCode + "\napprove it in the Jellyfin app on your phone" : "Use Quick Connect instead" }
        }
    }
}
