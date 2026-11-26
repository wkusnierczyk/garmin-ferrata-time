using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;

import Toybox.Lang;
import Toybox.Test;

// The inputs (#50): the demo input plays 0.1.0's climb as readings, the sensor input reads the watch,
// and the setting's choice is in FeedTest.
module InputsTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // The demo through the tracker keeps to the demo's own place on every climbing and descending
    // section (the plan's bar: 15 m; within a metre on the steep descent), and ends at the top. Driven
    // as the view drives it, a reading every tick.
    (:test)
    function demoThroughTrackerFollowsDemoClock(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        var input = new DemoInput(r);
        var t = new Tracker(r);
        t.start(:head, input.read(0));
        var worst = 0.0, checked = 0, worstDown = 0.0, down = 0;
        for (var ms = 250; ms <= DemoInput.LOOP_MS + 4000; ms += 250) {
            t.update(input.read(ms));
            var st = new Climb.State(input.minute);
            if (Climb.UP[st.cur] == 0) { continue; }
            var e = (t.d - st.d).abs();
            if (Climb.UP[st.cur] > 0) {
                if (e > worst) { worst = e; }
                checked++;
            } else {
                if (e > worstDown) { worstDown = e; }
                down++;
            }
            Test.assertMessage(e <= 15.0, "minute " + input.minute + ": tracker " + t.d + ", demo " + st.d);
        }
        logger.debug("checked " + checked + ", worst " + worst + " m; descending " + down + ", worst " + worstDown + " m");
        Test.assertMessage(checked > 100, "climbing readings checked: " + checked);
        Test.assertMessage(down > 50, "descending readings checked: " + down);
        // The Dihedral falls 4.4 m a metre along, so the height alone places the climber to a fraction of
        // a metre there: a metre is room enough, and lag on the descent shows (the review of #101).
        Test.assertMessage(worstDown <= 1.0, "on the descent, worst " + worstDown + " m");
        Test.assertMessage(near(t.d, Climb.totalD().toFloat(), 0.01), "at the top, d " + t.d);
        return true;
    }

    // The demo's vertical pace weighs a descent by its height, as a climb (the review of #101): the
    // Dihedral, down 110 m at grade 7, takes as long as a climb of 110 m at grade 7, not a moment as a
    // flat stretch; a flat one weighs 5 m.
    (:test)
    function demoDescentTakesItsHeight(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        Test.assertEqualMessage(Climb.NAME[3], "Dihedral", "the Dihedral");
        var grade7 = Math.pow(1.1, 3.5).toFloat();
        Test.assertMessage(near(Climb.demoWeight(3), 110 * grade7, 0.01), "the Dihedral " + Climb.demoWeight(3));
        Test.assertMessage(Climb.GRADE[1] < 0 && near(Climb.demoWeight(1), 5.0, 0.01), "the Ledge " + Climb.demoWeight(1));
        // Its share of the demo's two minutes: as its weight's share of the whole.
        var w = 0.0;
        for (var i = 0; i < Climb.count(); i++) { w += Climb.demoWeight(i); }
        var f0 = 0.0;
        for (var i = 0; i < 3; i++) { f0 += Climb.demoWeight(i) / w; }
        var f1 = f0 + Climb.demoWeight(3) / w;
        Test.assertMessage(near(Climb.demoMinute(f0), Climb.mAt(3).toFloat(), 0.01), "the Dihedral starts " + Climb.demoMinute(f0));
        Test.assertMessage(near(Climb.demoMinute(f1), Climb.mAt(4).toFloat(), 0.01), "and ends " + Climb.demoMinute(f1));
        Test.assertMessage((f1 - f0) * DemoInput.LOOP_MS > 10000, "over 10 s of the demo: " + (f1 - f0) * DemoInput.LOOP_MS + " ms");
        return true;
    }

    // The demo's watch reads 12 m low, so the sync at the head is visible; the clock starts at 0.1.0's
    // 08:22.
    (:test)
    function demoInputStartsTwelveMetresLow(logger as Logger) as Boolean {
        var input = new DemoInput(RouteTest.demo());
        var rd = input.read(0);
        Test.assertMessage(near(rd.alt as Float, 1278.0, 0.01), "alt " + rd.alt);
        Test.assertEqualMessage(rd.t, Climb.START_CLOCK * 60, "t at 08:22");
        // The demo route has no positions.
        Test.assertMessage(rd.lat == null && rd.lon == null, "no position");
        var t = new Tracker(RouteTest.demo());
        t.start(:head, rd);
        Test.assertMessage(near(t.offset as Float, 12.0, 0.01), "offset " + t.offset);
        return true;
    }

    // The clock runs at the demo's pace: minute m of the guidebook at m x PACE minutes past 08:22.
    // At the end it holds at the top.
    (:test)
    function demoInputEndsAtTheTop(logger as Logger) as Boolean {
        var input = new DemoInput(RouteTest.demo());
        input.read(0);
        var rd = input.read(DemoInput.LOOP_MS);
        Test.assertMessage(near(rd.alt as Float, 1568.0, 0.01), "alt " + rd.alt);
        var end = Math.round((Climb.START_CLOCK + Climb.totalM() * Climb.PACE) * 60).toNumber();
        Test.assertEqualMessage(rd.t, end, "t at the top");
        var later = input.read(DemoInput.LOOP_MS + 4000);
        Test.assertEqualMessage(later.t, end, "the clock holds at the top");
        return true;
    }

    // Between points with coordinates the position is interpolated by distance; before the first and
    // past the last it is theirs.
    (:test)
    function demoInputInterpolatesPosition(logger as Logger) as Boolean {
        var r = RouteTest.made([[100, 100], [100, 100]]);
        r.points[0]["lat"] = 46.0;
        r.points[0]["lon"] = 7.0;
        r.points.add({"kind" => "landmark", "at" => 100, "alt" => 1100, "name" => "Mid",
            "lat" => 46.01, "lon" => 7.02});
        var input = new DemoInput(r);
        var p = input.positionAt(50.0);
        Test.assertMessage(p != null && near(p[0], 46.005, 1e-4) && near(p[1], 7.01, 1e-4), "half way " + p);
        p = input.positionAt(150.0);
        Test.assertMessage(p != null && near(p[0], 46.01, 1e-4) && near(p[1], 7.02, 1e-4), "past the last " + p);
        p = input.positionAt(0.0);
        Test.assertMessage(p != null && near(p[0], 46.0, 1e-4), "at the first " + p);
        return true;
    }

    // The sensor input's time is seconds since local midnight (the watch's clock, not UTC), moving with
    // the caller's clock.
    (:test)
    function sensorInputCountsFromMidnight(logger as Logger) as Boolean {
        var input = new SensorInput();
        var before = clockSeconds();
        var a = input.read(5000);
        var after = clockSeconds();
        var b = input.read(65000);
        input.stop();
        // Across midnight the two clock readings straddle it: then either side will do.
        var ok = before <= after ? a.t >= before && a.t <= after : a.t >= before || a.t <= after;
        Test.assertMessage(ok, "t " + a.t + ", local clock " + before + " to " + after);
        Test.assertEqualMessage(b.t - a.t, 60, "a minute on");
        return true;
    }

    function clockSeconds() as Number {
        var c = System.getClockTime();
        return c.hour * 3600 + c.min * 60 + c.sec;
    }

    // A GPS fix is a position only while it is recent: 30 s at most (from the review of #91).
    (:test)
    function staleFixIsNoPosition(logger as Logger) as Boolean {
        var input = new SensorInput();
        input.stop();
        var fix = new Position.Info();
        fix.position = new Position.Location({:latitude => 46.0, :longitude => 7.0, :format => :degrees});
        fix.accuracy = Position.QUALITY_GOOD;
        fix.when = new Time.Moment(1000000);
        var p = input.positionOf(fix, 1000010);
        Test.assertMessage(p != null && near(p[0], 46.0, 1e-4) && near(p[1], 7.0, 1e-4), "10 s old: " + p);
        Test.assertMessage(input.positionOf(fix, 1000030) != null, "30 s old");
        Test.assertMessage(input.positionOf(fix, 1000031) == null, "31 s old");
        fix.accuracy = Position.QUALITY_NOT_AVAILABLE;
        Test.assertMessage(input.positionOf(fix, 1000010) == null, "no quality");
        Test.assertMessage(input.positionOf(null, 1000010) == null, "no fix");
        return true;
    }
}
