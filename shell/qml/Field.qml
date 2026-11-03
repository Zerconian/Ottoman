import QtQuick
// Keyboard text field for the sign-in overlay (M2: physical keyboard; the on-screen keyboard is M2.3).
Rectangle {
    id: f
    property string label
    property alias text: input.text
    property bool password: false
    property alias inputItem: input
    width: 520; height: 64; radius: 8
    color: input.activeFocus ? "#2a2f38" : "#1c2026"
    border.width: input.activeFocus ? 3 : 1; border.color: input.activeFocus ? "#ffffff" : "#3a3f47"
    Text { text: f.label; color: "#8a8f98"; font.pixelSize: 14; anchors { left: parent.left; top: parent.top; margins: 8 } }
    TextInput {
        id: input; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 } height: 28
        color: "#f2f2f2"; font.pixelSize: 22; echoMode: f.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true; clip: true
    }
}
