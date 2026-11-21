import Toybox.Lang;

// The demo's made-up route and the climber's place on it. Everything the pages show is derived
// from one value, the guidebook minute `m` the climber has reached, so all pages agree.
module Climb {

    // One entry per section: metres along the route, metres up, grade, guidebook minutes, name.
    // Grade 0 is walking, 1 to 5 are K1 to K5, and -1 marks a rest stretch.
    const LEN = [120, 35, 10, 140, 25, 150, 30, 40, 45, 15, 60, 20, 70] as Array<Number>;
    const UP = [20, 90, 0, 30, 110, 10, 0, 5, 70, 85, 5, 60, 45] as Array<Number>;
    const GRADE = [0, 3, -1, 2, 4, 1, -1, 1, 3, 5, 4, 4, 2] as Array<Number>;
    const MIN = [12, 20, 10, 14, 20, 15, 10, 6, 12, 15, 8, 12, 12] as Array<Number>;
    const NAME = ["Approach", "First wall", "Ledge", "Ledge traverse", "Dihedral", "Band", "Bench",
        "Band", "Slabs", "Overhang", "Bridge", "Ladders", "Exit gully"] as Array<String>;
    const GRADE_NAME = ["walk", "K1", "K2", "K3", "K4", "K5"] as Array<String>;

    // Exits leave at the start of these sections.
    const EXIT_AT = [5, 9] as Array<Number>;
    const EXIT_NAME = ["Band exit", "Last exit"] as Array<String>;
    // Danger points, in metres along the route: rockfall on the Ledge traverse, the exposed Bridge.
    const DANGER_AT = [175, 640] as Array<Number>;

    const START_ALT = 1270;
    // Own pace against the guidebook: 8 percent slower.
    const PACE = 1.08;
    // The demo clock reads 08:22 at the start.
    const START_CLOCK = 8 * 60 + 22;
    // How sure the position is, in metres up or down.
    const UNCERTAINTY = 25;

    function count() as Number { return LEN.size(); }

    // Cumulative distance, height and minutes at the start of each section, and at the top: built
    // once, since the pages look them up many times a frame.
    var cumD as Array<Number>? = null;
    var cumU as Array<Number>? = null;
    var cumM as Array<Number>? = null;

    function cumulative(steps as Array<Number>) as Array<Number> {
        var out = new [steps.size() + 1] as Array<Number>;
        out[0] = 0;
        for (var k = 0; k < steps.size(); k++) { out[k + 1] = out[k] + steps[k]; }
        return out;
    }

    function dAt(i as Number) as Number {
        var c = cumD;
        if (c == null) { c = cumulative(LEN); cumD = c; }
        return c[i];
    }
    function uAt(i as Number) as Number {
        var c = cumU;
        if (c == null) { c = cumulative(UP); cumU = c; }
        return c[i];
    }
    function mAt(i as Number) as Number {
        var c = cumM;
        if (c == null) { c = cumulative(MIN); cumM = c; }
        return c[i];
    }

    function totalD() as Number { return dAt(count()); }
    function totalU() as Number { return uAt(count()); }
    function totalM() as Number { return mAt(count()); }

    // Height climbed at a distance along the route.
    function heightAtDistance(d as Float) as Float {
        for (var i = 0; i < count(); i++) {
            var d1 = dAt(i + 1);
            if (d <= d1) {
                var d0 = dAt(i);
                return uAt(i) + (d - d0) / LEN[i].toFloat() * UP[i];
            }
        }
        return totalU().toFloat();
    }

    // The first distance at which the route reaches height u.
    function firstDistanceAt(u as Float) as Float {
        if (u <= 0) { return 0.0; }
        for (var i = 0; i < count(); i++) {
            if (UP[i] > 0 && uAt(i + 1) >= u) {
                return dAt(i) + (u - uAt(i)) / UP[i].toFloat() * LEN[i];
            }
        }
        return totalD().toFloat();
    }

    // The last distance at which the route is still at height u or lower.
    function lastDistanceAt(u as Float) as Float {
        if (u >= totalU()) { return totalD().toFloat(); }
        for (var i = count() - 1; i >= 0; i--) {
            if (uAt(i) <= u) {
                if (UP[i] > 0 && uAt(i + 1) > u) {
                    return dAt(i) + (u - uAt(i)) / UP[i].toFloat() * LEN[i];
                }
                return dAt(i + 1).toFloat();
            }
        }
        return 0.0;
    }

    function clockText(minutes as Float) as String {
        var t = minutes.toNumber() % 1440;
        return (t / 60).format("%d") + ":" + (t % 60).format("%02d");
    }

    function durationText(minutes as Float) as String {
        var t = minutes.toNumber();
        if (t < 0) { t = 0; }
        return (t / 60).format("%d") + ":" + (t % 60).format("%02d");
    }

    // The climber's state at guidebook minute m.
    class State {
        var m as Float;
        var cur as Number = 0;
        var d as Float = 0.0;
        var u as Float = 0.0;

        function initialize(minute as Float) {
            m = minute;
            var total = totalM();
            if (m > total) { m = total.toFloat(); }
            cur = count() - 1;
            for (var i = 0; i < count(); i++) {
                if (m < mAt(i + 1)) { cur = i; break; }
            }
            var f = (m - mAt(cur)) / MIN[cur].toFloat();
            if (f > 1.0) { f = 1.0; }
            d = dAt(cur) + f * LEN[cur];
            u = uAt(cur) + f * UP[cur];
        }

        function altitude() as Number { return START_ALT + u.toNumber(); }
        function climbed() as Number { return Math.round(u).toNumber(); }
        function elapsed() as Float { return m * PACE; }
        function left() as Float { return (totalM() - m) * PACE; }
        function clock() as Float { return START_CLOCK + elapsed(); }
        function finish() as Float { return clock() + left(); }

        // Minutes until the start of section i, at the climber's pace.
        function untilStart(i as Number) as Float { return (mAt(i) - m) * PACE; }

        function nextHard() as Number {
            for (var i = cur + 1; i < count(); i++) { if (GRADE[i] >= 4) { return i; } }
            return -1;
        }

        function nextRest() as Number {
            for (var i = cur + 1; i < count(); i++) { if (GRADE[i] < 0) { return i; } }
            return -1;
        }

        // Index into EXIT_AT of the next exit ahead, or -1.
        function nextExit() as Number {
            for (var e = 0; e < EXIT_AT.size(); e++) { if (dAt(EXIT_AT[e]) > d) { return e; } }
            return -1;
        }

        function exitsLeft() as Number {
            var n = 0;
            for (var e = 0; e < EXIT_AT.size(); e++) { if (dAt(EXIT_AT[e]) > d) { n++; } }
            return n;
        }

        function hardestDone() as Number {
            var g = -1;
            for (var i = 0; i < cur; i++) { if (GRADE[i] > g) { g = GRADE[i]; } }
            return g;
        }

        function hardestAhead() as Number {
            var g = -1;
            for (var i = cur; i < count(); i++) { if (GRADE[i] > g) { g = GRADE[i]; } }
            return g;
        }

        function firstAhead(grade as Number) as Number {
            for (var i = cur; i < count(); i++) { if (GRADE[i] == grade) { return i; } }
            return -1;
        }
    }
}
