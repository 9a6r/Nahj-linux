import QtQuick

// A pane of glass over the picture (glass.frag): put it first inside the thing it is the glass of, filling it. `source` is a texture of the
// whole picture and `frosted` a blurred one (both ShaderEffectSources, shared by every pane), `backdrop` the item they are of, to know where
// the pane is over it. `ready` is false if the shader could not be loaded: the greeter keeps its plain translucent fill then.
Item {
    id: pane
    property Item backdrop: null
    property var source: null
    property var frosted: null
    property real radius: height / 2
    property real bevel: 18
    property real refraction: 16
    property real dispersion: 0.35
    property real frost: 0.85
    property real rimLight: 0.55
    property color tint: Qt.rgba(1, 1, 1, 0.05)
    readonly property bool ready: fx.status === ShaderEffect.Compiled && !!backdrop

    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: !!pane.backdrop             // (not `ready`: a shader effect is only compiled once it is drawn)
        property var backdrop: pane.source
        property var frosted: pane.frosted
        property rect bgRect: Qt.rect(0, 0, 1, 1)
        property size paneSize: Qt.size(width, height)
        property real radius: pane.radius
        property real bevel: pane.bevel
        property real refraction: pane.refraction
        property real dispersion: pane.dispersion
        property real frost: pane.frost
        property real rimLight: pane.rimLight
        property vector4d tint: Qt.vector4d(pane.tint.r * pane.tint.a, pane.tint.g * pane.tint.a, pane.tint.b * pane.tint.a, pane.tint.a)
        fragmentShader: "glass.frag.qsb"
    }

    // Where it is over the picture: followed on the frames the window draws anyway (the bar shakes and rises, which no binding sees).
    function sync() {
        const b = pane.backdrop;
        if (!b || b.width <= 0 || b.height <= 0) return;
        const p = fx.mapToItem(b, 0, 0), q = fx.mapToItem(b, fx.width, fx.height);
        const r = Qt.rect(p.x / b.width, p.y / b.height, (q.x - p.x) / b.width, (q.y - p.y) / b.height);
        const o = fx.bgRect;
        if (Math.abs(r.x - o.x) + Math.abs(r.y - o.y) + Math.abs(r.width - o.width) + Math.abs(r.height - o.height) > 1e-6) fx.bgRect = r;
    }
    Connections {
        target: pane.backdrop ? pane.Window.window : null
        function onAfterAnimating() { pane.sync() }
    }
    Component.onCompleted: Qt.callLater(sync)
    onWidthChanged: Qt.callLater(sync)
    onHeightChanged: Qt.callLater(sync)
}
