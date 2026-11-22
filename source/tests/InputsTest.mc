using Toybox.Math;

import Toybox.Lang;
import Toybox.Test;

// The inputs (#50): the demo input plays 0.1.0's climb as readings, the sensor input reads the watch,
// and the demo setting chooses between them.
module InputsTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // The demo through the tracker keeps to the demo's own place on every climbing section (the
    // plan's bar: 15 m), and ends at the top. Driven as the view drives it, a reading every tick.
    (:test)
    function demoThroughTrackerFollowsDemoClock(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        var input = new DemoInput(r);
        var t = new Tracker(r);
        t.start(:head, input.read(0));
        var worst = 0.0, checked = 0;
        for (var ms = 250; ms <= DemoInput.LOOP_MS + DemoInput.HOLD_MS; ms += 250) {
            t.update(input.read(ms));
            var st = new Climb.State(input.minute);
            if (Climb.UP[st.cur] <= 0) { continue; }
            var e = (t.d - st.d).abs();
            if (e > worst) { worst = e; }
            checked++;
            Test.assertMessage(e <= 15.0, "minute " + input.minute + ": tracker " + t.d + ", demo " + st.d);
        }
        logger.debug("checked " + checked + ", worst " + worst + " m");
        Test.assertMessage(checked > 100, "climbing readings checked: " + checked);
        Test.assertMessage(near(t.d, Climb.totalD().toFloat(), 0.01), "at the top, d " + t.d);
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
        Test.assertMessage(near(rd.alt as Float, 1788.0, 0.01), "alt " + rd.alt);
        var end = Math.round((Climb.START_CLOCK + Climb.totalM() * Climb.PACE) * 60).toNumber();
        Test.assertEqualMessage(rd.t, end, "t at the top");
        var later = input.read(DemoInput.LOOP_MS + DemoInput.HOLD_MS);
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

    // The sensor input's time is seconds since local midnight, moving with the caller's clock.
    (:test)
    function sensorInputCountsFromMidnight(logger as Logger) as Boolean {
        var input = new SensorInput();
        var a = input.read(5000);
        var b = input.read(65000);
        input.stop();
        Test.assertMessage(a.t >= 0 && a.t < 86400, "t " + a.t);
        Test.assertEqualMessage(b.t - a.t, 60, "a minute on");
        return true;
    }

    // The setting is declared, a boolean, and is what chooses the input.
    (:test)
    function demoSettingChoosesInput(logger as Logger) as Boolean {
        var was = Settings.demo();
        Settings.setDemo(false);
        Test.assertMessage(!Settings.demo(), "off");
        var input = Settings.input(RouteTest.demo());
        input.stop();
        Test.assertMessage(input instanceof SensorInput, "sensor when off");
        Settings.setDemo(true);
        Test.assertMessage(Settings.demo(), "on");
        input = Settings.input(RouteTest.demo());
        input.stop();
        Test.assertMessage(input instanceof DemoInput, "demo when on");
        Settings.setDemo(was);
        return true;
    }
}
