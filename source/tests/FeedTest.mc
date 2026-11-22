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

// The view's wiring (#50, from the review of #91): what a tick, Start and a change of setting do.
module FeedTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // The resume reading is taken while the tracker is still paused (the tracker's contract).
    (:test)
    function resumeReadsWhilePaused(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), false, true);
        f.togglePause();
        Test.assertMessage(f.paused(), "paused");
        f.togglePause();
        Test.assertMessage(!f.paused(), "resumed");
        var phases = (f.made[0] as FakeInput).phases;
        Test.assertEqualMessage(phases[phases.size() - 1], Tracker.PAUSED as Number, "read while paused");
        return true;
    }

    // In the demo, a pause stops its clock: no reading moves the tracker until Start again.
    (:test)
    function demoClockStopsWhilePaused(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        for (var k = 0; k < 40; k++) { f.tick(); }
        Test.assertEqualMessage(f.demoMs, 40 * Feed.DEMO_TICK_MS, "the clock ran");
        f.togglePause();
        var lastT = f.tracker.lastT, d = f.tracker.d;
        for (var k = 0; k < 40; k++) { f.tick(); }
        Test.assertEqualMessage(f.demoMs, 40 * Feed.DEMO_TICK_MS, "the clock stopped");
        Test.assertEqualMessage(f.tracker.lastT, lastT, "the climb's time stopped");
        Test.assertMessage(near(f.tracker.d, d, 0.001), "the place held");
        f.togglePause();
        f.tick();
        Test.assertEqualMessage(f.demoMs, 41 * Feed.DEMO_TICK_MS, "the clock runs again");
        Test.assertMessage(f.tracker.d > d, "the place moves again");
        return true;
    }

    // After the climb and the hold at the top, the demo starts again on a new input.
    (:test)
    function demoStartsAgainAfterHold(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, true);
        var first = f.tracker;
        var ticks = (DemoInput.LOOP_MS + DemoInput.HOLD_MS) / Feed.DEMO_TICK_MS;
        for (var k = 0; k < ticks; k++) { f.tick(); }
        Test.assertMessage(f.tracker == first, "still the first climb at the end of the hold");
        f.tick();
        Test.assertMessage(f.tracker != first, "a new climb");
        Test.assertEqualMessage(f.demoMs, 0, "the clock from 0");
        Test.assertEqualMessage(f.made.size(), 2, "a new input");
        Test.assertMessage((f.made[0] as FakeInput).stopped, "the old input let go");
        return true;
    }

    // A change of setting starts again on the new input, the old one let go; saving the settings with
    // nothing changed keeps the climb.
    (:test)
    function restartOnlyOnChange(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, true);
        var first = f.tracker;
        Test.assertMessage(!f.restart(), "nothing changed");
        Test.assertMessage(f.tracker == first && f.made.size() == 1, "the climb kept");
        Test.assertMessage(!(f.made[0] as FakeInput).stopped, "the input kept");
        f.wants = false;
        Test.assertMessage(f.restart(), "the demo turned off");
        Test.assertMessage(!f.demo && f.tracker != first, "a new climb on the sensors");
        Test.assertMessage((f.made[0] as FakeInput).stopped, "the old input let go");
        Test.assertMessage(f.input == f.made[1], "the new input in use");
        return true;
    }

    // The demo's pace and time left are 0.1.0's from the first minute, before the tracker trusts a pace
    // of its own (10 guidebook minutes), and after.
    (:test)
    function demoTimeLeftMatches010(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
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

    // The setting chooses the input. Not in a replay build, where the replay takes the sensors' place.
    (:test, :noreplay)
    function demoSettingChoosesInput(logger as Logger) as Boolean {
        var was = Settings.demo();
        Settings.setDemo(false);
        Test.assertMessage(!Settings.demo(), "off");
        var f = new Feed(RouteTest.demo());
        Test.assertMessage(f.input instanceof SensorInput, "sensors when off");
        Settings.setDemo(true);
        Test.assertMessage(Settings.demo(), "on");
        Test.assertMessage(f.restart(), "started again");
        Test.assertMessage(f.input instanceof DemoInput, "the demo when on");
        f.stop();
        Settings.setDemo(was);
        return true;
    }
}
