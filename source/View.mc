using Toybox.Graphics;
using Toybox.Math;
using Toybox.Timer;
using Toybox.WatchUi;

import Toybox.Lang;

// Draws the climb the tracker follows, fed by the input the demo setting chooses: the demo plays the
// made-up climb (the whole route in about two minutes, a pause at the top, then again), the sensors
// read the watch.
class View extends WatchUi.View {

    // The page dots show for this long after the view appears (the app opening, or coming back from
    // the Ask list) or the page changes; counted down by the timer, not by the system clock, which wraps.
    const DOTS_MS = 2000;

    var page as Number = 0;
    // The section page 9 shows: -1 for the climber's, until the user steps with the chevrons.
    var sel as Number = -1;
    var timer as Timer.Timer?;
    var dotsMs as Number = 0;

    // The input feeding the tracker; null without a route.
    var feed as Feed?;

    function initialize(r as Route?) {
        View.initialize();
        if (r != null) { feed = new Feed(r); }
    }

    function onShow() as Void {
        dotsMs = DOTS_MS;
        startTimer();
    }

    function onHide() as Void {
        var t = timer;
        if (t != null) { t.stop(); }
        timer = null;
    }

    function startTimer() as Void {
        onHide();
        var t = new Timer.Timer();
        t.start(method(:tick), tickMs(), true);
        timer = t;
    }

    function tickMs() as Number {
        var f = feed;
        return f != null ? f.tickMs() : Feed.SENSOR_TICK_MS;
    }

    // After a change of setting: the new input, at its own rate; nothing when the input stays.
    function restart() as Void {
        var f = feed;
        if (f == null || !f.restart()) { return; }
        sel = -1;
        if (timer != null) { startTimer(); }
    }

    // Lets go of the input (the GPS).
    function stop() as Void {
        var f = feed;
        if (f != null) { f.stop(); }
    }

    function tick() as Void {
        if (dotsMs > 0) { dotsMs -= tickMs(); }
        var f = feed;
        if (f != null) { f.tick(); }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var f = feed;
        if (f == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, "No route",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var d = new Draw(dc);
        Pages.selected = sel;
        Pages.draw(page, d, f.tracker.state());
        if (dotsMs > 0) { pageDots(d); }
        if (f.paused()) { d.text(0.5, 0.052885, d.semi(0.0529), "PAUSED", 0xffd166); }
    }

    // Where this page sits among the others, as dots along the left edge.
    function pageDots(d as Draw) as Void {
        var n = Pages.COUNT;
        for (var i = 0; i < n; i++) {
            var a = Math.toRadians(180 + (i - (n - 1) / 2.0) * 5.0);
            var x = 0.5 + 0.475962 * Math.cos(a), y = 0.5 - 0.475962 * Math.sin(a);
            if (i == page) { d.dot(x, y, 0.009615, Graphics.COLOR_WHITE); } else { d.dot(x, y, 0.00601, 0x666666); }
        }
    }

    function nextPage(step as Number) as Void {
        page = (page + step + Pages.COUNT) % Pages.COUNT;
        dotsMs = DOTS_MS;
        sel = -1;
        WatchUi.requestUpdate();
    }

    // Page 9: step the selected section back or on, from the climber's at first, within the route.
    function stepSection(dir as Number) as Void {
        var f = feed;
        if (f == null) { return; }
        var i = (sel >= 0 ? sel : f.tracker.state().cur) + dir;
        // Nothing that way: leave the selection as it is (still following the climber if it was).
        if (i < 0 || i > Climb.count() - 1) { return; }
        sel = i;
        WatchUi.requestUpdate();
    }

    // Start pauses or resumes the climb; in the demo, its clock stops with it.
    function togglePause() as Void {
        var f = feed;
        if (f == null) { return; }
        f.togglePause();
        WatchUi.requestUpdate();
    }
}
