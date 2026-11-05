// GNOME-style screenshot / screencast UI for Hyprland.
// Opened via `qs -c gshot ipc call gshot open` (see ~/.local/bin/gshot).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/gshot"
    readonly property string helper: Quickshell.shellDir + "/helper.sh"

    // UI state (persists between invocations, like GNOME)
    property bool shown: false
    property string mode: "area" // area | screen | window
    property bool video: false
    property bool pointer: false

    // Snapshot data
    property string stamp: ""
    property var monitors: []
    property var clients: []
    property string focusedName: ""

    // Selections
    property string selScreen: ""
    property rect sel: Qt.rect(0, 0, 0, 0)
    property string pickedScreen: ""
    property var pickedWindow: null

    // Screencast
    property bool recording: false
    property string recFile: ""
    property real recStart: 0
    property int recElapsed: 0

    function monitor(name: string): var {
        return monitors.find(m => m.name === name) ?? null;
    }

    function screenFor(name: string): var {
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    // Clients on visible workspaces, topmost first
    function visibleClients(): var {
        const ws = new Set();
        for (const m of monitors) {
            ws.add(m.activeWorkspace.id);
            if (m.specialWorkspace?.id)
                ws.add(m.specialWorkspace.id);
        }
        return clients.filter(c => c.mapped && !c.hidden && ws.has(c.workspace.id)).sort((a, b) => (b.workspace.id < 0) - (a.workspace.id < 0) || (b.pinned - a.pinned) || ((b.fullscreen !== 0) - (a.fullscreen !== 0)) || (b.floating - a.floating) || (a.focusHistoryID - b.focusHistoryID));
    }

    function windowAt(gx: real, gy: real): var {
        return visibleClients().find(c => gx >= c.at[0] && gy >= c.at[1] && gx < c.at[0] + c.size[0] && gy < c.at[1] + c.size[1]) ?? null;
    }

    // Capture target in screen-local logical coords: { screen, x, y, w, h }
    function target(): var {
        if (mode === "area") {
            return {
                screen: selScreen,
                x: sel.x,
                y: sel.y,
                w: sel.width,
                h: sel.height
            };
        }
        if (mode === "screen") {
            const s = screenFor(pickedScreen);
            return s ? {
                screen: pickedScreen,
                x: 0,
                y: 0,
                w: s.width,
                h: s.height
            } : null;
        }
        const c = pickedWindow;
        if (!c)
            return null;
        const m = monitors.find(m => m.id === c.monitor) ?? monitor(focusedName);
        const s = m ? screenFor(m.name) : null;
        if (!s)
            return null;
        const x = Math.max(0, c.at[0] - s.x), y = Math.max(0, c.at[1] - s.y);
        return {
            screen: s.name,
            x: x,
            y: y,
            w: Math.min(s.width, c.at[0] - s.x + c.size[0]) - x,
            h: Math.min(s.height, c.at[1] - s.y + c.size[1]) - y
        };
    }

    function open(): void {
        if (recording) {
            recorder.signal(2); // SIGINT finalises the file
            return;
        }
        if (shown || grabber.running)
            return;
        stamp = Date.now().toString();
        grabber.command = [helper, "grab", dir, stamp];
        grabber.running = true;
    }

    function close(): void {
        shown = false;
    }

    function capture(): void {
        const t = target();
        if (!t || t.w < 1 || t.h < 1)
            return;
        const m = monitor(t.screen);
        const s = screenFor(t.screen);
        if (!m || !s)
            return;

        if (!video) {
            const k = m.scale;
            const src = `${dir}/${stamp}-${t.screen}${pointer ? "-c" : ""}.png`;
            Quickshell.execDetached([helper, "shot", src, Math.round(t.x * k), Math.round(t.y * k), Math.round(t.w * k), Math.round(t.h * k)].map(String));
            flash.start();
            return;
        }

        const args = ["gpu-screen-recorder", "-f", "60", "-c", "mp4", "-cursor", pointer ? "yes" : "no"];
        if (mode === "screen")
            args.push("-w", t.screen);
        else
            args.push("-w", "region", "-region", `${Math.round(t.w)}x${Math.round(t.h)}+${Math.round(s.x + t.x)}+${Math.round(s.y + t.y)}`);
        recorder.pendingArgs = args;
        shown = false;
        castFile.running = true;
    }

    IpcHandler {
        target: "gshot"

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }

    Process {
        id: grabber

        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    console.warn("gshot: grab failed", e);
                    return;
                }
                root.monitors = data.monitors;
                root.clients = data.clients;
                root.focusedName = (data.monitors.find(m => m.focused) ?? data.monitors[0]).name;

                // GNOME keeps the previous selection; otherwise start centred
                const fs = root.screenFor(root.focusedName);
                if (!root.screenFor(root.selScreen) && fs) {
                    root.selScreen = fs.name;
                    root.sel = Qt.rect(fs.width / 4, fs.height / 4, fs.width / 2, fs.height / 2);
                }
                root.pickedScreen = root.focusedName;
                const active = root.visibleClients().find(c => c.focusHistoryID === 0);
                root.pickedWindow = active ?? root.visibleClients()[0] ?? null;
                root.shown = true;
            }
        }
    }

    // Screencast pipeline: get file name -> wait for overlay to fade -> record
    Process {
        id: castFile

        command: [root.helper, "castfile"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.recFile = text.trim();
                castDelay.start();
            }
        }
    }

    Timer {
        id: castDelay

        interval: 350
        onTriggered: {
            recorder.command = recorder.pendingArgs.concat(["-o", root.recFile]);
            recorder.running = true;
        }
    }

    Process {
        id: recorder

        property list<string> pendingArgs

        onStarted: {
            root.recording = true;
            root.recStart = Date.now();
            root.recElapsed = 0;
        }
        onExited: {
            root.recording = false;
            Quickshell.execDetached([root.helper, "castdone", root.recFile]);
        }
    }

    Timer {
        running: root.recording
        repeat: true
        interval: 500
        onTriggered: root.recElapsed = Math.floor((Date.now() - root.recStart) / 1000)
    }

    SequentialAnimation {
        id: flash

        property real opacity: 0

        NumberAnimation {
            target: flash
            property: "opacity"
            from: 0
            to: 1
            duration: 60
        }
        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0
            duration: 220
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.close()
        }
    }

    // --- Overlay, one per monitor ---
    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property ShellScreen modelData
            readonly property string name: modelData.name
            readonly property bool isFocused: name === root.focusedName

            // Hole (undimmed region) in local coords
            readonly property var hole: {
                if (root.mode === "area")
                    return root.selScreen === name ? root.sel : null;
                const t = root.target();
                return t && t.screen === name ? Qt.rect(t.x, t.y, t.w, t.h) : null;
            }

            screen: modelData
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gshot"
            WlrLayershell.keyboardFocus: isFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Escape:
                        root.close();
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                    case Qt.Key_Space:
                        root.capture();
                        break;
                    case Qt.Key_S:
                        root.mode = "area";
                        break;
                    case Qt.Key_C:
                        root.mode = "screen";
                        break;
                    case Qt.Key_W:
                        root.mode = "window";
                        break;
                    case Qt.Key_V:
                        root.video = !root.video;
                        break;
                    case Qt.Key_P:
                        root.pointer = !root.pointer;
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                // Frozen frames
                Image {
                    anchors.fill: parent
                    source: `file://${root.dir}/${root.stamp}-${win.name}.png`
                    visible: !root.pointer
                    cache: false
                    smooth: true
                }

                Image {
                    anchors.fill: parent
                    source: `file://${root.dir}/${root.stamp}-${win.name}-c.png`
                    visible: root.pointer
                    cache: false
                    smooth: true
                }

                Dim {
                    anchors.fill: parent
                    hole: win.hole
                }

                // Selection outline
                Rectangle {
                    visible: !!win.hole && root.mode !== "screen"
                    x: (win.hole?.x ?? 0) - 1
                    y: (win.hole?.y ?? 0) - 1
                    width: (win.hole?.width ?? 0) + 2
                    height: (win.hole?.height ?? 0) + 2
                    color: "transparent"
                    border.color: "white"
                    border.width: root.mode === "window" ? 3 : 1
                    radius: root.mode === "window" ? 4 : 0
                }

                Rectangle {
                    visible: root.mode === "screen" && !!win.hole
                    anchors.fill: parent
                    color: "transparent"
                    border.color: "white"
                    border.width: 4
                }

                // Shutter flash
                Rectangle {
                    visible: !!win.hole
                    x: win.hole?.x ?? 0
                    y: win.hole?.y ?? 0
                    width: win.hole?.width ?? 0
                    height: win.hole?.height ?? 0
                    color: "white"
                    opacity: flash.opacity
                }

                // Corner handles
                Repeater {
                    model: root.mode === "area" && root.selScreen === win.name ? 4 : 0

                    Rectangle {
                        required property int index
                        readonly property int size: 18

                        x: root.sel.x + (index % 2 ? root.sel.width : 0) - size / 2
                        y: root.sel.y + (index > 1 ? root.sel.height : 0) - size / 2
                        width: size
                        height: size
                        radius: size / 2
                        color: "white"
                        border.color: Qt.rgba(0, 0, 0, 0.25)
                    }
                }

                Interaction {
                    app: root
                    anchors.fill: parent
                    screenName: win.name
                    screenX: win.modelData.x
                    screenY: win.modelData.y
                }

                Toolbar {
                    app: root
                    visible: win.isFocused
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 48
                }
            }
        }
    }

    // --- Recording indicator ---
    LazyLoader {
        active: root.recording

        PanelWindow {
            screen: root.screenFor(root.focusedName)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "gshot-indicator"
            anchors.top: true
            margins.top: 6
            implicitWidth: pill.width
            implicitHeight: pill.height

            Rectangle {
                id: pill

                width: row.implicitWidth + 24
                height: 30
                radius: 15
                color: stopArea.containsMouse ? "#c01c28" : "#e01b24"

                Row {
                    id: row

                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 2
                        color: "white"
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        color: "white"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        font.features: {
                            "tnum": 1
                        }
                        text: `${Math.floor(root.recElapsed / 60)}:${String(root.recElapsed % 60).padStart(2, "0")}`
                    }
                }

                MouseArea {
                    id: stopArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: recorder.signal(2)
                }
            }
        }
    }
}
