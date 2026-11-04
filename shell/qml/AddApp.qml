import QtQuick
// The "Add app" tile: pick from the TV-ready list; installs from Flathub, or re-shows a hidden app.
Rectangle {
    id: page
    signal done()
    anchors.fill: parent
    color: "#101214"
    property string message: ""
    function open() { message = ""; build(); list.currentIndex = 0; visible = true; list.forceActiveFocus(); system.log("addapp open") }
    function build() {
        const items = []
        for (const a of apps.catalogue()) {
            const sub = a.web ? "Streams in Firefox" + (a.note ? ", " + a.note.charAt(0).toLowerCase() + a.note.slice(1) : "") : a.note
            if (a.onRow) items.push({label: a.name, sub: sub, value: "On the row", action: "", web: a.web})
            else if (a.installed) items.push({label: a.name, sub: sub, value: a.web ? "Not on the row" : "Hidden", action: "unhide", id: a.key, web: a.web})
            else items.push({label: a.name, sub: sub, value: "Not installed", action: "install", id: a.flatpakId, key: a.key, web: a.web})
        }
        list.items = items
    }
    function hintFor(it) {
        if (!it) return ""
        if (it.action === "install") return it.web ? "OK adds it to the row. Firefox installs once and is shared by every streaming site." : "OK installs it from Flathub and adds it to the row."
        if (it.action === "unhide") return "OK puts it on the row."
        return "Already on the row. Hold OK on its tile to move or hide it."
    }
    function act(i) {
        const it = list.items[i]; if (!it.action) return
        system.log("addapp " + it.action + " " + it.id)
        if (it.action === "install") { message = "Installing " + it.label + "..."; if (it.key) apps.unhide(it.key); apps.install(it.id) } else { apps.unhide(it.id); build() }
    }
    Connections { target: apps; function onOpDone(ok, text) { page.message = text; page.build() } }
    Keys.onEscapePressed: { visible = false; done() }
    Text { text: "Add app"; color: "#f2f2f2"; font.pixelSize: 44; font.bold: true; anchors { left: parent.left; top: parent.top; margins: 48 } }
    Text { text: "Apps that work with a remote. Installs come from Flathub."; color: "#8a8f98"; font.pixelSize: 22; anchors { left: parent.left; top: parent.top; leftMargin: 48; topMargin: 118 } }
    OptionList { id: list; anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 48; topMargin: 180; bottomMargin: 110 }
        onActivated: function(i) { page.act(i) }
        onCurrentIndexChanged: if (activeFocus && items[currentIndex]) system.log("addapp option " + currentIndex + " " + items[currentIndex].label) }
    Text { text: page.message.length ? page.message : page.hintFor(list.items[list.currentIndex]); color: page.message.length ? "#d8dadf" : "#6b7079"; font.pixelSize: 22; anchors { left: parent.left; bottom: parent.bottom; margins: 48 } }
    Text { text: "Back returns home"; color: "#555a63"; font.pixelSize: 18; anchors { right: parent.right; bottom: parent.bottom; margins: 48 } }
}
