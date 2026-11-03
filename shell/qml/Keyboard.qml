import QtQuick
// On-screen keyboard for remotes: D-pad moves, Enter types, Back/Escape closes. Writes into `target` (a TextInput).
Rectangle {
    id: kb
    property Item target
    signal done()
    width: 1100; height: 330; radius: 12; color: "#1a1d22"; border.color: "#3a3f47"; border.width: 1
    property bool shift: false
    property var rows: [
        ["1","2","3","4","5","6","7","8","9","0","-","_"],
        ["q","w","e","r","t","y","u","i","o","p",".",":"],
        ["a","s","d","f","g","h","j","k","l","@","/","\\"],
        ["z","x","c","v","b","n","m",",","!","?","#","+"],
        ["Shift","Space","Backspace","Done"]]
    property int r: 1
    property int c: 0
    function key() { return rows[r][Math.min(c, rows[r].length - 1)] }
    function press() {
        const k = key(); system.log("osk press " + k)
        if (k === "Shift") shift = !shift
        else if (k === "Space") target.insert(target.cursorPosition, " ")
        else if (k === "Backspace") { if (target.cursorPosition > 0) target.remove(target.cursorPosition - 1, target.cursorPosition) }
        else if (k === "Done") done()
        else { target.insert(target.cursorPosition, shift ? k.toUpperCase() : k); shift = false }
    }
    focus: true
    onVisibleChanged: if (visible) { r = 1; c = 0; system.log("osk open") }
    Keys.onLeftPressed: c = Math.max(0, Math.min(c, rows[r].length - 1) - 1)
    Keys.onRightPressed: c = Math.min(rows[r].length - 1, c + 1)
    Keys.onUpPressed: { r = Math.max(0, r - 1); c = Math.min(c, rows[r].length - 1) }
    Keys.onDownPressed: { r = Math.min(rows.length - 1, r + 1); c = Math.min(c, rows[r].length - 1) }
    Keys.onReturnPressed: press()
    Keys.onEnterPressed: press()
    Keys.onSpacePressed: press()
    Keys.onEscapePressed: done()
    Keys.onBackPressed: done()
    Column {
        anchors.centerIn: parent; spacing: 8
        Repeater { model: kb.rows.length
            Row { spacing: 8; anchors.horizontalCenter: parent.horizontalCenter
                property int ri: index
                Repeater { model: kb.rows[parent.ri]
                    Rectangle {
                        property bool cur: kb.r === parent.ri && Math.min(kb.c, kb.rows[parent.ri].length - 1) === index
                        width: modelData.length > 1 ? 200 : 78; height: 52; radius: 8
                        color: cur ? "#ffffff" : (modelData === "Shift" && kb.shift ? "#3b5bdb" : "#2a2f38")
                        Text { anchors.centerIn: parent; text: modelData.length > 1 ? modelData : (kb.shift ? modelData.toUpperCase() : modelData); color: parent.cur ? "#111" : "#eee"; font.pixelSize: 24 }
                    }
                }
            }
        }
    }
}
