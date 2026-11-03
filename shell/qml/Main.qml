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
        rowIndex = i; r[i].forceActiveFocus()
    }
    Component.onCompleted: system.applySavedModes()
    Text { text: "OTTOMAN"; color: "#8a8f98"; font.pixelSize: 28; font.letterSpacing: 6; anchors { left: parent.left; top: parent.top; margins: 48 } }
    // Header bar: Up from the APPS row reaches Settings.
    Rectangle { id: settingsBtn; width: 170; height: 48; radius: 8; anchors { right: parent.right; top: parent.top; rightMargin: 48; topMargin: 118 }
        color: activeFocus ? "#ffffff" : "#1c2026"; border.width: 1; border.color: "#3a3f47"
        Text { anchors.centerIn: parent; text: "Settings"; font.pixelSize: 20; color: parent.activeFocus ? "#111" : "#d8dadf" }
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
                    delegate: Tile { label: model.name; tint: model.color; installed: model.installed; running: model.running; current: ListView.isCurrentItem
                        MouseArea { anchors.fill: parent; onClicked: { appsRow.currentIndex = index; apps.launch(index) } } }
                    Keys.onReturnPressed: apps.launch(currentIndex)
                    Keys.onEnterPressed: apps.launch(currentIndex)
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
    Connections { target: jellyfin; function onChanged() { if (!signIn.visible) Qt.callLater(function() { focusRow(rowIndex) }) } }
    ListModel { id: signInModel; ListElement { name: "Sign in to Jellyfin"; subtitle: "Enter to connect your server"; imageUrl: ""; progress: 0 } }
    SignIn { id: signIn; visible: false; onVisibleChanged: if (!visible) focusRow(rowIndex); onDone: visible = false }
    Settings { id: settings; visible: false; onDone: { visible = false; focusRow(rowIndex) } }
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
