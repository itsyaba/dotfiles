import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Shared drawer for the Pebble panels (Studio, Usage). Like Pebble Shell's drawers it
// grows out of the frame: the card sits in the frame's top-left inner corner (respecting
// Caelestia's reserved frame/bar space, so it is always flush with whatever is there) and
// unrolls downward. Content goes in `body` (contentWidth wide). Esc or a click away closes it.
PanelWindow {
    id: root

    property bool open: false
    property real progress: 0
    property string name: "drawer"
    property int contentWidth: 360
    property int pad: 22
    default property alias content: body.data
    readonly property int cardRadius: 21
    readonly property real fullHeight: Math.min(body.childrenRect.height + pad * 2, (screen?.height ?? 1080) - 60)

    function toggle(): void { open = !open; }

    visible: open || progress > 0
    color: "transparent"
    anchors.left: true
    anchors.top: true
    // Normal + zone 0: placed inside the space Caelestia reserves for its frame and bar.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: contentWidth + pad * 2
    implicitHeight: fullHeight
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pebble-" + name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: reveal }

    HyprlandFocusGrab {
        windows: [root]
        active: root.open && root.progress > 0.5
        onCleared: root.open = false
    }

    onOpenChanged: open ? (closeAnim.stop(), openAnim.restart()) : (openAnim.stop(), closeAnim.restart())
    NumberAnimation { id: openAnim; target: root; property: "progress"; to: 1; duration: 300; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macEase }
    NumberAnimation { id: closeAnim; target: root; property: "progress"; to: 0; duration: 180; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macExit }

    // The card unrolls from the frame's top edge: its surface grows with `progress`
    // while the content stays put underneath and is uncovered by the clip.
    Item {
        id: reveal
        width: parent.width
        height: Math.max(1, root.fullHeight * root.progress)
        clip: true
        focus: root.open
        Keys.onEscapePressed: root.open = false

        // Square top-left (it joins the frame corner), rounded elsewhere.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                readonly property real r: Math.min(root.cardRadius, reveal.height / 2)
                fillColor: Theme.frost
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: reveal.width - root.cardRadius; y: 0 }
                PathArc { x: reveal.width; y: root.cardRadius; radiusX: root.cardRadius; radiusY: root.cardRadius }
                PathLine { x: reveal.width; y: Math.max(root.cardRadius, reveal.height - root.cardRadius) }
                PathArc { x: reveal.width - root.cardRadius; y: reveal.height; radiusX: root.cardRadius; radiusY: root.cardRadius }
                PathLine { x: root.cardRadius; y: reveal.height }
                PathArc { x: 0; y: Math.max(0, reveal.height - root.cardRadius); radiusX: root.cardRadius; radiusY: root.cardRadius }
                PathLine { x: 0; y: 0 }
            }
        }

        Flickable {
            x: root.pad
            y: root.pad - 10 * (1 - root.progress)
            width: root.contentWidth
            height: root.fullHeight - root.pad * 2
            opacity: Math.max(0, (root.progress - 0.25) / 0.75)
            contentHeight: body.childrenRect.height
            clip: true
            interactive: contentHeight > height
            Item {
                id: body
                width: root.contentWidth
            }
        }
    }
}
