// Material Symbols icon, e.g. Icon { text: "palette" }
import QtQuick

Text {
    property bool fill: false

    color: Theme.subtext
    font.family: Theme.iconFont
    font.pixelSize: 22
    font.variableAxes: ({ FILL: fill ? 1 : 0 })
}
