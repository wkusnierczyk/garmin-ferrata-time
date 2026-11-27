using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The climb flow's choices (design/real-functionality.md, section 5; #51), worked out from the tracker
// and the route: the exits an End may name, the points Calibrate offers, the altitude entry's steps,
// and the words the menus show. Pure, for the tests; FlowMenus builds the menus from them and FlowDraw
// draws them. Points are indices into the route's points; on the ferrata their at is the place's
// metres along.
module Flow {

    // The menus' colours: the pages' (Widgets), calibration grade A's light blue, and the flow mock's
    // own white and greys.
    const WHITE = 0xffffff;
    const GREY = 0x9aa0a3;
    const DIM = 0x4a5050;
    const SYNC = 0x8ecae6;

    // The GPS prompt's reach, in metres (#52): a landmark it prompted stays suggested this near.
    const GPS = 50;
    // The altitude entry's step, in metres, or in feet when the watch shows feet (owner, 2026-11-27,
    // #144).
    const STEP = 10;
    const STEP_FT = 50;
    // Feet in a metre, the pages' (Widgets), and metres in a mile.
    const FT = 3.28084;
    const MILE = 1609.344;

    // The units are the watch's (Widgets.feet; #144): a value in feet is converted, never relabelled.
    // The route and the tracker stay in metres; only what is shown converts.
    function inUnit(m as Float, ft as Boolean) as Number {
        return Math.round(ft ? m * FT : m).toNumber();
    }

    function unit(ft as Boolean) as String { return ft ? "ft" : "m"; }

    // An altitude entered in the unit shown, back in metres.
    function toMetres(v as Number, ft as Boolean) as Float {
        return ft ? v / FT : v.toFloat();
    }

    // The route's range of altitudes (metres) in the unit shown.
    function rangeIn(range as [Number, Number], ft as Boolean) as [Number, Number] {
        return [inUnit(range[0].toFloat(), ft), inUnit(range[1].toFloat(), ft)];
    }

    // The kinds a calibration may use: the head, the landmarks, the exits and the top.
    function isMark(kind as Object?) as Boolean {
        return kind instanceof String && ["head", "landmark", "exit", "top"].indexOf(kind) >= 0;
    }

    // The points a calibration may use, those on the ferrata with an altitude, nearest the place first:
    // Calibrate's At landmark list.
    function marks(t as Tracker) as Array<Number> {
        var out = [] as Array<Number>;
        var pts = t.route.points;
        for (var i = 0; i < pts.size(); i++) {
            if (isMark(pts[i]["kind"] as Object?) && (pts[i]["alt"] as Object?) != null
                && (pts[i]["at"] as Number) >= 0) { out.add(i); }
        }
        return nearestFirst(t.route, out, t.d);
    }

    // The exits ahead, or behind but within the band (the stretch the pages show), nearest first: one
    // End at exit row each. An estimate that ran ahead does not hide the exit the climber is at.
    function exitsInReach(t as Tracker) as Array<Number> {
        var lo = Climb.stretchAround(t.d, t.band())[0];
        var out = [] as Array<Number>;
        var pts = t.route.points;
        for (var i = 0; i < pts.size(); i++) {
            if ("exit".equals(pts[i]["kind"] as Object?) && (pts[i]["at"] as Number) >= lo) { out.add(i); }
        }
        return nearestFirst(t.route, out, t.d);
    }

    // The point Calibrate suggests, -1 for none: the nearest within the band, or one the GPS prompted
    // (#52) within its reach of the place; never one calibrated at already in this climb.
    function suggested(t as Tracker, prompted as Array<Number>) as Number {
        var around = Climb.stretchAround(t.d, t.band());
        var list = marks(t);
        for (var k = 0; k < list.size(); k++) {
            var i = list[k], at = t.route.points[i]["at"] as Number;
            if (t.calibratedAt.indexOf(i) >= 0) { continue; }
            if (at >= around[0] && at <= around[1]) { return i; }
            if (prompted.indexOf(i) >= 0 && (at - t.d).abs() <= GPS) { return i; }
        }
        return -1;
    }

    // The points sorted by how far each is from d, nearest first (a few points: an insertion sort).
    function nearestFirst(r as Route, list as Array<Number>, d as Float) as Array<Number> {
        for (var i = 1; i < list.size(); i++) {
            for (var j = i; j > 0 && off(r, list[j], d) < off(r, list[j - 1], d); j--) {
                var x = list[j]; list[j] = list[j - 1]; list[j - 1] = x;
            }
        }
        return list;
    }

    function off(r as Route, point as Number, d as Float) as Float {
        return ((r.points[point]["at"] as Number) - d).abs();
    }

    // The altitude entry's steps, in the unit shown: the first press goes to the next 10 m (50 ft) mark
    // up or down, later presses 10 m (50 ft) between marks, kept within range (the route's lowest and
    // highest altitude, in that unit); an altitude outside it comes in at the first press.
    function altUp(v as Number, range as [Number, Number], ft as Boolean) as Number {
        var step = ft ? STEP_FT : STEP;
        return within(Math.floor(v.toFloat() / step).toNumber() * step + step, range);
    }

    function altDown(v as Number, range as [Number, Number], ft as Boolean) as Number {
        var step = ft ? STEP_FT : STEP;
        return within(Math.ceil(v.toFloat() / step).toNumber() * step - step, range);
    }

    function within(v as Number, range as [Number, Number]) as Number {
        return v < range[0] ? range[0] : (v > range[1] ? range[1] : v);
    }

    // The steps beside Up and Down: the change each press would make, with its own sign, "+4" and
    // "–6", "+0" or "–0" where it makes none; out of range both bring the altitude in, so both may read
    // "+12" (the review of #124). The fonts have the en dash, not the minus sign.
    function steps(v as Number, range as [Number, Number], ft as Boolean) as [String, String] {
        return [step(altUp(v, range, ft) - v, true), step(altDown(v, range, ft) - v, false)];
    }

    function step(change as Number, up as Boolean) as String {
        if (change == 0) { return up ? "+0" : "–0"; }
        return (change > 0 ? "+" : "–") + change.abs().format("%d");
    }

    // How far a point at at is from the place d, as a value and its unit for a details screen (#121):
    // "here" (within 5 m), or metres under a kilometre, else kilometres to one place, ahead or back; in
    // feet (#144), feet under 1000 ft, else miles to one place.
    function ahead(at as Float, d as Float, ft as Boolean) as [String, String] {
        var v = at - d, a = v.abs(), way = v > 0 ? " ahead" : " back";
        if (a < 5) { return ["here", ""]; }
        if (inUnit(a, ft) < 1000) { return [inUnit(a, ft).format("%d"), unit(ft) + way]; }
        var long = far(a, ft);
        return [long[0], long[1] + way];
    }

    // A distance in kilometres, or miles in feet, to one place (the approach's to the head, #144).
    function far(m as Float, ft as Boolean) as [String, String] {
        return [(m / (ft ? MILE : 1000)).format("%.1f"), ft ? "mi" : "km"];
    }

    // The summary's figures and their units (#144): the height climbed, the activity's time (seconds,
    // shown as h:mm) and the drift, signed; heights in the unit shown.
    function summary(climbed as Number, activeS as Number, drift as Float, ft as Boolean) as Array<Array<String> > {
        return [[inUnit(climbed.toFloat(), ft).format("%d"), hours(activeS / 60), signed(inUnit(drift, ft))],
            [unit(ft), "", unit(ft)]] as Array<Array<String> >;
    }

    // A whole number of metres or feet with its sign, + or - (the fonts have no minus sign).
    function signed(v as Number) as String {
        return (v >= 0 ? "+" : "-") + v.abs().format("%d");
    }

    // Minutes as h:mm.
    function hours(minutes as Number) as String {
        return (minutes / 60).format("%d") + ":" + (minutes % 60).format("%02d");
    }

    // What a point is, as a details screen's title shows it, and its colour, the pages' (Widgets;
    // #121): HEAD and EXIT green, TOP red; a landmark by its type, REST blue, BRIDGE and SIGN grey (the
    // pages have no colour for them), LANDMARK grey for one without a type.
    function word(p as Dictionary) as String {
        var kind = p["kind"] as String;
        if (kind.equals("head")) { return "HEAD"; }
        if (kind.equals("exit")) { return "EXIT"; }
        if (kind.equals("top")) { return "TOP"; }
        var type = p["type"];
        return type instanceof String ? type.toUpper() : "LANDMARK";
    }

    function colour(p as Dictionary) as Number {
        var kind = p["kind"] as String;
        if (kind.equals("head")) { return Widgets.GREEN; }
        if (kind.equals("exit")) { return Widgets.GREEN; }
        if (kind.equals("top")) { return Widgets.RED; }
        return "rest".equals(p["type"] as Object?) ? Widgets.REST : GREY;
    }
}
