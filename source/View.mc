using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

import Toybox.Lang;

// Draws the climb the tracker follows, fed by the input the demo setting chooses: the demo plays the
// made-up climb (a part of the route in about two minutes, then a hold at its end), the sensors read
// the watch. The climb flow (#51) has the screen before the start, on the approach (#121), after the
// end and while anything of it is open; the pages have it on the ferrata.
class View extends WatchUi.View {

    // The page dots show for this long after the view appears (the app opening, or coming back from
    // the Ask list) or the page changes; counted down by the timer, not by the system clock, which wraps.
    const DOTS_MS = 2000;

    var page as Number = 0;
    // The section page 15 shows: -1 for the climber's, until the user steps with the chevrons. Reset
    // when the part shown changes (the approach or the ferrata), whose sections are others.
    var sel as Number = -1;
    var ferrataShown as Boolean = true;
    var climbShown as Tracker? = null;
    var timer as Timer.Timer?;
    var dotsMs as Number = 0;

    // The input feeding the tracker, and the climb flow's menus; null without a route.
    var feed as Feed?;
    var flow as FlowMenus?;

    function initialize(r as Route?) {
        View.initialize();
        if (r != null) {
            var f = new Feed(r);
            feed = f;
            flow = new FlowMenus(f);
        }
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
        var fl = flow;
        if (fl != null) { fl.reset(); }
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
        var fl = flow;
        if (fl != null) {
            fl.tick(tickMs());
            leaveIfClosed(fl);
        }
        WatchUi.requestUpdate();
    }

    // After Back on the ready screen (#121), the app leaves.
    function leaveIfClosed(fl as FlowMenus) as Void {
        if (fl.quit) { System.exit(); }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var f = feed, fl = flow;
        if (f == null || fl == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, "No route",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var d = new Draw(dc);
        if (FlowDraw.draw(d, fl)) { return; }
        followPart();
        Pages.selected = sel;
        Pages.draw(page, d, f.tracker.state());
        if (dotsMs > 0) { pageDots(d); }
        if (f.paused()) { FlowDraw.band(d); }
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
        var fl = flow;
        page = fl != null ? fl.stepPage(page, step, Pages.COUNT) : (page + step + Pages.COUNT) % Pages.COUNT;
        dotsMs = DOTS_MS;
        sel = -1;
        WatchUi.requestUpdate();
    }

    // Page 15: step the selected section back or on, from the climber's at first, within the route.
    function stepSection(dir as Number) as Void {
        var f = feed;
        if (f == null) { return; }
        var i = (sel >= 0 ? sel : f.tracker.state().cur) + dir;
        // Nothing that way: leave the selection as it is (still following the climber if it was).
        if (i < 0 || i > Climb.count() - 1) { return; }
        sel = i;
        WatchUi.requestUpdate();
    }

    // From the approach to the ferrata or back, the sections are others, and a new climb starts with
    // the climber's own: page 15 follows the climber's again (the reviews of #88 and #114).
    function followPart() as Void {
        if (Climb.FERRATA != ferrataShown) {
            ferrataShown = Climb.FERRATA;
            sel = -1;
            // Onto the ferrata, its first page (the flow mock). Not onto the approach: this runs only
            // when the pages draw, after Up on F4 has already picked the last page (Codex, #124).
            if (Climb.FERRATA) { page = 0; }
        }
        var f = feed;
        if (f != null && f.tracker != climbShown) {
            climbShown = f.tracker;
            sel = -1;
        }
    }

    // Whether the climb flow has the screen, and with it Up and Down.
    function flowOnScreen() as Boolean {
        var fl = flow;
        return fl != null && fl.onScreen();
    }

    // A button for the climb flow (:start, :back, :up, :down); false when it does not take it.
    function press(key as Symbol) as Boolean {
        var fl = flow;
        if (fl == null) { return key != :back; }
        var taken = fl.press(key);
        leaveIfClosed(fl);
        WatchUi.requestUpdate();
        return taken;
    }
}
