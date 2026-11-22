import Toybox.Lang;

// The route the pages show and the climber's place on it. The route is one part of the loaded route
// file at a time (use: the approach, or the ferrata from its head), so the pages count from the start
// of the part shown. In the demo everything the pages show is derived from one value, the guidebook
// minute `m` the climber has reached, so all pages agree.
module Climb {

    // One entry per section of the part: metres along the route, metres up (negative going down),
    // grade, guidebook minutes, name. Grade 0 is walking, 1 to 5 are K1 to K5, and -1 marks a rest
    // stretch.
    var LEN as Array<Number> = [] as Array<Number>;
    var UP as Array<Number> = [] as Array<Number>;
    var GRADE as Array<Number> = [] as Array<Number>;
    var MIN as Array<Number> = [] as Array<Number>;
    var NAME as Array<String> = [] as Array<String>;
    const GRADE_NAME = ["walk", "K1", "K2", "K3", "K4", "K5"] as Array<String>;

    // Exits leave at the start of these sections.
    var EXIT_AT as Array<Number> = [] as Array<Number>;
    var EXIT_NAME as Array<String> = [] as Array<String>;
    // A front view, as on a topo photo of the face: each section moves sideways by this share of its
    // length (the sign is left or right; the rest goes into the face) while it rises by its height.
    // A real route needs a frontal track traced from a topo; a GPS track gives the map view.
    var SIDE as Array<Float> = [] as Array<Float>;
    // Danger points, in metres along the part.
    var DANGER_AT as Array<Number> = [] as Array<Number>;

    // Altitude at the start of the part.
    var START_ALT as Number = 0;
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
    // Net height at each boundary: up and down, where cumU counts only the metres gained.
    var cumN as Array<Number>? = null;

    // Fill the route's variables from one part of r: :approach or :ferrata.
    function use(r as Route, part as Symbol) as Void {
        var ferrata = part == :ferrata;
        var list = ferrata ? r.sections : r.approach;
        var n = list.size();
        LEN = new [n] as Array<Number>;
        UP = new [n] as Array<Number>;
        GRADE = new [n] as Array<Number>;
        MIN = new [n] as Array<Number>;
        NAME = new [n] as Array<String>;
        SIDE = new [n] as Array<Float>;
        for (var i = 0; i < n; i++) {
            var s = list[i];
            LEN[i] = s["len"] as Number;
            UP[i] = s["up"] as Number;
            GRADE[i] = kGrade(s["grade"] as Number);
            MIN[i] = Route.minutes(s);
            NAME[i] = s["name"] as String;
            SIDE[i] = (s["side"] as Numeric).toFloat();
        }
        cumD = null; cumU = null; cumM = null; cumN = null; cumW = null;

        // Points: at is metres from the head, so the approach's are shifted by its length.
        var shift = ferrata ? 0 : Route.lengthOf(r.approach);
        var lo = ferrata ? 0 : -shift, hi = ferrata ? Route.lengthOf(r.sections) : -1;
        EXIT_AT = [] as Array<Number>;
        EXIT_NAME = [] as Array<String>;
        DANGER_AT = [] as Array<Number>;
        for (var p = 0; p < r.points.size(); p++) {
            var pt = r.points[p];
            var at = pt["at"] as Number;
            if (at < lo || at > hi) { continue; }
            if ("danger".equals(pt["kind"] as Object?)) {
                DANGER_AT.add(at + shift);
            } else if ("exit".equals(pt["kind"] as Object?)) {
                for (var i = 0; i < n; i++) {
                    if (dAt(i) == at + shift) { EXIT_AT.add(i); EXIT_NAME.add(pt["name"] as String); break; }
                }
            }
        }
        sortExits();
        DANGER_AT.sort(null);

        var head = r.headAlt();
        START_ALT = head;
        if (!ferrata) {
            var a = r.point("approach");
            START_ALT = a >= 0 && r.points[a]["alt"] != null ? r.points[a]["alt"] as Number : head - Route.net(r.approach);
        }
    }

    // Exits in the order they come, their names with them; the route file need not list them so.
    function sortExits() as Void {
        for (var i = 1; i < EXIT_AT.size(); i++) {
            for (var j = i; j > 0 && EXIT_AT[j - 1] > EXIT_AT[j]; j--) {
                var e = EXIT_AT[j]; EXIT_AT[j] = EXIT_AT[j - 1]; EXIT_AT[j - 1] = e;
                var t = EXIT_NAME[j]; EXIT_NAME[j] = EXIT_NAME[j - 1]; EXIT_NAME[j - 1] = t;
            }
        }
    }

    // A grade in the route file's half steps (1 A, 2 A/B ... 11 F, 12 F/G; 0 walking, -1 rest) on
    // the K scale the pages draw: A is K1 to E K5, a half step rounds up to the harder grade, and F
    // and above draw as K5. Until the pages draw half steps (#58).
    function kGrade(h as Number) as Number {
        if (h <= 0) { return h; }
        var k = h / 2 + 1;
        return k < 5 ? k : 5;
    }

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
    // Height gained up to boundary i: the sum of the positive UP, as "climbed" and the route's total
    // count it, so the pages that stack sections by height draw a descent as flat.
    function uAt(i as Number) as Number {
        var c = cumU;
        if (c == null) {
            c = new [count() + 1] as Array<Number>;
            c[0] = 0;
            for (var k = 0; k < count(); k++) { c[k + 1] = c[k] + (UP[k] > 0 ? UP[k] : 0); }
            cumU = c;
        }
        return c[i];
    }
    // Net height at boundary i, up and down: the real height above the start of the part.
    function netAt(i as Number) as Number {
        var c = cumN;
        if (c == null) { c = cumulative(UP); cumN = c; }
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

    // The demo plays the climb at a vertical pace: each section takes as long as the metres it climbs
    // (a flat one as long as 5 m), so walks pass quickly and walls slowly, and 10 % longer for each
    // grade above walking (rests count as walking). The guidebook minute reached at fraction f.
    function demoWeight(i as Number) as Float {
        var w = (UP[i] > 5 ? UP[i] : 5).toFloat();
        for (var g = 0; g < GRADE[i]; g++) { w *= 1.1; }
        return w;
    }

    // The weights summed up to each boundary, worked out once.
    var cumW as Array<Float>? = null;

    function demoMinute(f as Float) as Float {
        // The end exactly, whatever the Float sums leave over.
        if (f >= 1.0) { return totalM().toFloat(); }
        var c = cumW;
        if (c == null) {
            c = new [count() + 1] as Array<Float>;
            c[0] = 0.0;
            for (var i = 0; i < count(); i++) { c[i + 1] = c[i] + demoWeight(i); }
            cumW = c;
        }
        var t = f * c[count()];
        for (var i = 0; i < count(); i++) {
            if (t <= c[i + 1]) { return mAt(i) + (t - c[i]) / demoWeight(i) * MIN[i]; }
        }
        return totalM().toFloat();
    }

    // Height climbed (gained) at a distance along the route.
    function heightAtDistance(d as Float) as Float {
        for (var i = 0; i < count(); i++) {
            var d1 = dAt(i + 1);
            if (d <= d1) {
                var d0 = dAt(i);
                return uAt(i) + (d - d0) / LEN[i].toFloat() * (UP[i] > 0 ? UP[i] : 0);
            }
        }
        return totalU().toFloat();
    }

    // The section a distance falls in: the first that ends at or after it, the last past the top.
    function sectionAt(d as Float) as Number {
        for (var i = 0; i < count(); i++) { if (d <= dAt(i + 1)) { return i; } }
        return count() - 1;
    }

    // Net height, up and down, at a distance along the route; the start's before it, the top's past it.
    function netAtDistance(d as Float) as Float {
        if (d <= 0) { return 0.0; }
        if (d >= totalD()) { return netAt(count()).toFloat(); }
        var i = sectionAt(d);
        return netAt(i) + (d - dAt(i)) / LEN[i].toFloat() * UP[i];
    }

    // Guidebook minutes to reach a distance along the route.
    function minuteAtDistance(d as Float) as Float {
        if (d <= 0) { return 0.0; }
        if (d >= totalD()) { return totalM().toFloat(); }
        var i = sectionAt(d);
        return mAt(i) + (d - dAt(i)) / LEN[i].toFloat() * MIN[i];
    }

    // Where the route is at net height u, at or after fromD: from the first distance that reaches u
    // to the last before the route rises above it, [lo, hi]. When u is at or below the height at
    // fromD, the climber cannot be behind: [fromD, the last distance at u or lower, at least fromD].
    // Past the top when the route never reaches u: [total, total].
    function stretchAhead(fromD as Float, u as Float) as [Float, Float] {
        var total = totalD().toFloat();
        if (fromD >= total) { return [total, total]; }
        if (fromD < 0) { fromD = 0.0; }
        if (u <= netAtDistance(fromD)) {
            var last = lastNetDistanceAt(u);
            return [fromD, last > fromD ? last : fromD];
        }
        // The first crossing upwards: each section starts below u, or the search would have stopped.
        var lo = total;
        var first = sectionAt(fromD);
        for (var i = first; i < count(); i++) {
            var d0 = i == first ? fromD : dAt(i).toFloat(), d1 = dAt(i + 1).toFloat();
            var a = netAtDistance(d0), b = netAt(i + 1).toFloat();
            if (b >= u) { lo = d0 + crossing(a, b, u) * (d1 - d0); break; }
        }
        if (lo >= total) { return [total, total]; }
        // From lo, where the route is at u, to where it first rises above u.
        var start = sectionAt(lo);
        for (var i = start; i < count(); i++) {
            var d0 = i == start ? lo : dAt(i).toFloat(), d1 = dAt(i + 1).toFloat();
            var a = netAtDistance(d0), b = netAt(i + 1).toFloat();
            if (b > u) { return [lo, d0 + crossing(a, b, u) * (d1 - d0)]; }
        }
        return [lo, total];
    }

    // The share of a section rising from a to b at which it reaches u, kept within the section.
    function crossing(a as Float, b as Float, u as Float) as Float {
        if (b <= a) { return 0.0; }
        var f = (u - a) / (b - a);
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    }

    // The last distance at which the route is at net height u or lower; 0 when it starts above.
    function lastNetDistanceAt(u as Float) as Float {
        for (var i = count() - 1; i >= 0; i--) {
            var a = netAt(i).toFloat(), b = netAt(i + 1).toFloat();
            if (b <= u) { return dAt(i + 1).toFloat(); }
            if (a <= u) { return dAt(i) + crossing(a, b, u) * LEN[i]; }
        }
        return 0.0;
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
            u = uAt(cur) + f * (UP[cur] > 0 ? UP[cur] : 0);
        }

        // The real altitude: net height, where u is the height gained.
        function altitude() as Number { return START_ALT + netAtDistance(d).toNumber(); }
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
