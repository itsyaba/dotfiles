// Material 3 switch
import QtQuick

Item {
    id: sw

    property bool checked
    signal toggled(bool value)

    implicitWidth: 52
    implicitHeight: 32

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: sw.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: sw.checked ? 0 : 2
        border.color: Theme.outline

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Rectangle {
        property real size: area.pressed ? 28 : sw.checked ? 24 : 16
        readonly property real centre: sw.checked ? sw.width - 16 : 16

        x: centre - size / 2
        anchors.verticalCenter: parent.verticalCenter
        width: size
        height: size
        radius: size / 2
        color: sw.checked ? Theme.primaryText : Theme.outline

        Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on size { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        Icon {
            anchors.centerIn: parent
            text: "check"
            font.pixelSize: 16
            color: Theme.primary
            opacity: sw.checked ? 1 : 0

            Behavior on opacity { NumberAnimation { duration: 150 } }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled(!sw.checked)
    }
}
