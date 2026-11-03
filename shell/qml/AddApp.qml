import QtQuick
// The "Add app" tile: pick from the TV-ready list; installs from Flathub, or re-shows a hidden app.
Rectangle {
    id: page
    signal done()
    anchors.fill: parent
    color: "#101214"
    property string message: ""
    function open() { build(); list.currentIndex = 0; visible = true; list.forceActiveFocus(); system.log("addapp open") }
    function build() {
        const items = []
        for (const a of apps.catalogue()) {
            if (a.installed && !a.hidden) items.push({label: a.name, value: "installed", action: ""})
            else if (a.installed && a.hidden) items.push({label: a.name, value: "hidden, Enter shows it", action: "unhide", id: a.flatpakId})
            else items.push({label: a.name, value: "Enter installs from Flathub", action: "install", id: a.flatpakId})
        }
        list.items = items
    }
    function act(i) {
        const it = list.items[i]; if (!it.action) return
        system.log("addapp " + it.action + " " + it.id)
        if (it.action === "install") { message = "Installing " + it.label + "..."; apps.install(it.id) } else { apps.unhide(it.id); build() }
    }
    Connections { target: apps; function onOpDone(ok, text) { page.message = text; page.build() } }
    Keys.onEscapePressed: { visible = false; done() }
    Text { text: "Add app"; color: "#f2f2f2"; font.pixelSize: 44; font.bold: true; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text { text: "Apps tested with a remote. Installs come from Flathub."; color: "#8a8f98"; font.pixelSize: 22; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 118 } }
    OptionList { id: list; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { page.act(i) }
        onCurrentIndexChanged: if (activeFocus && items[currentIndex]) system.log("addapp option " + currentIndex + " " + items[currentIndex].label) }
    Text { text: page.message; color: "#d8dadf"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
}
