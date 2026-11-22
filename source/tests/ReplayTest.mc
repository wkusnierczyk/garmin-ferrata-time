using Toybox.Math;

import Toybox.Lang;
import Toybox.Test;

// The replay input (#57): a recording, as tools/fit2replay.py writes it, played back through the
// tracker faster than real time.
module ReplayTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // The demo's climb as a replay: its readings, read as the view reads it (every 250 ms of the demo
    // clock), then put on a 10 s grid as tools/fit2replay.py does with a recording: [t, alt, null,
    // null], the altitude interpolated and in whole metres (the demo route has no positions).
    function demoReplay(r as Route) as Array<Array> {
        var input = new DemoInput(r);
        var ts = [] as Array<Number>, alts = [] as Array<Float>;
        for (var ms = 0; ms <= DemoInput.LOOP_MS; ms += 250) {
            var rd = input.read(ms);
            if (ts.size() > 0 && rd.t <= ts[ts.size() - 1]) { continue; }
            ts.add(rd.t);
            alts.add(rd.alt as Float);
        }
        var out = [] as Array<Array>;
        var k = 0, n = ts.size();
        for (var t = ts[0]; t < ts[n - 1]; t += 10) {
            while (ts[k + 1] < t) { k++; }
            var f = (t - ts[k]).toFloat() / (ts[k + 1] - ts[k]);
            var alt = alts[k] + (alts[k + 1] - alts[k]) * f;
            out.add([t, Math.round(alt).toNumber(), null, null]);
        }
        out.add([ts[n - 1], Math.round(alts[n - 1]).toNumber(), null, null]);
        return out;
    }

    // A replay made from the demo's readings drives a tracker to the demo's own places (the plan's
    // bar: 15 m, on every climbing section, as the demo through the tracker), and to the top. Read as
    // the view reads the sensors, once a second, at the replay's speed: a minute of the climb a
    // reading.
    (:test)
    function replayMatchesDemo(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        var samples = demoReplay(r);
        var input = new ReplayInput(samples, ReplayInput.SPEED);
        var t = new Tracker(r);
        t.start(:head, input.read(0));
        Test.assertMessage(near(t.offset as Float, 12.0, 0.01), "synced at the head, offset " + t.offset);
        var last = samples[samples.size() - 1][0] as Number;
        var worst = 0.0, checked = 0;
        for (var ms = 1000; ; ms += 1000) {
            var rd = input.read(ms);
            t.update(rd);
            var st = new Climb.State((rd.t / 60.0 - Climb.START_CLOCK) / Climb.PACE);
            if (Climb.UP[st.cur] > 0) {
                var e = (t.d - st.d).abs();
                if (e > worst) { worst = e; }
                checked++;
                Test.assertMessage(e <= 15.0, "t " + rd.t + ": tracker " + t.d + ", demo " + st.d);
            }
            if (rd.t >= last) { break; }
        }
        logger.debug(samples.size() + " entries; checked " + checked + ", worst " + worst + " m");
        Test.assertMessage(checked > 50, "climbing readings checked: " + checked);
        Test.assertMessage(near(t.d, Climb.totalD().toFloat(), 0.01), "at the top, d " + t.d);
        return true;
    }

    // Between entries the values are interpolated by time; when the later entry lacks one, the earlier's
    // holds (none when that lacks it too). A position is both halves or none. Past the last entry the
    // replay holds there.
    (:test)
    function replayInterpolatesAndHolds(logger as Logger) as Boolean {
        var input = new ReplayInput([
            [100, 1000, null, null],
            [110, 1010, 46.0, 7.0],
            [120, 1030, 46.001, 7.002],
            [130, null, 46.002, null]
        ] as Array<Array>, 1);
        var rd = input.read(50000);
        Test.assertEqualMessage(rd.t, 100, "the first entry at the first reading");
        Test.assertMessage(near(rd.alt as Float, 1000.0, 1e-3), "alt " + rd.alt);
        Test.assertMessage(rd.lat == null && rd.lon == null, "no position yet");
        rd = input.read(55000);
        Test.assertEqualMessage(rd.t, 105, "5 s on");
        Test.assertMessage(near(rd.alt as Float, 1005.0, 1e-3), "alt half way " + rd.alt);
        Test.assertMessage(rd.lat == null, "no position until the entry with one");
        rd = input.read(65000);
        Test.assertMessage(near(rd.alt as Float, 1020.0, 1e-3), "alt " + rd.alt);
        Test.assertMessage(near(rd.lat as Float, 46.0005, 1e-5) && near(rd.lon as Float, 7.001, 1e-5),
            "position half way " + rd.lat + ", " + rd.lon);
        rd = input.read(75000);
        Test.assertMessage(near(rd.alt as Float, 1030.0, 1e-3), "alt held before a missing one " + rd.alt);
        // The last entry has half a position, so none: the one before holds.
        Test.assertMessage(near(rd.lat as Float, 46.001, 1e-5) && near(rd.lon as Float, 7.002, 1e-5),
            "position held " + rd.lat + ", " + rd.lon);
        rd = input.read(500000);
        Test.assertEqualMessage(rd.t, 130, "held at the last entry");
        Test.assertMessage(rd.alt == null && rd.lat == null && rd.lon == null, "the last entry's: nothing");
        return true;
    }

    // The clock runs at the speed given: at 60, a minute of the recording a second.
    (:test)
    function replaySpeedScalesTheClock(logger as Logger) as Boolean {
        var input = new ReplayInput([[30000, 1000, null, null], [33600, 1600, null, null]] as Array<Array>,
            ReplayInput.SPEED);
        Test.assertEqualMessage(ReplayInput.SPEED, 60, "60 by default");
        Test.assertEqualMessage(input.read(1000).t, 30000, "t0 at the first reading");
        var rd = input.read(2000);
        Test.assertEqualMessage(rd.t, 30060, "a minute on");
        Test.assertMessage(near(rd.alt as Float, 1010.0, 1e-3), "alt " + rd.alt);
        Test.assertEqualMessage(input.read(61000).t, 33600, "an hour in a minute");
        return true;
    }

    // An empty replay reads nothing, rather than failing.
    (:test)
    function emptyReplayReadsNothing(logger as Logger) as Boolean {
        var rd = new ReplayInput([] as Array<Array>, ReplayInput.SPEED).read(0);
        Test.assertMessage(rd.alt == null && rd.lat == null && rd.lon == null, "nothing");
        return true;
    }
}
