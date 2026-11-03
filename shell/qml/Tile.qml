import QtQuick
Rectangle {
    id: tile
    property string label
    property color tint: "#444"
    property bool installed: true
    property bool running: false
    property bool current: false
    property bool isAdd: false
    property string note: ""
    property string iconUrl: ""
    property string monogram: ""
    width: 300; height: 170; radius: 10
    color: isAdd ? "#1c2026" : Qt.darker(tint, installed ? 1.6 : 3.0)
    border.width: current ? 5 : (isAdd ? 1 : 0)
    border.color: current ? "#ffffff" : "#3a3f47"
    scale: current ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }
    // Icon: the app's own exported icon when installed, a monogram roundel for web apps, the name alone otherwise.
    Image { id: icon; visible: tile.iconUrl.length > 0; source: tile.iconUrl; width: 84; height: 84; fillMode: Image.PreserveAspectFit; smooth: true; asynchronous: true
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 } }
    Rectangle { visible: tile.monogram.length > 0; width: 84; height: 84; radius: 42; color: Qt.lighter(tile.tint, 1.25)
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 22 }
            Text { anchors.centerIn: parent; text: tile.monogram; color: "#ffffff"; font.pixelSize: 44; font.bold: true } }
    property bool hasArt: tile.iconUrl.length > 0 || tile.monogram.length > 0
    Text { anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.verticalCenter; verticalCenterOffset: tile.hasArt ? 52 : 0 }
           text: (tile.isAdd ? "+  " : "") + tile.label; color: tile.isAdd ? "#8a8f98" : (installed ? "#f2f2f2" : "#777"); font.pixelSize: tile.isAdd ? 26 : (tile.hasArt ? 22 : 34); font.bold: !tile.isAdd }
    Text { visible: tile.note.length > 0 && tile.installed; text: tile.note; color: "#aab0ba"; font.pixelSize: 13; anchors { left: parent.left; bottom: parent.bottom; margins: 10 } }
    Rectangle { visible: running; width: 14; height: 14; radius: 7; color: "#3ddc84"; anchors { right: parent.right; bottom: parent.bottom; margins: 14 } }
}
