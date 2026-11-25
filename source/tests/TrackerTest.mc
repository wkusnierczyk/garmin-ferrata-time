import Toybox.Lang;
import Toybox.Test;

// The tracker (#49): syncs, drift, the place estimate and pace, on the demo route (head 1290 m, the
// Bench landmark at 390 m along and 1310 m, the top at 640 m and 1580 m: the Dihedral goes down 110 m,
// #100) and on made-up routes.
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
        t.update(at(150, 1320.0));
        // The estimate past the Bench, at 420 m.
        t.d = 420.0;
        Test.assertMessage(t.state().band > 10, "the band has grown, " + t.state().band);
        t.syncAt(BENCH, at(151, 1300.0));
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

    // The head counts as a landmark for a calibration (#51): calibrating there puts the place at the
    // head, as the climber says; a calibration that lowers the offset by 40 m is not undone by the next
    // reading.
    (:test)
    function headCalibrationPlacesAtHead(logger as Logger) as Boolean {
        var t = climbing(60);
        // The watch reads 1350; a calibration at the head (1290 m) as if the watch read 1330 lowers the
        // offset by 40.
        t.syncAt(HEAD, at(12, 1330.0));
        Test.assertMessage(near(t.offset as Float, -40.0), "offset " + t.offset);
        Test.assertMessage(near(t.drifts[0], -40.0), "drift " + t.drifts);
        Test.assertMessage(near(t.d, 0.0), "at the head, d " + t.d);
        t.update(at(12, 1330.0));
        Test.assertMessage(near(t.d, 0.0), "after the sync: d " + t.d);
        return true;
    }

    // Ending at the top checks its altitude (a drift, the offset unchanged) and puts the place at the
    // top; Resume undoes both and pauses (#51).
    (:test)
    function endAtTopRecordsDrift(logger as Logger) as Boolean {
        var t = climbing(90);
        var d = t.d, u = t.u;
        t.end(TOP, at(20, 1570.0));
        Test.assertEqualMessage(t.phase, Tracker.ENDED, "ended");
        Test.assertMessage(near(t.drifts[0], 10.0), "drift " + t.drifts);
        Test.assertMessage(near(t.offset as Float, 0.0), "the offset is not changed");
        Test.assertMessage(near(t.d, 640.0), "at the top, d " + t.d);
        Test.assertEqualMessage(t.state().climbed(), 400, "the whole climb");
        t.unend();
        Test.assertEqualMessage(t.phase, Tracker.PAUSED, "paused");
        Test.assertMessage(t.pausedFrom == Tracker.ASCENT, "from the ascent");
        Test.assertMessage(near(t.d, d) && near(t.u, u), "place and height as before");
        Test.assertEqualMessage(t.drifts.size(), 0, "the check undone");
        return true;
    }

    // End here checks nothing.
    (:test)
    function endHereNoCheck(logger as Logger) as Boolean {
        var t = climbing(60);
        var d = t.d;
        t.end(-1, at(20, 1500.0));
        Test.assertEqualMessage(t.phase, Tracker.ENDED, "ended");
        Test.assertEqualMessage(t.drifts.size(), 0, "no drift");
        Test.assertMessage(near(t.d, d), "the place kept");
        return true;
    }

    // At altitude (#51): a start at an entered altitude is on the approach, calibrated to it without a
    // drift, and the head's calibration after it is no drift either: the entry was a guess.
    (:test)
    function startAtAltitudeIsAGuess(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        t.syncAt(BENCH, at(1, 1300.0));
        t.startAt(1280.0, at(2, 1275.0));
        Test.assertEqualMessage(t.phase, Tracker.APPROACH, "on the approach");
        Test.assertMessage(near(t.offset as Float, 5.0), "offset " + t.offset);
        Test.assertEqualMessage(t.drifts.size(), 0, "a new climb, no drift");
        Test.assertEqualMessage(t.calibratedAt.size(), 0, "nothing calibrated at");
        // 10 m above the Car park: half way up the approach's 20 m, 60 m along.
        Test.assertMessage(near(t.d, 60.0), "the place at that altitude, d " + t.d);
        t.startAscent(at(14, 1281.0));
        Test.assertMessage(near(t.offset as Float, 9.0), "calibrated at the head, offset " + t.offset);
        Test.assertEqualMessage(t.drifts.size(), 0, "no drift from a guess");
        // From the head on, a known point's change is drift again.
        t.syncAt(BENCH, at(20, 1300.0));
        Test.assertMessage(t.drifts.size() == 1 && near(t.drifts[0], 1.0), "drift " + t.drifts);
        return true;
    }

    // Without an approach, At altitude starts on the ferrata at the point at that altitude nearest the
    // head.
    (:test)
    function startAtAltitudeWithoutApproach(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.made([[100, 100], [100, 100]]));
        t.startAt(1150.0, at(0, 1100.0));
        Test.assertEqualMessage(t.phase, Tracker.ASCENT, "on the ferrata");
        Test.assertMessage(near(t.d, 150.0), "150 m up, d " + t.d);
        Test.assertMessage(near(t.offset as Float, 50.0), "offset " + t.offset);
        return true;
    }

    // Calibrating to an entered altitude moves the place to the point at it nearest the estimate,
    // back if need be, and changes the offset without a drift.
    (:test)
    function calibrateToMovesPlace(logger as Logger) as Boolean {
        var t = climbing(90);
        Test.assertMessage(near(t.d, 35.0), "at the top of the first wall");
        // 1300 m is 10 m up: on the first wall at 35 x 10 / 90 m, or at the Dihedral's foot (210 m).
        t.calibrateTo(1300.0, at(20, 1380.0));
        Test.assertMessage(near(t.d, 35.0 * 10 / 90), "back on the first wall, d " + t.d);
        Test.assertMessage(near(t.offset as Float, -80.0), "offset " + t.offset);
        Test.assertEqualMessage(t.drifts.size(), 0, "no drift");
        Test.assertEqualMessage(t.band(), 10, "the band starts again");
        return true;
    }

    // The activity's time runs on the approach and the ferrata, not while paused.
    (:test)
    function activeTimeExcludesPauses(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:approachPoint, at(0, 1270.0));
        t.update(at(10, 1280.0));
        t.pause(at(12, 1282.0));
        t.update(at(40, 1282.0));
        t.resume(at(42, 1282.0));
        t.startAscent(at(50, 1290.0));
        t.update(at(55, 1300.0));
        Test.assertEqualMessage(t.activeS, (12 + 8 + 5) * 60, "25 minutes: " + t.activeS);
        return true;
    }

    // The points calibrated at in a climb, for Calibrate not to suggest them again.
    (:test)
    function calibratedAtKept(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        Test.assertMessage(t.calibratedAt.size() == 1 && t.calibratedAt[0] == HEAD, "the head");
        t.syncAt(BENCH, at(30, 1310.0));
        Test.assertMessage(t.calibratedAt.size() == 2 && t.calibratedAt[1] == BENCH, "and the Bench");
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

    // ---------------------------------------------------------------- from the review of #89

    // Review Focus 3: before the pace is trusted (10 guidebook minutes), a pause does not count as
    // walking. A 200 m traverse of 10 minutes, then a climb.
    (:test)
    function pauseBeforePaceTrustedHolds(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.made([[200, 0], [100, 100]]));
        t.start(:head, at(0, 1000.0));
        t.update(at(2, 1000.0));
        var d = t.d;
        t.pause(at(2, 1000.0));
        t.update(at(32, 1000.0));
        t.resume(at(32, 1000.0));
        Test.assertMessage(near(t.d, d), "the pause moved the place: " + t.d + ", was " + d);
        // Then on at the climber's pace, 1.0: a minute is 20 m.
        t.update(at(33, 1000.0));
        Test.assertMessage(near(t.d, d + 20.0), "a minute on: d " + t.d);
        return true;
    }

    (:test)
    function resumeWithoutPausedReadingHolds(logger as Logger) as Boolean {
        // No reading between the pause and the resume (Codex on #89).
        var t = new Tracker(RouteTest.made([[200, 0], [100, 100]]));
        t.start(:head, at(0, 1000.0));
        t.update(at(2, 1000.0));
        var d = t.d;
        t.pause(at(2, 1000.0));
        t.resume(at(32, 1000.0));
        Test.assertMessage(near(t.d, d), "the pause moved the place: " + t.d + ", was " + d);
        t.update(at(33, 1000.0));
        Test.assertMessage(near(t.d, d + 20.0), "a minute on: d " + t.d);
        return true;
    }

    (:test)
    function unsyncedPauseHolds(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:elsewhere, at(0, 1250.0));
        t.update(at(2, 1252.0));
        var d = t.d;
        t.pause(at(2, 1252.0));
        t.update(at(32, 1252.0));
        t.resume(at(32, 1252.0));
        Test.assertMessage(near(t.d, d), "the pause moved the place: " + t.d + ", was " + d);
        return true;
    }

    // Review Focus 1: a start sync confirmed while the watch had no altitude is applied at the first
    // reading that has one.
    (:test)
    function startSyncWaitsForAltitude(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, null));
        t.update(at(1, 1250.0));
        Test.assertMessage(t.offset != null && near(t.offset as Float, 40.0), "offset " + t.offset);
        Test.assertEqualMessage(t.drifts.size(), 0, "a first sync, no drift");
        Test.assertMessage(near(t.altitude() as Float, 1290.0), "altitude " + t.altitude());
        return true;
    }

    // 100 m up, 200 m flat, 100 m up, a landmark at the start of the flat.
    function withLandmark() as Route {
        var sections = [] as Array<Dictionary>;
        var steps = [[100, 100], [200, 0], [100, 100]];
        for (var i = 0; i < 3; i++) {
            sections.add({"len" => steps[i][0], "up" => steps[i][1], "grade" => 1, "min" => 10,
                "name" => "S" + i, "side" => 0.0});
        }
        return Route.fromJson({"format" => 1, "id" => "t", "name" => "T", "short" => "T",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 1000, "name" => "Head"},
                {"kind" => "landmark", "at" => 100, "alt" => 1100, "name" => "Ledge start"},
                {"kind" => "top", "at" => 400, "name" => "Top"}]}) as Route;
    }

    // A landmark sync on a flat is not undone by the next reading; the place goes on from it at the
    // climber's pace.
    (:test)
    function landmarkSyncSurvivesNextReading(logger as Logger) as Boolean {
        var t = new Tracker(withLandmark());
        t.start(:head, at(0, 1000.0));
        for (var k = 1; k <= 10; k++) { t.update(at(k, 1000.0 + 10 * k)); }
        for (var k = 11; k <= 25; k++) { t.update(at(k, 1100.0)); }
        Test.assertMessage(near(t.d, 300.0), "the estimate ran ahead, d " + t.d);
        t.syncAt(1, at(25, 1100.0));
        Test.assertMessage(near(t.d, 100.0), "at the landmark, d " + t.d);
        // The pace follows the landmark at once, before any reading (Codex on #89).
        Test.assertMessage(t.pace > 2.49 && t.pace < 2.51, "pace at the sync " + t.pace);
        t.update(new Reading(1100.0, null, null, 25 * 60 + 1));
        Test.assertMessage(t.d < 101.0, "one second later, d " + t.d);
        // 25 minutes for 10 guidebook ones: pace 2.5, so 5 minutes more are 2 guidebook minutes, 40 m.
        Test.assertMessage(t.pace > 2.49 && t.pace < 2.51, "pace " + t.pace);
        t.update(at(30, 1100.0));
        Test.assertMessage(t.d > 139.0 && t.d < 141.0, "five minutes on, d " + t.d);
        return true;
    }

    (:test)
    function landmarkSyncNextReadingLater(logger as Logger) as Boolean {
        // The next reading five minutes after the sync, none between (Codex on #89): 40 m, not 80.
        var t = new Tracker(withLandmark());
        t.start(:head, at(0, 1000.0));
        for (var k = 1; k <= 10; k++) { t.update(at(k, 1000.0 + 10 * k)); }
        for (var k = 11; k <= 25; k++) { t.update(at(k, 1100.0)); }
        t.syncAt(1, at(25, 1100.0));
        t.update(at(30, 1100.0));
        Test.assertMessage(t.d > 139.0 && t.d < 141.0, "five minutes on, d " + t.d);
        return true;
    }

    (:test)
    function altitudeOutageKeepsPace(logger as Logger) as Boolean {
        // A reading without altitude in the middle must not slow the catch-up (Codex on #89).
        var a = new Tracker(withLandmark());
        var b = new Tracker(withLandmark());
        a.start(:head, at(0, 1000.0));
        b.start(:head, at(0, 1000.0));
        for (var k = 1; k <= 10; k++) { a.update(at(k, 1000.0 + 10 * k)); b.update(at(k, 1000.0 + 10 * k)); }
        a.update(at(20, null));
        a.update(at(21, 1100.0));
        b.update(at(21, 1100.0));
        Test.assertMessage(near(a.d, b.d), "with the outage d " + a.d + ", without " + b.d);
        return true;
    }

    (:test)
    function syncWithoutAltitudeKeepsBand(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, at(0, 1290.0));
        t.update(at(65, 1300.0));
        var b = t.band();
        t.syncAt(HEAD, at(65, null));
        Test.assertEqualMessage(t.band(), b, "no sync, no reset");
        // The sync is applied at the next reading with an altitude, and the band starts again.
        t.update(at(66, 1300.0));
        Test.assertMessage(near(t.offset as Float, -10.0), "offset " + t.offset);
        Test.assertEqualMessage(t.band(), 10, "synced");
        return true;
    }

    (:test)
    function nothingAfterEnd(logger as Logger) as Boolean {
        var t = climbing(30);
        t.end(TOP, at(6, 1320.0));
        var n = t.drifts.size(), d = t.d, offset = t.offset;
        t.syncAt(BENCH, at(7, 1500.0));
        t.end(TOP, at(8, 1700.0));
        Test.assertEqualMessage(t.drifts.size(), n, "no drift after the end");
        Test.assertMessage(near(t.d, d) && t.offset == offset, "place and offset kept");
        return true;
    }

    // The clock comes from the readings' time, so a replay shows its own.
    (:test)
    function clockFromReadings(logger as Logger) as Boolean {
        var t = new Tracker(RouteTest.demo());
        t.start(:head, new Reading(1290.0, null, null, (8 * 60 + 30) * 60));
        t.update(new Reading(1300.0, null, null, (8 * 60 + 40) * 60));
        Test.assertEqualMessage(Climb.clockText(t.state().clock()), "8:40", "clock");
        return true;
    }

    (:test)
    function distanceAtMinuteIsInverse(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        for (var k = 0; k <= Climb.totalM() * 2; k++) {
            var m = k / 2.0;
            var back = Climb.minuteAtDistance(Climb.distanceAtMinute(m));
            Test.assertMessage(near(back, m), "m " + m + " back " + back);
        }
        Test.assertMessage(near(Climb.distanceAtMinute(Climb.totalM() + 5.0), Climb.totalD().toFloat()), "past the end");
        Test.assertMessage(near(Climb.distanceAtMinute(-3.0), 0.0), "before the start");
        return true;
    }

    // A placed state at the demo's place, pace and clock reads as the demo's state.
    (:test)
    function placedMatchesDemo(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        for (var k = 0; k < Climb.totalM(); k += 3) {
            var a = new Climb.State(k.toFloat());
            var b = Climb.State.placed(a.d, a.u, a.elapsed(), Climb.PACE, Climb.START_CLOCK.toFloat(), Climb.UNCERTAINTY);
            Test.assertMessage(a.cur == b.cur && near(a.m, b.m) && near(a.left(), b.left()) && near(a.clock(), b.clock()),
                "k " + k + ": cur " + a.cur + "/" + b.cur + " m " + a.m + "/" + b.m);
        }
        return true;
    }
}
