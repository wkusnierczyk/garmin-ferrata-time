using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;
using Toybox.Timer;
using Toybox.WatchUi;

import Toybox.Lang;

// Draws the climb the tracker follows, fed by the input the demo setting chooses: the demo plays the
// made-up climb (the whole route in about two minutes, a pause at the top, then again), the sensors
// read the watch.
class View extends WatchUi.View {

    // The demo moves fast, so it is read and drawn every 250 ms; the sensors once a second.
    const DEMO_TICK_MS = 250;
    const SENSOR_TICK_MS = 1000;
    // The page dots show for this long after the view appears (the app opening, or coming back from
    // the Ask list) or the page changes; counted down by the timer, not by the system clock, which wraps.
    const DOTS_MS = 2000;

    var page as Number = 0;
    // The section page 9 shows: -1 for the climber's, until the user steps with the chevrons.
    var sel as Number = -1;
    var timer as Timer.Timer?;
    var dotsMs as Number = 0;

    var route as Route?;
    var demo as Boolean = true;
    var input as Input?;
    var tracker as Tracker?;
    // The demo's clock, in milliseconds: it runs only while the climb is not paused, so a pause stops
    // the demo, as in 0.1.0.
    var demoMs as Number = 0;

    function initialize(r as Route?) {
        View.initialize();
        route = r;
        begin();
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

    function tickMs() as Number { return demo ? DEMO_TICK_MS : SENSOR_TICK_MS; }

    // The caller's clock the input reads: the demo's own, or the system's.
    function now() as Number { return demo ? demoMs : System.getTimer(); }

    // A new climb on the input the setting chooses: the demo from the head, synced there; the sensors
    // from wherever the climber is, unsynced, until the climb flow (#51) asks where.
    function begin() as Void {
        stop();
        var r = route;
        if (r == null) { return; }
        demo = Settings.demo();
        var in = Settings.input(r);
        input = in;
        demoMs = 0;
        var t = new Tracker(r);
        t.start(demo ? :head : :elsewhere, in.read(now()));
        tracker = t;
    }

    // After a change of setting: the new input, at its own rate.
    function restart() as Void {
        begin();
        sel = -1;
        if (timer != null) { startTimer(); }
    }

    // Lets go of the input (the GPS).
    function stop() as Void {
        var in = input;
        if (in != null) { in.stop(); }
        input = null;
    }

    function tick() as Void {
        if (dotsMs > 0) { dotsMs -= tickMs(); }
        var t = tracker, in = input;
        if (t != null && in != null) {
            if (demo && t.phase != Tracker.PAUSED) { demoMs += DEMO_TICK_MS; }
            if (demo && demoMs > DemoInput.LOOP_MS + DemoInput.HOLD_MS) {
                begin();
            } else {
                t.update(in.read(now()));
            }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var t = tracker;
        if (t == null) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
            dc.clear();
            dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_SMALL, "No route",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var d = new Draw(dc);
        Pages.selected = sel;
        Pages.draw(page, d, t.state());
        if (dotsMs > 0) { pageDots(d); }
        if (t.phase == Tracker.PAUSED) { d.text(208, 22, Graphics.FONT_XTINY, "PAUSED", 0xffd166); }
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
        dotsMs = DOTS_MS;
        sel = -1;
        WatchUi.requestUpdate();
    }

    // Page 9: step the selected section back or on, from the climber's at first, within the route.
    function stepSection(dir as Number) as Void {
        var t = tracker;
        if (t == null) { return; }
        var i = (sel >= 0 ? sel : t.state().cur) + dir;
        // Nothing that way: leave the selection as it is (still following the climber if it was).
        if (i < 0 || i > Climb.count() - 1) { return; }
        sel = i;
        WatchUi.requestUpdate();
    }

    // Start pauses or resumes the climb; in the demo, its clock stops with it.
    function togglePause() as Void {
        var t = tracker, in = input;
        if (t == null || in == null) { return; }
        var rd = in.read(now());
        if (t.phase == Tracker.PAUSED) { t.resume(rd); } else { t.pause(rd); }
        WatchUi.requestUpdate();
    }
}
