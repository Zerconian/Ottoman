import QtQuick
import QtQuick.Window
Window {
    id: win
    visible: true
    visibility: Window.FullScreen
    color: "#101214"
    title: "Ottoman"
    property int rowIndex: 0            // 0 apps, 1 continue, 2 latest
    function rows() { return [appsRow, contRow, latestRow] }
    function focusRow(i) {
        const r = rows(); const dir = i >= rowIndex ? 1 : -1
        i = Math.max(0, Math.min(r.length - 1, i))
        while (i > 0 && i < r.length && r[i].count === 0) i += dir      // skip empty rows in the direction of travel
        if (i < 0 || i >= r.length || (i > 0 && r[i].count === 0)) return
        if (r[i].currentIndex < 0) r[i].currentIndex = 0      // a model swap leaves no current item: Enter would act on nothing
        rowIndex = i; r[i].forceActiveFocus(); system.log("home row " + i + " item " + r[i].currentIndex)
    }
    Component.onCompleted: system.applySavedModes()
    // Home (sway brings the shell forward, so the window becomes active): close overlays and go to the top of
    // the home screen, like Android TV. First run stays until done.
    function goHome() { if (firstRun.visible) return; settings.visible = false; addApp.visible = false; tileMenu.visible = false; signIn.visible = false; osk.visible = false; page.contentY = 0; appsRow.currentIndex = 0; focusRow(0); system.log("home reset") }
    onActiveChanged: if (active) goHome()
    Connections { target: control; function onHomeRequested() { goHome() } }     // home.sh over D-Bus, works when already active
    Text { text: "OTTOMAN"; color: "#8a8f98"; font.pixelSize: 28; font.letterSpacing: 6; anchors { left: parent.left; top: parent.top; margins: 48 } }
    // Header bar: Up from the APPS row reaches Settings.
    Rectangle { id: settingsBtn; width: 170; height: 48; radius: 8; anchors { right: parent.right; top: parent.top; rightMargin: 48; topMargin: 118 }
        color: activeFocus ? "#ffffff" : "#1c2026"; border.width: 1; border.color: "#3a3f47"
        Text { anchors.centerIn: parent; text: "Settings"; font.pixelSize: 20; color: parent.activeFocus ? "#111" : "#d8dadf" }
        onActiveFocusChanged: if (activeFocus) system.log("home settings button")
        Keys.onDownPressed: focusRow(0)
        Keys.onReturnPressed: { settings.visible = true; settings.open() }
        Keys.onEnterPressed: { settings.visible = true; settings.open() }
        MouseArea { anchors.fill: parent; onClicked: { settings.visible = true; settings.open() } }
    }
    Text {
        id: clock; color: "#d8dadf"; font.pixelSize: 30
        anchors { right: parent.right; top: parent.top; margins: 48 }
        Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm") }
    }
    Text { text: jellyfin.state === "connected" ? "Jellyfin: " + jellyfin.userName : ""; color: "#6b7079"; font.pixelSize: 18; anchors { right: settingsBtn.left; top: parent.top; rightMargin: 24; topMargin: 130 } }

    Flickable {
        id: page
        anchors { fill: parent; topMargin: 130 }
        contentHeight: content.height + 100
        clip: true
        Behavior on contentY { NumberAnimation { duration: 150 } }
        Column {
            id: content; x: 48; spacing: 36
            // APPS
            Column { spacing: 14
                Text { text: "APPS"; color: "#8a8f98"; font.pixelSize: 22; font.letterSpacing: 3 }
                ListView {
                    id: appsRow; width: win.width - 48; height: 190; orientation: ListView.Horizontal; spacing: 24; clip: true
                    model: apps; focus: true; highlightMoveDuration: 0; preferredHighlightBegin: 0; preferredHighlightEnd: width - 60; highlightRangeMode: ListView.ApplyRange
                    delegate: Tile { label: model.name; tint: model.color; installed: model.installed; running: model.running; isAdd: model.isAdd; current: ListView.isCurrentItem
                        MouseArea { anchors.fill: parent; onClicked: { appsRow.currentIndex = index; appsRow.activate() } } }
                    function activate() { if (apps.isAddRow(currentIndex)) addApp.open(); else apps.launch(currentIndex) }
                    function openMenu(held) { if (!apps.isAddRow(currentIndex)) tileMenu.open(currentIndex, apps.data(apps.index(currentIndex, 0), 257), held) }
                    // Enter: tap launches, hold (600 ms) opens the tile menu; Menu/F2 opens it directly.
                    Timer { id: hold; interval: 600; onTriggered: { appsRow.held = true; appsRow.openMenu(true) } }
                    property bool held: false
                    property bool pressedHere: false     // an Enter released here after an overlay consumed the press must not fire
                    Keys.onPressed: function(e) {
                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) { held = false; pressedHere = true; hold.start(); e.accepted = true }
                        else if (e.key === Qt.Key_F2 || e.key === Qt.Key_Menu) { openMenu(false); e.accepted = true }
                    }
                    Keys.onReleased: function(e) {
                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !e.isAutoRepeat) { hold.stop(); if (pressedHere && !held) activate(); pressedHere = false; e.accepted = true }
                    }
                    Keys.onDownPressed: focusRow(1)
                    Keys.onUpPressed: settingsBtn.forceActiveFocus()
                }
            }
            // CONTINUE WATCHING
            Column { spacing: 14
                Row { spacing: 16
                    Text { text: "CONTINUE WATCHING"; color: "#8a8f98"; font.pixelSize: 22; font.letterSpacing: 3 }
                    Text { text: jellyfin.state === "connected" ? "" : "Jellyfin not signed in"; color: "#555a63"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                }
                ListView {
                    id: contRow; width: win.width - 48; height: 225; orientation: ListView.Horizontal; spacing: 24; clip: true
                    model: jellyfin.state === "connected" ? jellyfin.continueModel : signInModel
                    highlightMoveDuration: 0; preferredHighlightBegin: 0; preferredHighlightEnd: width - 60; highlightRangeMode: ListView.ApplyRange
                    delegate: Card { title: model.name; subtitle: model.subtitle; imageUrl: model.imageUrl; progress: model.progress; current: ListView.isCurrentItem
                        MouseArea { anchors.fill: parent; onClicked: { contRow.currentIndex = index; contRow.activate() } } }
                    function activate() { if (currentIndex < 0) currentIndex = 0; if (jellyfin.state === "connected") jellyfin.play(jellyfin.continueModel.idAt(currentIndex)); else signIn.visible = true }
                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: activate()
                    Keys.onUpPressed: focusRow(0)
                    Keys.onDownPressed: focusRow(2)
                }
            }
            // RECENTLY ADDED
            Column { spacing: 14; visible: jellyfin.state === "connected"
                Text { text: "RECENTLY ADDED"; color: "#8a8f98"; font.pixelSize: 22; font.letterSpacing: 3 }
                ListView {
                    id: latestRow; width: win.width - 48; height: 225; orientation: ListView.Horizontal; spacing: 24; clip: true
                    model: jellyfin.latestModel
                    highlightMoveDuration: 0; preferredHighlightBegin: 0; preferredHighlightEnd: width - 60; highlightRangeMode: ListView.ApplyRange
                    delegate: Card { title: model.name; subtitle: model.subtitle; imageUrl: model.imageUrl; progress: model.progress; current: ListView.isCurrentItem
                        MouseArea { anchors.fill: parent; onClicked: { latestRow.currentIndex = index; jellyfin.play(jellyfin.latestModel.idAt(index)) } } }
                    Keys.onReturnPressed: jellyfin.play(jellyfin.latestModel.idAt(currentIndex))
                    Keys.onEnterPressed: jellyfin.play(jellyfin.latestModel.idAt(currentIndex))
                    Keys.onUpPressed: focusRow(1)
                }
            }
        }
        // keep the focused row in view
        onHeightChanged: contentY = 0
    }
    onRowIndexChanged: page.contentY = rowIndex === 0 ? 0 : rowIndex === 1 ? 240 : 520
    // Row models swap when Jellyfin connects or signs out, which drops keyboard focus: re-focus the current row.
    // Re-focus the home rows after a Jellyfin state change, but never steal focus from an open overlay
    // (signing out from Settings > About used to drop focus behind the Settings page).
    Connections { target: jellyfin; function onChanged() { if (!signIn.visible && !settings.visible && !osk.visible && !firstRun.visible && !tileMenu.visible && !addApp.visible) Qt.callLater(function() { focusRow(rowIndex) }) } }
    ListModel { id: signInModel; ListElement { name: "Sign in to Jellyfin"; subtitle: "Enter to connect your server"; imageUrl: ""; progress: 0 } }
    SignIn { id: signIn; visible: false; z: 50; onVisibleChanged: { if (!visible) focusRow(rowIndex); system.log("signin " + (visible ? "open" : "close")) } onDone: visible = false }
    Settings { id: settings; visible: false; z: 50; onDone: { visible = false; focusRow(rowIndex) } }
    TileMenu { id: tileMenu; visible: false; z: 55; onDone: focusRow(0) }
    AddApp { id: addApp; visible: false; z: 55; onDone: focusRow(0) }
    FirstRun { id: firstRun; visible: !system.firstRunDone(); z: 60; onDone: { visible = false; focusRow(0); system.log("firstrun done") } }
    // On-screen keyboard overlay, shared by every Field.
    Item { id: osk; anchors.fill: parent; visible: false; z: 100
        property Item target
        property Item returnTo
        function openFor(input) { target = input; returnTo = input; visible = true; kb.forceActiveFocus() }
        Rectangle { anchors.fill: parent; color: "#99000000" }
        Keyboard { id: kb; target: osk.target; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 40 }
            onDone: { osk.visible = false; if (osk.returnTo) osk.returnTo.forceActiveFocus() } }
    }
    Text {
        text: apps.installedCount === 0 ? "Installing Jellyfin from Flathub, this takes about a minute on first boot." : "Enter opens. Home returns here, apps keep running (green dot)."
        color: "#6b7079"; font.pixelSize: 18
        anchors { left: parent.left; bottom: parent.bottom; margins: 48 }
    }
}
