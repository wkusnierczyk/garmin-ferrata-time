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
        Widgets.ascentWidest = 0.25;
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
        Test.assertEqualMessage(Climb.totalU(), 400, "gained height");
        Test.assertEqualMessage(Climb.totalD(), 640, "length");
        Test.assertEqualMessage(Climb.START_ALT, 1290, "start altitude");
        Test.assertEqualMessage(Climb.EXIT_AT.toString(), [4, 8].toString(), "exits");
        Test.assertEqualMessage(Climb.EXIT_NAME.toString(), ["Band exit", "Last exit"].toString(), "exit names");
        Test.assertEqualMessage(Climb.DANGER_AT.toString(), [55, 520].toString(), "dangers");
        // The half steps the pages draw (#95): 5 is C, 9 is E.
        Test.assertEqualMessage(Climb.GRADE[0], 5, "first wall");
        Test.assertEqualMessage(Climb.GRADE[8], 9, "overhang");
        return true;
    }

    // The demo route descends at the Dihedral (#100), the route's fifth section counting the approach,
    // the mocks' section 5: by its height, so the altitudes chain 1380 to 1410, down to 1300, then 1310.
    (:test)
    function demoDescendsAtTheDihedral(logger as Logger) as Boolean {
        Climb.use(demo(), :ferrata);
        for (var i = 0; i < Climb.count(); i++) {
            Test.assertEqualMessage(Climb.descends(i), i == 3, "section " + i + " " + Climb.NAME[i]);
        }
        Test.assertEqualMessage(Climb.NAME[3], "Dihedral", "the Dihedral");
        Test.assertEqualMessage(Climb.UP[3], -110, "down by its height");
        var alts = [] as Array<Number>;
        for (var b = 3; b <= 5; b++) { alts.add(Climb.START_ALT + Climb.netAt(b)); }
        Test.assertEqualMessage(alts.toString(), [1410, 1300, 1310].toString(), "the altitudes chain");
        Test.assertEqualMessage(Climb.START_ALT + Climb.netAt(Climb.count()), 1580, "the top");
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

    // A reading below the place, the route ahead rising a few metres to a crest and then going down:
    // the climber may have passed the crest between two readings (#100: the demo's Dihedral, after the
    // Ledge traverse), so the stretch runs on down the descent and time carries the place over; the
    // place itself stays (the review of #101). A longer rise keeps the stretch at the place, as on a
    // climb; and the same for a trough.
    (:test)
    function stretchAheadOverACrestJustAhead(logger as Logger) as Boolean {
        Climb.use(made([[100, 100], [100, -100], [100, 100]]), :ferrata);
        // 2 m below the crest; the reading 90: on to 10 m down the other side.
        stretch(98.0, 90.0, 98.0, 110.0);
        // Past the low point it stops there.
        stretch(98.0, -10.0, 98.0, 200.0);
        // 10 m below the crest: a reading falling on a climb.
        stretch(90.0, 80.0, 90.0, 90.0);
        // A flat stretch between the rise and the crest is crossed too.
        Climb.use(made([[100, 100], [20, 0], [10, 3], [100, -100]]), :ferrata);
        stretch(99.0, 50.0, 99.0, 183.0);
        // No descent after the crest: the place stays.
        Climb.use(made([[100, 100], [100, 0]]), :ferrata);
        stretch(98.0, 90.0, 98.0, 98.0);
        // The same for a trough: a reading above the place, the route ahead going down 2 m before it
        // climbs, runs on to 8 m up the climb after it; 10 m down, the place stays.
        Climb.use(made([[100, 100], [100, -100], [100, 100]]), :ferrata);
        stretch(198.0, 10.0, 198.0, 210.0);
        stretch(190.0, 20.0, 190.0, 190.0);
        return true;
    }

    // A reading a little off near a crest never moves the place over it (the review of #101: a reading
    // 0.5 m low, 2 m under a gentle crest 30 m ahead, jumped the place 33 m down the far side, and a
    // 20 m drop of the weather near a crest of at most CREST put it 20 m down). The stretch runs over
    // the crest, so time alone carries the place on.
    (:test)
    function stretchAheadNoJumpOverACrest(logger as Logger) as Boolean {
        // Up 4 m in 60 to a crest at 160 m, 104 m up, then down 40 m in 50.
        Climb.use(made([[100, 100], [60, 4], [50, -40], [100, 100]]), :ferrata);
        // At 130 m, 102 m up; the reading 101.5: the place stays, the stretch to 101.5 m beyond.
        stretch(130.0, 101.5, 130.0, 163.125);
        // A 20 m drop 2 m under a crest.
        Climb.use(made([[100, 100], [100, -100]]), :ferrata);
        stretch(98.0, 78.0, 98.0, 122.0);
        // Through the tracker: the place moves on only by time, at the climber's pace.
        var t = new Tracker(made([[100, 100], [60, 4], [50, -40], [100, 100]]));
        t.start(:head, new Reading(1000.0, null, null, 0));
        t.d = 130.0;
        t.update(new Reading(1101.5, null, null, 6));
        Test.assertMessage(t.d > 130.0 && t.d < 133.0, "moved by time only, d " + t.d);
        return true;
    }

    // A reading that reads the same either side of a trough or crest just ahead: the stretch runs over
    // it to where the route is back at that height, so time moves the place past it (#100: the demo's
    // whole-metre readings read 11 m on the Dihedral's last metre down and on the Band's first 15 m, a
    // metre in 15, and the place stayed a metre above the foot while the demo went 17 m up the Band).
    // A deeper turn, or one the route never comes back from, keeps it.
    (:test)
    function stretchAheadOverATurnAtTheSameHeight(logger as Logger) as Boolean {
        // Down 64 m in 64, then up 10 m in 160, a metre in 16.
        Climb.use(made([[64, 64], [64, -64], [160, 10]]), :ferrata);
        // A metre above the foot, reading the same: up to a metre up the climb after it, 16 m on.
        stretch(127.0, 1.0, 127.0, 144.0);
        // Followed down to 2 m above the foot: on to 2 m up the climb.
        stretch(64.0, 2.0, 126.0, 160.0);
        // 6 m above the foot: more than CREST, the place stays.
        stretch(122.0, 6.0, 122.0, 122.0);
        // A crest 2 m above, over a flat top, down to the same height.
        Climb.use(made([[64, 64], [16, 0], [64, -64]]), :ferrata);
        stretch(62.0, 62.0, 62.0, 82.0);
        // No way down after the crest: the place stays.
        Climb.use(made([[64, 64], [64, 0]]), :ferrata);
        stretch(62.0, 62.0, 62.0, 62.0);
        // Back at the height onto a flat stretch: over it too.
        Climb.use(made([[32, -2], [32, 2], [64, 0], [64, 64]]), :ferrata);
        stretch(0.0, 0.0, 0.0, 128.0);
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
                {"kind" => "approach", "at" => -150, "alt" => 1000, "type" => "Top station", "name" => "Start"},
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
        // S1 is C/D (6), not hard; S2 is D (7).
        Climb.use(Route.fromJson(source()) as Route, :ferrata);
        Test.assertEqualMessage(Climb.GRADE[0], 6, "C/D drawn as such");
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
        var grades = [13, -2, 12] as Array<Number>;
        for (var g = 0; g < grades.size(); g++) {
            data = source();
            var first = (data["sections"] as Array<Dictionary>)[0];
            first["grade"] = grades[g];
            Test.assertMessage((Route.fromJson(data) == null) == (g < 2), "grade " + grades[g] + ": only -1 to 12");
        }
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
        data = source(); point(data, "approach").remove("type");
        Test.assertMessage(Route.fromJson(data) == null, "an approach point without its type");
        data = source(); point(data, "approach")["type"] = 3;
        Test.assertMessage(Route.fromJson(data) == null, "type not a string");
        return true;
    }

    // The approach's start by what it is (#121): the Start menu's row reads its type.
    (:test)
    function approachStartType(logger as Logger) as Boolean {
        Test.assertEqualMessage((Route.fromJson(source()) as Route).approachType(), "Top station", "its type");
        Test.assertEqualMessage(demo().approachType(), "Car park", "the demo's");
        return true;
    }
}
