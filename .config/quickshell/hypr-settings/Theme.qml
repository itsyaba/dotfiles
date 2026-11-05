// Caelestia colour scheme and fonts, reloaded whenever the scheme changes
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme

    property var c: ({})
    function col(name: string, fallback: string): color {
        return theme.c[name] ? "#" + theme.c[name] : fallback;
    }

    readonly property color surface: col("surface", "#141218")
    readonly property color surfaceContainerLow: col("surfaceContainerLow", "#1d1b20")
    readonly property color surfaceContainer: col("surfaceContainer", "#211f26")
    readonly property color surfaceContainerHigh: col("surfaceContainerHigh", "#2b2930")
    readonly property color surfaceContainerHighest: col("surfaceContainerHighest", "#36343b")
    readonly property color text: col("onSurface", "#e6e0e9")
    readonly property color subtext: col("onSurfaceVariant", "#cac4d0")
    readonly property color outline: col("outline", "#938f99")
    readonly property color outlineVariant: col("outlineVariant", "#49454f")
    readonly property color primary: col("primary", "#d0bcff")
    readonly property color primaryText: col("onPrimary", "#381e72")
    readonly property color secondaryContainer: col("secondaryContainer", "#4a4458")
    readonly property color secondaryText: col("onSecondaryContainer", "#e8def8")

    readonly property string font: "Rubik"
    readonly property string iconFont: "Material Symbols Rounded"

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: theme.c = JSON.parse(text()).colours
    }
}
