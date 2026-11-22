using Toybox.Activity;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;

import Toybox.Lang;

// Where the tracker's readings come from: the watch's sensors or the demo (design/real-functionality.md,
// section 9). read(now) takes the caller's running clock in milliseconds (System.getTimer(), or the
// demo's own clock, which stops while paused) and gives a Reading whose t counts seconds from the local
// midnight of the day the input started; stop() lets go of anything the input holds.
class Input {

    function initialize() {
    }

    function read(now as Number) as Reading {
        return new Reading(null, null, null, 0);
    }

    function stop() as Void {
    }
}

// The watch: the altitude the activity info gives (null in the first seconds, or with no barometer
// reading) and the last GPS fix. The clock is the watch's at the first reading, moved on by the caller's.
class SensorInput extends Input {

    var fix as Position.Info? = null;
    // The caller's clock and the time of day, in seconds, at the first reading.
    var startMs as Number? = null;
    var startT as Number = 0;

    function initialize() {
        Input.initialize();
        Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }

    function onPosition(info as Position.Info) as Void {
        fix = info;
    }

    function read(now as Number) as Reading {
        var s = startMs;
        if (s == null) {
            var c = System.getClockTime();
            startT = c.hour * 3600 + c.min * 60 + c.sec;
            startMs = now;
            s = now;
        }
        var alt = null;
        var info = Activity.getActivityInfo();
        if (info != null) { alt = info.altitude; }
        var lat = null, lon = null;
        var f = fix;
        if (f != null && f.position != null && f.accuracy >= Position.QUALITY_POOR) {
            var deg = (f.position as Position.Location).toDegrees();
            lat = deg[0].toFloat();
            lon = deg[1].toFloat();
        }
        return new Reading(alt, lat, lon, startT + (now - s) / 1000);
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }
}

// 0.1.0's made-up climb as readings: the ferrata from the head in about two minutes at the demo's
// vertical pace (Climb.demoMinute), then a hold at the top. At guidebook minute m the clock reads
// m x PACE minutes past 08:22, the watch the route's altitude there less 12 m (so the sync at the head
// shows), and the position the route's points give. Never records anything.
class DemoInput extends Input {

    // The climb takes LOOP_MS of the caller's clock; the view holds at the top for HOLD_MS, then starts
    // again.
    static const LOOP_MS = 120000;
    static const HOLD_MS = 4000;
    // How low the demo's watch reads.
    static const LOW = 12;

    var route as Route;
    var startMs as Number? = null;
    // The guidebook minute of the last reading.
    var minute as Float = 0.0;

    // The demo plays the ferrata: it is put in use here, before the first reading.
    function initialize(r as Route) {
        Input.initialize();
        route = r;
        Climb.use(r, :ferrata);
    }

    function read(now as Number) as Reading {
        var s = startMs;
        if (s == null) { startMs = now; s = now; }
        minute = Climb.demoMinute((now - s).toFloat() / LOOP_MS);
        var d = Climb.distanceAtMinute(minute);
        var alt = Climb.START_ALT + Climb.netAtDistance(d) - LOW;
        var t = Math.round((Climb.START_CLOCK + minute * Climb.PACE) * 60).toNumber();
        var p = positionAt(d);
        return p != null ? new Reading(alt, p[0], p[1], t) : new Reading(alt, null, null, t);
    }

    // The position at d metres from the head, interpolated between the route's points that have one;
    // the nearest's before the first or past the last; null when none has.
    function positionAt(d as Float) as [Float, Float]? {
        var before = null, after = null;
        for (var i = 0; i < route.points.size(); i++) {
            var p = route.points[i];
            if (p["lat"] == null || p["lon"] == null || p["at"] == null) { continue; }
            var at = (p["at"] as Number).toFloat();
            if (at <= d && (before == null || at >= ((before as Dictionary)["at"] as Number))) { before = p; }
            if (at >= d && (after == null || at <= ((after as Dictionary)["at"] as Number))) { after = p; }
        }
        if (before == null) { before = after; }
        if (after == null) { after = before; }
        if (before == null || after == null) { return null; }
        var a = before as Dictionary, b = after as Dictionary;
        var a0 = (a["at"] as Number).toFloat(), b0 = (b["at"] as Number).toFloat();
        var f = b0 > a0 ? (d - a0) / (b0 - a0) : 0.0;
        if (f < 0) { f = 0.0; }
        if (f > 1) { f = 1.0; }
        return [lerp(a["lat"] as Numeric, b["lat"] as Numeric, f), lerp(a["lon"] as Numeric, b["lon"] as Numeric, f)];
    }

    function lerp(a as Numeric, b as Numeric, f as Float) as Float {
        return a.toFloat() + (b.toFloat() - a.toFloat()) * f;
    }
}
