using Toybox.Activity;
using Toybox.Math;
using Toybox.Position;
using Toybox.System;
using Toybox.Time;

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

    // The altitude a reading would give now, without starting or moving the input's clock; null when
    // there is none.
    function peek() as Float? {
        return null;
    }

    function stop() as Void {
    }

    // Back to its start for the next climb; only a replay has one.
    function rewind() as Void {
    }
}

// The watch: the altitude the activity info gives (null in the first seconds, or with no barometer
// reading) and the last GPS fix, while it is recent. The clock is the watch's at the first reading,
// moved on by the caller's. Not in Ferrata Demo (#140), which reads no sensors and so asks for no
// Positioning permission.
(:nodemo)
class SensorInput extends Input {

    // A fix older than this, in seconds, is no position: the climber has moved on since.
    static const FIX_MAX_AGE = 30;

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

    function peek() as Float? {
        var info = Activity.getActivityInfo();
        return info != null ? info.altitude : null;
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
        var t = startT + (now - s) / 1000;
        var p = positionOf(fix, Time.now().value());
        return p != null ? new Reading(alt, p[0], p[1], t) : new Reading(alt, null, null, t);
    }

    // The position of fix f at nowSec (seconds since the epoch, as Time.now()): null without one, below
    // usable accuracy, or older than FIX_MAX_AGE (owner, #113).
    function positionOf(f as Position.Info?, nowSec as Number) as [Float, Float]? {
        if (f == null || f.position == null || f.accuracy < Position.QUALITY_USABLE) { return null; }
        var when = f.when;
        if (when == null || nowSec - when.value() > FIX_MAX_AGE) { return null; }
        var deg = (f.position as Position.Location).toDegrees();
        return [deg[0].toFloat(), deg[1].toFloat()];
    }

    function stop() as Void {
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }
}

// 0.1.0's made-up climb as readings: the part in use (the ferrata from the head, or the approach) in
// about two minutes at the demo's vertical pace (Climb.demoMinute), then a hold at its end. At
// guidebook minute m the clock reads m x PACE minutes past the part's start (08:22 for the first), the
// watch the route's altitude there less 12 m (so the calibration at the start shows), and the position
// the route's points give. Never records anything.
class DemoInput extends Input {

    // A part takes LOOP_MS of the caller's clock, then the demo holds at its end.
    static const LOOP_MS = 120000;
    // How low the demo's watch reads.
    static const LOW = 12;

    var route as Route;
    var startMs as Number? = null;
    // The guidebook minute of the last reading.
    var minute as Float = 0.0;
    // The time of day at the part's start, and at the last reading, in seconds.
    var startT as Number = Climb.START_CLOCK * 60;
    var lastT as Number = Climb.START_CLOCK * 60;

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
        var t = startT + Math.round(minute * Climb.PACE * 60).toNumber();
        lastT = t;
        var p = positionAt(d);
        return p != null ? new Reading(alt, p[0], p[1], t) : new Reading(alt, null, null, t);
    }

    // The altitude at the last reading's minute, or at the part's start before the first.
    function peek() as Float? {
        var m = startMs == null ? 0.0 : minute;
        return Climb.START_ALT + Climb.netAtDistance(Climb.distanceAtMinute(m)) - LOW;
    }

    // The next part from its start, at the caller's next reading; the time of day goes on.
    function restart() as Void {
        startMs = null;
        startT = lastT;
    }

    // The position at d metres along the part in use (from the head on the ferrata, from the
    // approach's start on the approach), interpolated between the route's points that have one; the
    // nearest's before the first or past the last; null when none has.
    function positionAt(d as Float) as [Float, Float]? {
        var before = null, after = null;
        // Points' at is from the head: on the approach, shifted by its length (the review of #139).
        var shift = Climb.FERRATA ? 0 : Route.lengthOf(route.approach);
        for (var i = 0; i < route.points.size(); i++) {
            var p = route.points[i];
            if (p["lat"] == null || p["lon"] == null || p["at"] == null) { continue; }
            var at = ((p["at"] as Number) + shift).toFloat();
            if (at <= d && (before == null || at >= ((before as Dictionary)["at"] as Number) + shift)) { before = p; }
            if (at >= d && (after == null || at <= ((after as Dictionary)["at"] as Number) + shift)) { after = p; }
        }
        if (before == null) { before = after; }
        if (after == null) { after = before; }
        if (before == null || after == null) { return null; }
        var a = before as Dictionary, b = after as Dictionary;
        var a0 = ((a["at"] as Number) + shift).toFloat(), b0 = ((b["at"] as Number) + shift).toFloat();
        var f = b0 > a0 ? (d - a0) / (b0 - a0) : 0.0;
        if (f < 0) { f = 0.0; }
        if (f > 1) { f = 1.0; }
        return [lerp(a["lat"] as Numeric, b["lat"] as Numeric, f), lerp(a["lon"] as Numeric, b["lon"] as Numeric, f)];
    }

    function lerp(a as Numeric, b as Numeric, f as Float) as Float {
        return a.toFloat() + (b.toFloat() - a.toFloat()) * f;
    }
}
