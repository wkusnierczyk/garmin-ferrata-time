import Toybox.Lang;
import Toybox.Test;

// The tracker (#49): syncs, drift, the place estimate and pace, on the demo route (head 1290 m, the
// Bench landmark at 390 m along and 1530 m, the top at 640 m and 1800 m) and on made-up routes.
module TrackerTest {

    // A reading at minute min of the climb, the watch reading alt.
    function at(min as Number, alt as Float?) as Reading {
        return new Reading(alt, null, null, min * 60);
    }

    function near(a as Float, b as Float) as Boolean {
        var e = a - b;
        return e < 0.01 && e > -0.01;
    }

    // Point indices in the demo route.
    const HEAD = 1;
    const BENCH = 4;
    const TOP = 7;

    // On the ferrata from the head, the watch reading true (offset 0), then climbing the first wall
    // (35 m along, 90 m up) 10 m every 2 minutes up to u.
    function climbing(u as Number) as Tracker {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        for (var k = 1; k * 10 <= u; k++) { t.update(at(2 * k, 1290.0 + 10 * k)); }
        return t;
    }

    (:test)
    function startAtHeadSyncs(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1250.0));
        Test.assertEqualMessage(t.phase, Tracker.ASCENT, "on the ascent");
        Test.assertMessage(near(t.offset as Float, 40.0), "offset " + t.offset);
        Test.assertMessage(near(t.altitude() as Float, 1290.0), "altitude " + t.altitude());
        Test.assertEqualMessage(Climb.count(), 12, "the ferrata in use");
        Test.assertMessage(near(t.d, 0.0), "at the head");
        return true;
    }

    (:test)
    function startElsewhereIsUnsynced(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:elsewhere, at(0, 1250.0));
        Test.assertEqualMessage(t.phase, Tracker.APPROACH, "the route has an approach");
        Test.assertEqualMessage(Climb.count(), 1, "the approach in use");
        Test.assertMessage(t.offset == null, "unsynced");
        // The watch's own reading, unsynced.
        Test.assertMessage(near(t.altitude() as Float, 1250.0), "altitude " + t.altitude());
        // Unsynced, the place goes by time only: the approach is 12 guidebook minutes, 120 m.
        t.update(at(6, 1300.0));
        Test.assertMessage(near(t.d, 60.0), "half way by time, d " + t.d);
        return true;
    }

    (:test)
    function startAtApproachPointSyncs(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:approachPoint, at(0, 1265.0));
        Test.assertEqualMessage(t.phase, Tracker.APPROACH, "on the approach");
        Test.assertEqualMessage(Climb.count(), 1, "the approach in use");
        Test.assertMessage(near(t.offset as Float, 5.0), "offset " + t.offset);
        Test.assertMessage(near(t.altitude() as Float, 1270.0), "altitude " + t.altitude());
        return true;
    }

    (:test)
    function landmarkSyncSetsPlace(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        t.update(at(150, 1540.0));
        // The estimate past the Bench, at 420 m.
        t.d = 420.0;
        Test.assertMessage(t.state().band > 10, "the band has grown, " + t.state().band);
        t.syncAt(BENCH, at(151, 1520.0));
        Test.assertMessage(near(t.d, 390.0), "at the Bench, d " + t.d);
        Test.assertEqualMessage(t.state().band, 10, "band back to 10");
        Test.assertMessage(near(t.offset as Float, 10.0), "offset " + t.offset);
        return true;
    }

    (:test)
    function approachToAscentRecordsDrift(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:approachPoint, at(0, 1270.0));
        Test.assertMessage(near(t.offset as Float, 0.0), "offset 0");
        t.update(at(12, 1290.0));
        t.startAscent(at(13, 1286.0));
        Test.assertEqualMessage(t.phase, Tracker.ASCENT, "on the ascent");
        Test.assertEqualMessage(Climb.count(), 12, "the ferrata in use");
        Test.assertEqualMessage(t.drifts.size(), 1, "one drift");
        Test.assertMessage(near(t.drifts[0], 4.0), "drift " + t.drifts);
        Test.assertMessage(near(t.d, 0.0), "at the head");
        Test.assertMessage(near(t.state().elapsed(), 0.0), "the ascent's clock starts at the head");
        return true;
    }

    (:test)
    function climbMovesForward(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        var last = t.d;
        for (var k = 1; k <= 9; k++) {
            t.update(at(2 * k, 1290.0 + 10 * k));
            Test.assertMessage(t.d > last, "step " + k + ": d " + t.d + " after " + last);
            last = t.d;
        }
        // 90 m up is the top of the first wall.
        Test.assertMessage(near(t.d, 35.0), "top of the first wall, d " + t.d);
        Test.assertMessage(near(t.u, 90.0), "u " + t.u);
        Test.assertEqualMessage(t.state().climbed(), 90, "climbed");
        return true;
    }

    // Review Focus 2. At the top of the first wall the route goes on along the flat Ledge, so a later
    // reading may move the place along it with time, forward; at the same moment nothing moves.
    (:test)
    function fallDoesNotMoveBack(logger as Logger) as Boolean {
        var t = climbing(90);
        var d = t.d;
        t.update(at(18, 1350.0));
        Test.assertMessage(near(t.d, d), "same moment: d " + t.d + ", was " + d);
        Test.assertMessage(near(t.u, 60.0), "the height falls, u " + t.u);
        t.update(at(30, 1340.0));
        Test.assertMessage(t.d >= d, "later: d " + t.d + " not behind " + d);
        // Mid-wall, a fall keeps the place, however long it lasts.
        t = climbing(60);
        d = t.d;
        t.update(at(40, 1310.0));
        Test.assertMessage(near(t.d, d), "mid-wall: d " + t.d + ", was " + d);
        return true;
    }

    (:test)
    function traverseAdvancesWithTime(logger as Logger) as Boolean {
        // 100 m up, 200 m flat, 100 m up; 10 guidebook minutes each.
        var t = new Tracker(RouteTest.made([[100, 100], [200, 0], [100, 100]]));
        t.start(:head, at(0, 1000.0));
        for (var k = 1; k <= 10; k++) { t.update(at(k, 1000.0 + 10 * k)); }
        Test.assertMessage(near(t.d, 100.0), "at the traverse, d " + t.d);
        var last = t.d;
        for (var k = 11; k <= 40; k++) {
            t.update(at(k, 1100.0));
            Test.assertMessage(t.d >= last, "minute " + k + ": d " + t.d + " behind " + last);
            Test.assertMessage(t.d <= 300.0 + 0.01, "minute " + k + ": d " + t.d + " past the traverse");
            last = t.d;
        }
        // At the climber's pace (1.0) the traverse's 10 minutes take 10: at its end by minute 20, and
        // there it stays until the height moves.
        Test.assertMessage(near(t.d, 300.0), "at the traverse's end, d " + t.d);
        return true;
    }

    // Review Focus 1.
    (:test)
    function nullAltitudeHoldsPlace(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        // No altitude from the start: no sync, no place, no crash.
        t.start(:head, at(0, null));
        Test.assertMessage(t.offset == null, "no offset without a reading");
        Test.assertMessage(t.altitude() == null, "altitude unknown");
        t.update(at(1, null));
        Test.assertMessage(near(t.d, 0.0), "no place without a reading");
        t.state();
        // Then a gap mid-climb.
        t = climbing(50);
        var d = t.d, offset = t.offset;
        t.update(at(30, null));
        Test.assertMessage(near(t.d, d), "d " + t.d + ", was " + d);
        Test.assertMessage(t.offset == offset, "offset kept");
        Test.assertMessage(t.altitude() == null, "altitude unknown");
        Test.assertMessage(near(t.u, 50.0), "u kept");
        return true;
    }

    // Review Focus 3.
    (:test)
    function longPauseGrowsTimeLeft(logger as Logger) as Boolean {
        // 60 m up the first wall in 12 minutes.
        var t = climbing(60);
        var st = t.state();
        var left = st.left(), pace = t.pace, d = t.d;
        var m = Climb.minuteAtDistance(d), ahead = Climb.totalM() - m;
        t.pause(at(12, 1350.0));
        Test.assertEqualMessage(t.phase, Tracker.PAUSED, "paused");
        t.update(at(72, 1350.0));
        st = t.state();
        Test.assertMessage(near(t.d, d), "the place holds");
        Test.assertMessage(near(st.elapsed(), 72.0), "the pause counts, elapsed " + st.elapsed());
        Test.assertMessage(t.pace > pace, "pace " + t.pace + " after " + pace);
        // The pace is elapsed time against guidebook minutes done, so the hour adds 60 / m to it and
        // 60 x ahead / m to the time left.
        Test.assertMessage(near(t.pace - pace, 60.0 / m), "pace grows by 60 / m");
        Test.assertMessage(near(st.left() - left, 60.0 * ahead / m), "left " + st.left() + " after " + left);
        t.resume(at(72, 1350.0));
        Test.assertEqualMessage(t.phase, Tracker.ASCENT, "back on the ascent");
        return true;
    }

    (:test)
    function headSyncJumpDoesNotMoveBack(logger as Logger) as Boolean {
        var t = climbing(60);
        var d = t.d;
        // The watch reads 1350; a sync at the head (1290 m, a known point, not a landmark) as if the
        // watch read 1330 lowers the offset by 40.
        t.syncAt(HEAD, at(12, 1330.0));
        Test.assertMessage(near(t.offset as Float, -40.0), "offset " + t.offset);
        Test.assertMessage(near(t.drifts[0], -40.0), "drift " + t.drifts);
        Test.assertMessage(near(t.d, d), "d " + t.d + ", was " + d);
        t.update(at(13, 1335.0));
        Test.assertMessage(near(t.d, d), "after the sync: d " + t.d + ", was " + d);
        return true;
    }

    (:test)
    function endAtTopRecordsDrift(logger as Logger) as Boolean {
        var t = climbing(90);
        var d = t.d, u = t.u;
        t.end(TOP, at(20, 1790.0));
        Test.assertEqualMessage(t.phase, Tracker.ENDED, "ended");
        Test.assertMessage(near(t.drifts[0], 10.0), "drift " + t.drifts);
        Test.assertMessage(near(t.offset as Float, 0.0), "the offset is not changed");
        Test.assertMessage(near(t.d, d) && near(t.u, u), "place and height kept");
        return true;
    }

    (:test)
    function bandGrowsSinceSync(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        Test.assertEqualMessage(t.state().band, 10, "at the sync");
        t.update(at(65, 1300.0));
        Test.assertEqualMessage(t.state().band, 20, "65 minutes on");
        t.update(at(600, 1300.0));
        Test.assertEqualMessage(t.state().band, 50, "capped");
        return true;
    }

    // An approach with no gained height (flat or down) leaves the pages something to divide by
    // (the issue's comment, from the review of #88).
    (:test)
    function flatApproachHasHeightToDivideBy(logger as Logger) as Boolean {
        var data = RouteTest.source();
        var approach = data["approach"] as Array<Dictionary>;
        approach[0]["up"] = -10;
        approach[1]["up"] = 0;
        var t = new Tracker(Route.fromJson(data) as Route);
        t.start(:approachPoint, at(0, 1000.0));
        Test.assertMessage(Climb.totalU() > 0, "totalU " + Climb.totalU());
        Test.assertEqualMessage(t.state().climbed(), 0, "nothing climbed");
        return true;
    }
}
