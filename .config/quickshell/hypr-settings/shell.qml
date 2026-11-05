// Hyprland settings window in Caelestia's style. Reads the live values from Hyprland,
// applies changes instantly with `hyprctl eval`, and saves the ones changed here to
// ~/.config/hypr/hyprland-gui.lua (loaded last by hyprland.lua, so it wins). The set
// of changed values is kept in hyprland-gui.json next to it.
// Opened with Super+I (bound in ~/.config/caelestia/hypr-user.lua).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string hyprDir: Quickshell.env("HOME") + "/.config/hypr"

    readonly property var sections: [
        { id: "appearance", title: "Appearance", icon: "palette", desc: "Gaps, borders, corners and transparency" },
        { id: "effects", title: "Effects", icon: "blur_on", desc: "Blur, shadows and animations" },
        { id: "layout", title: "Layout", icon: "dashboard", desc: "How windows are tiled" },
        { id: "input", title: "Input", icon: "mouse", desc: "Mouse, keyboard and touchpad" },
        { id: "behaviour", title: "Behaviour", icon: "tune", desc: "Workspaces, focus and cursor" }
    ]

    // type: bool | int | float | choice. Keys are Hyprland option names; "var:" keys
    // are Caelestia variables that only take effect through a config reload.
    readonly property var options: [
        { section: "appearance", group: "Gaps & borders", key: "general:gaps_in", title: "Gap between windows", desc: "Space between tiled windows", type: "int", min: 0, max: 30, unit: "px" },
        { section: "appearance", group: "Gaps & borders", key: "general:gaps_out", title: "Gap to screen edges", desc: "Space between windows and the edge of the monitor", type: "int", min: 0, max: 60, unit: "px" },
        { section: "appearance", group: "Gaps & borders", key: "general:border_size", title: "Border width", desc: "Coloured outline around windows", type: "int", min: 0, max: 10, unit: "px" },
        { section: "appearance", group: "Corners", key: "decoration:rounding", title: "Corner radius", desc: "How round window corners are", type: "int", min: 0, max: 30, unit: "px" },
        { section: "appearance", group: "Corners", key: "decoration:rounding_power", title: "Corner shape", desc: "2 is a circle, higher values give smoother squircle corners", type: "float", min: 1, max: 10, step: 0.5, decimals: 1 },
        { section: "appearance", group: "Transparency", key: "var:windowOpacity", title: "Window opacity", desc: "How see-through windows are (not fullscreen ones)", type: "float", min: 0.5, max: 1, step: 0.01, scale: 100, unit: "%", reload: true },
        { section: "appearance", group: "Transparency", key: "decoration:dim_inactive", title: "Dim unfocused windows", desc: "Darken every window except the focused one", type: "bool" },
        { section: "appearance", group: "Transparency", key: "decoration:dim_strength", title: "Dim strength", desc: "How dark unfocused windows get", type: "float", min: 0, max: 1, step: 0.05, scale: 100, unit: "%" },
        { section: "appearance", group: "Transparency", key: "decoration:dim_special", title: "Dim behind special workspaces", desc: "Darkens the screen behind Telegram, Slack, music…", type: "float", min: 0, max: 1, step: 0.05, scale: 100, unit: "%" },

        { section: "effects", group: "Blur", key: "decoration:blur:enabled", title: "Blur", desc: "Blur what's behind see-through windows", type: "bool" },
        { section: "effects", group: "Blur", key: "decoration:blur:size", title: "Blur size", desc: "Radius of the blur", type: "int", min: 1, max: 20 },
        { section: "effects", group: "Blur", key: "decoration:blur:passes", title: "Blur passes", desc: "More passes look smoother but cost more GPU", type: "int", min: 1, max: 6 },
        { section: "effects", group: "Blur", key: "decoration:blur:vibrancy", title: "Vibrancy", desc: "Boost the saturation of blurred colours", type: "float", min: 0, max: 1, step: 0.01, decimals: 2 },
        { section: "effects", group: "Blur", key: "decoration:blur:noise", title: "Noise", desc: "Grain added to the blur", type: "float", min: 0, max: 0.2, step: 0.005, decimals: 3 },
        { section: "effects", group: "Blur", key: "decoration:blur:xray", title: "X-ray", desc: "Floating windows blur the wallpaper instead of the windows under them", type: "bool" },
        { section: "effects", group: "Shadows", key: "decoration:shadow:enabled", title: "Shadows", desc: "Drop shadows under windows", type: "bool" },
        { section: "effects", group: "Shadows", key: "decoration:shadow:range", title: "Shadow size", desc: "How far the shadow spreads", type: "int", min: 0, max: 50, unit: "px" },
        { section: "effects", group: "Shadows", key: "decoration:shadow:render_power", title: "Shadow falloff", desc: "Higher values fade the shadow out faster", type: "int", min: 1, max: 4 },
        { section: "effects", group: "Animations", key: "animations:enabled", title: "Animations", desc: "Animate windows, workspaces and layers", type: "bool" },

        { section: "layout", group: "Tiling", key: "general:layout", title: "Layout", desc: "How new windows are arranged", type: "choice", choices: [["dwindle", "Dwindle"], ["master", "Master"], ["scrolling", "Scrolling"]] },
        { section: "layout", group: "Tiling", key: "general:resize_on_border", title: "Resize from borders", desc: "Drag window edges with the mouse to resize", type: "bool" },
        { section: "layout", group: "Dwindle", key: "dwindle:preserve_split", title: "Keep split direction", desc: "Splits stay the same when windows open or close", type: "bool" },
        { section: "layout", group: "Dwindle", key: "dwindle:smart_split", title: "Split towards cursor", desc: "New windows open on the side of the cursor", type: "bool" },
        { section: "layout", group: "Master", key: "master:new_status", title: "New windows become", desc: "Where new windows go in the master layout", type: "choice", choices: [["master", "Master"], ["slave", "Stack"], ["inherit", "Inherit"]] },
        { section: "layout", group: "Scrolling", key: "scrolling:column_width", title: "Column width", desc: "Default width of a column, as part of the screen", type: "float", min: 0.1, max: 1, step: 0.05, scale: 100, unit: "%" },
        { section: "layout", group: "Performance", key: "general:allow_tearing", title: "Allow tearing", desc: "Lets games with the immediate rule skip vsync", type: "bool" },

        { section: "input", group: "Mouse", key: "input:sensitivity", title: "Pointer speed", desc: "Added on top of the device's own speed", type: "float", min: -1, max: 1, step: 0.05, decimals: 2 },
        { section: "input", group: "Mouse", key: "input:accel_profile", title: "Acceleration", desc: "How pointer speed reacts to fast movement", type: "choice", choices: [["", "Default"], ["adaptive", "Adaptive"], ["flat", "Flat"]] },
        { section: "input", group: "Mouse", key: "input:natural_scroll", title: "Natural scrolling", desc: "Content follows the wheel, like on a phone", type: "bool" },
        { section: "input", group: "Mouse", key: "input:follow_mouse", title: "Focus", desc: "Click: focus on click · Hover: focus follows the mouse · Loose: hover moves focus but typing stays · Separate: fully independent", type: "choice", choices: [[0, "Click"], [1, "Hover"], [2, "Loose"], [3, "Separate"]] },
        { section: "input", group: "Keyboard", key: "input:repeat_rate", title: "Repeat rate", desc: "Characters per second while a key is held", type: "int", min: 10, max: 80, unit: "/s" },
        { section: "input", group: "Keyboard", key: "input:repeat_delay", title: "Repeat delay", desc: "How long to hold a key before it repeats", type: "int", min: 150, max: 800, step: 10, unit: "ms" },
        { section: "input", group: "Keyboard", key: "input:numlock_by_default", title: "Num Lock on at start", desc: "Turn Num Lock on when Hyprland starts", type: "bool" },
        { section: "input", group: "Touchpad", key: "input:touchpad:natural_scroll", title: "Natural scrolling", desc: "Content follows your fingers", type: "bool" },
        { section: "input", group: "Touchpad", key: "input:touchpad:tap_to_click", title: "Tap to click", desc: "Tap the touchpad instead of pressing it", type: "bool" },
        { section: "input", group: "Touchpad", key: "input:touchpad:disable_while_typing", title: "Disable while typing", desc: "Ignore the touchpad while you type", type: "bool" },
        { section: "input", group: "Touchpad", key: "input:touchpad:clickfinger_behavior", title: "Click with fingers", desc: "Two-finger click is right click, three is middle click", type: "bool" },
        { section: "input", group: "Touchpad", key: "input:touchpad:scroll_factor", title: "Scroll speed", desc: "Multiplier for touchpad scrolling", type: "float", min: 0.1, max: 2, step: 0.05, decimals: 2, unit: "×" },

        { section: "behaviour", group: "Workspaces", key: "binds:workspace_back_and_forth", title: "Back and forth", desc: "Pressing the current workspace's key goes back to the previous one", type: "bool" },
        { section: "behaviour", group: "Workspaces", key: "binds:hide_special_on_workspace_change", title: "Hide special workspaces on switch", desc: "Telegram, Slack… close when you change workspace", type: "bool" },
        { section: "behaviour", group: "Workspaces", key: "misc:close_special_on_empty", title: "Close empty special workspaces", desc: "Hide a special workspace once its last window closes", type: "bool" },
        { section: "behaviour", group: "Windows", key: "misc:focus_on_activate", title: "Focus apps that ask for it", desc: "Jump to a window when an app requests focus", type: "bool" },
        { section: "behaviour", group: "Windows", key: "misc:middle_click_paste", title: "Middle-click paste", desc: "Paste the selection with the middle mouse button", type: "bool" },
        { section: "behaviour", group: "Cursor", key: "cursor:inactive_timeout", title: "Hide idle cursor", desc: "Seconds before an unmoved cursor hides (0 = never)", type: "float", min: 0, max: 30, step: 1, unit: "s" },
        { section: "behaviour", group: "Cursor", key: "cursor:hide_on_key_press", title: "Hide cursor while typing", desc: "Cursor reappears when the mouse moves", type: "bool" },
        { section: "behaviour", group: "Cursor", key: "cursor:no_warps", title: "Don't move the cursor", desc: "Stop the cursor jumping to newly focused windows", type: "bool" }
    ]

    property string section: "appearance"
    property string query: ""

    // Current value of every option in Hyprland, and the ones set from this app
    property var live: ({})
    property var overrides: ({})
    property var pending: ({})
    property bool needReload: false

    function valueOf(key: string): var {
        return key in overrides ? overrides[key] : live[key];
    }

    function set(opt: var, value: var): void {
        const o = Object.assign({}, overrides);
        o[opt.key] = value;
        overrides = o;
        if (opt.reload) {
            needReload = true;
        } else {
            pending[opt.key] = value;
            flushEval();
        }
        commitTimer.restart();
    }

    function reset(opt: var): void {
        const o = Object.assign({}, overrides);
        delete o[opt.key];
        overrides = o;
        needReload = true;
        commitTimer.restart();
    }

    readonly property var shownGroups: {
        const q = query.trim().toLowerCase();
        const groups = [];
        for (const o of options) {
            const hay = (o.title + " " + o.desc + " " + o.group + " " + o.key).toLowerCase();
            if (q ? !hay.includes(q) : o.section !== section)
                continue;
            const title = q ? sections.find(s => s.id === o.section).title + " · " + o.group : o.group;
            let g = groups.find(x => x.title === title);
            if (!g) {
                g = { title: title, opts: [] };
                groups.push(g);
            }
            g.opts.push(o);
        }
        return groups;
    }

    // Lua generation: "decoration:blur:size" -> { decoration = { blur = { size = … } } }
    function nest(map: var): var {
        const out = {};
        for (const key in map) {
            if (key.startsWith("var:"))
                continue;
            const parts = key.split(":");
            let t = out;
            for (const p of parts.slice(0, -1))
                t = t[p] = t[p] ?? {};
            t[parts[parts.length - 1]] = map[key];
        }
        return out;
    }

    function luaTable(obj: var, depth: int): string {
        const pad = "    ".repeat(depth + 1);
        const lines = Object.keys(obj).sort().map(k => {
            const key = /^[A-Za-z_]\w*$/.test(k) ? k : `["${k}"]`;
            const v = obj[k];
            const val = typeof v === "object" ? luaTable(v, depth + 1) : typeof v === "string" ? JSON.stringify(v) : String(v);
            return `${pad}${key} = ${val},`;
        });
        return "{\n" + lines.join("\n") + "\n" + "    ".repeat(depth) + "}";
    }

    function luaFile(): string {
        let lua = "-- Generated by Hyprland Settings (~/.config/quickshell/hypr-settings, Super+I).\n"
            + "-- Edits here get overwritten; the app keeps its values in hyprland-gui.json.\n";
        const settings = nest(overrides);
        if (Object.keys(settings).length)
            lua += "\n-- Settings\nhl.config(" + luaTable(settings, 0) + ")\n";
        if ("var:windowOpacity" in overrides)
            lua += "\n-- Window opacity (overrides Caelestia's own opacity rule)\n"
                + `hl.window_rule({ match = { fullscreen = false }, opacity = "${overrides["var:windowOpacity"]} override" })\n`;
        return lua;
    }

    function flushEval(): void {
        if (evalProc.running || !Object.keys(pending).length)
            return;
        evalProc.command = ["hyprctl", "eval", "hl.config(" + luaTable(nest(pending), 0) + ")"];
        pending = {};
        evalProc.running = true;
    }

    Process {
        id: evalProc
        onExited: root.flushEval()
    }

    // Write the files shortly after the last change, then reload if a change needs it
    Timer {
        id: commitTimer
        interval: 300
        onTriggered: {
            stateFile.setText(JSON.stringify(root.overrides, null, 2) + "\n");
            luaOut.setText(root.luaFile());
            if (root.needReload) {
                root.needReload = false;
                reloadProc.running = true;
            }
        }
    }

    FileView {
        id: stateFile
        path: root.hyprDir + "/hyprland-gui.json"
        blockWrites: true
        printErrors: false
        onLoaded: root.overrides = JSON.parse(text())
    }

    FileView {
        id: luaOut
        path: root.hyprDir + "/hyprland-gui.lua"
        blockWrites: true
        blockLoading: true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
        onExited: readProc.running = true
    }

    // Live values, all in one hyprctl call
    Process {
        id: readProc
        running: true
        command: ["hyprctl", "-j", "--batch", root.options.filter(o => !o.key.startsWith("var:")).map(o => "getoption " + o.key).join(";")]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = Object.assign({}, root.live);
                for (const chunk of text.match(/\{[^{}]*\}/g) ?? []) {
                    const j = JSON.parse(chunk);
                    l[j.option] = "css" in j ? parseInt(j.css) : "int" in j ? j.int : "float" in j ? Number(j.float.toFixed(4))
                        : "bool" in j ? j.bool : j.str === "[[EMPTY]]" ? "" : j.str;
                }
                root.live = l;
            }
        }
    }

    // Caelestia's window opacity variable (hypr-vars.lua overrides variables.lua)
    function readOpacity(): void {
        const re = /windowOpacity\s*=\s*([\d.]+)/;
        const m = userVars.text().match(re) ?? caelestiaVars.text().match(re);
        if (m)
            live = Object.assign({}, live, { "var:windowOpacity": Number(m[1]) });
    }

    FileView {
        id: caelestiaVars
        path: root.hyprDir + "/variables.lua"
        onLoaded: root.readOpacity()
    }

    FileView {
        id: userVars
        path: Quickshell.env("HOME") + "/.config/caelestia/hypr-vars.lua"
        printErrors: false
        onLoaded: root.readOpacity()
    }

    FloatingWindow {
        id: win

        title: "Hyprland Settings"
        implicitWidth: 960
        implicitHeight: 680
        minimumSize.width: 760
        minimumSize.height: 480
        color: Theme.surface

        onVisibleChanged: {
            if (!visible)
                Qt.quit();
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                if (root.query)
                    search.text = "";
                else
                    Qt.quit();
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                // Navigation
                ColumnLayout {
                    Layout.preferredWidth: 236
                    Layout.maximumWidth: 236
                    Layout.fillHeight: true
                    spacing: 4

                    Row {
                        Layout.leftMargin: 12
                        Layout.topMargin: 12
                        Layout.bottomMargin: 16
                        spacing: 10

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "settings"
                            fill: true
                            font.pixelSize: 26
                            color: Theme.primary
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Hyprland"
                            color: Theme.text
                            font.family: Theme.font
                            font.pixelSize: 22
                            font.weight: Font.Medium
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 12
                        implicitHeight: 48
                        radius: 24
                        color: Theme.surfaceContainerHigh

                        Icon {
                            id: searchIcon
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                        }

                        TextInput {
                            id: search
                            anchors.left: searchIcon.right
                            anchors.right: clear.left
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            selectionColor: Theme.primary
                            selectedTextColor: Theme.primaryText
                            font.family: Theme.font
                            font.pixelSize: 15
                            clip: true
                            onTextChanged: root.query = text
                            Keys.onEscapePressed: event => {
                                if (text) {
                                    text = "";
                                    event.accepted = true;
                                } else {
                                    event.accepted = false;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !search.text
                                text: "Search settings"
                                color: Theme.subtext
                                font: search.font
                            }
                        }

                        Icon {
                            id: clear
                            anchors.right: parent.right
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: "close"
                            visible: search.text !== ""

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: search.text = ""
                            }
                        }
                    }

                    Repeater {
                        model: root.sections

                        Rectangle {
                            id: nav

                            required property var modelData
                            readonly property bool active: !root.query && root.section === modelData.id

                            Layout.fillWidth: true
                            implicitHeight: 52
                            radius: 26
                            color: active ? Theme.secondaryContainer : navArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 14

                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: nav.modelData.icon
                                    fill: nav.active
                                    color: nav.active ? Theme.secondaryText : Theme.subtext
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: nav.modelData.title
                                    color: nav.active ? Theme.secondaryText : Theme.text
                                    font.family: Theme.font
                                    font.pixelSize: 15
                                    font.weight: nav.active ? Font.Medium : Font.Normal
                                }
                            }

                            MouseArea {
                                id: navArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    search.text = "";
                                    root.section = nav.modelData.id;
                                    flick.contentY = 0;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.margins: 12
                        text: "Changes apply instantly and are saved to hyprland-gui.lua"
                        wrapMode: Text.Wrap
                        color: Theme.subtext
                        font.family: Theme.font
                        font.pixelSize: 12
                    }
                }

                // Settings
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 24
                    color: Theme.surfaceContainerLow
                    clip: true

                    Flickable {
                        id: flick
                        anchors.fill: parent
                        contentHeight: page.implicitHeight + 64
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: page
                            x: 32
                            y: 32
                            width: flick.width - 64
                            spacing: 2

                            readonly property var current: root.sections.find(s => s.id === root.section)

                            Text {
                                text: root.query ? "Search results" : page.current.title
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 30
                            }

                            Text {
                                Layout.bottomMargin: 8
                                text: root.query ? `Settings matching “${root.query.trim()}”` : page.current.desc
                                color: Theme.subtext
                                font.family: Theme.font
                                font.pixelSize: 14
                            }

                            Text {
                                Layout.topMargin: 24
                                visible: root.shownGroups.length === 0
                                text: "Nothing matches that."
                                color: Theme.subtext
                                font.family: Theme.font
                                font.pixelSize: 15
                            }

                            Repeater {
                                model: root.shownGroups

                                ColumnLayout {
                                    id: group

                                    required property var modelData

                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.topMargin: 22
                                        Layout.bottomMargin: 8
                                        Layout.leftMargin: 4
                                        text: group.modelData.title
                                        color: Theme.primary
                                        font.family: Theme.font
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    Repeater {
                                        model: group.modelData.opts

                                        Rectangle {
                                            id: row

                                            required property var modelData
                                            required property int index
                                            readonly property var opt: modelData
                                            readonly property var value: root.valueOf(opt.key)
                                            readonly property bool changed: opt.key in root.overrides

                                            Layout.fillWidth: true
                                            implicitHeight: Math.max(72, text.implicitHeight + 28)
                                            color: Theme.surfaceContainer
                                            radius: 6
                                            topLeftRadius: index === 0 ? 20 : 6
                                            topRightRadius: index === 0 ? 20 : 6
                                            bottomLeftRadius: index === group.modelData.opts.length - 1 ? 20 : 6
                                            bottomRightRadius: index === group.modelData.opts.length - 1 ? 20 : 6

                                            ColumnLayout {
                                                id: text
                                                anchors.left: parent.left
                                                anchors.right: controls.left
                                                anchors.leftMargin: 20
                                                anchors.rightMargin: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 3

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: row.opt.title
                                                    color: Theme.text
                                                    font.family: Theme.font
                                                    font.pixelSize: 15
                                                    wrapMode: Text.Wrap
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: row.opt.desc
                                                    color: Theme.subtext
                                                    font.family: Theme.font
                                                    font.pixelSize: 13
                                                    wrapMode: Text.Wrap
                                                }
                                            }

                                            Row {
                                                id: controls
                                                anchors.right: parent.right
                                                anchors.rightMargin: 20
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 10

                                                // Back to the Caelestia default
                                                Rectangle {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: 36
                                                    height: 36
                                                    radius: 18
                                                    opacity: row.changed ? 1 : 0
                                                    color: resetArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"

                                                    Icon {
                                                        anchors.centerIn: parent
                                                        text: "undo"
                                                        font.pixelSize: 20
                                                    }

                                                    MouseArea {
                                                        id: resetArea
                                                        anchors.fill: parent
                                                        enabled: row.changed
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: root.reset(row.opt)
                                                    }
                                                }

                                                Loader {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    active: row.value !== undefined
                                                    sourceComponent: row.opt.type === "bool" ? toggle : row.opt.type === "choice" ? choice : slider
                                                }
                                            }

                                            Component {
                                                id: toggle

                                                Toggle {
                                                    checked: row.value
                                                    onToggled: v => root.set(row.opt, v)
                                                }
                                            }

                                            Component {
                                                id: choice

                                                Segmented {
                                                    choices: row.opt.choices
                                                    value: row.value
                                                    onPicked: v => root.set(row.opt, v)
                                                }
                                            }

                                            Component {
                                                id: slider

                                                ValueSlider {
                                                    from: row.opt.min
                                                    to: row.opt.max
                                                    stepSize: row.opt.step ?? 1
                                                    decimals: row.opt.decimals ?? 0
                                                    factor: row.opt.scale ?? 1
                                                    unit: row.opt.unit ?? ""
                                                    value: row.value
                                                    onMoved: v => root.set(row.opt, v)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
