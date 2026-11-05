import QtQuick

// Mouse handling for the three capture modes
MouseArea {
    id: ia

    required property var app
    required property string screenName
    required property real screenX
    required property real screenY

    property string op: ""
    property string hoverOp: "new"
    property real px
    property real py
    property rect start
    property string startScreen

    function clamp(v: real, lo: real, hi: real): real {
        return Math.max(lo, Math.min(hi, v));
    }

    function hitTest(x: real, y: real): string {
        if (app.mode !== "area" || app.selScreen !== screenName)
            return "new";
        const s = app.sel, r = 14;
        const corners = [["tl", s.x, s.y], ["tr", s.x + s.width, s.y], ["bl", s.x, s.y + s.height], ["br", s.x + s.width, s.y + s.height]];
        for (const [n, cx, cy] of corners)
            if (Math.abs(x - cx) <= r && Math.abs(y - cy) <= r)
                return n;
        if (x >= s.x && x <= s.x + s.width && y >= s.y && y <= s.y + s.height)
            return "move";
        return "new";
    }

    function rectFrom(ax: real, ay: real, bx: real, by: real): rect {
        bx = clamp(bx, 0, width);
        by = clamp(by, 0, height);
        return Qt.rect(Math.min(ax, bx), Math.min(ay, by), Math.abs(bx - ax), Math.abs(by - ay));
    }

    hoverEnabled: true
    cursorShape: {
        if (app.mode !== "area")
            return Qt.PointingHandCursor;
        switch (pressed ? op : hoverOp) {
        case "tl":
        case "br":
            return Qt.SizeFDiagCursor;
        case "tr":
        case "bl":
            return Qt.SizeBDiagCursor;
        case "move":
            return pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
        default:
            return Qt.CrossCursor;
        }
    }

    onPressed: mouse => {
        if (app.mode === "screen") {
            app.pickedScreen = screenName;
            return;
        }
        if (app.mode === "window") {
            const w = app.windowAt(screenX + mouse.x, screenY + mouse.y);
            if (w)
                app.pickedWindow = w;
            return;
        }
        op = hitTest(mouse.x, mouse.y);
        px = mouse.x;
        py = mouse.y;
        start = app.sel;
        startScreen = app.selScreen;
        if (op === "new") {
            app.selScreen = screenName;
            app.sel = Qt.rect(px, py, 0, 0);
        }
    }

    onPositionChanged: mouse => {
        if (!pressed) {
            hoverOp = hitTest(mouse.x, mouse.y);
            return;
        }
        if (app.mode !== "area")
            return;
        const s = start;
        switch (op) {
        case "new":
            app.sel = rectFrom(px, py, mouse.x, mouse.y);
            break;
        case "move":
            app.sel = Qt.rect(clamp(s.x + mouse.x - px, 0, width - s.width), clamp(s.y + mouse.y - py, 0, height - s.height), s.width, s.height);
            break;
        case "tl":
            app.sel = rectFrom(s.x + s.width, s.y + s.height, mouse.x, mouse.y);
            break;
        case "tr":
            app.sel = rectFrom(s.x, s.y + s.height, mouse.x, mouse.y);
            break;
        case "bl":
            app.sel = rectFrom(s.x + s.width, s.y, mouse.x, mouse.y);
            break;
        case "br":
            app.sel = rectFrom(s.x, s.y, mouse.x, mouse.y);
            break;
        }
    }

    onReleased: {
        // A plain click (no drag) keeps the previous selection
        if (op === "new" && (app.sel.width < 4 || app.sel.height < 4) && startScreen) {
            app.selScreen = startScreen;
            app.sel = start;
        }
        op = "";
        hoverOp = hitTest(mouseX, mouseY);
    }

    onDoubleClicked: app.capture()
}
