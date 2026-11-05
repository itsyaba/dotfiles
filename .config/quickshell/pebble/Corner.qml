pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

// Control corner, after denon.corner (omarchy-dotfiles). A frosted quarter circle fans
// out of the bottom-left corner: brightness, volume and mic as concentric arcs you drag
// (or scroll) along, everyday toggles on an inner arc, the battery in the corner.
// Left click toggles; right click opens the matching Caelestia panel. Esc or click away closes.
PanelWindow {
    id: root

    property bool open: false
    property real progress: 0
    readonly property real fanR: 440
    readonly property real reveal: fanR * progress

    signal studioRequested()
    signal usageRequested()

    function toggle(): void { open = !open; }

    visible: open || progress > 0
    color: "transparent"
    anchors.left: true
    anchors.bottom: true
    implicitWidth: fanR
    implicitHeight: fanR
    // Normal + zone 0: sits in the frame's inner corner (and beside the bar when it is shown),
    // so the fan grows out of the frame rather than over it.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pebble-corner"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // Only the quarter circle takes input; the rest of the square passes clicks through.
    mask: Region {
        x: -root.reveal
        y: root.fanR - root.reveal
        width: root.reveal * 2
        height: root.reveal * 2
        shape: RegionShape.Ellipse
    }

    HyprlandFocusGrab {
        windows: [root]
        active: root.open && root.progress > 0.5
        onCleared: root.open = false
    }

    onOpenChanged: {
        if (open) {
            closeAnim.stop();
            openAnim.restart();
            refresh();
        } else {
            openAnim.stop();
            closeAnim.restart();
            commitBrightness();
        }
    }
    NumberAnimation { id: openAnim; target: root; property: "progress"; to: 1; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macEase }
    NumberAnimation { id: closeAnim; target: root; property: "progress"; to: 0; duration: 170; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.macExit }

    // ------------------------------------------------------------------ state
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    PwObjectTracker { objects: [root.sink, root.source].filter(x => !!x) }
    readonly property real volume: sink?.audio ? Math.min(1, sink.audio.volume) : 0
    readonly property bool volumeMuted: sink?.audio?.muted ?? false
    readonly property real mic: source?.audio ? Math.min(1, source.audio.volume) : 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    property real brightness: 0.5
    property real brightnessDraft: -1

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property real batteryLevel: {
        const p = battery?.percentage ?? 0;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool charging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false
    readonly property string timeLeft: {
        const s = battery ? (charging ? battery.timeToFull : battery.timeToEmpty) : 0;
        if (!s || s <= 0) return "";
        const h = Math.floor(s / 3600), m = Math.round((s % 3600) / 60);
        return (h > 0 ? h + " h " : "") + m + " m";
    }

    property bool wifiOn: true
    property bool btOn: true
    property bool dndOn: false
    property bool awakeOn: false
    property bool gameOn: false
    property bool recording: false

    function refresh(): void { if (!stateRead.running) stateRead.running = true; }
    function run(cmd: list<string>): void { Quickshell.execDetached(cmd); refreshSoon.restart(); }
    function caelestia(args: list<string>): void { run(["qs", "-c", "caelestia", "ipc", "call", ...args]); }
    function panel(drawer: string): void { root.open = false; caelestia(["drawers", "toggle", drawer]); }

    Timer { interval: 4000; running: root.open; repeat: true; onTriggered: root.refresh() }
    Timer { id: refreshSoon; interval: 450; onTriggered: root.refresh() }

    Process {
        id: stateRead
        command: ["sh", "-c",
            "ipc() { qs -c caelestia ipc call \"$@\" 2>/dev/null; };" +
            "echo wifi=$(nmcli radio wifi 2>/dev/null);" +
            "echo bt=$(bluetoothctl show 2>/dev/null | sed -n 's/.*Powered: //p' | head -1);" +
            "echo dnd=$(ipc notifs isDndEnabled);" +
            "echo awake=$(ipc idleInhibitor isEnabled);" +
            "echo game=$(ipc gameMode isEnabled);" +
            "echo rec=$(pidof gpu-screen-recorder >/dev/null && echo true || echo false);" +
            "echo bright=$(ipc brightness get)"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of String(text).split("\n")) {
                    const i = line.indexOf("="), k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k === "wifi") root.wifiOn = v === "enabled";
                    else if (k === "bt") root.btOn = v === "yes";
                    else if (k === "dnd") root.dndOn = v === "true";
                    else if (k === "awake") root.awakeOn = v === "true";
                    else if (k === "game") root.gameOn = v === "true";
                    else if (k === "rec") root.recording = v === "true";
                    else if (k === "bright" && v !== "" && root.brightnessDraft < 0 && !isNaN(Number(v)))
                        root.brightness = Math.max(0, Math.min(1, Number(v)));
                }
            }
        }
    }

    function setBrightness(f: real): void {
        brightness = Math.max(0.01, Math.min(1, f));
        caelestia(["brightness", "set", brightness.toFixed(2)]);
    }
    function commitBrightness(): void {
        if (brightnessDraft >= 0) { setBrightness(brightnessDraft); brightnessDraft = -1; }
    }
    function setVolume(f: real): void {
        if (sink?.audio) { sink.audio.muted = false; sink.audio.volume = Math.max(0, Math.min(1, f)); }
    }
    function setMic(f: real): void {
        if (source?.audio) source.audio.volume = Math.max(0, Math.min(1, f));
    }

    // ------------------------------------------------------------------ parts
    component Ring: Shape {
        id: ring
        property real radius: 300
        property real value: 0
        property color tint: Theme.accent
        property real weight: 5
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.hair; strokeWidth: 2; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 0; centerY: root.fanR; radiusX: ring.radius; radiusY: ring.radius; startAngle: -90; sweepAngle: 90 }
        }
        ShapePath {
            strokeColor: ring.tint; strokeWidth: ring.weight; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: 0; centerY: root.fanR; radiusX: ring.radius; radiusY: ring.radius; startAngle: -90; sweepAngle: Math.max(0.5, 90 * ring.value) }
        }
    }

    component Knob: Rectangle {
        property real ringRadius: 300
        property real value: 0
        readonly property real theta: value * Math.PI / 2
        width: 16; height: width; radius: width / 2
        color: Theme.fg
        x: ringRadius * Math.sin(theta) - width / 2
        y: root.fanR - ringRadius * Math.cos(theta) - height / 2
    }

    component Icon: Text {
        font.family: Theme.icons
        font.pixelSize: 18
        color: Theme.fg
    }

    component Level: Item {
        id: level
        property string glyph: ""
        property real value: 0
        property color tint: Theme.fg
        property var action: null
        implicitWidth: levelRow.implicitWidth
        implicitHeight: levelRow.implicitHeight
        Row {
            id: levelRow
            spacing: 6
            Icon { anchors.verticalCenter: parent.verticalCenter; text: level.glyph; color: level.tint; font.pixelSize: 17 }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(level.value * 100)
                color: level.tint
                font.family: Theme.family
                font.pixelSize: 22
                font.weight: Font.ExtraLight
            }
        }
        MouseArea {
            anchors.fill: parent
            enabled: !!level.action
            cursorShape: Qt.PointingHandCursor
            onClicked: level.action()
        }
    }

    component Toggle: Rectangle {
        id: toggle
        property string glyph: ""
        property bool on: false
        property string tip: ""
        property real angle: 0
        signal flip()
        signal more()
        readonly property real ringR: 262
        width: 46; height: width; radius: width / 2
        x: ringR * Math.sin(angle * Math.PI / 180) - width / 2
        y: root.fanR - ringR * Math.cos(angle * Math.PI / 180) - height / 2
        color: on ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, toggleMouse.containsMouse ? 0.16 : 0.10)
        border.width: on ? 0 : 1
        border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.14)
        scale: toggleMouse.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }
        Icon {
            anchors.centerIn: parent
            text: toggle.glyph
            color: toggle.on ? Theme.onAccent : Theme.fg
        }
        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => mouse.button === Qt.RightButton ? toggle.more() : toggle.flip()
        }
        // Tooltip: a small frosted pill outside the toggle ring.
        Rectangle {
            visible: toggleMouse.containsMouse && toggle.tip !== ""
            x: toggle.width + 8
            y: (toggle.height - height) / 2
            width: tipText.implicitWidth + 16
            height: tipText.implicitHeight + 8
            radius: height / 2
            color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)
            z: 10
            Text { id: tipText; anchors.centerIn: parent; text: toggle.tip; color: Theme.fg; font.family: Theme.family; font.pixelSize: 12 }
        }
    }

    // ------------------------------------------------------------------ the fan
    Item {
        id: fan
        width: root.fanR
        height: root.fanR
        focus: root.open
        Keys.onEscapePressed: root.open = false

        readonly property real rB: root.fanR - 40
        readonly property real rV: root.fanR - 90
        readonly property real rM: root.fanR - 140
        readonly property real brightnessShown: root.brightnessDraft >= 0 ? root.brightnessDraft : root.brightness

        // Frosted quarter-circle surface with a glass rim; grows from the corner.
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.frost
                strokeColor: "transparent"
                startX: 0; startY: root.fanR
                PathLine { x: 0; y: root.fanR - root.reveal }
                PathArc { x: root.reveal; y: root.fanR; radiusX: root.reveal; radiusY: root.reveal }
                PathLine { x: 0; y: root.fanR }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.rim
                strokeWidth: 1
                PathAngleArc { centerX: 0; centerY: root.fanR; radiusX: Math.max(0, root.reveal - 0.5); radiusY: Math.max(0, root.reveal - 0.5); startAngle: -90; sweepAngle: 90 }
            }
        }

        Item {
            id: content
            anchors.fill: parent
            opacity: Math.max(0, (root.progress - 0.35) / 0.65)
            scale: 0.94 + 0.06 * root.progress
            transformOrigin: Item.BottomLeft

            Ring { radius: fan.rB; value: fan.brightnessShown; tint: Theme.warm }
            Ring { radius: fan.rV; value: root.volume; tint: root.volumeMuted ? Theme.muted : Theme.accent }
            Ring { radius: fan.rM; value: root.mic; tint: root.micMuted ? Theme.muted : Theme.fg; weight: 3 }
            Knob { ringRadius: fan.rB; value: fan.brightnessShown }
            Knob { ringRadius: fan.rV; value: root.volume }
            Knob { ringRadius: fan.rM; value: root.mic; width: 12 }

            // Drag along an arc: the ring is picked by distance from the corner, the value by the angle.
            MouseArea {
                id: arcs
                anchors.fill: parent
                property string ring: ""
                function polar(mx: real, my: real): var {
                    const dx = mx, dy = root.fanR - my;
                    return { d: Math.sqrt(dx * dx + dy * dy), f: Math.max(0, Math.min(1, Math.atan2(dx, dy) / (Math.PI / 2))) };
                }
                function pick(d: real): string {
                    const tol = 22;
                    if (Math.abs(d - fan.rB) < tol) return "b";
                    if (Math.abs(d - fan.rV) < tol) return "v";
                    if (Math.abs(d - fan.rM) < tol) return "m";
                    return "";
                }
                function apply(p: var): void {
                    if (ring === "b") root.brightnessDraft = p.f;
                    else if (ring === "v") root.setVolume(p.f);
                    else if (ring === "m") root.setMic(p.f);
                }
                onPressed: mouse => {
                    const p = polar(mouse.x, mouse.y);
                    ring = pick(p.d);
                    if (!ring) { mouse.accepted = false; return; }
                    apply(p);
                }
                onPositionChanged: mouse => { if (pressed && ring) apply(polar(mouse.x, mouse.y)); }
                onReleased: { if (ring === "b") root.commitBrightness(); ring = ""; }
                onWheel: wheel => {
                    const r = pick(polar(wheel.x, wheel.y).d), step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
                    if (r === "b") root.setBrightness(root.brightness + step);
                    else if (r === "v") root.setVolume(root.volume + step);
                    else if (r === "m") root.setMic(root.mic + step);
                    else wheel.accepted = false;
                }
            }

            Level { x: 14; y: root.fanR - fan.rB + 10; glyph: "light_mode"; value: fan.brightnessShown; tint: Theme.warm }
            Level {
                x: 14; y: root.fanR - fan.rV + 10
                glyph: root.volumeMuted ? "volume_off" : "volume_up"; value: root.volume; tint: Theme.accent
                action: () => { if (root.sink?.audio) root.sink.audio.muted = !root.sink.audio.muted; }
            }
            Level {
                x: 14; y: root.fanR - fan.rM + 8
                glyph: root.micMuted ? "mic_off" : "mic"; value: root.mic; tint: Theme.fg
                action: () => { if (root.source?.audio) root.source.audio.muted = !root.source.audio.muted; }
            }

            Toggle {
                angle: 21; glyph: root.wifiOn ? "wifi" : "wifi_off"; on: root.wifiOn; tip: "Wi-Fi · right-click for networks"
                onFlip: { root.wifiOn = !root.wifiOn; root.run(["nmcli", "radio", "wifi", root.wifiOn ? "on" : "off"]); }
                onMore: root.panel("utilities")
            }
            Toggle {
                angle: 32; glyph: root.btOn ? "bluetooth" : "bluetooth_disabled"; on: root.btOn; tip: "Bluetooth · right-click for devices"
                onFlip: { root.btOn = !root.btOn; root.run(["bluetoothctl", "power", root.btOn ? "on" : "off"]); }
                onMore: root.panel("utilities")
            }
            Toggle {
                angle: 43; glyph: "do_not_disturb_on"; on: root.dndOn; tip: "Do not disturb · right-click for notifications"
                onFlip: { root.dndOn = !root.dndOn; root.caelestia(["notifs", "toggleDnd"]); }
                onMore: root.panel("sidebar")
            }
            Toggle {
                angle: 54; glyph: "coffee"; on: root.awakeOn; tip: "Keep awake"
                onFlip: { root.awakeOn = !root.awakeOn; root.caelestia(["idleInhibitor", "toggle"]); }
            }
            Toggle {
                angle: 65; glyph: "sports_esports"; on: root.gameOn; tip: "Game mode"
                onFlip: { root.gameOn = !root.gameOn; root.caelestia(["gameMode", "toggle"]); }
            }
            Toggle {
                angle: 76; glyph: root.recording ? "stop_circle" : "radio_button_checked"; on: root.recording
                tip: root.recording ? "Stop recording" : "Record screen · right-click for a region"
                onFlip: { root.open = false; root.run(["caelestia", "record"]); }
                onMore: { root.open = false; root.run(["caelestia", "record", "-r"]); }
            }

            // The battery, in the corner.
            Column {
                x: 22
                y: root.fanR - 150
                spacing: 2
                Text {
                    text: !root.hasBattery ? "On AC power" : (root.charging ? "Charging" : "On battery") + (root.timeLeft ? " · " + root.timeLeft : "")
                    color: Theme.muted; font.family: Theme.family; font.pixelSize: 12
                }
                Text {
                    visible: root.hasBattery
                    text: Math.round(root.batteryLevel * 100) + "<span style='font-size:22px'>%</span>"
                    textFormat: Text.StyledText
                    color: root.batteryLevel <= 0.2 && !root.charging ? Theme.urgent : Theme.fg
                    font.family: Theme.family
                    font.pixelSize: 56
                    font.weight: Font.ExtraLight
                    font.letterSpacing: -2
                }
                // Shortcuts: icon chips (hover for the name).
                Row {
                    topPadding: 8
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: "palette", label: "Studio", act: () => root.studioRequested() },
                            { icon: "data_usage", label: "Usage", act: () => root.usageRequested() },
                            { icon: "tune", label: "Settings", act: () => { root.open = false; root.caelestia(["nexus", "open"]); } },
                            { icon: "power_settings_new", label: "Power", act: () => root.panel("session") }
                        ]
                        delegate: Rectangle {
                            id: link
                            required property var modelData
                            width: 34; height: 34; radius: 17
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, linkMouse.containsMouse ? 0.16 : 0.08)
                            scale: linkMouse.pressed ? 0.92 : 1
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }
                            Icon { anchors.centerIn: parent; text: link.modelData.icon; color: Theme.accent; font.pixelSize: 17 }
                            MouseArea { id: linkMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: link.modelData.act() }
                            Rectangle {
                                visible: linkMouse.containsMouse
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -height - 6
                                width: linkTip.implicitWidth + 14; height: linkTip.implicitHeight + 6; radius: height / 2
                                color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.92)
                                Text { id: linkTip; anchors.centerIn: parent; text: link.modelData.label; color: Theme.fg; font.family: Theme.family; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }
        }
    }
}
