using Toybox.Math;
import Toybox.Lang;

// The route the pages show and the climber's place on it. The route is one part of the loaded route
// file at a time (use: the approach, or the ferrata from its head), so the pages count from the start
// of the part shown. In the demo everything the pages show is derived from one value, the guidebook
// minute `m` the climber has reached, so all pages agree.
module Climb {

    // One entry per section of the part: metres along the route, metres up (negative going down),
    // grade, guidebook minutes, name. The grade is the route file's, in half steps: 1 A, 2 A/B ... 7 D
    // ... 12 F/G; 0 is walking, and -1 marks a rest stretch.
    var LEN as Array<Number> = [] as Array<Number>;
    var UP as Array<Number> = [] as Array<Number>;
    var GRADE as Array<Number> = [] as Array<Number>;
    var MIN as Array<Number> = [] as Array<Number>;
    var NAME as Array<String> = [] as Array<String>;
    // The grades as the route file has them: the pages draw these too (A to F, #95), so GRADE is HALF
    // until the K setting (#58) lets the pages draw K grades instead.
    var HALF as Array<Number> = [] as Array<Number>;
    // Hard is D and above (design, section 5).
    const HARD = 7;

    // Exits leave at the start of these sections.
    var EXIT_AT as Array<Number> = [] as Array<Number>;
    var EXIT_NAME as Array<String> = [] as Array<String>;
    // A front view, as on a topo photo of the face: each section moves sideways by this share of its
    // length (the sign is left or right; the rest goes into the face) while it rises by its height.
    // A real route needs a frontal track traced from a topo; a GPS track gives the map view.
    var SIDE as Array<Float> = [] as Array<Float>;
    // Danger points, in metres along the part.
    var DANGER_AT as Array<Number> = [] as Array<Number>;

    // Whether the part is the ferrata (else the approach): only the ferrata starts at its head and ends
    // at the route's top.
    var FERRATA as Boolean = true;

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
    // The lowest and the highest net height at a boundary: the profile's range.
    var netRange as [Number, Number]? = null;

    // Fill the route's variables from one part of r: :approach or :ferrata.
    function use(r as Route, part as Symbol) as Void {
        var ferrata = part == :ferrata;
        FERRATA = ferrata;
        var list = ferrata ? r.sections : r.approach;
        var n = list.size();
        LEN = new [n] as Array<Number>;
        UP = new [n] as Array<Number>;
        GRADE = new [n] as Array<Number>;
        MIN = new [n] as Array<Number>;
        NAME = new [n] as Array<String>;
        HALF = new [n] as Array<Number>;
        SIDE = new [n] as Array<Float>;
        for (var i = 0; i < n; i++) {
            var s = list[i];
            LEN[i] = s["len"] as Number;
            UP[i] = s["up"] as Number;
            HALF[i] = s["grade"] as Number;
            GRADE[i] = HALF[i];
            MIN[i] = Route.minutes(s);
            NAME[i] = s["name"] as String;
            SIDE[i] = (s["side"] as Numeric).toFloat();
        }
        cumD = null; cumU = null; cumM = null; cumN = null; cumW = null; netRange = null;
        Widgets.forgetRoute();

        // Points: at is metres from the head, so the approach's are shifted by its length.
        var shift = ferrata ? 0 : Route.lengthOf(r.approach);
        var lo = ferrata ? 0 : -shift, hi = ferrata ? Route.lengthOf(r.sections) : -1;
        EXIT_AT = [] as Array<Number>;
        EXIT_NAME = [] as Array<String>;
        DANGER_AT = [] as Array<Number>;
        for (var p = 0; p < r.points.size(); p++) {
            var pt = r.points[p];
            if (!Route.isKnownKind(pt["kind"] as String)) { continue; }
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
    // the K scale: A is K1 to E K5, a half step rounds up to the harder grade, and F and above are K5.
    // For the K setting (#58); the pages draw the half steps meanwhile.
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
    // The height section i gains: its UP, or 0 for a section that loses height.
    function gain(i as Number) as Number { return UP[i] > 0 ? UP[i] : 0; }
    // Whether section i loses height (#100): its grade box is a trapezium, narrower at its foot.
    function descends(i as Number) as Boolean { return UP[i] < 0; }

    // Height gained up to boundary i: the sum of the positive UP, as "climbed" and the route's total
    // count it, so the pages that stack sections by height draw a descent as flat.
    function uAt(i as Number) as Number {
        var c = cumU;
        if (c == null) {
            c = new [count() + 1] as Array<Number>;
            c[0] = 0;
            for (var k = 0; k < count(); k++) { c[k + 1] = c[k] + gain(k); }
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

    // The lowest and the highest net height of the part, at its boundaries: below 0 when the part dips
    // under its start, above the top's when it goes higher before coming down to it.
    function netLow() as Number { return netRangeOf()[0]; }
    function netHigh() as Number { return netRangeOf()[1]; }

    function netRangeOf() as [Number, Number] {
        var r = netRange;
        if (r == null) {
            var lo = 0, hi = 0;
            for (var i = 1; i <= count(); i++) {
                var n = netAt(i);
                if (n < lo) { lo = n; }
                if (n > hi) { hi = n; }
            }
            r = [lo, hi];
            netRange = r;
        }
        return r;
    }

    function mAt(i as Number) as Number {
        var c = cumM;
        if (c == null) { c = cumulative(MIN); cumM = c; }
        return c[i];
    }

    function totalD() as Number { return dAt(count()); }
    // At least 1: an approach that gains no height (flat, or going down) would leave the pages that
    // draw the climb by height dividing by 0. Pages on the approach hide height figures (owner,
    // 2026-11-22); until then, a guard against dividing by 0.
    function totalU() as Number { var u = uAt(count()); return u > 0 ? u : 1; }
    function totalM() as Number { return mAt(count()); }

    // The demo plays the climb at a vertical pace: each section takes as long as the metres it climbs
    // (a flat one as long as 5 m), so walks pass quickly and walls slowly, and 10 % longer for each
    // full grade above walking, 1.1 to the power of half the half steps, as the mocks (rests count as
    // walking). The guidebook minute reached at fraction f.
    function demoWeight(i as Number) as Float {
        var w = (UP[i] > 5 ? UP[i] : 5).toFloat();
        return w * Math.pow(1.1, (GRADE[i] > 0 ? GRADE[i] : 0) / 2.0).toFloat();
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
                return uAt(i) + (d - d0) / LEN[i].toFloat() * gain(i);
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

    // The distance at which the guidebook minutes reach m: the start's before it, the end's past it.
    function distanceAtMinute(m as Float) as Float {
        if (m <= 0) { return 0.0; }
        for (var i = 0; i < count(); i++) {
            if (m <= mAt(i + 1)) {
                return MIN[i] > 0 ? dAt(i) + (m - mAt(i)) / MIN[i].toFloat() * LEN[i] : dAt(i + 1).toFloat();
            }
        }
        return totalD().toFloat();
    }

    // Where the climber is when the height since the start of the part reads u (net), having been
    // at fromD: [lo, hi], never behind fromD. The route is followed from fromD only as far as it keeps
    // going towards u:
    // - u above the height at fromD: up to the next high point ahead (where the route first turns
    //   down, or the end). lo is where it first reaches u there; when it does not (a reading above
    //   that high point: noise, or a sync off), lo is where it first reaches that high point.
    // - u below: if the route ahead goes down (after any flat), down to the next low point, likewise;
    //   if it goes up, lo is fromD: a reading falling on a climb does not move the place.
    // - Either way, a turn just ahead is passed: when the route first goes the other way by at most
    //   CREST metres (over any flats) before it turns towards u, the climber passed that crest or
    //   trough between two readings, and the search goes on from there (#100: the demo's readings step
    //   over the top of the Dihedral and over its foot, and the place stayed before each for good).
    // - u equal: lo is fromD.
    // hi extends lo over a flat stretch at lo's height (a traverse), else it is lo.
    // (Coordinator's definition, replacing the plan's, after the review of #88: the plan's searched
    // the whole route ahead, so a reading a few metres off jumped past a dip or to the top.)
    // A crest or trough no more than this from the place may have been passed between two readings:
    // more than a reading's climb (a metre or two, at a reading a second or the demo's every 250 ms),
    // less than a reading falling on a climb is taken for (a sync, a weather drop: tens of metres).
    const CREST = 5;

    function stretchAhead(fromD as Float, u as Float) as [Float, Float] {
        var total = totalD().toFloat();
        if (fromD >= total) { return [total, total]; }
        if (fromD < 0) { fromD = 0.0; }
        var h = netAtDistance(fromD);
        var lo = fromD;
        if (u != h) {
            // dir: 1 searching up, -1 down; started once the route goes that way.
            var dir = u > h ? 1 : -1, started = false;
            var turn = fromD;
            for (var i = sectionAt(fromD); i < count(); i++) {
                var d0 = fromD > dAt(i) ? fromD : dAt(i).toFloat(), d1 = dAt(i + 1).toFloat();
                if (d1 <= d0 || UP[i] == 0) { continue; }
                var slope = UP[i] > 0 ? 1 : -1;
                if (slope != dir) {
                    if (!started && dir * (netAt(i + 1) - h) >= -CREST) { continue; }
                    break;
                }
                started = true;
                var a = netAtDistance(d0), b = netAt(i + 1).toFloat();
                if (dir > 0 ? b >= u : b <= u) {
                    turn = d0 + crossing(dir * a, dir * b, dir * u) * (d1 - d0);
                    break;
                }
                turn = d1;
            }
            lo = turn;
        }
        // Over the flat stretch lo is on, if any.
        var hi = lo;
        for (var i = sectionAt(lo); i < count(); i++) {
            var d0 = lo > dAt(i) ? lo : dAt(i).toFloat(), d1 = dAt(i + 1).toFloat();
            if (d1 <= d0) { continue; }
            if (UP[i] != 0) { break; }
            hi = d1;
        }
        return [lo, hi];
    }

    // The stretch around distance d the climber may be on when the altitude is sure to band metres up
    // or down: [lo, hi], the route followed back and ahead from d while its real (net) height stays
    // within band of d's, over flat stretches too, to where it first leaves that band each way. A
    // descent is followed down like a climb up. On a route without descents this is the stretch
    // firstDistanceAt and lastDistanceAt give around the height gained.
    function stretchAround(d as Float, band as Number) as [Float, Float] {
        var total = totalD().toFloat();
        if (d < 0) { d = 0.0; }
        if (d > total) { d = total; }
        var n = netAtDistance(d), up = n + band, down = n - band;
        // Ahead: from d to the first point out of the band.
        var hi = total;
        for (var i = sectionAt(d); i < count(); i++) {
            var x0 = d > dAt(i) ? d : dAt(i).toFloat(), x1 = dAt(i + 1).toFloat();
            if (x1 <= x0) { continue; }
            var a = netAtDistance(x0), b = netAt(i + 1).toFloat();
            if (b > up || b < down) {
                var edge = b > up ? up : down;
                hi = x0 + (edge - a) / (b - a) * (x1 - x0);
                break;
            }
        }
        // Back: from d to the first point out of the band.
        var lo = 0.0;
        for (var i = sectionAt(d); i >= 0; i--) {
            var x0 = dAt(i).toFloat(), x1 = d < dAt(i + 1) ? d : dAt(i + 1).toFloat();
            if (x1 <= x0) { continue; }
            var a = netAtDistance(x1), b = netAt(i).toFloat();
            if (b > up || b < down) {
                var edge = b > up ? up : down;
                lo = x1 - (edge - a) / (b - a) * (x1 - x0);
                break;
            }
        }
        return [lo, hi];
    }

    // The share of a section rising from a to b at which it reaches u, kept within the section.
    function crossing(a as Float, b as Float, u as Float) as Float {
        if (b <= a) { return 0.0; }
        var f = (u - a) / (b - a);
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
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

    // The climber's state at guidebook minute m (the demo), or at a place the tracker worked out
    // (placed).
    class State {
        var m as Float;
        var cur as Number = 0;
        var d as Float = 0.0;
        var u as Float = 0.0;
        // How sure the place is, in metres up or down.
        var band as Number = UNCERTAINTY;
        // Own pace against the guidebook, and the clock at the start of the part.
        var pace as Float = PACE;
        var startClock as Float = START_CLOCK.toFloat();
        // Minutes since the start of the part, when the tracker gives them; else the demo's, m at pace.
        var given as Float? = null;

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
            u = uAt(cur) + f * gain(cur);
        }

        // The state at distance d along the part, u the height gained there, elapsed minutes since the
        // part started (pauses included) at pace against the guidebook, the part started at
        // startClock (minutes of the day), the place sure to band metres.
        static function placed(d as Float, u as Float, elapsed as Float, pace as Float, startClock as Float,
                band as Number) as State {
            var st = new State(0.0);
            var td = totalD().toFloat();
            st.d = d < 0 ? 0.0 : (d > td ? td : d);
            st.u = u;
            st.m = minuteAtDistance(st.d);
            st.cur = count() - 1;
            for (var i = 0; i < count(); i++) {
                if (st.d < dAt(i + 1)) { st.cur = i; break; }
            }
            st.given = elapsed;
            st.pace = pace;
            st.startClock = startClock;
            st.band = band;
            return st;
        }

        // The real height above the start of the part (net, up and down), where u is the height gained;
        // and the real altitude.
        function net() as Float { return netAtDistance(d); }
        function altitude() as Number { return START_ALT + net().toNumber(); }
        // The stretch the climber may be on, from how sure the altitude is (stretchAround).
        function stretch() as [Float, Float] { return stretchAround(d, band); }
        function climbed() as Number { return Math.round(u).toNumber(); }
        function elapsed() as Float { var e = given; return e != null ? e : m * pace; }
        function left() as Float { return (totalM() - m) * pace; }
        function clock() as Float { return startClock + elapsed(); }

        // The next section ahead that is D or harder, by its half-step grade; -1 if none.
        function nextHard() as Number {
            for (var i = cur + 1; i < count(); i++) { if (HALF[i] >= HARD) { return i; } }
            return -1;
        }
    }
}
