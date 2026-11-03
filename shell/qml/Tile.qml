import QtQuick
Rectangle {
    id: tile
    property string label
    property color tint: "#444"
    property bool installed: true
    property bool running: false
    property bool current: false
    width: 300; height: 170; radius: 10
    color: Qt.darker(tint, installed ? 1.6 : 3.0)
    border.width: current ? 5 : 0
    border.color: "#ffffff"
    scale: current ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }
    Text { anchors.centerIn: parent; text: tile.label; color: installed ? "#f2f2f2" : "#777"; font.pixelSize: 34; font.bold: true }
    Rectangle { visible: running; width: 14; height: 14; radius: 7; color: "#3ddc84"; anchors { right: parent.right; bottom: parent.bottom; margins: 14 } }
    Text { visible: !installed; text: "not installed"; color: "#999"; font.pixelSize: 18; anchors { left: parent.left; bottom: parent.bottom; margins: 14 } }
}
