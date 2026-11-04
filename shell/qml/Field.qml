import QtQuick
// Text field: types from a physical keyboard, and Menu/F2 with a remote opens the on-screen keyboard (M2.3).
// `accepted` fires on Enter from the keyboard or Done on the OSK. Fills its parent's width inside a Dialog.
Rectangle {
    id: f
    property string label
    property alias text: input.text
    property bool password: false
    property alias inputItem: input
    signal accepted()
    width: parent && parent.width > 0 ? parent.width : 520; height: 64; radius: 8
    color: input.activeFocus ? "#2a2f38" : "#1c2026"
    border.width: input.activeFocus ? 3 : 1; border.color: input.activeFocus ? "#ffffff" : "#3a3f47"
    Text { text: f.label; color: "#8a8f98"; font.pixelSize: 14; anchors { left: parent.left; top: parent.top; margins: 8 } }
    TextInput {
        id: input; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 10 } height: 28
        color: "#f2f2f2"; font.pixelSize: 22; echoMode: f.password ? TextInput.Password : TextInput.Normal
        selectByMouse: true; clip: true
        onAccepted: f.accepted()
        Keys.onPressed: function(e) { if (e.key === Qt.Key_F2 || e.key === Qt.Key_Menu) { osk.openFor(input, f.label); e.accepted = true } }
    }
}
