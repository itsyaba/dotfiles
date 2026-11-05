// Desktop music card, modelled on Caelestia's dashboard media tab: cover art in a
// rotating cookie shape ringed by an audio visualiser, track details with a wavy
// progress bar and controls, and synced lyrics. Shown on empty workspaces directly
// under Caelestia's top-center desktop clock and exactly as wide as it.
// Colours follow the Caelestia scheme. Started from ~/.config/caelestia/hypr-user.lua.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import M3Shapes
import Caelestia.Components
import Caelestia.Services

ShellRoot {
    id: root

    // Caelestia colour scheme, reloaded whenever it changes
    property var c: ({})
    function col(name: string, fallback: string): color {
        return root.c[name] ? "#" + root.c[name] : fallback;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/caelestia/scheme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.c = JSON.parse(text()).colours
    }

    // Desktop clock scale, so the card tracks the clock's size
    property real clockScale: 1

    FileView {
        path: Quickshell.env("HOME") + "/.config/caelestia/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.clockScale = JSON.parse(text()).background?.desktopClock?.scale ?? 1
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Last player that started playing or was picked from the selector (so a paused
    // YouTube stays resumable), else whatever is playing, else the first player
    property MprisPlayer lastPlayed: null
    readonly property list<MprisPlayer> players: Mpris.players.values
    readonly property MprisPlayer player: (players.includes(lastPlayed) ? lastPlayed : null) ?? players.find(p => p.isPlaying) ?? players[0] ?? null

    Variants {
        model: root.players

        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged(): void {
                if (modelData.isPlaying)
                    root.lastPlayed = modelData;
            }
        }
    }

    function cyclePlayer(): void {
        if (players.length > 1)
            lastPlayed = players[(players.indexOf(player) + 1) % players.length];
    }

    function fmt(secs: real): string {
        const s = Math.max(0, Math.floor(secs));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Timer {
        running: root.player?.isPlaying ?? false
        interval: 500
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Lyrics for the current track (same service as the Caelestia dashboard)
    function updateLyrics(): void {
        const p = root.player;
        if (p?.trackTitle)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        else
            Lyrics.clearTrack();
    }

    onPlayerChanged: updateLyrics()
    Connections {
        target: root.player
        function onTrackTitleChanged(): void { root.updateLyrics(); }
        function onTrackArtistChanged(): void { root.updateLyrics(); }
    }

    // Audio levels for the ring around the cover
    readonly property int ringBars: 30

    CavaProvider {
        id: cava
        bars: root.ringBars
    }

    ServiceRef {
        service: cava
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData
            screen: modelData

            readonly property bool desktopEmpty: (Hyprland.monitorFor(modelData)?.activeWorkspace?.toplevels?.values.length ?? 0) === 0
            readonly property bool shouldShow: desktopEmpty && root.player !== null && root.player.trackTitle !== ""

            visible: card.opacity > 0
            color: "transparent"
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "desktop-media"
            // Like Caelestia's background: centred on the whole screen, not the space beside the bar
            exclusionMode: ExclusionMode.Ignore
            anchors.top: true
            // Clock sits 32px from the top inside a box padded by 16 * scale above and below;
            // skip the bottom padding so the card hugs the clock
            margins.top: 32 + replica.implicitHeight + 16 * root.clockScale
            implicitWidth: replica.implicitWidth
            implicitHeight: 236

            // Invisible copy of Caelestia's DesktopClock text layout, used only for its size
            RowLayout {
                id: replica

                opacity: 0 // not visible: false, layouts skip hidden children when sizing
                spacing: 16 * root.clockScale

                RowLayout {
                    spacing: 8

                    ClockText {
                        text: String(clock.hours % 12 || 12).padStart(2, "0")
                        font.pointSize: 28 * 3 * root.clockScale
                        font.weight: Font.Bold
                    }
                    ClockText {
                        text: ":"
                        font.pointSize: 28 * 3 * root.clockScale
                        Layout.topMargin: -16 * 1.5 * root.clockScale
                    }
                    ClockText {
                        text: String(clock.minutes).padStart(2, "0")
                        font.pointSize: 28 * 3 * root.clockScale
                        font.weight: Font.Bold
                    }
                    ClockText {
                        text: clock.hours < 12 ? "AM" : "PM"
                        font.pointSize: 16 * root.clockScale
                    }
                }

                Item {
                    Layout.preferredWidth: 4 * root.clockScale
                }

                ColumnLayout {
                    spacing: 0

                    ClockText {
                        text: Qt.formatDateTime(clock.date, "MMMM").toUpperCase()
                        font.pointSize: 16 * root.clockScale
                        font.letterSpacing: 4
                        font.weight: Font.Bold
                    }
                    ClockText {
                        text: Qt.formatDateTime(clock.date, "dd")
                        font.pointSize: 28 * root.clockScale
                        font.letterSpacing: 2
                        font.weight: Font.Medium
                    }
                    ClockText {
                        text: Qt.formatDateTime(clock.date, "dddd")
                        font.pointSize: 16 * root.clockScale
                        font.letterSpacing: 2
                    }
                }
            }

            ClippingRectangle { // clips the drifting shapes to the rounded corners
                id: card

                anchors.fill: parent
                radius: 24
                color: Qt.alpha(root.col("surfaceContainer", "#1a1a1a"), 0.88)
                border.width: 1
                border.color: Qt.alpha(root.col("outlineVariant", "#484848"), 0.5)

                opacity: win.shouldShow ? 1 : 0
                scale: win.shouldShow ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                BackgroundShapes {
                    anchors.fill: parent
                    running: win.visible && (root.player?.isPlaying ?? false)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 20

                    CoverVisualiser {
                        Layout.fillHeight: true
                        Layout.preferredWidth: height
                    }

                    Details {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    LyricsPanel {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 190
                    }
                }
            }
        }
    }

    component ClockText: Text {
        font.family: "Rubik"
    }

    component Label: Text {
        font.family: "Rubik"
        elide: Text.ElideRight
        color: root.col("onSurface", "#e6e6e6")
    }

    component Icon: Text {
        property bool fill: false
        font.family: "Material Symbols Rounded"
        font.variableAxes: ({ FILL: fill ? 1 : 0 })
        color: root.col("onSurface", "#e6e6e6")
    }

    // Slowly drifting translucent shapes behind everything
    component BackgroundShapes: Item {
        id: bg

        property bool running
        readonly property list<int> pool: [MaterialShape.Circle, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Sunny, MaterialShape.SoftBurst, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.Arch, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Fan, MaterialShape.Oval]

        function rand(min: real, max: real): real {
            return min + Math.random() * (max - min);
        }

        Repeater {
            id: shapes
            model: 12

            MaterialShape {
                required property int index
                property real vx: bg.rand(4, 16) * (Math.random() < 0.5 ? -1 : 1)
                property real vy: bg.rand(4, 16) * (Math.random() < 0.5 ? -1 : 1)
                property real vr: bg.rand(-12, 12)
                readonly property int colourIdx: Math.floor(Math.random() * 4)

                implicitSize: 30 + index / 12 * 80
                shape: bg.pool[Math.floor(Math.random() * bg.pool.length)]
                color: [root.col("primaryContainer", "#474747"), root.col("secondaryContainer", "#3b3b3b"), root.col("tertiaryContainer", "#545853"), root.col("outlineVariant", "#484848")][colourIdx]
                opacity: [0.16, 0.16, 0.04, 0.16][colourIdx]
                rotation: bg.rand(0, 360)
                x: bg.rand(0, 700)
                y: bg.rand(0, 200)
            }
        }

        FrameAnimation {
            running: bg.running
            onTriggered: {
                for (let i = 0; i < shapes.count; i++) {
                    const s = shapes.itemAt(i);
                    if (!s)
                        continue;
                    s.x += s.vx * frameTime;
                    s.y += s.vy * frameTime;
                    s.rotation += s.vr * frameTime;
                    if (s.x + s.width < 0) s.x = bg.width;
                    else if (s.x > bg.width) s.x = -s.width;
                    if (s.y + s.height < 0) s.y = bg.height;
                    else if (s.y > bg.height) s.y = -s.height;
                }
            }
        }
    }

    // Cover art in a rotating cookie shape, ringed by audio bars
    component CoverVisualiser: Item {
        id: vis

        readonly property real gap: 8
        readonly property real coverSize: Math.round(width * 0.56)
        readonly property real maxMagnitude: (width - coverSize) / 2 - gap

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            data: bars.instances
        }

        Variants {
            id: bars
            model: Array.from({ length: root.ringBars }, (_, i) => i)

            ShapePath {
                id: bar

                required property int modelData
                readonly property real value: Math.max(1e-2, Math.min(1, cava.values[modelData] ?? 0))
                readonly property real angle: modelData * 2 * Math.PI / root.ringBars
                readonly property real edge: {
                    shape.rotation; // Update when the cover rotates
                    return shape.distanceAtAngle(modelData * 360 / root.ringBars + 90) + vis.gap + strokeWidth / 2;
                }
                readonly property real dist: edge + value * (vis.maxMagnitude - strokeWidth)

                capStyle: ShapePath.RoundCap
                strokeWidth: 360 / root.ringBars - 2
                strokeColor: root.col("primary", "#c7c7c7")
                fillColor: "transparent"
                startX: vis.width / 2 + edge * Math.cos(angle)
                startY: vis.height / 2 + edge * Math.sin(angle)

                PathLine {
                    x: vis.width / 2 + bar.dist * Math.cos(bar.angle)
                    y: vis.height / 2 + bar.dist * Math.sin(bar.angle)
                }
            }
        }

        Item {
            anchors.centerIn: parent
            width: vis.coverSize
            height: vis.coverSize

            // Slight glow to separate from the background
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 1
                shadowColor: root.col("outline", "#767676")
                shadowOpacity: 0.3
            }

            Item {
                id: shapeWrapper
                anchors.fill: parent
                layer.enabled: true

                MaterialShape {
                    id: shape
                    implicitSize: vis.coverSize
                    shape: MaterialShape.Cookie9Sided
                    color: root.col("surfaceContainerHighest", "#262626")

                    RotationAnimation on rotation {
                        running: true
                        paused: !(root.player?.isPlaying ?? false)
                        from: 360
                        to: 0
                        duration: 23500
                        loops: Animation.Infinite
                    }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "art_track"
                font.pixelSize: vis.coverSize * 0.35
                color: root.col("onSurfaceVariant", "#ababab")
            }

            Image {
                id: art
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(vis.coverSize * 2, vis.coverSize * 2)
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: shapeWrapper
                    maskSpreadAtMin: 1
                    maskThresholdMin: 0.5
                }
            }
        }
    }

    // Title, artist, album, wavy progress bar and playback controls
    component Details: ColumnLayout {
        spacing: 2

        Label {
            Layout.fillWidth: true
            text: root.player?.trackTitle ?? ""
            font.pixelSize: 24
            font.weight: Font.Medium
        }
        Label {
            Layout.fillWidth: true
            text: root.player?.trackArtist || "Unknown artist"
            font.pixelSize: 17
            color: root.col("onSurfaceVariant", "#ababab")
        }
        Label {
            Layout.fillWidth: true
            text: root.player?.trackAlbum || "Unknown album"
            font.pixelSize: 17
            color: root.col("secondary", "#9d9d9d")
        }

        RowLayout {
            Layout.topMargin: 18
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: root.fmt(seek.dragging ? seek.pos * (root.player?.length ?? 0) : root.player?.position ?? 0)
                font.pixelSize: 13
                color: root.col("onSurfaceVariant", "#ababab")
            }
            WavySlider {
                id: seek
                Layout.fillWidth: true
            }
            Label {
                text: root.fmt(root.player?.length ?? 0)
                font.pixelSize: 13
                color: root.col("onSurfaceVariant", "#ababab")
            }
        }

        RowLayout {
            Layout.topMargin: 14
            Layout.fillWidth: true
            spacing: 4

            MediaButton {
                icon: "shuffle"
                small: true
                checked: root.player?.shuffle ?? false
                enabled: root.player?.shuffleSupported ?? false
                onClicked: root.player.shuffle = !root.player.shuffle
            }
            MediaButton {
                icon: "skip_previous"
                enabled: root.player?.canGoPrevious ?? false
                onClicked: root.player.previous()
            }
            MediaButton {
                Layout.fillWidth: true
                icon: root.player?.isPlaying ? "pause" : "play_arrow"
                primary: true
                checked: root.player?.isPlaying ?? false
                enabled: root.player?.canTogglePlaying ?? false
                onClicked: root.player.togglePlaying()
            }
            MediaButton {
                icon: "skip_next"
                enabled: root.player?.canGoNext ?? false
                onClicked: root.player.next()
            }
            MediaButton {
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                small: true
                checked: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                enabled: root.player?.loopSupported ?? false
                onClicked: {
                    const s = root.player.loopState;
                    root.player.loopState = s === MprisLoopState.None ? MprisLoopState.Track
                        : s === MprisLoopState.Track ? MprisLoopState.Playlist : MprisLoopState.None;
                }
            }
        }
    }

    // Material 3 expressive style progress: animated wave up to a handle, flat track after
    component WavySlider: Item {
        id: slider

        readonly property real value: root.player ? Math.min(1, root.player.position / (root.player.length || 1)) : 0
        property real pos: value
        property bool dragging: mouse.pressed
        readonly property real handleGap: 4
        readonly property real usable: width - 4 - handleGap * 2
        readonly property real shown: dragging ? pos : value

        implicitHeight: 26

        WavyLine {
            id: wave
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            lineWidth: 4
            frequency: 5
            startX: x
            fullLength: slider.usable
            color: root.col("primary", "#c7c7c7")
            implicitWidth: slider.usable * slider.shown
            implicitHeight: lineWidth * amplitudeMultiplier * 2 + lineWidth

            NumberAnimation on waveProgress {
                running: true
                paused: !(root.player?.isPlaying ?? false)
                from: 0
                to: 1
                duration: 2000
                loops: Animation.Infinite
            }
        }

        Rectangle {
            id: handle
            x: slider.usable * slider.shown + slider.handleGap
            anchors.verticalCenter: parent.verticalCenter
            width: 4
            height: mouse.pressed ? 26 : 20
            radius: 2
            color: root.col("primary", "#c7c7c7")
            Behavior on height { NumberAnimation { duration: 150 } }
        }

        Rectangle {
            anchors.left: handle.right
            anchors.leftMargin: slider.handleGap
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 8
            radius: 4
            color: root.col("secondaryContainer", "#3b3b3b")

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 2
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: 4
                radius: 2
                color: root.col("primary", "#c7c7c7")
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            enabled: root.player?.canSeek ?? false
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: e => slider.pos = Math.max(0, Math.min(1, e.x / slider.usable))
            onPositionChanged: e => slider.pos = Math.max(0, Math.min(1, e.x / slider.usable))
            onReleased: root.player.position = slider.pos * root.player.length
        }
    }

    component MediaButton: Rectangle {
        id: btn

        required property string icon
        property bool small: false
        property bool primary: false
        property bool checked: false
        signal clicked

        implicitWidth: small ? 42 : 52
        implicitHeight: 52
        // Shape morph: checked buttons square off, unchecked ones stay round
        radius: checked ? 14 : height / 2
        opacity: enabled ? 1 : 0.4
        color: {
            const base = primary ? root.col("primary", "#c7c7c7")
                : checked ? root.col("secondary", "#9d9d9d")
                : root.col("secondaryContainer", "#3b3b3b");
            return area.containsMouse ? Qt.lighter(base, 1.15) : base;
        }
        scale: area.pressed ? 0.92 : 1
        Behavior on radius { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        Behavior on scale { NumberAnimation { duration: 120 } }
        Behavior on color { ColorAnimation { duration: 150 } }

        Icon {
            anchors.centerIn: parent
            text: btn.icon
            fill: true
            font.pixelSize: btn.small ? 22 : 28
            color: btn.primary ? root.col("onPrimary", "#404040")
                : btn.checked ? root.col("onSecondary", "#202020")
                : root.col("onSecondaryContainer", "#bfbfbf")
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    // Synced lyrics plus the player selector
    component LyricsPanel: ColumnLayout {
        spacing: 10

        RowLayout {
            spacing: 8

            Icon {
                text: "lyrics"
                font.pixelSize: 22
            }
            Label {
                Layout.fillWidth: true
                text: "Lyrics"
                font.pixelSize: 17
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: lyricList

                anchors.fill: parent
                visible: Lyrics.hasLyrics && !Lyrics.loading
                model: Lyrics.lyrics
                currentIndex: Lyrics.indexForTime((root.player?.position ?? 0))
                spacing: 6
                interactive: false
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: height / 2 - 14
                preferredHighlightEnd: height / 2 + 14
                highlightMoveDuration: 400

                delegate: Label {
                    id: line

                    required property string modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem

                    width: ListView.view.width
                    text: modelData || "♪"
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                    font.pixelSize: current ? 15 : 13
                    font.weight: current ? Font.Medium : Font.Normal
                    color: current ? root.col("onSurface", "#e6e6e6") : root.col("onSurfaceVariant", "#ababab")
                    opacity: current ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.player.position = Lyrics.timeForIndex(line.index)
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: !lyricList.visible
                spacing: 6

                Icon {
                    Layout.alignment: Qt.AlignHCenter
                    text: Lyrics.loading ? "hourglass_empty" : "sentiment_dissatisfied"
                    font.pixelSize: 44
                    color: root.col("onSurfaceVariant", "#ababab")
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: Lyrics.loading ? "Loading lyrics…" : "No lyrics found"
                    font.pixelSize: 15
                    color: root.col("onSurfaceVariant", "#ababab")
                }
            }
        }

        // Player selector: click to switch between players
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 38
            radius: 19
            color: Qt.lighter(root.col("secondaryContainer", "#3b3b3b"), selArea.containsMouse ? 1.15 : 1)

            RowLayout {
                anchors.centerIn: parent
                width: parent.width - 24
                spacing: 8

                Item { Layout.fillWidth: true }
                Icon {
                    text: "library_music"
                    font.pixelSize: 18
                    color: root.col("onSecondaryContainer", "#bfbfbf")
                }
                Label {
                    Layout.maximumWidth: 110
                    text: root.player?.identity ?? ""
                    font.pixelSize: 14
                    color: root.col("onSecondaryContainer", "#bfbfbf")
                }
                Item { Layout.fillWidth: true }
                Icon {
                    visible: root.players.length > 1
                    text: "swap_horiz"
                    font.pixelSize: 18
                    color: root.col("onSecondaryContainer", "#bfbfbf")
                }
            }

            MouseArea {
                id: selArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cyclePlayer()
            }
        }
    }
}
