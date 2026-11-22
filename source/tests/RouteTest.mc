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
    function usingAnotherPartForgetsWidgetLayouts(logger as Logger) as Boolean {
        // A layout measured on one part must not survive into another (Codex on #88).
        Climb.use(demo(), :approach);
        Widgets.gaugeStarts = [[0.0, 1.0] as Array<Float>, null] as Array<Array<Float>?>;
        Widgets.ascentWidest = 99;
        Climb.use(demo(), :ferrata);
        Test.assertMessage(Widgets.gaugeStarts[0] == null, "gauge layout forgotten");
        Test.assertMessage(Widgets.ascentWidest == null, "ascent width forgotten");
        Test.assertMessage(Widgets.front == null && Widgets.frontScreen == null, "front view forgotten");
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

    function stretch(fromD as Float, u as Float, lo as Float, hi as Float) as Void {
        var s = Climb.stretchAhead(fromD, u);
        Test.assertMessage(near(s[0], lo) && near(s[1], hi),
            "stretchAhead(" + fromD + ", " + u + ") is " + s + ", not [" + lo + ", " + hi + "]");
    }

    (:test)
    function stretchAheadOnClimb(logger as Logger) as Boolean {
        Climb.use(made([[100, 100]]), :ferrata);
        stretch(0.0, 50.0, 50.0, 50.0);
        return true;
    }

    (:test)
    function stretchAheadOnTraverse(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [200, 0], [100, 100]]), :ferrata);
        stretch(0.0, 100.0, 100.0, 300.0);
        return true;
    }

    (:test)
    function stretchAheadNeverBehind(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [200, 0], [100, 100]]), :ferrata);
        stretch(250.0, 100.0, 250.0, 300.0);
        // Below, on a traverse that then climbs: the place stays, over the rest of the traverse.
        stretch(250.0, 40.0, 250.0, 300.0);
        return true;
    }

    (:test)
    function stretchAheadAcrossDescent(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [50, -50], [100, 100]]), :ferrata);
        // At 160 the route is 60 m up, climbing the third section: 75 m is 15 m further.
        stretch(160.0, 75.0, 175.0, 175.0);
        return true;
    }

    // A reading above the next high point stops there, before the dip: not past it, not at the top.
    (:test)
    function stretchAheadOvershootStopsAtHighPoint(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [100, -50], [100, 0]]), :ferrata);
        stretch(90.0, 105.0, 100.0, 100.0);
        Climb.use(made([[100, 100], [100, -50], [100, 100]]), :ferrata);
        stretch(100.0, 101.0, 100.0, 100.0);
        // Above the top: the top.
        Climb.use(made([[100, 100]]), :ferrata);
        stretch(50.0, 150.0, 100.0, 100.0);
        return true;
    }

    // A reading falling on a climb does not move the place, even with lower ground further on.
    (:test)
    function stretchAheadFallOnClimbStays(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [100, -100], [100, 100]]), :ferrata);
        stretch(50.0, 49.0, 50.0, 50.0);
        return true;
    }

    // On a real descent the place follows the reading down, and no further than the low point.
    (:test)
    function stretchAheadFollowsDescent(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [100, -100], [100, 100]]), :ferrata);
        stretch(100.0, 70.0, 130.0, 130.0);
        stretch(130.0, 40.0, 160.0, 160.0);
        stretch(160.0, -10.0, 200.0, 200.0);
        stretch(200.0, 30.0, 230.0, 230.0);
        // A flat start, then down: followed down.
        Climb.use(made([[100, 0], [100, -100]]), :ferrata);
        stretch(50.0, -20.0, 120.0, 120.0);
        return true;
    }

    (:test)
    function stretchAheadAtTheEnd(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [100, -100], [100, 100]]), :ferrata);
        stretch(300.0, 50.0, 300.0, 300.0);
        stretch(300.0, 150.0, 300.0, 300.0);
        return true;
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

    // A fresh, valid route source with an approach, for the shape and fallback tests to change.
    function source() as Dictionary {
        return {"format" => 1, "id" => "t", "name" => "Test", "short" => "Test",
            "approach" => [
                {"len" => 100, "up" => 10, "grade" => 0, "min" => 10, "name" => "A1", "side" => 0.0},
                {"len" => 50, "up" => 10, "grade" => 0, "name" => "A2", "side" => 0.0}],
            "sections" => [
                {"len" => 40, "up" => 30, "grade" => 6, "min" => 10, "name" => "S1", "side" => 0.5},
                {"len" => 60, "up" => 50, "grade" => 7, "min" => 10, "name" => "S2", "side" => -0.5}],
            "points" => [
                {"kind" => "approach", "at" => -150, "alt" => 1000, "name" => "Start"},
                {"kind" => "exit", "at" => -50, "name" => "Approach exit"},
                {"kind" => "danger", "at" => -60, "name" => "Approach danger"},
                {"kind" => "head", "at" => 0, "alt" => 1020, "name" => "Head"},
                {"kind" => "danger", "at" => 70, "name" => "Danger"},
                {"kind" => "top", "at" => 100, "alt" => 1100, "name" => "Top"},
                {"kind" => "hut", "alt" => 1050}]};
    }

    function point(data as Dictionary, kind as String) as Dictionary {
        var points = data["points"] as Array<Dictionary>;
        for (var i = 0; i < points.size(); i++) {
            if (kind.equals(points[i]["kind"] as Object?)) { return points[i]; }
        }
        return {};
    }

    (:test)
    function approachPointsAreShifted(logger as Logger) as Boolean {
        var r = Route.fromJson(source()) as Route;
        Climb.use(r, :approach);
        Test.assertEqualMessage(Climb.EXIT_AT.toString(), [1].toString(), "approach exit");
        Test.assertEqualMessage(Climb.EXIT_NAME.toString(), ["Approach exit"].toString(), "approach exit name");
        Test.assertEqualMessage(Climb.DANGER_AT.toString(), [90].toString(), "approach danger");
        Test.assertEqualMessage(Climb.START_ALT, 1000, "approach start");
        Climb.use(r, :ferrata);
        Test.assertEqualMessage(Climb.EXIT_AT.size(), 0, "no exit on the ferrata");
        Test.assertEqualMessage(Climb.DANGER_AT.toString(), [70].toString(), "ferrata danger");
        Test.assertEqualMessage(Climb.START_ALT, 1020, "head");
        return true;
    }

    (:test)
    function unknownKindsAreIgnored(logger as Logger) as Boolean {
        // The hut has an alt but no at and no name: accepted, not a known point, not read by use.
        var r = Route.fromJson(source()) as Route;
        Test.assertEqualMessage(r.knownPoints().toString(), [0, 3, 5].toString(), "known points");
        Climb.use(r, :ferrata);
        return true;
    }

    (:test)
    function startAltitudeFallbacks(logger as Logger) as Boolean {
        // No head alt: the top's less the ferrata's net 80 m.
        var data = source();
        point(data, "head").remove("alt");
        var r = Route.fromJson(data) as Route;
        Climb.use(r, :ferrata);
        Test.assertEqualMessage(Climb.START_ALT, 1020, "from the top");
        // Neither: the approach start's plus the approach's 20 m.
        point(data, "top").remove("alt");
        r = Route.fromJson(data) as Route;
        Climb.use(r, :ferrata);
        Test.assertEqualMessage(Climb.START_ALT, 1020, "from the approach start");
        // No altitude anywhere: 0.
        point(data, "approach").remove("alt");
        r = Route.fromJson(data) as Route;
        Climb.use(r, :ferrata);
        Test.assertEqualMessage(Climb.START_ALT, 0, "none");
        // The approach without its start's alt: the head's less the approach's 20 m.
        data = source();
        point(data, "approach").remove("alt");
        r = Route.fromJson(data) as Route;
        Test.assertMessage(!r.approachKnown(), "approach not known");
        Climb.use(r, :approach);
        Test.assertEqualMessage(Climb.START_ALT, 1000, "approach from the head");
        return true;
    }

    (:test)
    function minutesEstimateDownAndAlong(logger as Logger) as Boolean {
        // 100 m down at 500 m an hour, 12 minutes, plus half of 1.5 along: 12.75.
        Test.assertEqualMessage(Route.minutes({"len" => 100, "up" => -100}), 13, "down");
        // 400 m along at 4 km an hour.
        Test.assertEqualMessage(Route.minutes({"len" => 400, "up" => 0}), 6, "along");
        Test.assertEqualMessage(Route.minutes({"len" => 10, "up" => 0}), 1, "at least a minute");
        Test.assertEqualMessage(Route.minutes({"len" => 10, "up" => 0, "min" => 7}), 7, "given");
        return true;
    }

    (:test)
    function hardIsDAndAbove(logger as Logger) as Boolean {
        // S1 is C/D (6), drawn as K4 but not hard; S2 is D (7).
        Climb.use(Route.fromJson(source()) as Route, :ferrata);
        Test.assertEqualMessage(Climb.GRADE[0], 4, "C/D draws as K4");
        var st = new Climb.State(0.0);
        Test.assertEqualMessage(st.nextHard(), 1, "D is the next hard section");
        var data = source();
        var s2 = (data["sections"] as Array<Dictionary>)[1];
        s2["grade"] = 6;
        Climb.use(Route.fromJson(data) as Route, :ferrata);
        Test.assertEqualMessage(new Climb.State(0.0).nextHard(), -1, "C/D is not hard");
        return true;
    }

    // Each malformed shape returns null rather than crashing.
    (:test)
    function fromJsonRejectsMalformed(logger as Logger) as Boolean {
        Test.assertMessage(Route.fromJson(source()) != null, "the source is valid");
        var data, s;
        data = source(); data["points"] = [1]; Test.assertMessage(Route.fromJson(data) == null, "a point not a dictionary");
        data = source(); data["sections"] = [1]; Test.assertMessage(Route.fromJson(data) == null, "a section not a dictionary");
        data = source(); data["sections"] = []; Test.assertMessage(Route.fromJson(data) == null, "no sections");
        data = source(); data["approach"] = 1; Test.assertMessage(Route.fromJson(data) == null, "approach not a list");
        data = source(); ((data["sections"] as Array<Dictionary>)[0]).remove("grade");
        Test.assertMessage(Route.fromJson(data) == null, "a section without grade");
        data = source(); s = (data["sections"] as Array<Dictionary>)[0]; s["len"] = 10.5;
        Test.assertMessage(Route.fromJson(data) == null, "a fractional len");
        data = source(); s = (data["sections"] as Array<Dictionary>)[0]; s["min"] = "10";
        Test.assertMessage(Route.fromJson(data) == null, "min a string");
        data = source(); ((data["approach"] as Array<Dictionary>)[0]).remove("up");
        Test.assertMessage(Route.fromJson(data) == null, "an approach section without up");
        data = source(); point(data, "danger").remove("at");
        Test.assertMessage(Route.fromJson(data) == null, "a point without at");
        data = source(); point(data, "head")["alt"] = "1020";
        Test.assertMessage(Route.fromJson(data) == null, "alt a string");
        data = source(); point(data, "top")["lat"] = "46";
        Test.assertMessage(Route.fromJson(data) == null, "lat a string");
        data = source(); (data["points"] as Array<Dictionary>).add({"kind" => 3, "at" => 0});
        Test.assertMessage(Route.fromJson(data) == null, "kind not a string");
        return true;
    }
}
