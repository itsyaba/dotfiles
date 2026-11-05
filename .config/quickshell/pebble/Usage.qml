pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io

// Usage limits, after denon.agents (omarchy-dotfiles). One stacked block per agent:
// mark, name and plan, the binding limit as a big "% left" over a wavy fuel line, and a
// footnote for the other windows. Token history (7 days + top models) folds out of the
// footer. Data: ~/.local/bin/pebble-usage, run on open and every minute while open.
Drawer {
    id: root
    name: "usage"
    contentWidth: 360

    // Collector output: { claude: {...}, codex: {...}, ... }; an agent is left out when it has no data.
    property var report: ({})
    property bool loaded: false
    property bool launching: false
    property string failure: ""
    property double lastRun: 0
    property double nowMs: Date.now()
    property bool historyOpen: false
    property string historyKey: ""

    readonly property var agentKeys: Object.keys(report).filter(k => !!report[k] && typeof report[k] === "object")
    readonly property var tokenKeys: agentKeys.filter(k => report[k].tokensToday !== null && report[k].tokensToday !== undefined)
    readonly property string historyAgentKey: tokenKeys.indexOf(historyKey) >= 0 ? historyKey : (tokenKeys[0] ?? "")
    readonly property var historyAgent: historyAgentKey !== "" ? report[historyAgentKey] : null

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
        onExited: (code, status) => {
            if (code !== 0) {
                root.failure = "pebble-usage exited with code " + code;
                root.loaded = true;
            }
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
    }

    // ------------------------------------------------------------------ formatting
    function tint(c: color, a: real): color { return Qt.rgba(c.r, c.g, c.b, a); }

    function compact(n: real): string {
        const units = [[1e9, "B"], [1e6, "M"], [1e3, "K"]];
        for (const [size, suffix] of units) {
            if (n >= size) {
                const v = n / size;
                return (v >= 100 ? Math.round(v) : v.toFixed(1)) + suffix;
            }
        }
        return String(Math.round(n));
    }

    function span(ms: real): string {
        const m = Math.max(1, Math.round(ms / 60000));
        const d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60), mm = m % 60;
        if (d > 0) return d + " d " + h + " h";
        if (h > 0) return h + " h " + mm + " m";
        return mm + " m";
    }

    function ago(iso: string): string {
        const t = new Date(iso).getTime();
        if (!isFinite(t)) return "";
        const ms = root.nowMs - t;
        return ms < 60000 ? "just now" : span(ms) + " ago";
    }

    function msUntil(iso: var): real {
        const t = new Date(iso ?? "").getTime();
        return isFinite(t) ? t - root.nowMs : -1;
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

    // ------------------------------------------------------------------ limits
    // Percent LEFT, not used: a window whose reset has passed since it was recorded is full again.
    function leftOf(l: var): int {
        if (!l) return -1;
        return l.reset ? 100 : Math.max(0, Math.min(100, Math.round(100 - (Number(l.usedPercent) || 0))));
    }

    function hasLimits(a: var): bool {
        return !!a && a.limitsStatus !== "signin" && (a.limits ?? []).length > 0;
    }

    // The block leads with the weekly window, the one that actually runs out.
    function primaryOf(a: var): var {
        if (!hasLimits(a)) return null;
        const ls = a.limits;
        return ls.find(l => l.label === "Weekly") ?? ls[0];
    }

    function resetLine(l: var): string {
        if (!l) return "";
        if (l.reset) return "Reset since last use";
        const ms = msUntil(l.resetsAt);
        if (ms <= 0) return l.reached ? "Limit reached" : "";
        const when = Qt.formatDateTime(new Date(root.nowMs + ms), "ddd h:mm AP");
        return (l.reached ? "Limit reached · resets " : "Resets ") + when + " · in " + span(ms);
    }

    function footnote(a: var): string {
        if (!a) return "";
        if (a.limitsStatus === "signin") return "Open Claude Code to refresh sign-in";
        if (!hasLimits(a)) return a.limitsNote ?? "Plan limits aren't in the local logs";
        const p = primaryOf(a), bits = [];
        for (const l of a.limits) {
            if (l === p) continue;
            const ms = msUntil(l.resetsAt);
            bits.push(l.label + " " + leftOf(l) + "% left" + (!l.reset && ms > 0 ? " · resets in " + span(ms) : ""));
        }
        if (!a.limits.some(l => l.label === "Session")) bits.push("No 5-hour limit on this plan");
        if (a.limitsStatus === "offline" && p?.observedAt) bits.push("Offline · as of " + ago(p.observedAt));
        return bits.join("    ");
    }

    function leftColor(left: int): color {
        return left < 0 ? Theme.muted : left < 10 ? Theme.urgent : left < 30 ? Theme.warm : Theme.fg;
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

    // Fuel line: a sine squiggle over the share that is left, then a hairline for the rest.
    // The squiggle is drawn once, one wavelength longer than shown, and slid under a clip,
    // so the drift costs no path rebuilds. It only moves while the drawer is open.
    component Wave: Item {
        id: wave
        property real level: 0
        readonly property real wavelength: 28
        readonly property real amp: 3.2
        readonly property real filled: width * Math.max(0, Math.min(1, level))
        readonly property bool shown: filled > 2
        readonly property var points: {
            const pts = [], mid = height / 2, len = filled + wavelength;
            for (let x = 0; x <= len; x += 2)
                pts.push(Qt.point(x, mid + Math.sin(2 * Math.PI * x / wavelength) * amp));
            return pts.length > 1 ? pts : [Qt.point(0, mid), Qt.point(1, mid)];
        }
        height: 14

        Item {
            width: wave.filled
            height: parent.height
            clip: true
            visible: wave.shown
            Shape {
                width: wave.filled + wave.wavelength
                height: parent.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.accent
                    strokeWidth: 2.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: wave.points }
                }
                NumberAnimation on x {
                    from: -wave.wavelength; to: 0
                    duration: 3200
                    loops: Animation.Infinite
                    running: root.open && wave.shown
                }
            }
        }
        Rectangle {
            x: wave.shown ? wave.filled + 5 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, wave.width - x)
            height: 1
            color: Theme.hair
        }
    }

    component AgentBlock: Column {
        id: block
        required property string modelData
        readonly property var agent: root.report[modelData] ?? null
        readonly property var primary: root.primaryOf(agent)
        readonly property int leftPct: root.leftOf(primary)
        width: parent?.width ?? 0
        spacing: 14

        // Mark, name, plan.
        Row {
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: block.modelData.startsWith("claude") ? "asterisk" : "terminal"
                color: Theme.accent
                font.pixelSize: 17
            }
            Label {
                id: agentName
                anchors.verticalCenter: parent.verticalCenter
                text: block.agent?.name ?? block.modelData
                font.pixelSize: 15
                font.weight: Font.Medium
            }
            Label {
                anchors.baseline: agentName.baseline
                visible: text !== ""
                text: block.agent?.plan ?? ""
                color: Theme.muted
                font.pixelSize: 12
            }
        }

        // The binding window: label and reset on the left, a big "% left" on the right.
        Item {
            width: parent.width
            height: Math.max(limitText.implicitHeight, bigLeft.implicitHeight)
            Column {
                id: limitText
                anchors.left: parent.left
                anchors.right: bigRow.left
                anchors.rightMargin: 10
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                spacing: 3
                Label {
                    text: block.primary?.label ?? "Weekly"
                    font.pixelSize: 14
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: root.resetLine(block.primary)
                    color: Theme.muted
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
            Row {
                id: bigRow
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 5
                Label {
                    id: bigLeft
                    text: block.leftPct >= 0 ? block.leftPct + "%" : "—"
                    color: root.leftColor(block.leftPct)
                    font.pixelSize: 40
                    font.weight: Font.ExtraLight
                    font.letterSpacing: -1
                }
                Label {
                    anchors.baseline: bigLeft.baseline
                    visible: block.leftPct >= 0
                    text: "left"
                    color: Theme.muted
                    font.pixelSize: 11
                }
            }
        }

        Wave {
            width: parent.width
            level: block.leftPct >= 0 ? block.leftPct / 100 : 0
        }

        Label {
            width: parent.width
            visible: text !== ""
            text: root.footnote(block.agent)
            color: Theme.muted
            font.pixelSize: 11
            wrapMode: Text.WordWrap
        }
    }

    component DayRow: Item {
        id: dayRow
        required property var modelData
        readonly property bool today: modelData.date === root.todayIso()
        readonly property real tokens: Number(modelData.tokens) || 0
        readonly property real peak: Math.max(1, ...(root.historyAgent?.days ?? []).map(d => Number(d.tokens) || 0))
        width: parent?.width ?? 0
        height: 20
        Label {
            id: dayName
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            text: root.dayLabel(dayRow.modelData.date)
            color: dayRow.today ? Theme.fg : Theme.muted
            font.pixelSize: 11
            font.bold: dayRow.today
        }
        Rectangle {
            anchors.left: dayName.right
            anchors.right: dayValue.left
            anchors.leftMargin: 6
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 3
            radius: 1.5
            color: Theme.hair
            Rectangle {
                height: parent.height
                radius: parent.radius
                width: dayRow.tokens > 0 ? Math.max(parent.height, parent.width * dayRow.tokens / dayRow.peak) : 0
                color: dayRow.today ? Theme.fg : Theme.muted
                Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            }
        }
        Label {
            id: dayValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 50
            horizontalAlignment: Text.AlignRight
            text: dayRow.tokens > 0 ? root.compact(dayRow.tokens) : "–"
            color: dayRow.today ? Theme.fg : Theme.muted
            font.pixelSize: 11
            font.bold: dayRow.today
        }
    }

    // Name and total, with the share bar behind the row; hover for the in / out / cache split.
    component ModelRow: Item {
        id: modelRow
        required property var modelData
        readonly property real peak: Math.max(1, Number(root.historyAgent?.models?.[0]?.tokens) || 1)
        width: parent?.width ?? 0
        height: 26
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.min(1, Number(modelRow.modelData.tokens) / modelRow.peak)
            radius: 7
            color: root.tint(Theme.fg, modelHover.containsMouse ? 0.10 : 0.06)
        }
        Label {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.right: modelValue.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: modelRow.modelData.name || modelRow.modelData.model
            font.pixelSize: 12
            elide: Text.ElideRight
        }
        Label {
            id: modelValue
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: modelHover.containsMouse
                ? "in " + root.compact(modelRow.modelData.input) + " · out " + root.compact(modelRow.modelData.output) + " · cache " + root.compact(modelRow.modelData.cache)
                : root.compact(modelRow.modelData.tokens)
            color: modelHover.containsMouse ? Theme.fg : Theme.muted
            font.pixelSize: 11
            font.bold: !modelHover.containsMouse
        }
        MouseArea { id: modelHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    // ------------------------------------------------------------------ layout
    Column {
        width: parent.width
        spacing: 22

        // Header: title, freshness, refresh.
        Item {
            width: parent.width
            height: 28
            Label {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Usage limits"
                font.pixelSize: 20
                font.weight: Font.Light
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: collector.running && !root.loaded ? "Reading logs…"
                        : root.lastRun > 0 ? "Updated " + root.ago(new Date(root.lastRun).toISOString()) : ""
                    color: Theme.muted
                    font.pixelSize: 11
                }
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: root.tint(Theme.fg, refreshMouse.containsMouse ? 0.14 : 0.07)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Icon {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.pixelSize: 15
                        color: Theme.muted
                        RotationAnimation on rotation { running: collector.running; loops: Animation.Infinite; from: 0; to: 360; duration: 900 }
                    }
                    MouseArea { id: refreshMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.refresh() }
                }
            }
        }

        // Quiet empty state.
        Column {
            visible: root.loaded && root.agentKeys.length === 0
            width: parent.width
            bottomPadding: 6
            spacing: 6
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
                font.pixelSize: 11
            }
        }

        // One block per agent, stacked.
        Repeater {
            model: root.agentKeys
            delegate: AgentBlock {}
        }

        Label {
            visible: root.failure !== "" && root.agentKeys.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.failure
            color: Theme.urgent
            font.pixelSize: 11
        }

        // Footer: today's tokens per agent, and the token history fold-out.
        Column {
            visible: root.tokenKeys.length > 0
            width: parent.width
            spacing: 14

            Rectangle { width: parent.width; height: 1; color: Theme.hair }

            Item {
                width: parent.width
                height: 18
                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 16
                    Repeater {
                        model: root.tokenKeys
                        delegate: Item {
                            id: todayItem
                            required property string modelData
                            readonly property bool picked: root.historyOpen && root.historyAgentKey === modelData
                            width: todayRow.implicitWidth
                            height: todayRow.implicitHeight
                            Row {
                                id: todayRow
                                spacing: 6
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5; height: 5; radius: 2.5
                                    color: todayItem.picked ? Theme.fg : Theme.muted
                                }
                                Label {
                                    text: root.compact(Number(root.report[todayItem.modelData]?.tokensToday) || 0) + " today"
                                    color: todayItem.picked || todayMouse.containsMouse ? Theme.fg : Theme.muted
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                }
                            }
                            MouseArea {
                                id: todayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.historyKey = todayItem.modelData;
                                    root.historyOpen = true;
                                }
                            }
                        }
                    }
                }
                Row {
                    id: historyLink
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 1
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Token history"
                        color: root.historyOpen || historyMouse.containsMouse ? Theme.fg : Theme.muted
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "chevron_right"
                        rotation: root.historyOpen ? 90 : 0
                        color: Theme.muted
                        font.pixelSize: 15
                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
                MouseArea {
                    id: historyMouse
                    anchors.fill: historyLink
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.historyOpen = !root.historyOpen
                }
            }

            // Token history: the last 7 days and the top 3 models for the picked agent.
            Column {
                visible: root.historyOpen && !!root.historyAgent
                width: parent.width
                spacing: 2
                Label {
                    bottomPadding: 6
                    text: (root.historyAgent?.name ?? "") + " · last 7 days"
                    color: Theme.muted
                    font.pixelSize: 11
                }
                Repeater {
                    model: root.historyAgent?.days ?? []
                    delegate: DayRow {}
                }
                Item { width: 1; height: 10 }
                Repeater {
                    model: (root.historyAgent?.models ?? []).slice(0, 3)
                    delegate: ModelRow {}
                }
            }
        }
    }
}
