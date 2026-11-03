import QtQuick
// App tile: diagonal gradient of the app's tint with a soft glow behind the art, the app's own exported icon
// (or a monogram roundel for web apps), the name and an optional quality note centered beneath it.
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
    border.width: current ? 4 : (isAdd ? 1 : 0)
    border.color: current ? "#ffffff" : "#3a3f47"
    scale: current ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 90 } }
    // background: gradient of the tint, dimmer when not installed, neutral for the Add tile
    Rectangle {
        anchors.fill: parent; anchors.margins: tile.current ? 4 : 0; radius: 10
        gradient: Gradient { orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: tile.isAdd ? "#22262c" : Qt.lighter(tile.tint, tile.installed ? 1.15 : 0.6) }
            GradientStop { position: 1.0; color: tile.isAdd ? "#15181c" : Qt.darker(tile.tint, tile.installed ? 2.2 : 4.0) } }
        // diagonal sheen
        Rectangle { anchors.fill: parent; radius: 10; opacity: 0.18
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#ffffff" } GradientStop { position: 0.55; color: "transparent" } } }
        // glow behind the art
        Rectangle { visible: tile.hasArt; width: 150; height: 150; radius: 75; color: "#ffffff"; opacity: 0.08
            anchors { horizontalCenter: parent.horizontalCenter; verticalCenter: parent.top; verticalCenterOffset: 58 } }
    }
    Image { id: icon; visible: tile.iconUrl.length > 0; source: tile.iconUrl; width: 80; height: 80
            sourceSize.width: 256; sourceSize.height: 256; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 } }
    Rectangle { visible: tile.monogram.length > 0; width: 80; height: 80; radius: 40; color: Qt.lighter(tile.tint, 1.3)
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 18 }
            Text { anchors.centerIn: parent; text: tile.monogram; color: "#ffffff"; font.pixelSize: 42; font.bold: true } }
    Column {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: tile.note.length ? 10 : 18 }
        spacing: 2
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: (tile.isAdd ? "+  " : "") + tile.label
               color: tile.isAdd ? "#8a8f98" : (installed ? "#f2f2f2" : "#8a8f98"); font.pixelSize: tile.isAdd ? 26 : (tile.hasArt ? 22 : 32); font.bold: !tile.isAdd }
        Text { visible: tile.note.length > 0 && tile.installed; anchors.horizontalCenter: parent.horizontalCenter; text: tile.note; color: "#c9cdd4"; font.pixelSize: 12 }
    }
    // the Add tile and uninstalled apps centre their name when there is no art
    states: State { when: !tile.hasArt; AnchorChanges { target: tile.children[tile.children.length - 1]; anchors.bottom: undefined; anchors.verticalCenter: tile.verticalCenter } }
    Rectangle { visible: running; width: 14; height: 14; radius: 7; color: "#3ddc84"; anchors { right: parent.right; top: parent.top; margins: 12 } }
}
