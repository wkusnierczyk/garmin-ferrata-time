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
    // The sections before the head; empty when the route has no approach.
    var approach as Array<Dictionary>;
    // The ferrata, from the head to the top.
    var sections as Array<Dictionary>;
    var points as Array<Dictionary>;

    function initialize(data as Dictionary) {
        id = data["id"] as String;
        name = data["name"] as String;
        short = data["short"] as String;
        var a = data["approach"];
        approach = a instanceof Array ? a as Array<Dictionary> : [] as Array<Dictionary>;
        sections = data["sections"] as Array<Dictionary>;
        points = data["points"] as Array<Dictionary>;
    }

    // The route in data, or null when it is another format (this app reads format 1) or lacks a head, a top or sections.
    static function fromJson(data as Dictionary) as Route? {
        var f = data["format"];
        if (!(f instanceof Number) || f != 1) { return null; }
        if (!(data["id"] instanceof String) || !(data["name"] instanceof String)
            || !(data["short"] instanceof String)) { return null; }
        var s = data["sections"], p = data["points"], a = data["approach"];
        if (!(s instanceof Array) || (s as Array).size() == 0 || !(p instanceof Array)) { return null; }
        if (a != null && !(a instanceof Array)) { return null; }
        var r = new Route(data);
        if (r.point("head") < 0 || r.point("top") < 0) { return null; }
        return r;
    }

    // Index into points of the first point of this kind, or -1.
    function point(kind as String) as Number {
        for (var i = 0; i < points.size(); i++) {
            if (kind.equals(points[i]["kind"] as Object?)) { return i; }
        }
        return -1;
    }

    // Indices into points of the known points: those with an altitude, which can sync it.
    function knownPoints() as Array<Number> {
        var out = [] as Array<Number>;
        for (var i = 0; i < points.size(); i++) {
            if (points[i]["alt"] != null) { out.add(i); }
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
