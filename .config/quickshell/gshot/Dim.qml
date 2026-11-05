import QtQuick

// Darkens everything except `hole`
Item {
    id: dim

    property var hole: null
    readonly property color shade: Qt.rgba(0, 0, 0, 0.5)
    readonly property real hx: hole?.x ?? 0
    readonly property real hy: hole?.y ?? 0
    readonly property real hw: hole?.width ?? 0
    readonly property real hh: hole?.height ?? 0

    Rectangle {
        visible: !dim.hole
        anchors.fill: parent
        color: dim.shade
    }

    Rectangle {
        visible: !!dim.hole
        width: dim.width
        height: dim.hy
        color: dim.shade
    }

    Rectangle {
        visible: !!dim.hole
        y: dim.hy + dim.hh
        width: dim.width
        height: dim.height - y
        color: dim.shade
    }

    Rectangle {
        visible: !!dim.hole
        y: dim.hy
        width: dim.hx
        height: dim.hh
        color: dim.shade
    }

    Rectangle {
        visible: !!dim.hole
        x: dim.hx + dim.hw
        y: dim.hy
        width: dim.width - x
        height: dim.hh
        color: dim.shade
    }
}
