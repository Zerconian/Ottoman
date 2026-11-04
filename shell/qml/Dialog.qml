import QtQuick
// A modal surface over the dimmed screen: title, content, one hint line. Every overlay that asks for a decision
// or for typing (tile menu, Jellyfin sign-in, Wi-Fi password) uses it, so they read as one kind of thing
// instead of text floating over the page (UI pass 2026-11-04).
Item {
    id: dlg
    property string title
    property string hint
    property color hintColor: "#8a8f98"
    property int panelWidth: 640
    default property alias content: slot.data
    anchors.fill: parent
    Rectangle { anchors.fill: parent; color: "#d90b0d10" }
    Rectangle {
        anchors.centerIn: parent; width: dlg.panelWidth; height: col.height + 72; radius: 16
        color: "#15181c"; border.width: 1; border.color: "#2a2f38"
        Column { id: col; x: 36; y: 36; width: parent.width - 72; spacing: 20
            Text { visible: text.length > 0; text: dlg.title; color: "#f2f2f2"; font.pixelSize: 34; font.bold: true }
            Column { id: slot; width: parent.width; spacing: 14 }
            Text { visible: text.length > 0; text: dlg.hint; color: dlg.hintColor; font.pixelSize: 18; width: parent.width; wrapMode: Text.Wrap }
        }
    }
}
