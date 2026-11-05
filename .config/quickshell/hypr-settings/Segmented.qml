// Row of pill buttons picking one of several values; choices are [[value, label], ...]
import QtQuick

Row {
    id: seg

    property var choices: []
    property var value
    signal picked(var value)

    spacing: 4

    Repeater {
        model: seg.choices

        Rectangle {
            id: pill

            required property var modelData
            readonly property bool selected: modelData[0] === seg.value

            width: content.implicitWidth + 32
            height: 36
            radius: selected ? 18 : 10
            color: selected ? Theme.secondaryContainer : area.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh

            Behavior on radius { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Row {
                id: content
                anchors.centerIn: parent
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pill.selected
                    text: "check"
                    font.pixelSize: 18
                    color: Theme.secondaryText
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: pill.modelData[1]
                    color: pill.selected ? Theme.secondaryText : Theme.subtext
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.picked(pill.modelData[0])
            }
        }
    }
}
