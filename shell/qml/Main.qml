import QtQuick
import QtQuick.Window
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    color: "#101214"
    title: "Ottoman"
    // Header: name, clock, settings/power placeholders (M2.3).
    Text { text: "OTTOMAN"; color: "#8a8f98"; font.pixelSize: 28; font.letterSpacing: 6; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text {
        id: clock; color: "#d8dadf"; font.pixelSize: 30
        anchors { right: parent.right; top: parent.top; margins: 48 }
        Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
    }
    Text { text: "APPS"; color: "#8a8f98"; font.pixelSize: 22; font.letterSpacing: 3; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 150 } }
    ListView {
        id: row
        anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 48; topMargin: 190 }
        height: 200
        orientation: ListView.Horizontal
        spacing: 24
        model: apps
        focus: true
        keyNavigationWraps: false
        highlightMoveDuration: 0
        delegate: Tile {
            label: model.name; tint: model.color; installed: model.installed; running: model.running
            current: ListView.isCurrentItem
            MouseArea { anchors.fill: parent; onClicked: { row.currentIndex = index; apps.launch(index) } }
        }
        Keys.onReturnPressed: apps.launch(currentIndex)
        Keys.onEnterPressed: apps.launch(currentIndex)
        Keys.onSpacePressed: apps.launch(currentIndex)
    }
    Text {
        text: apps.installedCount === 0 ? "Installing Jellyfin from Flathub, this takes about a minute on first boot." : "Enter launches. Home returns here, the app keeps running (green dot)."
        color: "#6b7079"; font.pixelSize: 20
        anchors { left: parent.left; bottom: parent.bottom; margins: 48 }
    }
}
