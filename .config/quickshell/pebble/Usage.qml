pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Usage limits, after denon.agents (omarchy-dotfiles): Claude Code and Codex token use
// from their local session logs, read by ~/.local/bin/pebble-usage (no credentials, no
// network). Hero, a chip switch when both agents have data, limit meters, then tokens
// by day and by model for the last 7 days. Refreshes on open and every minute while open.
Drawer {
    id: root
    name: "usage"
    contentWidth: 380

    // Collector output: { claude: {...}, codex: {...} }, an agent left out when it has no data.
    property var report: ({})
    property bool loaded: false
    property string failure: ""
    property double lastRun: 0
    property bool launching: false
    property double nowMs: Date.now()
    property string selected: ""

    readonly property var agentIds: ["claude", "codex"].filter(id => !!root.report[id])
    readonly property string current: agentIds.indexOf(selected) >= 0 ? selected : (agentIds[0] ?? "")
    readonly property var agent: current !== "" ? report[current] : null
    readonly property var days: agent?.days ?? []
    readonly property var models: (agent?.models ?? []).slice(0, 5)
    readonly property var limits: agent?.limits ?? []
    readonly property real dayPeak: Math.max(1, ...days.map(d => Number(d.tokens) || 0))
    readonly property real modelPeak: Math.max(1, models.length ? Number(models[0].tokens) : 1)

    function refresh(): void {
        nowMs = Date.now();
        if (collector.running) return;
        launching = true;
        collector.running = true;
    }

    onOpenChanged: if (open) refresh()
    Timer { interval: 60000; running: root.open; repeat: true; onTriggered: root.refresh() }

    Process {
        id: collector
        command: [Quickshell.env("HOME") + "/.local/bin/pebble-usage"]
        onStarted: root.launching = false
        // A missing or non-executable collector never starts, so it never exits either.
        onRunningChanged: if (!running && root.launching) {
            root.launching = false;
            root.failure = "Couldn't run ~/.local/bin/pebble-usage";
            root.loaded = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const out = String(text).trim();
                if (out === "") return;
                try {
                    root.report = JSON.parse(out);
                    root.failure = "";
                    root.lastRun = Date.now();
                } catch (e) {
                    root.failure = "Couldn't read the collector's output";
                }
                root.loaded = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const err = String(text).trim();
                if (err !== "") console.warn("pebble-usage:", err.split("\n").slice(-1)[0]);
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.failure = "pebble-usage exited with code " + code;
                root.loaded = true;
            }
        }
    }

    // ------------------------------------------------------------------ formatting
    function tint(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a); }

    function compact(n: real): string {
        const units = [[1e9, "B"], [1e6, "M"], [1e3, "K"]];
        for (const [size, suffix] of units) {
            if (n >= size) {
                const v = n / size;
                return (v >= 100 ? Math.round(v) : v.toFixed(1).replace(/\.0$/, "")) + suffix;
            }
        }
        return String(Math.round(n));
    }

    function span(ms: real): string {
        const m = Math.max(1, Math.round(ms / 60000));
        const d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60), mm = m % 60;
        if (d > 0) return d + " d" + (h > 0 ? " " + h + " h" : "");
        if (h > 0) return h + " h" + (mm > 0 ? " " + mm + " m" : "");
        return mm + " m";
    }

    function ago(iso: string): string {
        const t = new Date(iso).getTime();
        if (!isFinite(t)) return "";
        const ms = root.nowMs - t;
        return ms < 60000 ? "just now" : span(ms) + " ago";
    }

    function todayIso(): string {
        const d = new Date(root.nowMs);
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }

    function dayLabel(date: string): string {
        if (date === todayIso()) return "Today";
        const d = new Date(date + "T00:00:00");
        return isNaN(d.getTime()) ? date : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][d.getDay()];
    }

    function limitNote(l: var): string {
        if (l.reset) return "Reset since last use · seen " + ago(l.observedAt);
        const t = new Date(l.resetsAt ?? "").getTime();
        const left = isFinite(t) ? t - root.nowMs : -1;
        const when = left > 0 ? "resets in " + span(left) : "resetting";
        return l.reached ? "Limit reached · " + when : when.charAt(0).toUpperCase() + when.slice(1);
    }

    function meterColor(used: real): color {
        return used >= 90 ? Theme.urgent : used >= 70 ? Theme.warm : Theme.accent;
    }

    // ------------------------------------------------------------------ parts
    component Label: Text {
        color: Theme.fg
        font.family: Theme.family
        font.pixelSize: 13
        textFormat: Text.PlainText
    }

    component Icon: Text {
        font.family: Theme.icons
        font.pixelSize: 18
        color: Theme.fg
    }

    component Section: Label {
        topPadding: 6
        color: Theme.muted
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.8
        font.capitalization: Font.AllUppercase
    }

    component Meter: Column {
        id: meter
        required property var modelData
        readonly property real used: Math.max(0, Math.min(100, Number(modelData.usedPercent) || 0))
        width: parent?.width ?? 0
        spacing: 7
        Item {
            width: parent.width
            height: Math.max(meterText.implicitHeight, meterValue.implicitHeight)
            Column {
                id: meterText
                anchors.left: parent.left
                anchors.right: meterValue.left
                anchors.rightMargin: 8
                anchors.bottom: parent.bottom
                spacing: 2
                Label {
                    text: meter.modelData.label + (meter.modelData.window ? "  ·  " + meter.modelData.window : "")
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    text: root.limitNote(meter.modelData)
                    color: meter.modelData.reached ? Theme.urgent : Theme.muted
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
            Row {
                id: meterValue
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 4
                Label {
                    id: pct
                    text: Math.round(meter.used) + "%"
                    color: meter.used >= 90 ? Theme.urgent : Theme.fg
                    font.pixelSize: 26
                    font.weight: Font.Light
                    font.letterSpacing: -0.5
                }
                Label {
                    anchors.baseline: pct.baseline
                    text: "used"
                    color: Theme.muted
                    font.pixelSize: 12
                }
            }
        }
        Rectangle {
            width: parent.width
            height: 5
            radius: height / 2
            color: Theme.hair
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: meter.used > 0 ? Math.max(parent.height, parent.width * meter.used / 100) : 0
                color: root.meterColor(meter.used)
                Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    component DayRow: Item {
        id: dayRow
        required property var modelData
        readonly property bool today: modelData.date === root.todayIso()
        readonly property real tokens: Number(modelData.tokens) || 0
        width: parent?.width ?? 0
        height: 22
        Label {
            id: dayName
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 46
            text: root.dayLabel(dayRow.modelData.date)
            color: dayRow.today ? Theme.fg : Theme.muted
            font.pixelSize: 12
            font.bold: dayRow.today
        }
        Rectangle {
            anchors.left: dayName.right
            anchors.right: dayValue.left
            anchors.leftMargin: 6
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 5
            radius: height / 2
            color: Theme.hair
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: dayRow.tokens > 0 ? Math.max(parent.height, parent.width * dayRow.tokens / root.dayPeak) : 0
                color: dayRow.today ? Theme.accent : root.tint(Theme.fg, 0.45)
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
        Label {
            id: dayValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            horizontalAlignment: Text.AlignRight
            text: dayRow.tokens > 0 ? root.compact(dayRow.tokens) : "–"
            color: dayRow.today ? Theme.fg : Theme.muted
            font.pixelSize: 12
            font.bold: dayRow.today
        }
    }

    // The share bar fills the row behind the name; hover for the input / output / cache split.
    component ModelRow: Item {
        id: modelRow
        required property var modelData
        width: parent?.width ?? 0
        height: 32
        Rectangle {
            anchors.fill: parent
            radius: 9
            color: root.tint(Theme.fg, modelHover.containsMouse ? 0.08 : 0.05)
        }
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1, Number(modelRow.modelData.tokens) / root.modelPeak)
            radius: 9
            color: root.tint(Theme.accent, 0.2)
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: modelValue.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: modelRow.modelData.name || modelRow.modelData.model
            elide: Text.ElideRight
        }
        Label {
            id: modelValue
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: modelHover.containsMouse
                ? "in " + root.compact(modelRow.modelData.input) + " · out " + root.compact(modelRow.modelData.output) + " · cache " + root.compact(modelRow.modelData.cache)
                : root.compact(modelRow.modelData.tokens)
            color: modelHover.containsMouse ? Theme.fg : Theme.muted
            font.pixelSize: 12
            font.bold: !modelHover.containsMouse
        }
        MouseArea { id: modelHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    // ------------------------------------------------------------------ layout
    Column {
        width: parent.width
        spacing: 12

        // Header: title, freshness, refresh.
        Item {
            width: parent.width
            height: 28
            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Usage limits"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: collector.running && !root.loaded ? "Reading logs…" : root.lastRun > 0 ? "Updated " + root.ago(new Date(root.lastRun).toISOString()) : ""
                    color: Theme.muted
                    font.pixelSize: 11
                }
                Rectangle {
                    width: 28; height: 28; radius: 9
                    color: root.tint(Theme.fg, refreshMouse.containsMouse ? 0.14 : 0.07)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Icon {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.pixelSize: 17
                        color: Theme.muted
                        RotationAnimation on rotation { running: collector.running; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                    }
                    MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                }
            }
        }

        // Quiet empty state.
        Column {
            visible: root.loaded && root.agentIds.length === 0
            width: parent.width
            topPadding: 18
            bottomPadding: 14
            spacing: 6
            Icon { anchors.horizontalCenter: parent.horizontalCenter; text: "data_usage"; font.pixelSize: 28; color: Theme.muted }
            Label {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.failure !== "" ? root.failure : "No usage recorded yet"
                color: root.failure !== "" ? Theme.urgent : Theme.fg
            }
            Label {
                visible: root.failure === ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Claude Code and Codex show up here once their sessions log some tokens."
                color: Theme.muted
                font.pixelSize: 12
            }
        }

        // Agent switch: one chip per agent, only when there is a choice.
        Rectangle {
            visible: root.agentIds.length > 1
            width: parent.width
            height: 34
            radius: 12
            color: root.tint(Theme.fg, 0.06)
            Row {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 3
                Repeater {
                    model: root.agentIds
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        readonly property bool on: root.current === modelData
                        width: (parent.width - 3 * (root.agentIds.length - 1)) / root.agentIds.length
                        height: parent.height
                        radius: 9
                        color: on ? Theme.accent : root.tint(Theme.fg, chipMouse.containsMouse ? 0.08 : 0)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Label {
                            anchors.centerIn: parent
                            text: root.report[chip.modelData]?.name ?? chip.modelData
                            color: chip.on ? Theme.onAccent : Theme.fg
                            font.weight: chip.on ? Font.DemiBold : Font.Medium
                        }
                        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = chip.modelData }
                    }
                }
            }
        }

        // Hero: the agent, its plan, and today's tokens.
        Row {
            visible: !!root.agent
            width: parent.width
            spacing: 12
            Rectangle {
                width: 40; height: 40; radius: 12
                color: root.tint(Theme.accent, 0.16)
                Icon { anchors.centerIn: parent; text: root.current === "codex" ? "terminal" : "smart_toy"; color: Theme.accent; font.pixelSize: 21 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Row {
                    spacing: 8
                    Label {
                        text: root.agent?.name ?? ""
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }
                    Label {
                        anchors.baseline: parent.children[0].baseline
                        visible: text !== ""
                        text: root.agent?.plan ?? ""
                        color: Theme.muted
                    }
                }
                Label {
                    text: {
                        const n = Number(root.agent?.tokensToday ?? 0);
                        if (n > 0) return "today: " + root.compact(n) + " tokens";
                        const last = root.agent?.lastActivity ?? "";
                        return "today: no tokens" + (last ? " · last used " + root.ago(last) : "");
                    }
                    color: Theme.muted
                    font.pixelSize: 12
                }
            }
        }

        // Limits.
        Section { visible: !!root.agent; text: "Limits" }
        Repeater {
            model: root.limits
            delegate: Meter {}
        }
        Label {
            visible: !!root.agent && root.limits.length === 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.current === "claude"
                ? "No limit hit right now. Claude Code only writes its plan limits to the local logs when a request is refused."
                : "No rate-limit record in the local logs yet."
            color: Theme.muted
            font.pixelSize: 12
        }

        // Tokens by day.
        Section { visible: root.days.length > 0; text: "Tokens by day" }
        Column {
            width: parent.width
            spacing: 2
            Repeater {
                model: root.days
                delegate: DayRow {}
            }
        }

        // Tokens by model.
        Section { visible: root.models.length > 0; text: "Tokens by model · 7 days" }
        Column {
            width: parent.width
            spacing: 5
            Repeater {
                model: root.models
                delegate: ModelRow {}
            }
        }

        Label {
            visible: root.failure !== "" && root.agentIds.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.failure
            color: Theme.urgent
            font.pixelSize: 11
        }
    }
}
