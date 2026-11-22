using Toybox.System;

import Toybox.Lang;

// One reading from an input (the watch's sensors, or the demo): the watch's altitude in metres, null
// when it has none yet; the position, null without a fix; t in seconds, monotonic.
class Reading {
    var alt as Float?;
    var lat as Float?;
    var lon as Float?;
    var t as Number;

    function initialize(a as Float?, la as Float?, lo as Float?, time as Number) {
        alt = a;
        lat = la;
        lon = lo;
        t = time;
    }
}

// The climb (design/real-functionality.md, sections 6 and 7): its phase, the app's own altitude offset
// (the watch's calibration is never touched), the place on the route and the pace. Fed readings; the
// pages draw the state() it builds. The place is in metres along the part in use (Climb.use): the
// approach, or the ferrata from its head.
class Tracker {

    enum Phase { IDLE, APPROACH, ASCENT, PAUSED, ENDED }

    var route as Route;
    var phase as Phase = IDLE;
    // The phase a pause came from, to resume to.
    var pausedFrom as Phase? = null;
    // Known altitude less the watch's, from the last sync; null until the first.
    var offset as Float? = null;
    // The change in offset at each sync after the first.
    var drifts as Array<Float> = [] as Array<Float>;
    // The place, metres along the part, and the synced altitude less the part's start altitude (net).
    var d as Float = 0.0;
    var u as Float = 0.0;
    // Own pace against the guidebook: minutes taken per guidebook minute.
    var pace as Float = 1.0;

    // When the part started, the last sync and the last reading, in reading seconds; the watch's last
    // altitude (null when the last reading had none); the clock at the start of the part.
    var partT as Number = 0;
    var syncT as Number = 0;
    var lastT as Number = 0;
    var alt as Float? = null;
    var startClock as Float = 0.0;

    // Guidebook minutes done before the pace is trusted; until then it is 1 (my call, the plan).
    const PACE_AFTER = 10;
    // The band: 10 m at a sync, 5 m more every 30 minutes since, at most 50 (my call, the plan; to be
    // set by the ground-truth data).
    const BAND = 10;
    const BAND_STEP = 5;
    const BAND_EVERY = 30;
    const BAND_MAX = 50;

    function initialize(r as Route) {
        route = r;
    }

    // Start the climb where the climber says: :head (the ferrata, synced to the head),
    // :approachPoint (the approach, synced to its start) or :elsewhere (the approach when the route
    // has one, else the ferrata; unsynced).
    function start(where as Symbol, rd as Reading) as Void {
        offset = null;
        drifts = [] as Array<Float>;
        pausedFrom = null;
        var ferrata = where == :head || where == :elsewhere && !route.hasApproach();
        begin(ferrata, rd);
        if (where != :elsewhere) { sync(Climb.START_ALT.toFloat(), rd); }
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // Leave the approach for the ferrata: synced to the head, the change in offset a drift.
    function startAscent(rd as Reading) as Void {
        begin(true, rd);
        sync(Climb.START_ALT.toFloat(), rd);
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    function pause(rd as Reading) as Void {
        if (phase != APPROACH && phase != ASCENT) { return; }
        update(rd);
        pausedFrom = phase;
        phase = PAUSED;
    }

    function resume(rd as Reading) as Void {
        if (phase != PAUSED) { return; }
        phase = pausedFrom as Phase;
        pausedFrom = null;
        update(rd);
    }

    // Sync at a known point (an index into the route's points) the climber confirms. A landmark in the
    // part in use also sets the place to it, even behind: the climber said where they are.
    function syncAt(point as Number, rd as Reading) as Void {
        var p = route.points[point];
        lastT = rd.t;
        alt = rd.alt;
        var known = p["alt"];
        if (known != null) { sync((known as Number).toFloat(), rd); }
        syncT = rd.t;
        if ("landmark".equals(p["kind"] as Object?)) {
            var at = (p["at"] as Number) + shift();
            if (at >= 0 && at <= Climb.totalD()) { d = at.toFloat(); }
        }
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // End at a point: its altitude, when known, is checked against the watch's and the drift kept,
    // not applied to the climb done.
    function end(point as Number, rd as Reading) as Void {
        var known = route.points[point]["alt"];
        var a = rd.alt, o = offset;
        if (known != null && a != null && o != null) { drifts.add((known as Number) - a - o); }
        lastT = rd.t;
        phase = ENDED;
    }

    // A new reading: the height maps to a stretch of the route ahead (Climb.stretchAhead), time moves
    // the place within it at the climber's pace, and the place never goes back. Unsynced, time alone
    // moves it; with no altitude, it holds. Paused, only the pace follows the time.
    function update(rd as Reading) as Void {
        if (phase == IDLE || phase == ENDED) { return; }
        lastT = rd.t;
        alt = rd.alt;
        var elapsed = elapsedAt(rd.t);
        if (phase != PAUSED && rd.alt != null) {
            var timeD = Climb.distanceAtMinute(elapsed / pace);
            var s = synced(rd);
            var to = timeD;
            if (s != null) {
                u = s;
                var stretch = Climb.stretchAhead(d, u);
                to = timeD < stretch[0] ? stretch[0] : (timeD > stretch[1] ? stretch[1] : timeD);
            }
            if (to > d) { d = to; }
        }
        var m = Climb.minuteAtDistance(d);
        pace = m >= PACE_AFTER && elapsed > 0 ? elapsed / m : 1.0;
    }

    // What the pages draw: the place, the height gained there, the time and the band.
    function state() as Climb.State {
        return Climb.State.placed(d, Climb.heightAtDistance(d), elapsedAt(lastT), pace, startClock, band());
    }

    // The altitude shown: the watch's plus the offset, the watch's own when unsynced, null when the
    // watch has none.
    function altitude() as Float? {
        var a = alt, o = offset;
        if (a == null) { return null; }
        return o != null ? a + o : a;
    }

    // Metres up or down the place may be off: grows with the time since the last sync.
    function band() as Number {
        var b = BAND + BAND_STEP * ((lastT - syncT) / 60 / BAND_EVERY);
        return b < BAND_MAX ? b : BAND_MAX;
    }

    // ---------------------------------------------------------------- helpers

    // A new part from rd: the approach or the ferrata, at its start, the clocks restarted.
    function begin(ferrata as Boolean, rd as Reading) as Void {
        Climb.use(route, ferrata ? :ferrata : :approach);
        phase = ferrata ? ASCENT : APPROACH;
        d = 0.0;
        u = 0.0;
        pace = 1.0;
        partT = rd.t;
        syncT = rd.t;
        lastT = rd.t;
        alt = rd.alt;
        var c = System.getClockTime();
        startClock = c.hour * 60 + c.min + c.sec / 60.0;
    }

    // The offset becomes known less the watch's; a change from an earlier one is a drift. Nothing
    // without a watch reading.
    function sync(known as Float, rd as Reading) as Void {
        var a = rd.alt;
        if (a == null) { return; }
        var next = known - a, o = offset;
        if (o != null) { drifts.add(next - o); }
        offset = next;
        syncT = rd.t;
    }

    // The synced altitude less the part's start, or null (unsynced, or no reading).
    function synced(rd as Reading) as Float? {
        var a = rd.alt, o = offset;
        if (a == null || o == null) { return null; }
        return a + o - Climb.START_ALT;
    }

    // Points are in metres from the head; the approach part counts from its own start.
    function shift() as Number {
        return phase == APPROACH || phase == PAUSED && pausedFrom == APPROACH ? Route.lengthOf(route.approach) : 0;
    }

    // Minutes since the part started, pauses included.
    function elapsedAt(t as Number) as Float {
        return (t - partT) / 60.0;
    }
}
