import QtQuick
// A focusable list of {label, value, sub?} rows for Settings panels. Enter emits activated(index).
// `sub` is an optional second line under the label. The current row keeps a faint plate while the list is not
// focused, so a two-column page shows where Right will land.
ListView {
    id: list
    property var items: []
    signal activated(int index)
    model: items.length
    spacing: 6; clip: true
    delegate: Rectangle {
        property var it: list.items[index] || ({})
        property bool hot: ListView.isCurrentItem && list.activeFocus
        width: list.width; height: it.sub ? 80 : 64; radius: 8
        color: hot ? "#2a2f38" : (ListView.isCurrentItem ? "#181b20" : "transparent")
        border.width: hot ? 3 : 0; border.color: "#ffffff"
        Column { anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 } spacing: 2
            Text { text: it.label || ""; color: "#e6e7ea"; font.pixelSize: 24 }
            Text { visible: !!it.sub; text: it.sub || ""; color: "#8a8f98"; font.pixelSize: 17 } }
        Text { text: it.value || ""; color: "#8a8f98"; font.pixelSize: 22; anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 18 } }
        MouseArea { anchors.fill: parent; onClicked: { list.currentIndex = index; list.activated(index) } }
    }
    // A menu opened by HOLDING Enter must not act on that same key: swallow Enter until it is released.
    property bool ignoreEnterUntilRelease: false
    // Qt emits the specific onReturnPressed BEFORE the general onPressed, so the guard lives in the specific handlers.
    // Qt's Wayland client emulates auto-repeat as release+press pairs flagged isAutoRepeat (measured 2026-11-03):
    // only a REAL release ends the guard.
    Keys.onReleased: function(e) { if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) ignoreEnterUntilRelease = false }
    Keys.onReturnPressed: function(e) { if (ignoreEnterUntilRelease) { e.accepted = true; return } if (currentIndex >= 0) activated(currentIndex) }
    Keys.onEnterPressed: function(e) { if (ignoreEnterUntilRelease) { e.accepted = true; return } if (currentIndex >= 0) activated(currentIndex) }
}
