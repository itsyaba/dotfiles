pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Studio, after denon.studio / denon.glass / denon.recess (omarchy-dotfiles): one drawer for the look.
//  Glass  shell opacity (Caelestia shell.json) + Hyprland blur, applied live while dragging.
//  Depth  recessed / raised / off windows, tuned separately for light and dark themes.
// Everything is saved to ~/.config/caelestia/studio.json, which hypr-look.lua and hypr-recess.lua read.
Drawer {
    id: root
    name: "studio"
    contentWidth: 340

    readonly property string home: Quickshell.env("HOME")
    readonly property var defaults: ({
        blur: { size: 6, passes: 2, vibrancy: 0.08, brightness: 1.15, contrast: 0.9, noise: 0 },
        depth: {
            style: "recessed",
            dark: { win_depth: 0.896, win_soft: 14, win_light: 0.3, win_lip: 0.64 },
            light: { win_depth: 0.45, win_soft: 10, win_light: 0.3, win_lip: 0.5 }
        }
    })
    property var st: JSON.parse(JSON.stringify(defaults))
    property real shellOpacity: Theme.base
    readonly property string mode: Theme.light ? "light" : "dark"

    function get(path: string): var {
        return path.split(".").reduce((o, k) => o?.[k], st);
    }
    function set(path: string, value: var): void {
        const keys = path.split("."), next = JSON.parse(JSON.stringify(st));
        let o = next;
        for (const k of keys.slice(0, -1)) { if (o[k] === undefined) o[k] = {}; o = o[k]; }
        o[keys[keys.length - 1]] = value;
        st = next;
    }
    function save(reload: bool): void {
        studioFile.setText(JSON.stringify(st, null, 2) + "\n");
        if (reload) reloadSoon.restart();
    }
    function liveBlur(key: string, value: real): void {
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { blur = { ${key} = ${value} } } })`]);
    }
    function saveShellOpacity(v: real): void {
        shellFile.reload();
        let cfg = {};
        try { cfg = JSON.parse(shellFile.text()); } catch (e) { return; } // never clobber a file we can't read
        if (!cfg.appearance) cfg.appearance = {};
        if (!cfg.appearance.transparency) cfg.appearance.transparency = {};
        cfg.appearance.transparency.enabled = true;
        cfg.appearance.transparency.base = Math.round(v * 100) / 100;
        shellFile.setText(JSON.stringify(cfg, null, 2) + "\n");
    }
    function resetAll(): void {
        st = JSON.parse(JSON.stringify(defaults));
        save(true);
        saveShellOpacity(0.55);
    }

    Timer { id: reloadSoon; interval: 120; onTriggered: Quickshell.execDetached(["hyprctl", "reload"]) }

    FileView {
        id: studioFile
        path: root.home + "/.config/caelestia/studio.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                const merged = JSON.parse(JSON.stringify(root.defaults));
                Object.assign(merged.blur, s.blur ?? {});
                merged.depth.style = s.depth?.style ?? merged.depth.style;
                Object.assign(merged.depth.dark, s.depth?.dark ?? {});
                Object.assign(merged.depth.light, s.depth?.light ?? {});
                root.st = merged;
            } catch (e) {}
        }
    }
    FileView {
        id: shellFile
        path: root.home + "/.config/caelestia/shell.json"
        blockLoading: true
    }
    Connections {
        target: Theme
        function onBaseChanged(): void { root.shellOpacity = Theme.base; }
    }

    // ------------------------------------------------------------------ parts
    component Heading: Text {
        color: Theme.muted
        font.family: Theme.family
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 1.6
        topPadding: 6
    }

    component Slider: Item {
        id: slider
        property string label: ""
        property real from: 0
        property real to: 1
        property real value: 0
        property int decimals: 2
        property string suffix: ""
        signal moved(real v)
        signal committed(real v)
        width: parent?.width ?? 300
        implicitHeight: 46
        readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
        function valueAt(x: real): real {
            const f = Math.max(0, Math.min(1, (x - knob.width / 2) / (track.width - knob.width)));
            const v = from + f * (to - from);
            const p = Math.pow(10, decimals);
            return Math.round(v * p) / p;
        }

        Text {
            text: slider.label
            color: Theme.fg
            font.family: Theme.family
            font.pixelSize: 13
        }
        Text {
            anchors.right: parent.right
            text: slider.value.toFixed(slider.decimals) + slider.suffix
            color: Theme.muted
            font.family: Theme.family
            font.pixelSize: 12
        }
        Item {
            id: track
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 22
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2
                color: Theme.hair
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: knob.x + knob.width / 2; height: 4; radius: 2
                color: Theme.accent
            }
            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                x: slider.frac * (track.width - width)
                width: drag.pressed ? 18 : 16; height: width; radius: width / 2
                color: Theme.fg
                Behavior on width { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: drag
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => slider.moved(slider.valueAt(mouse.x))
                onPositionChanged: mouse => { if (pressed) slider.moved(slider.valueAt(mouse.x)); }
                onReleased: mouse => slider.committed(slider.valueAt(mouse.x))
                onWheel: wheel => {
                    const step = (slider.to - slider.from) / 20 * (wheel.angleDelta.y > 0 ? 1 : -1);
                    const p = Math.pow(10, slider.decimals);
                    const v = Math.round(Math.max(slider.from, Math.min(slider.to, slider.value + step)) * p) / p;
                    slider.moved(v);
                    slider.committed(v);
                }
            }
        }
    }

    component Segmented: Row {
        id: seg
        property var options: []
        property string current: ""
        signal picked(string v)
        spacing: 6
        Repeater {
            model: seg.options
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: seg.current === modelData.value
                width: (seg.width - seg.spacing * (seg.options.length - 1)) / seg.options.length
                height: 34
                radius: 17
                color: on ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, chipMouse.containsMouse ? 0.16 : 0.10)
                Behavior on color { ColorAnimation { duration: 160 } }
                Text {
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.on ? Theme.onAccent : Theme.fg
                    font.family: Theme.family
                    font.pixelSize: 13
                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(chip.modelData.value)
                }
            }
        }
    }

    // ------------------------------------------------------------------ layout
    Column {
        width: parent.width
        spacing: 10

        Row {
            spacing: 10
            Text { text: "palette"; font.family: Theme.icons; font.pixelSize: 22; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Studio"; color: Theme.fg; font.family: Theme.family; font.pixelSize: 22; font.weight: Font.Light }
        }

        Heading { text: "GLASS" }
        Slider {
            label: "Shell opacity"; from: 0.3; to: 0.95; value: root.shellOpacity
            onMoved: v => root.shellOpacity = v
            onCommitted: v => root.saveShellOpacity(v)
        }
        Repeater {
            model: [
                { key: "size", label: "Blur size", from: 2, to: 14, decimals: 0 },
                { key: "passes", label: "Blur passes", from: 1, to: 4, decimals: 0 },
                { key: "vibrancy", label: "Vibrancy", from: 0, to: 0.4, decimals: 2 },
                { key: "brightness", label: "Brightness", from: 0.8, to: 1.4, decimals: 2 },
                { key: "noise", label: "Grain", from: 0, to: 0.08, decimals: 3 }
            ]
            delegate: Slider {
                required property var modelData
                label: modelData.label; from: modelData.from; to: modelData.to; decimals: modelData.decimals
                value: root.get("blur." + modelData.key) ?? 0
                onMoved: v => { root.set("blur." + modelData.key, v); root.liveBlur(modelData.key, v); }
                onCommitted: v => { root.set("blur." + modelData.key, v); root.save(false); }
            }
        }

        Heading { text: "DEPTH · " + root.mode.toUpperCase() + " THEME" }
        Segmented {
            width: parent.width
            options: [{ label: "Recessed", value: "recessed" }, { label: "Raised", value: "raised" }, { label: "Off", value: "off" }]
            current: root.get("depth.style") ?? "recessed"
            onPicked: v => { root.set("depth.style", v); root.save(true); }
        }
        Repeater {
            model: [
                { key: "win_depth", label: "Depth", from: 0, to: 1, decimals: 2 },
                { key: "win_soft", label: "Softness", from: 2, to: 24, decimals: 0 },
                { key: "win_light", label: "Light from above", from: 0, to: 1, decimals: 2 },
                { key: "win_lip", label: "Lip", from: 0, to: 1, decimals: 2 }
            ]
            delegate: Slider {
                required property var modelData
                readonly property string path: "depth." + root.mode + "." + modelData.key
                enabled: (root.get("depth.style") ?? "recessed") !== "off"
                opacity: enabled ? 1 : 0.4
                label: modelData.label; from: modelData.from; to: modelData.to; decimals: modelData.decimals
                value: root.get(path) ?? 0
                onMoved: v => root.set(path, v)
                onCommitted: v => { root.set(path, v); root.save(true); }
            }
        }

        Item { width: 1; height: 4 }
        Text {
            text: "Reset to defaults"
            color: Theme.accent
            font.family: Theme.family
            font.pixelSize: 12
            font.weight: Font.DemiBold
            MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: root.resetAll() }
        }
    }
}
