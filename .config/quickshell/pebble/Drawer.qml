import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Shared drawer for the Pebble panels (Studio, Usage): a frosted card that slides out
// of Caelestia's left frame, vertically centred. Put content inside; it is laid out in
// `body` (contentWidth wide, padded). Esc or a click elsewhere closes it.
PanelWindow {
    id: root

    property bool open: false
    property real progress: 0
    property string name: "drawer"
    property int contentWidth: 360
    property int pad: 22
    default property alias content: body.data
    readonly property int frame: 10
    readonly property int cardRadius: 21

    function toggle(): void { open = !open; }

    visible: open || progress > 0
    color: "transparent"
    anchors.left: true
    margins.left: frame
    implicitWidth: contentWidth + pad * 2 + 24
    implicitHeight: Math.min(body.childrenRect.height + pad * 2, (screen?.height ?? 1080) - 80)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pebble-" + name
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: card }

    HyprlandFocusGrab {
        windows: [root]
        active: root.open && root.progress > 0.5
        onCleared: root.open = false
    }

    onOpenChanged: open ? (closeAnim.stop(), openAnim.restart()) : (openAnim.stop(), closeAnim.restart())
    NumberAnimation { id: openAnim; target: root; property: "progress"; to: 1; duration: 280; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macEase }
    NumberAnimation { id: closeAnim; target: root; property: "progress"; to: 0; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macExit }

    Item {
        id: card
        width: root.contentWidth + root.pad * 2
        height: root.implicitHeight
        // Slides out from under the frame.
        x: -(1 - root.progress) * (width + 12)
        opacity: Math.min(1, root.progress * 2)
        focus: root.open
        Keys.onEscapePressed: root.open = false

        // Flush against the frame on the left (square corners there), rounded on the right,
        // so it reads as part of the frame rather than a floating window.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.frost
                strokeColor: Theme.rim
                strokeWidth: 1
                readonly property real r: root.cardRadius
                startX: 0; startY: 0
                PathLine { x: card.width - root.cardRadius; y: 0 }
                PathArc { x: card.width; y: root.cardRadius; radiusX: root.cardRadius; radiusY: root.cardRadius }
                PathLine { x: card.width; y: card.height - root.cardRadius }
                PathArc { x: card.width - root.cardRadius; y: card.height; radiusX: root.cardRadius; radiusY: root.cardRadius }
                PathLine { x: 0; y: card.height }
            }
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: root.pad
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
