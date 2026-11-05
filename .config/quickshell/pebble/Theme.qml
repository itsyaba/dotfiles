pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours and surface opacity, live from Caelestia (scheme.json + shell.json),
// so the Pebble panels re-theme along with the rest of the shell.
Singleton {
    id: root

    property var c: ({})
    property string mode: "dark"
    property real base: 0.55

    readonly property bool light: mode === "light"
    function col(name: string, fallback: string): color {
        return root.c[name] ? "#" + root.c[name] : fallback;
    }

    readonly property color surface: col("surface", "#101418")
    readonly property color fg: col("onSurface", "#e0e3e8")
    readonly property color muted: Qt.rgba(fg.r, fg.g, fg.b, 0.6)
    readonly property color hair: Qt.rgba(fg.r, fg.g, fg.b, 0.16)
    readonly property color accent: col("primary", "#9ccaff")
    readonly property color onAccent: col("onPrimary", "#003258")
    readonly property color warm: Qt.tint(col("tertiary", "#ffb870"), Qt.rgba(1, 0.75, 0.3, 0.45))
    readonly property color urgent: col("error", "#ff6b6b")
    // Same alpha Caelestia uses for its own frame (it drops 0.1 in light mode).
    readonly property color frost: Qt.rgba(surface.r, surface.g, surface.b, Math.max(0.35, base - (light ? 0.1 : 0)))
    readonly property color rim: Qt.rgba(1, 1, 1, light ? 0.5 : 0.1)

    // Caelestia's own UI font (bundled with the shell, not installed system-wide).
    readonly property string family: gsf.status === FontLoader.Ready ? gsf.name : "Rubik"
    FontLoader {
        id: gsf
        source: "file:///etc/xdg/quickshell/caelestia/assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf"
    }
    readonly property string icons: "Material Symbols Rounded"

    // macOS-style curves, matching hypr-look.lua
    readonly property list<real> macEase: [0.25, 1, 0.5, 1, 1, 1]
    readonly property list<real> macExit: [0.3, 0, 0.8, 0.15, 1, 1]

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const s = JSON.parse(text());
            root.c = s.colours ?? {};
            root.mode = s.mode ?? "dark";
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/caelestia/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = JSON.parse(text()).appearance?.transparency;
                root.base = t?.enabled === false ? 1 : (t?.base ?? 0.85);
            } catch (e) {}
        }
    }
}
