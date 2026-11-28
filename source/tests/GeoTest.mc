import Toybox.Lang;
import Toybox.Test;

// On the approach, the distance to the head from GPS (#113): along the approach's track (its points
// with coordinates), else straight to the head, else by time alone; it may grow. The time follows from
// the distance at the climber's pace.
module GeoTest {

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // Leg 1 runs 1000 m north from the car park (46.0, 7.0) to a ford, a danger (46.009, 7.0), flat, 20
    // minutes; leg 2 1000 m east to the head (46.009, 7.0129), 100 m up, 30 minutes. track: the car park
    // and the ford have coordinates; head: the head has. Then a short ferrata.
    function route(track as Boolean, head as Boolean) as Route {
        var start = {"kind" => "approach", "at" => -2000, "alt" => 1000, "type" => "Car park", "name" => "Car park"};
        var ford = {"kind" => "danger", "at" => -1000, "name" => "Ford"};
        var h = {"kind" => "head", "at" => 0, "alt" => 1100, "name" => "Head"};
        if (track) {
            start["lat"] = 46.0; start["lon"] = 7.0;
            ford["lat"] = 46.009; ford["lon"] = 7.0;
        }
        if (head) { h["lat"] = 46.009; h["lon"] = 7.0129; }
        return Route.fromJson({"format" => 1, "units" => "m", "id" => "g", "name" => "Geo", "short" => "Geo",
            "approach" => [
                {"len" => 1000, "up" => 0, "grade" => 0, "min" => 20, "name" => "Valley", "side" => 0.0},
                {"len" => 1000, "up" => 100, "grade" => 0, "min" => 30, "name" => "Slope", "side" => 0.0}],
            "sections" => [{"len" => 100, "up" => 50, "grade" => 1, "min" => 10, "name" => "Wall", "side" => 0.0}],
            "points" => [start, ford, h, {"kind" => "top", "at" => 100, "alt" => 1150, "name" => "Top"}]}) as Route;
    }

    // The same route with the approach's track in the file (#143): the car park, the ford and the head,
    // as the route tool writes it, with the head's coordinates and none on the points between.
    function routeWithTrack() as Route {
        var r = route(false, true);
        r.track = [[46.0, 7.0], [46.0045, 7.0], [46.009, 7.0], [46.009, 7.00645], [46.009, 7.0129]];
        return r;
    }

    // On the approach from its start, the watch reading true (offset 0).
    function walking(r as Route) as Tracker {
        var t = new Tracker(r);
        t.start(:approachPoint, new Reading(1000.0, null, null, 0));
        return t;
    }

    // Beside leg 1 halfway (about 20 m off it), and beside leg 2 halfway.
    const LEG1 = [46.0045, 7.0003] as [Float, Float];
    const LEG2 = [46.0092, 7.00645] as [Float, Float];

    function fix(p as [Float, Float], tSec as Number) as Reading {
        return new Reading(1000.0, p[0], p[1], tSec);
    }

    (:test)
    function distanceKnownPair(logger as Logger) as Boolean {
        var m = Geo.distance(46.0, 7.0, 46.001, 7.0);
        Test.assertMessage(near(m, 111.2, 1.0), "0.001 degrees of latitude: " + m);
        return true;
    }

    // On leg 1, 250 m and 800 m from the car park; the ford, 1000 m.
    const AT250 = [46.00225, 7.0003] as [Float, Float];
    const AT800 = [46.0072, 7.0003] as [Float, Float];
    const FORD = [46.009, 7.0] as [Float, Float];

    (:test)
    function snapsToTheTrack(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(AT250, 300));
        t.update(fix(LEG1, 900));
        var h = t.toHead();
        // Along the track: 500 m of leg 1 and all of leg 2; straight to the head it would be 1094 m.
        Test.assertMessage(near(h[0], 1500.0, 10.0), "along the track: " + h[0]);
        Test.assertMessage(near(t.d, 500.0, 10.0), "the place follows: " + t.d);
        // 10 guidebook minutes done in 15: pace 1.5, so the 40 minutes ahead take 60.
        Test.assertMessage(near(t.pace, 1.5, 0.02), "pace from the fixes: " + t.pace);
        Test.assertMessage(near(h[1], 60.0, 1.0), "time at the pace: " + h[1]);
        t.update(fix(LEG2, 1200));
        Test.assertMessage(near(t.toHead()[0], 500.0, 10.0), "on leg 2: " + t.toHead()[0]);
        return true;
    }

    // An ALTITUDE start on the flat leg puts the climber at the car park; the first fix says the ford,
    // 1000 m in. The skipped stretch is not counted as walked (the review of #139): without that, a
    // pace of 0.05 and a minute to the head.
    (:test)
    function firstFixDoesNotCountTheSkippedStretch(logger as Logger) as Boolean {
        var t = new Tracker(route(true, true));
        t.startAt(1000.0, new Reading(1000.0, null, null, 0));
        Test.assertMessage(near(t.d, 0.0, 0.01), "placed at the car park: " + t.d);
        t.update(fix(FORD, 60));
        var h = t.toHead();
        Test.assertMessage(near(h[0], 1000.0, 5.0), "from the ford: " + h[0]);
        Test.assertMessage(near(t.pace, 1.0, 0.001), "pace as assumed: " + t.pace);
        Test.assertMessage(near(h[1], 30.0, 0.5), "leg 2's 30 minutes: " + h[1]);
        // 15 guidebook minutes walked from the ford in 10: a pace that follows the walk.
        t.update(fix(LEG2, 660));
        Test.assertMessage(t.pace > 0.5 && t.pace < 1.0, "pace from the ford on: " + t.pace);
        return true;
    }

    // Straight to the head is a distance, not a place on the route: the place moves by time and
    // height, and the time to the head is the guidebook's from there (the review of #139).
    (:test)
    function straightLineWithoutTrack(logger as Logger) as Boolean {
        var t = walking(route(false, true));
        t.update(fix(LEG1, 600));
        var h = t.toHead();
        // 500 m south and 973 m west of the head.
        Test.assertMessage(near(h[0], 1094.0, 5.0), "straight to the head: " + h[0]);
        Test.assertMessage(near(t.d, 500.0, 0.5), "the place by time: " + t.d);
        Test.assertMessage(near(t.pace, 1.0, 0.001), "pace by time: " + t.pace);
        Test.assertMessage(near(h[1], 40.0, 0.5), "the guidebook's 40 minutes: " + h[1]);
        return true;
    }

    // A track that ends before the head (the car park and the ford have coordinates, the head none)
    // is no track: snapped to it, the distance could never fall below the ford's 1000 m (Codex on #139).
    // Without the head's coordinates, time and height.
    (:test)
    function partialTrackIsNoTrack(logger as Logger) as Boolean {
        var t = walking(route(true, false));
        // GPS on leg 2 would say 1500 m along; time says 500 m.
        t.update(fix(LEG2, 600));
        Test.assertMessage(near(t.toHead()[0], 1500.0, 0.5), "by time: " + t.toHead()[0]);
        Test.assertMessage(t.headLeft == null, "no GPS distance");
        return true;
    }

    // A track that starts partway (the ford and the head have coordinates, the car park none) is no
    // track either: at the car park, snapped to it, the climber would be at the ford (Codex on #139).
    // The straight line to the head instead.
    (:test)
    function trackStartingPartwayIsNoTrack(logger as Logger) as Boolean {
        var r = route(true, true);
        r.points[0].remove("lat");
        r.points[0].remove("lon");
        var t = walking(r);
        t.update(fix([46.0, 7.0] as [Float, Float], 60));
        // 1001 m south and 996 m west of the head; snapped to the ford it would be 1000 m along.
        Test.assertMessage(near(t.toHead()[0], 1412.0, 5.0), "straight to the head: " + t.toHead()[0]);
        // A minute of leg 1's 50 m a minute.
        Test.assertMessage(near(t.d, 50.0, 1.0), "the place by time: " + t.d);
        return true;
    }

    // 3 km south of the head, on a 2 km approach (Codex on #139): when the fix goes, the 1 km beyond the
    // approach is carried, and time takes it off first; the next fix, or the ferrata, clears it.
    const FAR = [45.98202, 7.0129] as [Float, Float];

    // While metres beyond the approach's start are carried, the place holds at the start: an altitude
    // 50 m above it must not move it up leg 2 (Codex on #139), on the fix's reading or after.
    (:test)
    function offRouteHoldsThePlace(logger as Logger) as Boolean {
        var t = walking(route(false, true));
        t.update(new Reading(1050.0, FAR[0], FAR[1], 600));
        Test.assertMessage(near(t.d, 0.0, 0.01), "held on the fix: " + t.d);
        Test.assertMessage(near(t.toHead()[0], 3000.0, 5.0), "straight: " + t.toHead()[0]);
        t.update(new Reading(1050.0, null, null, 900));
        Test.assertMessage(near(t.d, 0.0, 0.01), "held without a fix: " + t.d);
        Test.assertMessage(near(t.toHead()[0], 2800.0, 5.0), "carried on by time: " + t.toHead()[0]);
        return true;
    }

    (:test)
    function offRouteDistanceCarried(logger as Logger) as Boolean {
        var t = walking(route(false, true));
        t.update(fix(FAR, 600));
        Test.assertMessage(near(t.toHead()[0], 3000.0, 5.0), "straight: " + t.toHead()[0]);
        // 5 minutes at the approach's 40 m a minute, pace 1: 200 m off the 1000 m beyond.
        t.update(new Reading(1000.0, null, null, 900));
        var h = t.toHead();
        Test.assertMessage(near(h[0], 2800.0, 5.0), "carried on by time: " + h[0]);
        Test.assertMessage(near(h[1], 70.0, 0.5), "the approach's 50 minutes and 20 more: " + h[1]);
        t.update(fix(LEG1, 960));
        Test.assertMessage(near(t.toHead()[0], 1094.0, 5.0), "the next fix: " + t.toHead()[0]);
        t.update(new Reading(1000.0, null, null, 1020));
        Test.assertMessage(t.toHead()[0] <= 2000.0, "nothing carried after it: " + t.toHead()[0]);
        var f = walking(route(false, true));
        f.update(fix(FAR, 600));
        f.update(new Reading(1000.0, null, null, 660));
        f.startAscent(new Reading(1100.0, null, null, 720));
        Test.assertMessage(near(f.toHead()[0], 100.0, 0.01), "the ferrata's 100 m: " + f.toHead()[0]);
        return true;
    }

    (:test)
    function timeAloneWithoutCoordinates(logger as Logger) as Boolean {
        var t = walking(route(false, false));
        // GPS would say 500 m; time says 10 of the 20 minutes of leg 1 done.
        t.update(fix(LEG2, 600));
        var h = t.toHead();
        Test.assertMessage(near(h[0], 1500.0, 0.5), "by time: " + h[0]);
        Test.assertMessage(near(h[1], 40.0, 0.5), "time: " + h[1]);
        return true;
    }

    // A stale or poor fix reaches the tracker as a reading without a position (SensorInput.positionOf,
    // InputsTest): time and height move the place on from where the last fix put it.
    (:test)
    function staleFixFallsBackToTime(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        // Time says 500 m at minute 10; the fix says 800 m.
        t.update(fix(AT800, 600));
        t.update(new Reading(1000.0, null, null, 780));
        var h = t.toHead();
        // From 800 m (minute 16), 3 more minutes at pace 1: 950 m. From time's 500 m it would be 650.
        Test.assertMessage(near(t.d, 950.0, 5.0), "on from the fix: " + t.d);
        Test.assertMessage(near(h[0], 1050.0, 5.0), "to the head: " + h[0]);
        Test.assertMessage(near(h[1], 31.0, 0.5), "time: " + h[1]);
        return true;
    }

    (:test)
    function distanceMayGrow(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(LEG2, 600));
        var before = t.toHead()[0];
        t.update(fix(LEG1, 660));
        var after = t.toHead()[0];
        Test.assertMessage(near(before, 500.0, 10.0), "on leg 2: " + before);
        Test.assertMessage(near(after, 1500.0, 10.0), "back on leg 1: " + after);
        return true;
    }

    // Paused, fixes move nothing and the distance stays as it was; after the resume, the next fix
    // counts.
    (:test)
    function pauseKeepsTheDistance(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(LEG1, 600));
        t.pause(fix(LEG1, 660));
        t.update(fix(LEG2, 900));
        Test.assertMessage(near(t.toHead()[0], 1500.0, 10.0), "paused: " + t.toHead()[0]);
        Test.assertMessage(near(t.d, 500.0, 10.0), "the place paused: " + t.d);
        t.resume(fix(LEG2, 960));
        t.update(fix(LEG2, 1020));
        Test.assertMessage(near(t.toHead()[0], 500.0, 10.0), "after the resume: " + t.toHead()[0]);
        return true;
    }

    // Paused, a reading without a fix leaves the straight distance shown (the review of #139), not the
    // place's 1500 m.
    (:test)
    function pauseKeepsTheStraightDistance(logger as Logger) as Boolean {
        var t = walking(route(false, true));
        t.update(fix(LEG1, 600));
        t.pause(fix(LEG1, 660));
        t.update(new Reading(1000.0, null, null, 900));
        Test.assertMessage(near(t.toHead()[0], 1094.0, 5.0), "paused: " + t.toHead()[0]);
        return true;
    }

    (:test)
    function ferrataClearsTheDistance(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(LEG1, 600));
        t.startAscent(new Reading(1100.0, null, null, 660));
        Test.assertMessage(t.headLeft == null, "no GPS distance on the ferrata");
        Test.assertMessage(near(t.toHead()[0], 100.0, 0.01), "the ferrata's 100 m: " + t.toHead()[0]);
        return true;
    }

    (:test)
    function gpsLeavesTheFerrataAlone(logger as Logger) as Boolean {
        var t = new Tracker(route(true, true));
        t.start(:head, new Reading(1100.0, null, null, 0));
        t.update(new Reading(1100.0, LEG1[0], LEG1[1], 60));
        Test.assertMessage(near(t.d, 0.0, 0.01), "still at the head: " + t.d);
        return true;
    }

    // The demo's position on the approach counts from its start, as the place does (the review of
    // #139): 500 m in is halfway along leg 1, not the head.
    (:test)
    function demoPositionOnTheApproach(logger as Logger) as Boolean {
        var r = route(true, true);
        var input = new DemoInput(r);
        Climb.use(r, :approach);
        var p = input.positionAt(500.0);
        Test.assertMessage(p != null && near(p[0], 46.0045, 1e-5) && near(p[1], 7.0, 1e-5), "approach: " + p);
        Climb.use(r, :ferrata);
        p = input.positionAt(0.0);
        Test.assertMessage(p != null && near(p[0], 46.009, 1e-5) && near(p[1], 7.0129, 1e-5), "head: " + p);
        return true;
    }

    // The file's track (#143) is snapped to as the points' was: beside leg 1 halfway, 500 m along it.
    (:test)
    function snapsToTheFilesTrack(logger as Logger) as Boolean {
        var t = walking(routeWithTrack());
        t.update(fix(LEG1, 600));
        // The map's 2000 m and the approach's are about the same: 1500 m of it left.
        Test.assertMessage(near(t.toHead()[0], 1500.0, 15.0), "along the track: " + t.toHead()[0]);
        Test.assertMessage(near(t.d, 500.0, 15.0), "the place follows: " + t.d);
        return true;
    }

    // More than 200 m off the track (owner, #143): not snapped. The distance is the straight line to
    // the head, and time moves the place, so a wild fix cannot jump it. 0.0045 degrees east of leg 1
    // halfway is about 350 m off it, and 1000 m along it from the car park.
    (:test)
    function offTrackIsNotSnapped(logger as Logger) as Boolean {
        var t = walking(routeWithTrack());
        var off = [46.0045, 7.0045] as [Float, Float];
        t.update(fix(off, 600));
        var straight = Geo.distance(off[0], off[1], 46.009, 7.0129);
        Test.assertMessage(near(t.toHead()[0], straight, 1.0), "straight to the head: " + t.toHead()[0] + ", " + straight);
        // Ten minutes of leg 1's 50 m a minute.
        Test.assertMessage(near(t.d, 500.0, 0.5), "the place by time: " + t.d);
        Test.assertMessage(!t.fixed, "no fix on the track yet");
        // Back within 200 m (about 150 m east of leg 1), snapped again: the place where GPS says.
        t.update(fix([46.0072, 7.0019] as [Float, Float], 660));
        Test.assertMessage(near(t.d, 800.0, 15.0), "snapped again: " + t.d);
        Test.assertMessage(t.fixed, "on the track");
        return true;
    }

    // The cutoff holds on a track of the points too: the straight line, and the place by time.
    (:test)
    function offTheTrackOfThePoints(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        var off = [46.0045, 7.0045] as [Float, Float];
        t.update(fix(off, 600));
        Test.assertMessage(near(t.toHead()[0], Geo.distance(off[0], off[1], 46.009, 7.0129), 1.0), "straight: " + t.toHead()[0]);
        Test.assertMessage(near(t.d, 500.0, 0.5), "the place by time: " + t.d);
        return true;
    }
}
