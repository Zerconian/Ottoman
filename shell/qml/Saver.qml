import QtQuick
import QtQuick.Window
// Screensaver: a dim clock that drifts a little so nothing burns in. swayidle starts and kills it.
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    color: "#000000"
    title: "Ottoman screensaver"
    Item {
        id: clock
        width: 420; height: 160
        x: (win.width - width) / 2; y: (win.height - height) / 2
        Text { id: t; anchors.centerIn: parent; color: "#3a3f47"; font.pixelSize: 120; font.weight: Font.Light; text: Qt.formatTime(new Date(), "HH:mm") }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: t.text = Qt.formatTime(new Date(), "HH:mm") }
        Timer { interval: 60000; running: true; repeat: true; onTriggered: { clock.x = 80 + Math.random() * (win.width - clock.width - 160); clock.y = 80 + Math.random() * (win.height - clock.height - 160) } }
        Behavior on x { NumberAnimation { duration: 2000 } }
        Behavior on y { NumberAnimation { duration: 2000 } }
    }
}
