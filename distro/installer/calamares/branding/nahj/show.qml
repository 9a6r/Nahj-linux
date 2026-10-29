import QtQuick 2.15

Rectangle {
    color: "#1b2127"
    function onActivate() {}
    function onLeave() {}
    Image {
        anchors.fill: parent
        anchors.margins: 24
        source: "welcome.svg"
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
