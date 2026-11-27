import Toybox.Lang;

// One reading from an input (the watch's sensors, or the demo): the watch's altitude in metres, null
// when it has none yet; the position, null without a fix; t in seconds since the local midnight of
// the day the input started, monotonic (it keeps counting past midnight), so it gives the clock too.
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
    // Own pace against the guidebook: minutes taken per guidebook minute, counted from the guidebook
    // minute the part started at (m0: 0 from its start, more after an At altitude start partway).
    var pace as Float = 1.0;
    var m0 as Float = 0.0;
    // The pace assumed until enough is done to trust the climber's own: 1, or the demo's (#50), so the
    // demo's time left reads as 0.1.0's from the first minute.
    var basePace as Float = 1.0;

    // When the part started, the last sync, the last reading, and up to when the place has been moved
    // by time (active time only: a pause never moves it), in reading seconds; the watch's last
    // altitude (null when the last reading had none); the clock at the start of the part, in minutes.
    var partT as Number = 0;
    var syncT as Number = 0;
    var lastT as Number = 0;
    var moveT as Number = 0;
    var alt as Float? = null;
    var startClock as Float = 0.0;
    // A known altitude confirmed while the watch had none: synced at the first reading that has one;
    // pendingGuess when it is an altitude the climber entered.
    var pending as Float? = null;
    var pendingGuess as Boolean = false;
    // Whether the offset came from a known point, else from an altitude the climber entered (a guess,
    // design section 6): only the change from one known point's offset to the next is drift.
    var fromKnown as Boolean = false;
    // The points calibrated at in this climb (indices into the route's points): Calibrate does not
    // suggest them again (#51).
    var calibratedAt as Array<Number> = [] as Array<Number>;
    // The activity's time, in seconds: the approach and the ferrata while not paused, as Garmin's timer.
    var activeS as Number = 0;
    // As the climb was before the end, for Resume on the summary to undo it: the phase, the place, the
    // height and how many drifts there were.
    var endedFrom as Phase? = null;
    var endD as Float = 0.0;
    var endU as Float = 0.0;
    var endDrifts as Number = 0;
    // On the approach, the metres to the head the last reading's GPS fix gave (#113), kept through a
    // pause; null when it had none, or the route no coordinates to measure it by. The route's track and the head's position,
    // looked up once.
    var headLeft as Float? = null;
    // Whether the part has had a fix on the approach's track yet.
    var fixed as Boolean = false;
    var track as Array<[Float, Float, Float]>;
    var headAt as [Float, Float]?;

    // Guidebook minutes done before the pace is trusted; until then it is basePace (my call, the plan).
    const PACE_AFTER = 10;
    // The band: 10 m at a sync, 5 m more every 30 minutes since, at most 50 (my call, the plan; to be
    // set by the ground-truth data).
    const BAND = 10;
    const BAND_STEP = 5;
    const BAND_EVERY = 30;
    const BAND_MAX = 50;

    function initialize(r as Route) {
        route = r;
        track = r.approachTrack();
        headAt = r.headPosition();
    }

    // Start the climb where the climber says: :head (the ferrata, synced to the head),
    // :approachPoint (the approach, synced to its start) or :elsewhere (the approach when the route
    // has one, else the ferrata; unsynced).
    function start(where as Symbol, rd as Reading) as Void {
        fresh();
        var ferrata = where == :head || where == :elsewhere && !route.hasApproach();
        begin(ferrata, rd);
        if (where != :elsewhere) { sync(Climb.START_ALT.toFloat(), rd); }
        if (where == :head) { calibratedAt.add(route.point("head")); }
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // Start at an altitude the climber entered (At altitude, #51): on the approach when the route has
    // one, else on the ferrata; calibrated to it, a guess, so no drift; the place the point at that
    // altitude nearest the part's start.
    function startAt(known as Float, rd as Reading) as Void {
        fresh();
        begin(!route.hasApproach(), rd);
        guess(known, rd);
        d = Climb.distanceAtNet(known - Climb.START_ALT, 0.0);
        m0 = Climb.minuteAtDistance(d);
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // Leave the approach for the ferrata: synced to the head, the change in offset a drift.
    function startAscent(rd as Reading) as Void {
        takeTime(rd);
        begin(true, rd);
        pausedFrom = null;
        sync(Climb.START_ALT.toFloat(), rd);
        calibratedAt.add(route.point("head"));
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    function pause(rd as Reading) as Void {
        if (phase != APPROACH && phase != ASCENT) { return; }
        update(rd);
        moveT = rd.t;
        pausedFrom = phase;
        phase = PAUSED;
    }

    // The resume reading is taken while still paused, so the pause up to it is never counted as
    // moving, whether or not a paused reading came just before (Codex on #89).
    function resume(rd as Reading) as Void {
        if (phase != PAUSED) { return; }
        update(rd);
        phase = pausedFrom as Phase;
        pausedFrom = null;
    }

    // Calibrate at a known point (an index into the route's points) the climber confirms. A point in
    // the part in use (the head, a landmark, an exit, the top: Calibrate's list, #51) also sets the
    // place to it, even behind: the climber said where they are.
    function syncAt(point as Number, rd as Reading) as Void {
        if (phase == IDLE || phase == ENDED) { return; }
        var p = route.points[point];
        takeTime(rd);
        alt = rd.alt;
        var known = p["alt"];
        if (known != null) { sync((known as Number).toFloat(), rd); }
        if (calibratedAt.indexOf(point) < 0) { calibratedAt.add(point); }
        if (["head", "landmark", "exit", "top"].indexOf(p["kind"] as String) >= 0) {
            var at = (p["at"] as Number) + shift();
            // The place is known now: time moves it on from here, and the band starts again.
            // The pace follows the corrected place at once (Codex on #89).
            if (at >= 0 && at <= Climb.totalD()) { moveTo(at.toFloat(), rd); }
        }
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // Calibrate to an altitude the climber entered (At altitude, #51): a guess, so the offset changes
    // without a drift; the place moves to the point at that altitude nearest the estimate, back or on.
    function calibrateTo(known as Float, rd as Reading) as Void {
        if (phase == IDLE || phase == ENDED) { return; }
        takeTime(rd);
        alt = rd.alt;
        guess(known, rd);
        moveTo(Climb.distanceAtNet(known - Climb.START_ALT, d), rd);
        var s = synced(rd);
        if (s != null) { u = s; }
    }

    // End at a point (-1: here, no check): its altitude, when known, is checked against the watch's
    // and the drift kept, not applied to the climb done; the place is set to the point, as the climber
    // says they are there (#51). Resume undoes it (unend).
    function end(point as Number, rd as Reading) as Void {
        if (phase == IDLE || phase == ENDED) { return; }
        takeTime(rd);
        endedFrom = phase;
        endD = d;
        endU = u;
        endDrifts = drifts.size();
        if (point >= 0) {
            var p = route.points[point];
            var known = p["alt"];
            var a = rd.alt, o = offset;
            if (known != null && a != null && o != null && fromKnown) { drifts.add((known as Number) - a - o); }
            var at = (p["at"] as Number) + shift();
            if (at >= 0 && at <= Climb.totalD()) {
                d = at.toFloat();
                u = Climb.netAtDistance(d);
            }
        }
        phase = ENDED;
    }

    // Resume from the summary: the climb paused as it was before the end, the end's check undone.
    function unend() as Void {
        if (phase != ENDED) { return; }
        d = endD;
        u = endU;
        drifts = drifts.slice(0, endDrifts);
        if (endedFrom != PAUSED) { pausedFrom = endedFrom; }
        endedFrom = null;
        phase = PAUSED;
    }

    // The sum of the drifts, in metres.
    function drift() as Float {
        var sum = 0.0;
        for (var i = 0; i < drifts.size(); i++) { sum += drifts[i]; }
        return sum;
    }

    // A new reading: the height maps to a stretch of the route ahead (Climb.stretchAhead), time moves
    // the place within it at the climber's pace, and the place never goes back. Time moves it on from
    // where it is by the active time since the last reading, so a pause or a landmark sync is never
    // undone. Unsynced, time alone moves it; with no altitude, it holds (the time waits for the next
    // reading with one). Paused, only the pace follows the time, which counts pauses.
    function update(rd as Reading) as Void {
        if (phase == IDLE || phase == ENDED) { return; }
        takeTime(rd);
        alt = rd.alt;
        var known = pending;
        if (known != null) {
            if (pendingGuess) { guess(known, rd); } else { sync(known, rd); }
        }
        var elapsed = elapsedAt(rd.t);
        if (approachByGps(rd, elapsed)) { return; }
        if (phase == PAUSED) {
            moveT = rd.t;
        } else if (rd.alt != null) {
            var active = (rd.t - moveT) / 60.0;
            moveT = rd.t;
            var timeD = Climb.distanceAtMinute(Climb.minuteAtDistance(d) + active / pace);
            var s = synced(rd);
            var to = timeD;
            if (s != null) {
                u = s;
                var stretch = Climb.stretchAhead(d, u);
                to = timeD < stretch[0] ? stretch[0] : (timeD > stretch[1] ? stretch[1] : timeD);
            }
            if (to > d) { d = to; }
        }
        // A reading without altitude moves nothing, so it leaves the pace as it was: the time it
        // skipped is caught up at the next reading at that pace (Codex on #89).
        if (phase == PAUSED || rd.alt != null) { repace(elapsed); }
    }

    // On the approach, a reading with a position (the input gives one only for a fix at most 30 s old,
    // of usable accuracy or better; owner, #113). Snapped to the approach's track, it puts the place
    // where GPS says, back as well as on: walking the wrong way shows as a longer way to the head. The
    // part's first such fix moves m0 by what time had not explained, so a stretch skipped by a start
    // in the wrong place (an ALTITUDE start on a flat) never counts as walked, as startAt does; later
    // fixes set the pace. With only the head's position, the straight line is the distance shown and
    // nothing more: the place is no place on the route. True when GPS set the place; else time and
    // height move it, as on the ferrata, from where it is. A paused reading leaves the distance as it
    // was.
    function approachByGps(rd as Reading, elapsed as Float) as Boolean {
        if (phase != APPROACH) { return false; }
        headLeft = null;
        var lat = rd.lat, lon = rd.lon;
        if (lat == null || lon == null) { return false; }
        var along = Geo.snap(lat, lon, track);
        if (along == null) {
            var h = headAt;
            if (h != null) { headLeft = Geo.distance(lat, lon, h[0], h[1]); }
            return false;
        }
        if (!fixed) {
            var explained = Climb.minuteAtDistance(d) + (rd.t - moveT) / 60.0 / pace;
            if (explained > Climb.totalM()) { explained = Climb.totalM().toFloat(); }
            m0 += Climb.minuteAtDistance(along) - explained;
            fixed = true;
        }
        d = along;
        headLeft = Climb.totalD() - along;
        moveT = rd.t;
        var s = synced(rd);
        if (s != null) { u = s; }
        repace(elapsed);
        return true;
    }

    // On the approach, the metres and the minutes to the head (#113): the distance from the last
    // reading's GPS fix (along the track, or straight to the head), or else from the place; the
    // minutes are the guidebook's from the place at the climber's pace. On the ferrata, to the top.
    function toHead() as [Float, Float] {
        var g = headLeft;
        var left = g != null ? g : Climb.totalD() - d;
        return [left > 0 ? left : 0.0, (Climb.totalM() - Climb.minuteAtDistance(d)) * pace];
    }

    // The pace from the place and the time taken: elapsed minutes per guidebook minute done, once
    // enough is done to trust it.
    function repace(elapsed as Float) as Void {
        var m = Climb.minuteAtDistance(d) - m0;
        pace = m >= PACE_AFTER && elapsed > 0 ? elapsed / m : basePace;
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

    // A new climb: no offset, drift or calibration yet, the activity's time from 0.
    function fresh() as Void {
        offset = null;
        pending = null;
        pendingGuess = false;
        fromKnown = false;
        drifts = [] as Array<Float>;
        pausedFrom = null;
        endedFrom = null;
        calibratedAt = [] as Array<Number>;
        activeS = 0;
    }

    // The time of reading rd: the activity's time runs on while not paused.
    function takeTime(rd as Reading) as Void {
        if ((phase == APPROACH || phase == ASCENT) && rd.t > lastT) { activeS += rd.t - lastT; }
        lastT = rd.t;
    }

    // The place set by the climber: time moves it on from here, the band starts again, and the pace
    // follows it at once.
    function moveTo(at as Float, rd as Reading) as Void {
        d = at;
        moveT = rd.t;
        syncT = rd.t;
        repace(elapsedAt(rd.t));
    }

    // A new part from rd: the approach or the ferrata, at its start, the clocks restarted.
    function begin(ferrata as Boolean, rd as Reading) as Void {
        Climb.use(route, ferrata ? :ferrata : :approach);
        phase = ferrata ? ASCENT : APPROACH;
        d = 0.0;
        u = 0.0;
        m0 = 0.0;
        pace = basePace;
        partT = rd.t;
        syncT = rd.t;
        lastT = rd.t;
        moveT = rd.t;
        pending = null;
        headLeft = null;
        fixed = false;
        alt = rd.alt;
        startClock = rd.t / 60.0;
    }

    // The offset becomes known less the watch's; a change from an earlier one is a drift. Without a
    // watch reading, it waits for the first one with an altitude.
    function sync(known as Float, rd as Reading) as Void {
        var a = rd.alt;
        if (a == null) { pending = known; pendingGuess = false; return; }
        pending = null;
        var next = known - a, o = offset;
        if (o != null && fromKnown) { drifts.add(next - o); }
        offset = next;
        fromKnown = true;
        syncT = rd.t;
    }

    // The offset from an altitude the climber entered: no drift, and the next known point's change
    // from it is none either. Without a watch reading, it waits for the first one with an altitude.
    function guess(known as Float, rd as Reading) as Void {
        var a = rd.alt;
        if (a == null) { pending = known; pendingGuess = true; return; }
        pending = null;
        pendingGuess = false;
        offset = known - a;
        fromKnown = false;
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
