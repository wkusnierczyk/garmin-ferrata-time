using Toybox.Math;

import Toybox.Lang;

// A route file, resources/routes/<id>.json, as tools/route.py writes it (design/real-functionality.md,
// section 4). The tool has checked it; this only refuses what the app cannot climb at all. Sections
// and points stay the file's dictionaries: Climb reads them one part at a time.
class Route {

    var id as String;
    var name as String;
    // The activity's name, at most 15 characters.
    var short as String;
    // Where the route is, for the ready screen (#51); empty when the file has none.
    var place as String;
    // The sections before the head; empty when the route has no approach.
    var approach as Array<Dictionary>;
    // The ferrata, from the head to the top.
    var sections as Array<Dictionary>;
    var points as Array<Dictionary>;

    function initialize(data as Dictionary) {
        id = data["id"] as String;
        name = data["name"] as String;
        short = data["short"] as String;
        var pl = data["place"];
        place = pl instanceof String ? pl : "";
        var a = data["approach"];
        approach = a instanceof Array ? a as Array<Dictionary> : [] as Array<Dictionary>;
        sections = data["sections"] as Array<Dictionary>;
        points = data["points"] as Array<Dictionary>;
    }

    // The route in data, or null when the app cannot read it: another format (this app reads format
    // 1), a head, a top or sections missing, or any section or known point of the wrong shape. The
    // checks go down to every field the app reads, so a route from elsewhere than the build (storage,
    // later) cannot crash it.
    static function fromJson(data as Dictionary) as Route? {
        var f = data["format"];
        if (!(f instanceof Number) || f != 1) { return null; }
        if (!(data["id"] instanceof String) || !(data["name"] instanceof String)
            || !(data["short"] instanceof String)) { return null; }
        var s = data["sections"], p = data["points"], a = data["approach"];
        if (!(s instanceof Array) || (s as Array).size() == 0 || !(p instanceof Array)) { return null; }
        if (a != null && !(a instanceof Array)) { return null; }
        if (!sectionsValid(s as Array) || a != null && !sectionsValid(a as Array)) { return null; }
        var pts = p as Array;
        for (var i = 0; i < pts.size(); i++) {
            if (!pointValid(pts[i] as Object?)) { return null; }
        }
        var r = new Route(data);
        if (r.point("head") < 0 || r.point("top") < 0) { return null; }
        return r;
    }

    // Each a dictionary with whole-number len, up and grade (min too, when there), a name and a side.
    static function sectionsValid(list as Array) as Boolean {
        for (var i = 0; i < list.size(); i++) {
            var s = list[i];
            if (!(s instanceof Dictionary)) { return false; }
            var d = s as Dictionary;
            if (!(d["len"] instanceof Number) || !(d["up"] instanceof Number)
                || !(d["grade"] instanceof Number) || !(d["name"] instanceof String)
                || !isNumeric(d["side"] as Object?)) { return false; }
            if (d["min"] != null && !(d["min"] instanceof Number)) { return false; }
            // A grade from -1 (rest) and 0 (walking) to 12 (F/G), as the route tool checks: the pages
            // look a grade up in tables of these.
            var g = d["grade"] as Number;
            if (g < -1 || g > 12) { return false; }
        }
        return true;
    }

    // A dictionary with a string kind; a point of a known kind also has a whole-number at and a name,
    // the approach's start and a landmark a type, and alt, lat and lon are numbers when there. Unknown
    // kinds are not checked: they are ignored.
    static function pointValid(p as Object?) as Boolean {
        if (!(p instanceof Dictionary)) { return false; }
        var d = p as Dictionary;
        var kind = d["kind"];
        if (!(kind instanceof String)) { return false; }
        if (!isKnownKind(kind as String)) { return true; }
        if (!(d["at"] instanceof Number) || !(d["name"] instanceof String)) { return false; }
        if (d["alt"] != null && !(d["alt"] instanceof Number)) { return false; }
        // The approach's start and a landmark say what they are (#121), which the Start menu and the
        // details show. A landmark's type the app does not know (the tool has rest, bridge, sign) shows
        // as it is, in grey.
        var typed = "approach".equals(kind) || "landmark".equals(kind), type = d["type"];
        if (typed && (!(type instanceof String) || type.length() == 0)) { return false; }
        if (d["lat"] != null && !isNumeric(d["lat"] as Object?)) { return false; }
        if (d["lon"] != null && !isNumeric(d["lon"] as Object?)) { return false; }
        return true;
    }

    static function isNumeric(v as Object?) as Boolean {
        return v instanceof Number || v instanceof Float || v instanceof Double || v instanceof Long;
    }

    // The kinds of format 1; later formats may add others, which this app ignores.
    static function isKnownKind(kind as String) as Boolean {
        return ["approach", "head", "landmark", "danger", "exit", "top"].indexOf(kind) >= 0;
    }

    // Index into points of the first point of this kind, or -1.
    function point(kind as String) as Number {
        for (var i = 0; i < points.size(); i++) {
            if (kind.equals(points[i]["kind"] as Object?)) { return i; }
        }
        return -1;
    }

    // Indices into points of the known points: those of a known kind with an altitude, which can
    // sync it.
    function knownPoints() as Array<Number> {
        var out = [] as Array<Number>;
        for (var i = 0; i < points.size(); i++) {
            if (isKnownKind(points[i]["kind"] as String) && (points[i]["alt"] as Object?) != null) { out.add(i); }
        }
        return out;
    }

    function hasApproach() as Boolean { return approach.size() > 0; }

    // Whether the approach's start has an altitude, so the climb can sync there.
    function approachKnown() as Boolean {
        var i = point("approach");
        if (i < 0) { return false; }
        return (points[i]["alt"] as Object?) != null;
    }

    // What the approach's start is, "Top station" or "Car park" (the route tool requires it): the Start
    // menu names the point by it, never by its own name (#121). Empty without one.
    function approachType() as String {
        var i = point("approach");
        return i >= 0 ? points[i]["type"] as String : "";
    }

    // The ferrata's figures for the ready screen (#51): the height it gains (the sum of the positive
    // up), its guidebook minutes and its hardest grade, in half steps.
    function ascent() as Number {
        var u = 0;
        for (var i = 0; i < sections.size(); i++) {
            var up = sections[i]["up"] as Number;
            if (up > 0) { u += up; }
        }
        return u;
    }

    function guideMinutes() as Number {
        var m = 0;
        for (var i = 0; i < sections.size(); i++) { m += minutes(sections[i]); }
        return m;
    }

    function hardest() as Number {
        var g = -1;
        for (var i = 0; i < sections.size(); i++) {
            var h = sections[i]["grade"] as Number;
            if (h > g) { g = h; }
        }
        return g;
    }

    // The lowest and the highest altitude on the route, the approach included: the range an entered
    // altitude is kept within (#51).
    function altRange() as [Number, Number] {
        var head = headAlt(), lo = head, hi = head;
        var a = point("approach");
        var lists = [approach, sections] as Array<Array<Dictionary> >;
        var starts = [a >= 0 && points[a]["alt"] != null ? points[a]["alt"] as Number : head - net(approach), head];
        for (var k = 0; k < 2; k++) {
            var h = starts[k] as Number;
            if (h < lo) { lo = h; }
            if (h > hi) { hi = h; }
            for (var i = 0; i < lists[k].size(); i++) {
                h += lists[k][i]["up"] as Number;
                if (h < lo) { lo = h; }
                if (h > hi) { hi = h; }
            }
        }
        return [lo, hi];
    }

    // Net height of a list of sections: up and down.
    static function net(list as Array<Dictionary>) as Number {
        var u = 0;
        for (var i = 0; i < list.size(); i++) { u += list[i]["up"] as Number; }
        return u;
    }

    // Length of a list of sections.
    static function lengthOf(list as Array<Dictionary>) as Number {
        var d = 0;
        for (var i = 0; i < list.size(); i++) { d += list[i]["len"] as Number; }
        return d;
    }

    // The head's altitude: its own, else worked out from the top's or the approach start's.
    function headAlt() as Number {
        var p = points[point("head")]["alt"];
        if (p != null) { return p as Number; }
        p = points[point("top")]["alt"];
        if (p != null) { return (p as Number) - net(sections); }
        var a = point("approach");
        if (a >= 0 && points[a]["alt"] != null) { return (points[a]["alt"] as Number) + net(approach); }
        return 0;
    }

    // Guidebook minutes for a section that has none (min is optional): a hiker's rule (DIN 33466),
    // 300 m an hour up, 500 m an hour down, 4 km an hour along; the larger of the climb and the
    // distance, plus half the smaller. At least a minute.
    static function minutes(s as Dictionary) as Number {
        var m = s["min"];
        if (m != null) { return m as Number; }
        var up = (s["up"] as Number).toFloat(), len = (s["len"] as Number).toFloat();
        var v = up >= 0 ? up / 300.0 * 60 : -up / 500.0 * 60;
        var h = len / 4000.0 * 60;
        var t = v > h ? v + h / 2 : h + v / 2;
        var n = Math.round(t).toNumber();
        return n > 1 ? n : 1;
    }
}
