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
    // own white, greys and the paused yellow.
    const WHITE = 0xffffff;
    const GREY = 0x9aa0a3;
    const DIM = 0x4a5050;
    const SYNC = 0x8ecae6;
    const PAUSED = 0xffd166;

    // The GPS prompt's reach, in metres (#52): a landmark it prompted stays suggested this near.
    const GPS = 50;
    // The altitude entry's step, in metres.
    const STEP = 10;

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

    // The altitude entry's steps: the first press goes to the next 10 m mark up or down, later presses
    // 10 m between marks, kept within range (the route's lowest and highest altitude); an altitude
    // outside it comes in at the first press.
    function altUp(v as Number, range as [Number, Number]) as Number {
        return within(Math.floor(v.toFloat() / STEP).toNumber() * STEP + STEP, range);
    }

    function altDown(v as Number, range as [Number, Number]) as Number {
        return within(Math.ceil(v.toFloat() / STEP).toNumber() * STEP - STEP, range);
    }

    function within(v as Number, range as [Number, Number]) as Number {
        return v < range[0] ? range[0] : (v > range[1] ? range[1] : v);
    }

    // A distance as the menus show it: metres under a kilometre, else kilometres to one place.
    function metres(a as Float) as String {
        return a < 1000 ? Math.round(a).toNumber().format("%d") + " m" : (a / 1000).format("%.1f") + " km";
    }

    // How far a point at at is from the place d, for a landmark's row: "in 60 m", "60 m back", "here".
    function inDistance(at as Float, d as Float) as String {
        var v = at - d, a = v.abs();
        if (a < 5) { return "here"; }
        return v > 0 ? "in " + metres(a) : metres(a) + " back";
    }

    // The same for the altitude entry: "60 m ahead", "60 m back", "here".
    function away(at as Float, d as Float) as String {
        var v = at - d, a = v.abs();
        if (a < 5) { return "here"; }
        return metres(a) + (v > 0 ? " ahead" : " back");
    }

    // Metres along the route in kilometres, to two places.
    function km(d as Float) as String {
        return (d / 1000).format("%.2f") + " km";
    }

    // A whole number of metres with its sign, + or - (the fonts have no minus sign).
    function signed(v as Number) as String {
        return (v >= 0 ? "+" : "-") + v.abs().format("%d");
    }

    // Minutes as h:mm.
    function hours(minutes as Number) as String {
        return (minutes / 60).format("%d") + ":" + (minutes % 60).format("%02d");
    }

    // A point's kind as a landmark's row shows it, and its colour, the pages' (Widgets): the head
    // orange, an exit green, the top red. A landmark's own kind (a rest, a bridge, a sign) is not in
    // the route file yet: LANDMARK in grey, as the mock's bridge and sign.
    function kindWord(kind as String) as String {
        if (kind.equals("head")) { return "HEAD"; }
        if (kind.equals("exit")) { return "EXIT"; }
        if (kind.equals("top")) { return "TOP"; }
        return "LANDMARK";
    }

    function kindColour(kind as String) as Number {
        if (kind.equals("head")) { return Widgets.CLIMBER; }
        if (kind.equals("exit")) { return Widgets.GREEN; }
        if (kind.equals("top")) { return Widgets.RED; }
        return GREY;
    }
}
