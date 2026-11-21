using Toybox.Graphics;
using Toybox.Math;
using Toybox.Timer;
using Toybox.WatchUi;

import Toybox.Lang;

// Plays the made-up climb: the whole route in about two minutes, then a pause at the top, then again.
class View extends WatchUi.View {

    const TICK_MS = 250;
    const LOOP_SECONDS = 120.0;
    const HOLD_AT_TOP_SECONDS = 4.0;

    var page as Number = 0;
    // The section page 9 shows: -1 for the climber's, until the user steps with the chevrons.
    var sel as Number = -1;
    var paused as Boolean = false;
    var seconds as Float = 0.0;
    var timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        var t = new Timer.Timer();
        t.start(method(:tick), TICK_MS, true);
        timer = t;
    }

    function onHide() as Void {
        var t = timer;
        if (t != null) { t.stop(); }
        timer = null;
    }

    function tick() as Void {
        if (!paused) {
            seconds += TICK_MS / 1000.0;
            if (seconds > LOOP_SECONDS + HOLD_AT_TOP_SECONDS) { seconds = 0.0; }
        }
        WatchUi.requestUpdate();
    }

    function minute() as Float {
        var f = seconds / LOOP_SECONDS;
        if (f > 1.0) { f = 1.0; }
        return f * Climb.totalM();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var d = new Draw(dc);
        Pages.selected = sel;
        Pages.draw(page, d, new Climb.State(minute()));
        pageDots(d);
        if (paused) { d.text(208, 22, Graphics.FONT_XTINY, "PAUSED", 0xffd166); }
    }

    // Where this page sits among the others, as dots along the left edge.
    function pageDots(d as Draw) as Void {
        var n = Pages.COUNT;
        for (var i = 0; i < n; i++) {
            var a = Math.toRadians(180 + (i - (n - 1) / 2.0) * 5.0);
            var x = 208 + 198 * Math.cos(a), y = 208 - 198 * Math.sin(a);
            if (i == page) { d.dot(x, y, 4, Graphics.COLOR_WHITE); } else { d.dot(x, y, 2.5, 0x666666); }
        }
    }

    function nextPage(step as Number) as Void {
        page = (page + step + Pages.COUNT) % Pages.COUNT;
        sel = -1;
        WatchUi.requestUpdate();
    }

    // Page 9: step the selected section back or on, from the climber's at first, within the route.
    function stepSection(dir as Number) as Void {
        var i = (sel >= 0 ? sel : new Climb.State(minute()).cur) + dir;
        if (i < 0) { i = 0; }
        if (i > Climb.count() - 1) { i = Climb.count() - 1; }
        sel = i;
        WatchUi.requestUpdate();
    }

    function togglePause() as Void {
        paused = !paused;
        WatchUi.requestUpdate();
    }
}
