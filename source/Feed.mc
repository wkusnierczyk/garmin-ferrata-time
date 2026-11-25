using Toybox.System;
using Toybox.WatchUi;

import Toybox.Lang;

// The input the demo setting chooses, feeding the tracker: what the view does each tick, and what the
// climb flow's menus (FlowMenus, #51) do to the climb, kept out of the view so the tests can drive it.
// A climb waits on the ready screen until the climber starts it where they are; the demo, at 0.1.0's
// pace, plays the part started from its start (its watch 12 m low, so the calibration shows as the
// offset) and holds at the top until the climber ends it. A replay build (make run REPLAY=1,
// replay.jungle) plays its recording in the sensors' place, whatever the setting says.
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
    (:noreplay)
    function wantsDemo() as Boolean { return Settings.demo(); }

    (:replay)
    function wantsDemo() as Boolean { return false; }

    function newInput(isDemo as Boolean) as Input {
        return isDemo ? new DemoInput(route) as Input : sensors();
    }

    // The watch's sensors; in a replay build, the recording (resources-replay/replay.json).
    (:noreplay)
    function sensors() as Input { return new SensorInput(); }

    (:replay)
    function sensors() as Input {
        return new ReplayInput(WatchUi.loadResource(Rez.JsonData.replay) as Array<Array>, ReplayInput.SPEED);
    }

    // Whether the climb may be recorded as a Garmin activity (the Recorder, #53, keys on this, not on
    // demo): never in the demo, never in a replay build, whose input is not the watch's.
    (:noreplay)
    function records() as Boolean { return !demo; }

    (:replay)
    function records() as Boolean { return false; }

    function tickMs() as Number { return demo ? DEMO_TICK_MS : SENSOR_TICK_MS; }

    // The clock the input reads: the demo's own, or the system's.
    function now() as Number { return demo ? demoMs : System.getTimer(); }

    // A new climb on the input the setting chooses, the old input let go.
    function begin() as Void {
        input.stop();
        demo = wantsDemo();
        input = newInput(demo);
        ready();
    }

    // A new climb, not started: the ready screen. The demo's watch reads where a start at an altitude
    // would begin (the approach's start, when the route has one).
    function ready() as Void {
        demoMs = 0;
        var t = new Tracker(route);
        if (demo) { t.basePace = Climb.PACE; }
        tracker = t;
        if (demo) { demoPart(!route.hasApproach()); }
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

    // On the approach or the ferrata, not paused.
    function running() as Boolean { return tracker.phase == Tracker.APPROACH || tracker.phase == Tracker.ASCENT; }

    // Between the start and the end.
    function climbing() as Boolean { return running() || paused(); }

    // One tick: the demo's clock moves on while the climb runs (it holds at the top when it gets
    // there); a started climb takes a reading. Before the start nothing is read, so a replay plays
    // from its first entry when the climb starts.
    function tick() as Void {
        if (demo && running()) { demoMs += DEMO_TICK_MS; }
        if (climbing()) { tracker.update(reading()); }
    }

    function reading() as Reading { return input.read(now()); }

    // ---------------------------------------------------------------- the climb flow (#51)

    // Start at the head or at the approach's start (:head, :approachPoint), calibrated to it.
    function start(where as Symbol) as Void {
        if (demo) { demoPart(where == :head); }
        tracker.start(where, reading());
    }

    // Start at an altitude the climber entered.
    function startAt(known as Float) as Void {
        if (demo) { demoPart(!route.hasApproach()); }
        tracker.startAt(known, reading());
    }

    // From the approach onto the ferrata, calibrated at the head.
    function startAscent() as Void {
        if (demo) { demoPart(true); }
        tracker.startAscent(reading());
    }

    // A pause's readings are taken first; a resume's while still paused, as the tracker's resume wants.
    function pause() as Void { tracker.pause(reading()); }

    function resume() as Void { tracker.resume(reading()); }

    // A calibration, at a point or to an altitude entered; the climb goes on from it.
    function calibrateAt(point as Number) as Void {
        var rd = reading();
        tracker.syncAt(point, rd);
        tracker.resume(rd);
    }

    function calibrateTo(known as Float) as Void {
        var rd = reading();
        tracker.calibrateTo(known, rd);
        tracker.resume(rd);
    }

    // End at a point, or here (-1); Resume on the summary undoes it.
    function end(point as Number) as Void { tracker.end(point, reading()); }

    function unend() as Void { tracker.unend(); }

    // Save or discard the ended climb, then the ready screen. The Recorder (#53) saves or discards the
    // activity here; until then nothing is recorded.
    function save() as Void { ready(); }

    function discard() as Void { ready(); }

    // The demo plays one part from its start: the ferrata from the head, or the approach from its
    // start, its clock from 0 and its time of day going on from where it was.
    function demoPart(ferrata as Boolean) as Void {
        Climb.use(route, ferrata || !route.hasApproach() ? :ferrata : :approach);
        demoMs = 0;
        if (input instanceof DemoInput) { (input as DemoInput).restart(); }
    }
}
