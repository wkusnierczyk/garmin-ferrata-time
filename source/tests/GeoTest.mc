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
        return Route.fromJson({"format" => 1, "id" => "g", "name" => "Geo", "short" => "Geo",
            "approach" => [
                {"len" => 1000, "up" => 0, "grade" => 0, "min" => 20, "name" => "Valley", "side" => 0.0},
                {"len" => 1000, "up" => 100, "grade" => 0, "min" => 30, "name" => "Slope", "side" => 0.0}],
            "sections" => [{"len" => 100, "up" => 50, "grade" => 1, "min" => 10, "name" => "Wall", "side" => 0.0}],
            "points" => [start, ford, h, {"kind" => "top", "at" => 100, "alt" => 1150, "name" => "Top"}]}) as Route;
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

    (:test)
    function snapsToTheTrack(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(LEG1, 600));
        var h = t.toHead();
        // Along the track: 500 m of leg 1 and all of leg 2; straight to the head it would be 1094 m.
        Test.assertMessage(near(h[0], 1500.0, 10.0), "along the track: " + h[0]);
        Test.assertMessage(near(t.d, 500.0, 10.0), "the place follows: " + t.d);
        // 10 guidebook minutes done in 10: pace 1, so the 40 minutes ahead.
        Test.assertMessage(near(h[1], 40.0, 0.5), "time at the pace: " + h[1]);
        t.update(fix(LEG2, 1200));
        Test.assertMessage(near(t.toHead()[0], 500.0, 10.0), "on leg 2: " + t.toHead()[0]);
        return true;
    }

    (:test)
    function straightLineWithoutTrack(logger as Logger) as Boolean {
        var t = walking(route(false, true));
        t.update(fix(LEG1, 600));
        var left = t.toHead()[0];
        // 500 m south and 973 m west of the head.
        Test.assertMessage(near(left, 1094.0, 5.0), "straight to the head: " + left);
        return true;
    }

    (:test)
    function timeAloneWithoutCoordinates(logger as Logger) as Boolean {
        var t = walking(route(false, false));
        // GPS would say 500 m; time alone says 10 of the 20 minutes of leg 1 done.
        t.update(fix(LEG2, 600));
        var h = t.toHead();
        Test.assertMessage(near(h[0], 1500.0, 0.5), "by time: " + h[0]);
        Test.assertMessage(near(h[1], 40.0, 0.5), "time: " + h[1]);
        return true;
    }

    // A stale or poor fix reaches the tracker as a reading without a position (SensorInput.positionOf,
    // InputsTest): time moves the place on from where the last fix put it.
    (:test)
    function staleFixFallsBackToTime(logger as Logger) as Boolean {
        var t = walking(route(true, true));
        t.update(fix(LEG1, 600));
        t.update(new Reading(1000.0, null, null, 1200));
        var h = t.toHead();
        // From 500 m at minute 10, 10 more minutes at pace 1: the end of leg 1.
        Test.assertMessage(near(h[0], 1000.0, 10.0), "by time from the fix: " + h[0]);
        Test.assertMessage(near(h[1], 30.0, 0.5), "time: " + h[1]);
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

    (:test)
    function gpsLeavesTheFerrataAlone(logger as Logger) as Boolean {
        var t = new Tracker(route(true, true));
        t.start(:head, new Reading(1100.0, null, null, 0));
        t.update(new Reading(1100.0, LEG1[0], LEG1[1], 60));
        Test.assertMessage(near(t.d, 0.0, 0.01), "still at the head: " + t.d);
        return true;
    }
}
