pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// GNOME-style bottom panel
Rectangle {
    id: bar

    required property var app

    readonly property real sideWidth: Math.max(modes.implicitWidth, toggles.implicitWidth)

    width: content.implicitWidth + 32
    height: 88
    radius: 28
    color: "#242424"
    border.color: Qt.rgba(1, 1, 1, 0.08)

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.8
        shadowVerticalOffset: 4
        shadowColor: Qt.rgba(0, 0, 0, 0.5)
    }

    // Swallow clicks so they don't reach the selection area
    MouseArea {
        anchors.fill: parent
    }

    Row {
        id: content

        anchors.centerIn: parent

        Item {
            width: bar.sideWidth
            height: 64

            Row {
                id: modes

                anchors.left: parent.left
                spacing: 4

                ModeButton {
                    icon: "crop_free"
                    label: "Selection"
                    checked: bar.app.mode === "area"
                    onClicked: bar.app.mode = "area"
                }
                ModeButton {
                    icon: "desktop_windows"
                    label: "Screen"
                    checked: bar.app.mode === "screen"
                    onClicked: bar.app.mode = "screen"
                }
                ModeButton {
                    icon: "select_window"
                    label: "Window"
                    checked: bar.app.mode === "window"
                    onClicked: bar.app.mode = "window"
                }
            }
        }

        Item {
            width: 112
            height: 64

            // Shutter
            Rectangle {
                anchors.centerIn: parent
                width: 64
                height: 64
                radius: 32
                color: "transparent"
                border.color: "white"
                border.width: 4

                Rectangle {
                    anchors.centerIn: parent
                    width: shutter.pressed ? 44 : 48
                    height: width
                    radius: width / 2
                    color: bar.app.video ? (shutter.containsMouse ? "#f03a42" : "#e01b24") : (shutter.containsMouse ? "#ffffff" : "#dedede")

                    Behavior on width {
                        NumberAnimation {
                            duration: 80
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }
                }

                MouseArea {
                    id: shutter

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.app.capture()
                }
            }
        }

        Item {
            width: bar.sideWidth
            height: 64

            Row {
                id: toggles

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // Screenshot / screencast switch
                Rectangle {
                    width: 92
                    height: 40
                    radius: 20
                    color: Qt.rgba(1, 1, 1, 0.08)

                    Row {
                        anchors.centerIn: parent

                        IconToggle {
                            icon: "photo_camera"
                            checked: !bar.app.video
                            onClicked: bar.app.video = false
                        }
                        IconToggle {
                            icon: "videocam"
                            checked: bar.app.video
                            onClicked: bar.app.video = true
                        }
                    }
                }

                IconToggle {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "arrow_selector_tool"
                    checked: bar.app.pointer
                    onClicked: bar.app.pointer = !bar.app.pointer
                }
            }
        }
    }

    // Close button on the corner
    Rectangle {
        x: bar.width - width / 2 - 14
        y: -height / 2 + 14
        width: 32
        height: 32
        radius: 16
        color: closeArea.containsMouse ? "#4a4a4a" : "#383838"
        border.color: Qt.rgba(1, 1, 1, 0.08)

        Text {
            anchors.centerIn: parent
            text: "close"
            color: "white"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 18
        }

        MouseArea {
            id: closeArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bar.app.close()
        }
    }

    component ModeButton: Rectangle {
        id: mb

        required property string icon
        required property string label
        property bool checked
        signal clicked

        width: 80
        height: 64
        radius: 14
        color: checked ? Qt.rgba(1, 1, 1, mbArea.containsMouse ? 0.2 : 0.15) : Qt.rgba(1, 1, 1, mbArea.containsMouse ? 0.08 : 0)

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mb.icon
                color: "white"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 24
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: mb.label
                color: "white"
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: mbArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: mb.clicked()
        }
    }

    component IconToggle: Rectangle {
        id: it

        required property string icon
        property bool checked
        signal clicked

        width: 46
        height: 40
        radius: 20
        color: checked ? Qt.rgba(1, 1, 1, itArea.containsMouse ? 0.25 : 0.2) : Qt.rgba(1, 1, 1, itArea.containsMouse ? 0.08 : 0)

        Text {
            anchors.centerIn: parent
            text: it.icon
            color: "white"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
        }

        MouseArea {
            id: itArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: it.clicked()
        }
    }
}
