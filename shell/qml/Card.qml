import QtQuick
// A content-row card: 16:9 artwork, title, subtitle, progress bar. Without artwork (a prompt card, an item with
// no image) it shows a tinted plate with an icon or the title's initial instead of an empty box.
Item {
    id: card
    property string title
    property string subtitle
    property string imageUrl
    property real progress: 0
    property bool current: false
    property color tint: "#2a2d33"
    property string iconUrl: ""
    width: 300; height: 215
    Rectangle {
        id: art; width: 300; height: 170; radius: 10; color: "#2a2d33"; clip: true
        border.width: card.current ? 5 : 0; border.color: "#ffffff"
        scale: card.current ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Rectangle { anchors.fill: parent; anchors.margins: card.current ? 5 : 0; radius: 8; visible: card.imageUrl.length === 0 || pic.status !== Image.Ready
            gradient: Gradient { orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.darker(card.tint, 1.25) }
                GradientStop { position: 1.0; color: Qt.darker(card.tint, 2.6) } }
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: "#ffffff"; opacity: 0.18 }
            Image { visible: card.iconUrl.length > 0; source: card.iconUrl; width: 72; height: 72; anchors.centerIn: parent
                    sourceSize.width: 256; sourceSize.height: 256; fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true }
            Text { visible: card.iconUrl.length === 0; anchors.centerIn: parent; text: card.title.length ? card.title.charAt(0).toUpperCase() : ""; color: "#ffffff"; opacity: 0.85; font.pixelSize: 64; font.bold: true }
        }
        Image { id: pic; anchors.fill: parent; anchors.margins: card.current ? 5 : 0; source: card.imageUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
        Rectangle { visible: card.progress > 0; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 } height: 6; radius: 3; color: "#55000000"
            Rectangle { width: parent.width * Math.min(1, card.progress); height: parent.height; radius: 3; color: "#00a4dc" } }
    }
    Text { anchors { top: art.bottom; topMargin: 8; left: parent.left } width: 300; elide: Text.ElideRight; text: card.title; color: "#e6e7ea"; font.pixelSize: 20; font.bold: true }
    Text { anchors { top: art.bottom; topMargin: 32; left: parent.left } width: 300; elide: Text.ElideRight; text: card.subtitle; color: "#8a8f98"; font.pixelSize: 16 }
}
