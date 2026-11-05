// Pebble: extra panels in the style of denonmaryland/omarchy-dotfiles, built to sit on
// top of Caelestia and follow its colours. Started from ~/.config/caelestia/hypr-user.lua.
//   qs -c pebble ipc call corner toggle      (Super+O, or push the pointer into the bottom-left corner)
//   qs -c pebble ipc call studio toggle      (Super+Shift+O)
//   qs -c pebble ipc call usage toggle       (Super+Ctrl+O)
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

ShellRoot {
    id: shell

    function focusedScreen(): var {
        const name = Hyprland.focusedMonitor?.name;
        return Quickshell.screens.find(s => s.name === name) ?? Quickshell.screens[0];
    }

    Corner {
        id: corner
        screen: shell.focusedScreen()
        onStudioRequested: shell.openDrawer(studio)
        onUsageRequested: shell.openDrawer(shell.usageDrawer)
    }

    Studio {
        id: studio
        screen: shell.focusedScreen()
    }

    Usage {
        id: usage
        screen: shell.focusedScreen()
    }
    readonly property var usageDrawer: usage

    function openDrawer(d: var): void {
        if (!d) return;
        corner.open = false;
        d.screen = focusedScreen();
        d.open = true;
    }

    function openCornerOn(s: var): void {
        if (corner.open && corner.screen === s) return;
        corner.open = false;
        corner.screen = s;
        corner.open = true;
    }

    IpcHandler {
        target: "corner"
        function toggle(): void {
            if (corner.open) corner.open = false;
            else shell.openCornerOn(shell.focusedScreen());
        }
        function open(): void { shell.openCornerOn(shell.focusedScreen()); }
        function close(): void { corner.open = false; }
    }
    IpcHandler {
        target: "studio"
        function toggle(): void { studio.open ? studio.open = false : shell.openDrawer(studio); }
    }
    IpcHandler {
        target: "usage"
        function toggle(): void { usage.open ? usage.open = false : shell.openDrawer(usage); }
        function refresh(): void { usage.refresh(); }
    }

    // Hot corner: a 2px target in each screen's bottom-left corner. A short dwell
    // avoids opening when the pointer just flicks past on its way somewhere else.
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: hot
            required property var modelData
            screen: modelData
            color: "transparent"
            anchors.left: true
            anchors.bottom: true
            implicitWidth: 2
            implicitHeight: 2
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "pebble-hotcorner"
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: dwell.restart()
                onExited: dwell.stop()
            }
            Timer { id: dwell; interval: 140; onTriggered: shell.openCornerOn(hot.modelData) }
        }
    }
}
