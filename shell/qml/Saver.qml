import QtQuick
import QtQuick.Window
// Screensaver (DESIGN.md 4.10 #7; animated wallpaper added 2026-11-03 for zerc's friend). Modes, picked in
// Settings > Display and passed by saver.sh as --mode=: clock (dim drifting clock), aurora (slow soft colour
// fields, small clock), stars (drifting starfield, small clock). Everything dim and in motion: no burn-in,
// no shaders (Qt 6 needs precompiled .qsb; these are plain composited items, cheap on a Haswell GPU).
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    color: "#000000"
    title: "Ottoman screensaver"
    property string mode: typeof saverMode !== "undefined" ? saverMode : "clock"
    function now() { return Qt.formatTime(new Date(), "HH:mm") }
    // Any key or click ends it (a preview from Settings has no swayidle resume to kill it). On RELEASE, not press:
    // quitting on the press handed the same key's release to the launcher, which closed the Settings page (2026-11-03).
    Item { anchors.fill: parent; focus: true; Keys.onReleased: function(e) { if (!e.isAutoRepeat) Qt.quit() }; MouseArea { anchors.fill: parent; onReleased: Qt.quit() } }

    // ---- aurora: five large radial blobs drifting and breathing over black
    Item {
        id: aurora; anchors.fill: parent; visible: win.mode === "aurora"
        Repeater {
            model: visible ? 5 : 0
            Item {
                id: blob
                property var palette: ["#1d4ed8", "#0e7490", "#6d28d9", "#0f766e", "#1e3a8a"]
                property real size: Math.max(win.width, win.height) * (0.55 + 0.2 * (index % 3))
                width: size; height: size
                opacity: 0.42
                Canvas {
                    anchors.fill: parent
                    onPaint: { const c = getContext("2d"); const r = width / 2; const g = c.createRadialGradient(r, r, 0, r, r, r)
                        g.addColorStop(0, blob.palette[index]); g.addColorStop(0.55, Qt.rgba(0, 0, 0, 0.35)); g.addColorStop(1, "transparent")
                        c.fillStyle = g; c.fillRect(0, 0, width, height) }
                }
                SequentialAnimation on x { loops: Animation.Infinite
                    NumberAnimation { from: -blob.size * 0.4 + index * 90; to: win.width - blob.size * 0.6 - index * 70; duration: 90000 + index * 23000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: -blob.size * 0.4 + index * 90; duration: 90000 + index * 23000; easing.type: Easing.InOutSine } }
                SequentialAnimation on y { loops: Animation.Infinite
                    NumberAnimation { from: win.height - blob.size * 0.7 - index * 60; to: -blob.size * 0.4 + index * 50; duration: 110000 - index * 9000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: win.height - blob.size * 0.7 - index * 60; duration: 110000 - index * 9000; easing.type: Easing.InOutSine } }
                SequentialAnimation on scale { loops: Animation.Infinite
                    NumberAnimation { from: 0.85; to: 1.15; duration: 40000 + index * 7000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.85; duration: 40000 + index * 7000; easing.type: Easing.InOutSine } }
            }
        }
    }

    // ---- stars: 140 small dim points, each twinkling on its own clock, the whole field drifting
    Item {
        id: stars; anchors.fill: parent; visible: win.mode === "stars"
        Item {
            id: field; width: win.width * 1.3; height: win.height * 1.3
            SequentialAnimation on x { loops: Animation.Infinite
                NumberAnimation { from: 0; to: -win.width * 0.3; duration: 240000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0; duration: 240000; easing.type: Easing.InOutSine } }
            SequentialAnimation on y { loops: Animation.Infinite
                NumberAnimation { from: -win.height * 0.3; to: 0; duration: 300000; easing.type: Easing.InOutSine }
                NumberAnimation { to: -win.height * 0.3; duration: 300000; easing.type: Easing.InOutSine } }
            Repeater {
                model: stars.visible ? 140 : 0
                Rectangle {
                    property real seed: Math.random()
                    x: Math.random() * field.width; y: Math.random() * field.height
                    width: 1 + Math.round(seed * 2); height: width; radius: width / 2
                    color: seed > 0.8 ? "#b8c4ff" : "#8a8f98"
                    SequentialAnimation on opacity { loops: Animation.Infinite
                        PauseAnimation { duration: seed * 6000 }
                        NumberAnimation { from: 0.15; to: 0.25 + seed * 0.45; duration: 1500 + seed * 3000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.15; duration: 1500 + seed * 3000; easing.type: Easing.InOutSine } }
                }
            }
        }
    }

    // ---- clock: big and centred in clock mode; small in a corner for the scenes. Drifts every minute.
    Item {
        id: clock
        property bool big: win.mode === "clock"
        width: big ? 420 : 170; height: big ? 160 : 60
        x: (win.width - width) / 2; y: big ? (win.height - height) / 2 : win.height - height - 60
        Text { id: t; anchors.centerIn: parent; color: clock.big ? "#3a3f47" : "#596069"; font.pixelSize: clock.big ? 120 : 44; font.weight: Font.Light; text: win.now() }
        Timer { interval: 1000; running: true; repeat: true; onTriggered: t.text = win.now() }
        Timer { interval: 60000; running: true; repeat: true; onTriggered: { clock.x = 80 + Math.random() * (win.width - clock.width - 160); clock.y = 80 + Math.random() * (win.height - clock.height - 160) } }
        Behavior on x { NumberAnimation { duration: 2000 } }
        Behavior on y { NumberAnimation { duration: 2000 } }
    }
}
