using Toybox.WatchUi;

import Toybox.Lang;
import Toybox.Test;

// The route file into Climb (#48): parts, counting from the head, gained against net height, and the
// lookups the tracker uses.
module RouteTest {

    // The bundled route, as App loads it.
    function demo() as Route {
        return Route.fromJson(WatchUi.loadResource(Rez.JsonData.route) as Dictionary) as Route;
    }

    // A route of the given sections, each [len, up], with only a head and a top.
    function made(steps as Array<Array<Number> >) as Route {
        var sections = [] as Array<Dictionary>;
        var len = 0;
        for (var i = 0; i < steps.size(); i++) {
            sections.add({"len" => steps[i][0], "up" => steps[i][1], "grade" => 1, "min" => 10,
                "name" => "S" + i, "side" => 0.0});
            len += steps[i][0];
        }
        return Route.fromJson({"format" => 1, "id" => "t", "name" => "Test", "short" => "Test",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 1000, "name" => "Head"},
                {"kind" => "top", "at" => len, "name" => "Top"}]}) as Route;
    }

    function near(a as Float, b as Float) as Boolean {
        var e = a - b;
        return e < 0.001 && e > -0.001;
    }

    (:test)
    function fromJsonRejectsWrongFormat(logger as Logger) as Boolean {
        var data = WatchUi.loadResource(Rez.JsonData.route) as Dictionary;
        data["format"] = 2;
        return Route.fromJson(data) == null;
    }

    (:test)
    function fromJsonRejectsMissingHead(logger as Logger) as Boolean {
        var data = WatchUi.loadResource(Rez.JsonData.route) as Dictionary;
        var kept = [] as Array<Dictionary>;
        var points = data["points"] as Array<Dictionary>;
        for (var i = 0; i < points.size(); i++) {
            if (!"head".equals(points[i]["kind"] as Object?)) { kept.add(points[i]); }
        }
        data["points"] = kept;
        return Route.fromJson(data) == null;
    }

    (:test)
    function demoRouteParts(logger as Logger) as Boolean {
        var r = demo();
        Test.assertEqualMessage(r.short, "Demo", "short");
        Test.assertMessage(r.hasApproach(), "has an approach");
        Test.assertMessage(r.approachKnown(), "the approach point has an altitude");
        // Car park, head, Bench, top.
        Test.assertEqualMessage(r.knownPoints().toString(), [0, 1, 4, 7].toString(), "known points");
        return true;
    }

    (:test)
    function useFerrataDropsApproach(logger as Logger) as Boolean {
        Climb.use(demo(), :ferrata);
        Test.assertEqualMessage(Climb.count(), 12, "sections");
        Test.assertEqualMessage(Climb.totalU(), 510, "gained height");
        Test.assertEqualMessage(Climb.totalD(), 640, "length");
        Test.assertEqualMessage(Climb.START_ALT, 1290, "start altitude");
        Test.assertEqualMessage(Climb.EXIT_AT.toString(), [4, 8].toString(), "exits");
        Test.assertEqualMessage(Climb.EXIT_NAME.toString(), ["Band exit", "Last exit"].toString(), "exit names");
        Test.assertEqualMessage(Climb.DANGER_AT.toString(), [55, 520].toString(), "dangers");
        // Half steps on the K scale the pages draw: 5 (C) is K3, 9 (E) is K5.
        Test.assertEqualMessage(Climb.GRADE[0], 3, "first wall");
        Test.assertEqualMessage(Climb.GRADE[8], 5, "overhang");
        return true;
    }

    (:test)
    function useApproachIsItsOwnPart(logger as Logger) as Boolean {
        Climb.use(demo(), :approach);
        Test.assertEqualMessage(Climb.count(), 1, "sections");
        Test.assertEqualMessage(Climb.totalD(), 120, "length");
        Test.assertEqualMessage(Climb.START_ALT, 1270, "start altitude");
        Test.assertEqualMessage(Climb.EXIT_AT.size(), 0, "no exits");
        Test.assertEqualMessage(Climb.DANGER_AT.size(), 0, "no dangers");
        return true;
    }

    (:test)
    function halfStepsRoundUpToK(logger as Logger) as Boolean {
        var k = [] as Array<Number>;
        for (var h = -1; h <= 12; h++) { k.add(Climb.kGrade(h)); }
        Test.assertEqualMessage(k.toString(), [-1, 0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5, 5, 5].toString(), "K grades");
        return true;
    }

    (:test)
    function missingMinutesAreEstimated(logger as Logger) as Boolean {
        var data = WatchUi.loadResource(Rez.JsonData.route) as Dictionary;
        var sections = data["sections"] as Array<Dictionary>;
        sections[0].remove("min");
        Climb.use(Route.fromJson(data) as Route, :ferrata);
        // First wall, 35 m long and 90 m up: 18 minutes at 300 m an hour, plus half of the half minute
        // its length takes at 4 km an hour.
        Test.assertEqualMessage(Climb.MIN[0], 18, "estimated");
        Test.assertEqualMessage(Climb.MIN[1], 10, "kept");
        return true;
    }

    (:test)
    function stretchAheadOnClimb(logger as Logger) as Boolean {
        Climb.use(made([[100, 100]]), :ferrata);
        var s = Climb.stretchAhead(0.0, 50.0);
        return near(s[0], 50.0) && near(s[1], 50.0);
    }

    (:test)
    function stretchAheadOnTraverse(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [200, 0], [100, 100]]), :ferrata);
        var s = Climb.stretchAhead(0.0, 100.0);
        return near(s[0], 100.0) && near(s[1], 300.0);
    }

    (:test)
    function stretchAheadNeverBehind(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [200, 0], [100, 100]]), :ferrata);
        var s = Climb.stretchAhead(250.0, 100.0);
        Test.assertMessage(near(s[0], 250.0) && near(s[1], 300.0), "on the traverse: " + s);
        s = Climb.stretchAhead(250.0, 40.0);
        Test.assertMessage(near(s[0], 250.0) && near(s[1], 250.0), "below: " + s);
        return true;
    }

    (:test)
    function stretchAheadAcrossDescent(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [50, -50], [100, 100]]), :ferrata);
        // At 160 the route is 60 m up, climbing the third section: 75 m is 15 m further.
        var s = Climb.stretchAhead(160.0, 75.0);
        return near(s[0], 175.0) && near(s[1], 175.0);
    }

    (:test)
    function gainedIgnoresDescent(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [50, -50], [100, 100]]), :ferrata);
        Test.assertEqualMessage(Climb.totalU(), 200, "gained");
        Test.assertEqualMessage(Climb.netAt(3), 150, "net");
        Test.assertMessage(near(Climb.netAtDistance(125.0), 75.0), "net mid-descent");
        return true;
    }

    (:test)
    function minuteAtDistanceMidSection(logger as Logger) as Boolean {
        Climb.use(demo(), :ferrata);
        // First wall: 35 m in 20 minutes; Ledge: 10 m in 10.
        Test.assertMessage(near(Climb.minuteAtDistance(17.5), 10.0), "first wall");
        Test.assertMessage(near(Climb.minuteAtDistance(40.0), 25.0), "ledge");
        Test.assertMessage(near(Climb.minuteAtDistance(640.0), Climb.totalM().toFloat()), "top");
        return true;
    }
}
