import QtQuick
// App tile (10-foot): the app's own icon on a gradient of its colour, the name on a darker plate along the
// bottom with an optional quality note. One bold thing per tile, the colour; no decoration beyond that.
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
    property bool hasArt: iconUrl.length > 0 || monogram.length > 0
    width: 300; height: 170; radius: 12
    color: "transparent"
    border.width: current ? 4 : 0
    border.color: "#ffffff"
    scale: current ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }
    Rectangle {
        id: body
        anchors.fill: parent; anchors.margins: tile.current ? 4 : 0; radius: 10; clip: true
        gradient: Gradient { orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: tile.isAdd ? "#262a31" : Qt.lighter(tile.tint, tile.installed ? 1.10 : 0.55) }
            GradientStop { position: 1.0; color: tile.isAdd ? "#181b20" : Qt.darker(tile.tint, tile.installed ? 1.6 : 3.0) } }
        // hairline at the top edge: the only highlight, gives the surface an edge
        Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: "#ffffff"; opacity: 0.22 }
        // name plate along the bottom
        Rectangle { id: plate; visible: tile.hasArt; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: tile.note.length ? 58 : 46; color: "#000000"; opacity: 0.34 }
    }
    Image { visible: tile.iconUrl.length > 0; source: tile.iconUrl; width: 76; height: 76
            sourceSize.width: 256; sourceSize.height: 256; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: tile.note.length ? 18 : 24 } }
    Rectangle { visible: tile.monogram.length > 0; width: 76; height: 76; radius: 38; color: Qt.lighter(tile.tint, 1.35)
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: tile.note.length ? 18 : 24 }
            Text { anchors.centerIn: parent; text: tile.monogram; color: "#ffffff"; font.pixelSize: 40; font.bold: true } }
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: tile.hasArt ? (tile.note.length ? 9 : 12) : 0; verticalCenter: tile.hasArt ? undefined : parent.verticalCenter }
        spacing: 1
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: (tile.isAdd ? "+  " : "") + tile.label
               color: tile.isAdd ? "#9aa0a8" : (installed ? "#f4f5f7" : "#9aa0a8"); font.pixelSize: tile.isAdd ? 26 : (tile.hasArt ? 21 : 32); font.bold: !tile.isAdd }
        Text { visible: tile.note.length > 0 && tile.installed; anchors.horizontalCenter: parent.horizontalCenter; text: tile.note; color: "#cfd3d9"; font.pixelSize: 15 }
    }
    Rectangle { visible: running; width: 12; height: 12; radius: 6; color: "#3ddc84"; anchors { right: parent.right; top: parent.top; margins: 12 } }
}
