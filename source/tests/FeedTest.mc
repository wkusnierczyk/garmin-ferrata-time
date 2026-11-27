using Toybox.Application.Properties;

import Toybox.Lang;
import Toybox.Test;

// An input that reads the watch at 1290 m, t from the caller's clock, and keeps what it was asked:
// the tracker's phase at each reading, and whether it was let go.
class FakeInput extends Input {

    var feed as Feed;
    var phases as Array<Number> = [] as Array<Number>;
    var stopped as Boolean = false;

    function initialize(f as Feed) {
        Input.initialize();
        feed = f;
    }

    function read(now as Number) as Reading {
        phases.add(feed.tracker.phase as Number);
        return new Reading(1290.0, null, null, 30000 + now / 1000);
    }

    function stop() as Void {
        stopped = true;
    }
}

// A feed whose setting is a field and whose inputs are fakes (or the real ones, with fake false).
class TestFeed extends Feed {

    var wants as Boolean = true;
    var fake as Boolean = true;
    var made as Array<Input> = [] as Array<Input>;

    function initialize(r as Route, w as Boolean, f as Boolean) {
        wants = w;
        fake = f;
        Feed.initialize(r);
    }

    function wantsDemo() as Boolean { return wants; }

    function newInput(isDemo as Boolean) as Input {
        var i = fake ? new FakeInput(self) as Input : Feed.newInput(isDemo);
        made.add(i);
        return i;
    }
}

// The view's wiring (#50, from the review of #91): what a tick and Start do, and the input each app reads.
module FeedTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // The resume reading is taken while the tracker is still paused (the tracker's contract).
    (:test)
    function resumeReadsWhilePaused(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), false, true);
        f.start(:head);
        f.pause();
        Test.assertMessage(f.paused(), "paused");
        f.resume();
        Test.assertMessage(!f.paused(), "resumed");
        var phases = (f.made[0] as FakeInput).phases;
        Test.assertEqualMessage(phases[phases.size() - 1], Tracker.PAUSED as Number, "read while paused");
        return true;
    }

    // In the demo, a pause stops its clock: no reading moves the tracker until Start again.
    (:test)
    function demoClockStopsWhilePaused(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        f.start(:head);
        for (var k = 0; k < 40; k++) { f.tick(); }
        Test.assertEqualMessage(f.demoMs, 40 * Feed.DEMO_TICK_MS, "the clock ran");
        f.pause();
        var lastT = f.tracker.lastT, d = f.tracker.d;
        for (var k = 0; k < 40; k++) { f.tick(); }
        Test.assertEqualMessage(f.demoMs, 40 * Feed.DEMO_TICK_MS, "the clock stopped");
        Test.assertEqualMessage(f.tracker.lastT, lastT, "the climb's time stopped");
        Test.assertMessage(near(f.tracker.d, d, 0.001), "the place held");
        f.resume();
        f.tick();
        Test.assertEqualMessage(f.demoMs, 41 * Feed.DEMO_TICK_MS, "the clock runs again");
        Test.assertMessage(f.tracker.d > d, "the place moves again");
        return true;
    }

    // A climb waits on the ready screen: nothing is read until it starts (#51), so a replay plays from
    // its first entry when the climb starts.
    (:test)
    function nothingReadBeforeStart(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), false, true);
        for (var k = 0; k < 10; k++) { f.tick(); }
        Test.assertEqualMessage(f.tracker.phase, Tracker.IDLE, "ready");
        Test.assertEqualMessage((f.made[0] as FakeInput).phases.size(), 0, "nothing read");
        f.start(:head);
        f.tick();
        Test.assertEqualMessage(f.tracker.phase, Tracker.ASCENT, "started");
        Test.assertMessage((f.made[0] as FakeInput).phases.size() > 0, "read once started");
        return true;
    }

    // The demo holds at the top until the climber ends the climb (#51); it no longer starts again.
    (:test)
    function demoHoldsAtTheTop(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        f.start(:head);
        var first = f.tracker;
        var ticks = (DemoInput.LOOP_MS + 4000) / Feed.DEMO_TICK_MS;
        for (var k = 0; k < ticks; k++) { f.tick(); }
        Test.assertMessage(f.tracker == first, "the same climb");
        Test.assertMessage(near(f.tracker.d, Climb.totalD().toFloat(), 0.01), "at the top, d " + f.tracker.d);
        Test.assertEqualMessage(f.made.size(), 1, "the same input");
        return true;
    }

    // The demo plays the approach from its start, then the ferrata from the head, each calibrated at
    // its start against the demo's watch, 12 m low: the offset 12 m both times, so no drift; its clock
    // goes on from the approach's end.
    (:test)
    function demoApproachThenFerrata(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        f.start(:approachPoint);
        Test.assertMessage(!Climb.FERRATA, "the approach in use");
        Test.assertMessage(near(f.tracker.offset as Float, 12.0, 0.01), "offset " + f.tracker.offset);
        for (var k = 0; k < 40; k++) { f.tick(); }
        var t = f.tracker.lastT;
        f.startAscent();
        Test.assertMessage(Climb.FERRATA, "the ferrata in use");
        Test.assertMessage(near(f.tracker.offset as Float, 12.0, 0.01), "offset " + f.tracker.offset);
        Test.assertEqualMessage(f.tracker.drifts.size(), 1, "a calibration at the head");
        Test.assertMessage(near(f.tracker.drifts[0], 0.0, 0.01), "no drift: " + f.tracker.drifts);
        Test.assertMessage(f.tracker.lastT >= t, "the clock goes on, " + f.tracker.lastT + " after " + t);
        return true;
    }

    // Save and Discard leave a new climb on the ready screen.
    (:test)
    function saveLeavesReadyClimb(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), false, true);
        f.start(:head);
        f.end(-1);
        var first = f.tracker;
        f.save();
        Test.assertMessage(f.tracker != first && f.tracker.phase == Tracker.IDLE, "a new climb, ready");
        Test.assertEqualMessage(f.made.size(), 1, "the same input");
        return true;
    }

    // The demo's pace and time left are 0.1.0's from the first minute, before the tracker trusts a pace
    // of its own (10 guidebook minutes), and after.
    (:test)
    function demoTimeLeftMatches010(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        f.start(:head);
        var input = f.input as DemoInput;
        var marks = [2.0, 12.0] as Array<Float>;
        for (var i = 0; i < marks.size(); i++) {
            while (input.minute < marks[i]) { f.tick(); }
            var st = f.tracker.state(), old = new Climb.State(input.minute);
            Test.assertMessage(near(st.left(), old.left(), 0.1),
                "minute " + input.minute + ": left " + st.left() + ", 0.1.0 " + old.left());
            Test.assertMessage(near(st.clock(), old.clock(), 0.1),
                "minute " + input.minute + ": clock " + st.clock() + ", 0.1.0 " + old.clock());
        }
        return true;
    }

    // The demo never records; the sensors may (the Recorder, #53, keys on records()). Not in a replay
    // build, where nothing records (ReplayTest.replayBuildPlaysTheRecording).
    (:test, :noreplay)
    function onlyTheSensorsRecord(logger as Logger) as Boolean {
        Test.assertMessage(!(new TestFeed(RouteTest.demo(), true, true)).records(), "the demo");
        Test.assertMessage((new TestFeed(RouteTest.demo(), false, true)).records(), "the sensors");
        return true;
    }

    // Ferrata reads the sensors and may record (#140): no setting, fixed when the app is built. Not in
    // a replay build, where the replay takes the sensors' place (ReplayTest.replayBuildPlaysTheRecording).
    (:test, :noreplay, :nodemo)
    function appReadsTheSensors(logger as Logger) as Boolean {
        var f = new Feed(RouteTest.demo());
        Test.assertMessage(!f.demo && f.input instanceof SensorInput, "the sensors");
        Test.assertMessage(f.records(), "recorded");
        Test.assertEqualMessage(f.tickMs(), Feed.SENSOR_TICK_MS, "read once a second");
        f.stop();
        return true;
    }

    // Ferrata Demo plays the demo and never records (#140; make test DEMO=1).
    (:test, :demo)
    function demoAppPlaysTheDemo(logger as Logger) as Boolean {
        var f = new Feed(RouteTest.demo());
        Test.assertMessage(f.demo && f.input instanceof DemoInput, "the demo");
        Test.assertMessage(!f.records(), "never recorded");
        Test.assertEqualMessage(f.tickMs(), Feed.DEMO_TICK_MS, "read every 250 ms");
        return true;
    }

    // The properties resource is there, so a property can be read at all (playbook,
    // reference/settings.md): an unknown key raises an exception the app can catch (with no property
    // table the failure cannot be caught), and the marker reads back as a Number.
    (:test)
    function propertiesResourceDeclared(logger as Logger) as Boolean {
        var caught = false;
        try { Properties.getValue("noSuchProperty"); } catch (e) { caught = true; }
        Test.assertMessage(caught, "an unknown key raises a catchable exception");
        var marker = Properties.getValue("settingsSchema");
        Test.assertMessage(marker instanceof Number, "the settingsSchema marker reads back as a Number, not " + marker);
        return true;
    }
}
