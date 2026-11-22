using Toybox.System;

import Toybox.Lang;

// The input the demo setting chooses, feeding the tracker: what the view does each tick, kept out of
// the view so the tests can drive it. The demo starts at the head (synced, so its 12 m low watch shows
// as the offset) at 0.1.0's pace, and starts again after the hold at the top; the sensors start from
// wherever the climber is, unsynced, until the climb flow (#51) asks where.
class Feed {

    // The demo moves fast, so it is read every 250 ms; the sensors once a second.
    static const DEMO_TICK_MS = 250;
    static const SENSOR_TICK_MS = 1000;

    var route as Route;
    var demo as Boolean = true;
    var input as Input;
    var tracker as Tracker;
    // The demo's clock, in milliseconds: it runs only while the climb is not paused, so a pause stops
    // the demo, as in 0.1.0.
    var demoMs as Number = 0;

    function initialize(r as Route) {
        route = r;
        // Set by begin(); the placeholders keep the fields non-null for the type checker.
        input = new Input();
        tracker = new Tracker(r);
        begin();
    }

    // What the setting says, and the input for it: the tests replace both.
    function wantsDemo() as Boolean { return Settings.demo(); }

    function newInput(isDemo as Boolean) as Input {
        return isDemo ? new DemoInput(route) as Input : new SensorInput() as Input;
    }

    function tickMs() as Number { return demo ? DEMO_TICK_MS : SENSOR_TICK_MS; }

    // The clock the input reads: the demo's own, or the system's.
    function now() as Number { return demo ? demoMs : System.getTimer(); }

    // A new climb on the input the setting chooses; the old input is let go.
    function begin() as Void {
        input.stop();
        demo = wantsDemo();
        input = newInput(demo);
        demoMs = 0;
        var t = new Tracker(route);
        if (demo) { t.basePace = Climb.PACE; }
        t.start(demo ? :head : :elsewhere, input.read(now()));
        tracker = t;
    }

    // After the settings change: a new climb only when the input changes, so saving the settings on the
    // phone with nothing changed keeps the climb. True when it started again.
    function restart() as Boolean {
        if (wantsDemo() == demo) { return false; }
        begin();
        return true;
    }

    // Lets go of the input (the GPS).
    function stop() as Void {
        input.stop();
    }

    function paused() as Boolean { return tracker.phase == Tracker.PAUSED; }

    // One tick: the demo's clock moves on unless paused, and starts again after the hold at the top;
    // the tracker takes a reading.
    function tick() as Void {
        if (demo && !paused()) { demoMs += DEMO_TICK_MS; }
        if (demo && demoMs > DemoInput.LOOP_MS + DemoInput.HOLD_MS) {
            begin();
            return;
        }
        tracker.update(input.read(now()));
    }

    // Start pauses or resumes the climb. The reading is taken first, while still paused on a resume,
    // as the tracker's resume wants.
    function togglePause() as Void {
        var rd = input.read(now());
        if (paused()) { tracker.resume(rd); } else { tracker.pause(rd); }
    }
}
