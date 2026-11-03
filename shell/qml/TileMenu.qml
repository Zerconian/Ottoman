import QtQuick
// Long-press / Menu on an app tile: move, hide, uninstall.
Rectangle {
    id: menu
    property int row: -1
    property string appName: ""
    signal done()
    anchors.fill: parent
    color: "#cc101214"
    function open(r, name) { row = r; appName = name; list.items = [{label: "Move left", action: "left"}, {label: "Move right", action: "right"}, {label: "Hide from the row", action: "hide"}, {label: "Uninstall", action: "uninstall"}, {label: "Cancel", action: "cancel"}]; list.currentIndex = 0; list.ignoreEnterUntilRelease = true; visible = true; list.forceActiveFocus(); system.log("tilemenu open " + name) }
    function act(i) {
        const a = list.items[i].action; system.log("tilemenu " + a + " " + appName)
        if (a === "left") apps.move(row, -1); else if (a === "right") apps.move(row, 1)
        else if (a === "hide") apps.hide(row); else if (a === "uninstall") apps.uninstall(row)
        visible = false; done()
    }
    Keys.onEscapePressed: { visible = false; done() }
    Column { anchors.centerIn: parent; spacing: 16
        Text { text: menu.appName; color: "#f2f2f2"; font.pixelSize: 34; font.bold: true }
        OptionList { id: list; width: 520; height: 360; onActivated: function(i) { menu.act(i) } }
    }
}
