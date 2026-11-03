import QtQuick
// A focusable list of {label, value} rows for Settings panels. Enter emits activated(index).
ListView {
    id: list
    property var items: []
    signal activated(int index)
    model: items.length
    spacing: 6; clip: true
    delegate: Rectangle {
        width: list.width; height: 64; radius: 8
        color: ListView.isCurrentItem && list.activeFocus ? "#2a2f38" : "transparent"
        border.width: ListView.isCurrentItem && list.activeFocus ? 3 : 0; border.color: "#ffffff"
        Text { text: list.items[index].label; color: "#e6e7ea"; font.pixelSize: 24; anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 } }
        Text { text: list.items[index].value || ""; color: "#8a8f98"; font.pixelSize: 22; anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 18 } }
        MouseArea { anchors.fill: parent; onClicked: { list.currentIndex = index; list.activated(index) } }
    }
    Keys.onReturnPressed: if (currentIndex >= 0) activated(currentIndex)
    Keys.onEnterPressed: if (currentIndex >= 0) activated(currentIndex)
}
