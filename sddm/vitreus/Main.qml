import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// Vitreus's lock screen as a login screen: the picture stays sharp, then the clock, the date, the avatar and the password bar rise in one after another.
// A typed character is a random shape (the password itself is never drawn). Sleep, restart and power off are held for a second, since none of them can be undone.
Item {
    id: root
    width: 1920
    height: 1080

    readonly property real u: Math.max(0.55, height / 1080)
    readonly property color accent: config.accent ? config.accent : "#9ed6bd"
    readonly property color ink: config.ink ? config.ink : "#f5f7f5"
    readonly property color glass: config.glass ? config.glass : "#1b2127"
    readonly property bool clock24: config.clock24 === "true"
    readonly property string fontName: groteskBold.status === FontLoader.Ready ? groteskBold.name : "Space Grotesk"
    readonly property color barColor: Qt.rgba(Math.min(1, glass.r * 1.9 + 0.06), Math.min(1, glass.g * 2.1 + 0.08), Math.min(1, glass.b * 2.6 + 0.12), 0.58)
    readonly property color edge: Qt.rgba(ink.r, ink.g, ink.b, 0.34)

    property int stage: 0                 // 1 the picture blurs, 2 the clock, 3 the date and the avatar, 4 the bar, 5 the corners
    property string errorText: ""
    property bool leaving: false
    property date now: new Date()
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    readonly property string userName: userList.currentItem ? userList.currentItem.uname : userModel.lastUser
    readonly property string realName: userList.currentItem && userList.currentItem.real !== "" ? userList.currentItem.real : userName
    readonly property string sessionName: sessionList.currentItem ? sessionList.currentItem.sname : ""

    // The shapes a typed character can be (the lock screen's own set, 24 x 24).
    readonly property var shapePaths: [
        "M 12,2 A 10,10 0 1 0 12,22 A 10,10 0 1 0 12,2 Z",
        "M 12,2 L 22,12 L 12,22 L 2,12 Z",
        "M 5,3 L 19,3 C 20.1,3 21,3.9 21,5 L 21,19 C 21,20.1 20.1,21 19,21 L 5,21 C 3.9,21 3,20.1 3,19 L 3,5 C 3,3.9 3.9,3 5,3 Z",
        "M 12,2.5 L 22.5,20.5 L 1.5,20.5 Z",
        "M 1.5,3.5 L 22.5,3.5 L 12,21.5 Z",
        "M 12,2 L 21.5,7.5 L 21.5,16.5 L 12,22 L 2.5,16.5 L 2.5,7.5 Z",
        "M 12,2 L 22,9.2 L 18.2,21 L 5.8,21 L 2,9.2 Z",
        "M 7.5,2 L 16.5,2 L 22,7.5 L 22,16.5 L 16.5,22 L 7.5,22 L 2,16.5 L 2,7.5 Z",
        "M 12,2 Q 12,12 2,12 Q 12,12 12,22 Q 12,12 22,12 Q 12,12 12,2 Z",
        "M 12,2 L 15,8.5 L 22,9.3 L 17,14 L 18.5,21 L 12,17.5 L 5.5,21 L 7,14 L 2,9.3 L 9,8.5 Z",
        "M 9,3 L 15,3 L 15,9 L 21,9 L 21,15 L 15,15 L 15,21 L 9,21 L 9,15 L 3,15 L 3,9 L 9,9 Z",
        "M 12,21.35 L 10.55,20.03 C 5.4,15.36 2,12.28 2,8.5 C 2,5.42 4.42,3 7.5,3 C 9.24,3 10.91,3.81 12,5.09 C 13.09,3.81 14.76,3 16.5,3 C 19.58,3 22,5.42 22,8.5 C 22,12.28 18.6,15.36 13.45,20.03 Z",
        "M 12,2 A 10,10 0 0 0 22,14 A 10,10 0 1 1 12,2 Z",
        "M 12,2 L 20.5,5.5 L 20.5,11.5 C 20.5,16.8 16.9,21.2 12,22 C 7.1,21.2 3.5,16.8 3.5,11.5 L 3.5,5.5 Z"
    ]
    readonly property var shapeColors: [accent, Qt.lighter(accent, 1.35), ink, Qt.darker(accent, 1.25), "#ffd88a", "#ff9ec4"]

    // Its three weights, as their own files (a greeter runs as another user, which does not see yours; the variable file shows only its lightest)
    FontLoader { source: "fonts/SpaceGrotesk-Regular.ttf" }
    FontLoader { source: "fonts/SpaceGrotesk-Medium.ttf" }
    FontLoader { id: groteskBold; source: "fonts/SpaceGrotesk-Bold.ttf" }

    // Who and how: SDDM's models, read through a list nobody sees.
    ListView {
        id: userList
        visible: false
        width: 100; height: 100      // a list with no size makes no delegates, and currentItem stays null
        model: userModel
        currentIndex: root.userIndex
        delegate: Item { property string uname: model.name; property string real: model.realName }
    }
    ListView {
        id: sessionList
        visible: false
        width: 100; height: 100      // a list with no size makes no delegates, and currentItem stays null
        model: sessionModel
        currentIndex: root.sessionIndex
        delegate: Item { property string sname: model.name }
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }
    Timer {
        interval: 420
        running: true
        repeat: true
        onTriggered: { root.stage += 1; if (root.stage >= 5) stop() }
    }

    // ── the picture ──
    Image {
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle { anchors.fill: parent; color: "#0b0e11"; opacity: root.stage >= 1 ? 0.30 : 0.10; Behavior on opacity { NumberAnimation { duration: 1600 } } }
    Rectangle { anchors.fill: parent; color: "black"; opacity: root.leaving ? 1 : 0; Behavior on opacity { NumberAnimation { duration: 500 } } z: 50 }

    MouseArea { anchors.fill: parent; onClicked: pw.forceActiveFocus() }

    // ── the clock and the date ──
    Item {
        id: clockBox
        width: clockText.width + 70 * root.u
        height: clockText.height
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.142 + (root.stage >= 2 ? 0 : 26 * root.u)
        opacity: root.stage >= 2 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 800; easing.type: Easing.OutBack } }
        Text {
            id: clockText
            x: 0
            text: root.clock24 ? Qt.formatTime(root.now, "HH:mm") : ((root.now.getHours() % 12 === 0 ? 12 : root.now.getHours() % 12) + ":" + Qt.formatTime(root.now, "mm"))
            color: root.ink
            opacity: 0.88
            font.family: root.fontName
            font.pixelSize: 230 * root.u
            font.weight: Font.Bold
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#66000000"; shadowBlur: 0.9; shadowVerticalOffset: 8 }
        }
        Rectangle {
            visible: !root.clock24
            x: clockText.width + 10 * root.u
            y: clockText.height * 0.34
            width: ampm.width + 22 * root.u
            height: 30 * root.u
            radius: height / 2
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)
            border.color: root.edge
            border.width: 1
            Text {
                id: ampm
                anchors.centerIn: parent
                text: root.now.getHours() < 12 ? "AM" : "PM"
                color: root.ink
                font.family: root.fontName
                font.pixelSize: 14 * root.u
                font.weight: Font.Medium
            }
        }
    }
    Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockBox.bottom
        anchors.topMargin: -22 * root.u
        text: Qt.formatDate(root.now, "dddd, MMMM d, yyyy")
        color: root.ink
        opacity: root.stage >= 3 ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
        font.family: root.fontName
        font.pixelSize: 25 * root.u
        font.weight: Font.Medium
    }

    // ── who ──
    Item {
        id: who
        width: 170 * root.u
        height: 170 * root.u
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dateText.bottom
        anchors.topMargin: 34 * root.u
        opacity: root.stage >= 3 ? 1 : 0
        scale: root.stage >= 3 ? 1 : 0.8
        Behavior on opacity { NumberAnimation { duration: 600 } }
        Behavior on scale { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.barColor
            border.color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.5)
            border.width: 2.5
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#55000000"; shadowBlur: 0.8; shadowVerticalOffset: 8 }
        }
        Item {
            id: faceMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            Rectangle { anchors.fill: parent; anchors.margins: 3; radius: width / 2 }
        }
        Image {
            id: face
            anchors.fill: parent
            // your face, from the folder install.sh made for it (it is the one that changes when you change your picture); the copy in the theme is the one it was installed with
            property bool bundled: false
            source: bundled ? config.avatar : "file://" + (config.shared ? config.shared : "/usr/local/share/vitreus-greeter") + "/avatar.png"
            onStatusChanged: if (status === Image.Error && !bundled) bundled = true
            cache: false
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: status === Image.Ready
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: faceMask }
        }
        // no picture: a person, drawn
        Shape {
            visible: face.status !== Image.Ready
            anchors.centerIn: parent
            width: 24
            height: 24
            scale: 3.6 * root.u
            ShapePath {
                strokeColor: root.ink
                strokeWidth: 1.5
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 12,4 A 3.6,3.6 0 1 0 12,11.2 A 3.6,3.6 0 1 0 12,4 Z M 4.5,20.5 C 4.5,16.4 7.9,13.6 12,13.6 C 16.1,13.6 19.5,16.4 19.5,20.5" }
            }
        }
        MouseArea { anchors.fill: parent; enabled: userModel.count > 1; cursorShape: Qt.PointingHandCursor; onClicked: { root.userIndex = (root.userIndex + 1) % userModel.count; pw.forceActiveFocus() } }
    }
    Text {
        id: nameText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: who.bottom
        anchors.topMargin: 16 * root.u
        text: root.realName !== "" ? root.realName : qsTr("Welcome")
        color: root.ink
        opacity: root.stage >= 3 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
        font.family: root.fontName
        font.pixelSize: 24 * root.u
        font.weight: Font.Bold
    }
    Text {
        id: subText
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: nameText.bottom
        anchors.topMargin: 2 * root.u
        text: root.errorText !== "" ? root.errorText : (root.realName !== "" ? qsTr("Welcome back") : "")
        color: root.errorText !== "" ? "#ff9ec4" : root.ink
        opacity: root.stage >= 3 ? (root.errorText !== "" ? 1 : 0.7) : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        font.family: root.fontName
        font.pixelSize: 14 * root.u
        font.weight: Font.Medium
    }

    // ── the password bar ──
    Rectangle {
        id: bar
        width: 470 * root.u
        height: 56 * root.u
        radius: height / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: subText.bottom
        anchors.topMargin: 22 * root.u
        color: root.barColor
        border.color: pw.activeFocus ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.7) : root.edge
        border.width: 1.5
        opacity: root.stage >= 4 ? 1 : 0
        property real shake: 0
        transform: Translate { x: bar.shake }
        Behavior on opacity { NumberAnimation { duration: 600 } }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#44000000"; shadowBlur: 0.7; shadowVerticalOffset: 6 }

        SequentialAnimation {
            id: shakeAnim
            NumberAnimation { target: bar; property: "shake"; to: -14 * root.u; duration: 60 }
            NumberAnimation { target: bar; property: "shake"; to: 12 * root.u; duration: 90 }
            NumberAnimation { target: bar; property: "shake"; to: -8 * root.u; duration: 80 }
            NumberAnimation { target: bar; property: "shake"; to: 0; duration: 80 }
        }

        // the lock
        Shape {
            x: 20 * root.u
            anchors.verticalCenter: parent.verticalCenter
            width: 24
            height: 24
            scale: 0.9 * root.u
            ShapePath {
                strokeColor: root.ink
                strokeWidth: 1.7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 6,10.5 L 18,10.5 Q 19.5,10.5 19.5,12 L 19.5,19.5 Q 19.5,21 18,21 L 6,21 Q 4.5,21 4.5,19.5 L 4.5,12 Q 4.5,10.5 6,10.5 Z M 8,10.5 L 8,7.5 A 4,4 0 0 1 16,7.5 L 16,10.5" }
            }
        }
        Text {
            visible: pw.text.length === 0
            x: 60 * root.u
            anchors.verticalCenter: parent.verticalCenter
            text: root.leaving ? qsTr("Signing in…") : qsTr("Enter password…")
            color: root.ink
            opacity: 0.55
            font.family: root.fontName
            font.pixelSize: 17 * root.u
            font.weight: Font.Medium
        }
        // what was typed: a shape for each character
        ListModel { id: picks }
        Row {
            x: 56 * root.u
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6 * root.u
            Repeater {
                model: picks
                delegate: Shape {
                    width: 24
                    height: 24
                    scale: 0.82 * root.u
                    ShapePath {
                        fillColor: root.shapeColors[col]
                        strokeColor: "transparent"
                        fillRule: ShapePath.OddEvenFill
                        PathSvg { path: root.shapePaths[kind] }
                    }
                }
            }
        }
        // go
        Rectangle {
            id: go
            width: 42 * root.u
            height: width
            radius: width / 2
            anchors.right: parent.right
            anchors.rightMargin: 7 * root.u
            anchors.verticalCenter: parent.verticalCenter
            color: pw.text.length > 0 ? root.accent : Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)
            Behavior on color { ColorAnimation { duration: 200 } }
            Shape {
                anchors.centerIn: parent
                width: 24
                height: 24
                scale: 0.9 * root.u
                ShapePath {
                    strokeColor: pw.text.length > 0 ? "#10161a" : root.ink
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathSvg { path: "M 5,12 L 19,12 M 13,6 L 19,12 L 13,18" }
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tryLogin() }
        }
    }

    // The field that takes the keys: nothing of it is seen.
    TextInput {
        id: pw
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.Password
        focus: true
        enabled: !root.leaving
        onAccepted: root.tryLogin()
        onTextChanged: {
            root.errorText = ""
            while (picks.count < text.length) picks.append({ kind: Math.floor(Math.random() * root.shapePaths.length), col: Math.floor(Math.random() * root.shapeColors.length) })
            while (picks.count > text.length) picks.remove(picks.count - 1)
        }
        Keys.onEscapePressed: text = ""
    }
    function tryLogin() {
        if (pw.text.length === 0 || root.leaving) return
        sddm.login(root.userName, pw.text, root.sessionIndex)
    }
    Connections {
        target: sddm
        function onLoginFailed() {
            root.errorText = qsTr("Wrong password")
            pw.text = ""
            shakeAnim.restart()
            pw.forceActiveFocus()
        }
        function onLoginSucceeded() { root.leaving = true }
    }
    Component.onCompleted: pw.forceActiveFocus()

    // ── the corners: the machine, and how to log in ──
    Rectangle {
        x: 34 * root.u
        y: 30 * root.u
        height: 34 * root.u
        width: hostText.width + 34 * root.u
        radius: height / 2
        color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.45)
        border.color: root.edge
        opacity: root.stage >= 5 ? 1 : 0
        visible: sddm.hostName !== ""
        Behavior on opacity { NumberAnimation { duration: 600 } }
        Text { id: hostText; anchors.centerIn: parent; text: sddm.hostName; color: root.ink; opacity: 0.85; font.family: root.fontName; font.pixelSize: 14 * root.u; font.weight: Font.Medium }
    }
    Rectangle {
        id: sessionChip
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: bar.bottom
        anchors.topMargin: 20 * root.u
        height: 52 * root.u
        width: sessionLabel.width + 64 * root.u
        radius: height / 2
        color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, sessionMouse.containsMouse ? 0.7 : 0.45)
        border.color: root.edge
        opacity: root.stage >= 4 ? 1 : 0
        visible: sessionModel.count > 0 && root.sessionName !== ""
        Behavior on opacity { NumberAnimation { duration: 600 } }
        Text { id: sessionLabel; anchors.centerIn: parent; text: root.sessionName; color: root.ink; opacity: 0.9; font.family: root.fontName; font.pixelSize: 21 * root.u; font.weight: Font.Medium }
        MouseArea {
            id: sessionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.sessionIndex = (root.sessionIndex + 1) % sessionModel.count; pw.forceActiveFocus() }
        }
    }

    // ── sleep, restart, power off: each held for a second ──
    Rectangle {
        id: power
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40 * root.u
        height: 58 * root.u
        width: powerRow.width + 28 * root.u
        radius: height / 2
        color: Qt.rgba(root.glass.r, root.glass.g, root.glass.b, 0.5)
        border.color: root.edge
        opacity: root.stage >= 5 ? 1 : 0
        visible: powerRow.width > 0
        Behavior on opacity { NumberAnimation { duration: 600 } }
        property string holding: ""
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 10 * root.u
            text: power.holding
            color: root.ink
            opacity: power.holding !== "" ? 0.8 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }
            font.family: root.fontName
            font.pixelSize: 14 * root.u
            font.weight: Font.Medium
        }
        Row {
            id: powerRow
            anchors.centerIn: parent
            spacing: 14 * root.u
            Repeater {
                model: [
                    { label: qsTr("Hold to sleep"), ok: sddm.canSuspend, path: "M 12,2 A 10,10 0 0 0 22,14 A 10,10 0 1 1 12,2 Z", act: 0, fill: true },
                    { label: qsTr("Hold to restart"), ok: sddm.canReboot, path: "M 19.5,12 A 7.5,7.5 0 1 1 16,5.6 M 16.5,2.5 L 16.5,6.5 L 12.5,6.5", act: 1, fill: false },
                    { label: qsTr("Hold to power off"), ok: sddm.canPowerOff, path: "M 12,3 L 12,12 M 6.4,6.4 A 8,8 0 1 0 17.6,6.4", act: 2, fill: false }
                ]
                delegate: Item {
                    id: pb
                    visible: modelData.ok
                    width: visible ? 42 * root.u : 0
                    height: 42 * root.u
                    property real prog: 0
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, pbMouse.containsMouse ? 0.2 : 0.1) }
                    Shape {
                        anchors.centerIn: parent
                        width: 24
                        height: 24
                        scale: 0.8 * root.u
                        ShapePath {
                            strokeColor: modelData.fill ? "transparent" : root.ink
                            strokeWidth: 1.9
                            fillColor: modelData.fill ? root.ink : "transparent"
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: modelData.path }
                        }
                    }
                    Shape {
                        anchors.fill: parent
                        visible: pb.prog > 0
                        ShapePath {
                            strokeColor: root.accent
                            strokeWidth: 3
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            PathAngleArc { centerX: pb.width / 2; centerY: pb.height / 2; radiusX: pb.width / 2 - 1.5; radiusY: pb.height / 2 - 1.5; startAngle: -90; sweepAngle: 360 * pb.prog }
                        }
                    }
                    NumberAnimation {
                        id: fill
                        target: pb
                        property: "prog"
                        from: 0
                        to: 1
                        duration: 1000
                        onFinished: {
                            power.holding = ""
                            pb.prog = 0
                            if (modelData.act === 0) sddm.suspend()
                            else if (modelData.act === 1) sddm.reboot()
                            else sddm.powerOff()
                        }
                    }
                    MouseArea {
                        id: pbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPressed: { power.holding = modelData.label; fill.start() }
                        onReleased: { fill.stop(); pb.prog = 0; power.holding = "" }
                    }
                }
            }
        }
    }
}
