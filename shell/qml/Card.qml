import QtQuick
// A content-row card: 16:9 artwork, title, subtitle, progress bar.
Item {
    id: card
    property string title
    property string subtitle
    property string imageUrl
    property real progress: 0
    property bool current: false
    width: 300; height: 215
    Rectangle {
        id: art; width: 300; height: 170; radius: 10; color: "#2a2d33"; clip: true
        border.width: card.current ? 5 : 0; border.color: "#ffffff"
        scale: card.current ? 1.06 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }
        Image { anchors.fill: parent; anchors.margins: card.current ? 5 : 0; source: card.imageUrl; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: true }
        Rectangle { visible: card.progress > 0; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 6 } height: 6; radius: 3; color: "#55000000"
            Rectangle { width: parent.width * Math.min(1, card.progress); height: parent.height; radius: 3; color: "#00a4dc" } }
    }
    Text { anchors { top: art.bottom; topMargin: 8; left: parent.left } width: 300; elide: Text.ElideRight; text: card.title; color: "#e6e7ea"; font.pixelSize: 20; font.bold: true }
    Text { anchors { top: art.bottom; topMargin: 32; left: parent.left } width: 300; elide: Text.ElideRight; text: card.subtitle; color: "#8a8f98"; font.pixelSize: 16 }
}
