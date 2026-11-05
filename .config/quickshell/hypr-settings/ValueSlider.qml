// Material 3 slider with the value shown on the right. Emits moved() while
// dragging; the owner feeds the new value back in.
import QtQuick

Item {
    id: s

    property real from: 0
    property real to: 1
    property real stepSize: 1
    property real value: 0
    property int decimals: 0
    property real factor: 1
    property string unit: ""
    signal moved(real value)

    implicitWidth: 300
    implicitHeight: 40

    readonly property real ratio: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function setFromX(x: real): void {
        const r = Math.max(0, Math.min(1, (x - handle.width / 2) / (track.width - handle.width)));
        const v = Number((Math.round((from + r * (to - from)) / stepSize) * stepSize).toFixed(4));
        if (v !== value)
            moved(v);
    }

    Item {
        id: track
        anchors.left: parent.left
        anchors.right: label.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 40

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, handle.x - 6)
            height: 16
            radius: 8
            topRightRadius: 3
            bottomRightRadius: 3
            color: Theme.primary
            visible: width > 0
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: handle.x + handle.width + 6
            width: Math.max(0, track.width - x)
            height: 16
            radius: 8
            topLeftRadius: 3
            bottomLeftRadius: 3
            color: Theme.secondaryContainer
            visible: width > 0
        }

        Rectangle {
            id: handle
            anchors.verticalCenter: parent.verticalCenter
            x: s.ratio * (track.width - width)
            width: area.pressed ? 2 : 4
            height: 36
            radius: 2
            color: Theme.primary
        }

        MouseArea {
            id: area
            anchors.fill: parent
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => s.setFromX(mouse.x)
            onPositionChanged: mouse => s.setFromX(mouse.x)
        }
    }

    Text {
        id: label
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 56
        horizontalAlignment: Text.AlignRight
        text: (s.value * s.factor).toFixed(s.decimals) + s.unit
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 14
        font.features: ({ tnum: 1 })
    }
}
