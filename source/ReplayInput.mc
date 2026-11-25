import Toybox.Lang;

// A recorded climb played back as readings, faster than real time (design/real-functionality.md,
// section 9): the end-to-end test of sync, place and pace in the simulator. The recording is
// tools/fit2replay.py's, an entry every 10 s, [t, alt, lat, lon] (t the local time of day in seconds,
// alt in metres, the position in degrees; each may be null). read(now) gives the recording at its
// first t plus the caller's time since the first reading times speed, interpolated between the entries
// around it; past the last entry, the last. A replay build (make run REPLAY=1) plays it in the
// sensors' place; it never records anything. The class is in every build, so the unit tests reach it;
// the recording and the code that loads it are in the replay build only (replay.jungle).
class ReplayInput extends Input {

    // A minute of the climb a second: a 5 h 40 climb in under 6 minutes.
    static const SPEED = 60;

    var samples as Array<Array>;
    var speed as Number;
    var startMs as Number? = null;
    // The entry at or before the last reading: the readings move forward, so the search starts there.
    var at as Number = 0;

    function initialize(s as Array<Array>, sp as Number) {
        Input.initialize();
        samples = s;
        speed = sp;
    }

    function read(now as Number) as Reading {
        var n = samples.size();
        if (n == 0) { return new Reading(null, null, null, 0); }
        var s = startMs;
        if (s == null) { startMs = now; s = now; }
        var t = (samples[0][0] as Number) + (now - s).toFloat() / 1000 * speed;
        while (at + 1 < n && (samples[at + 1][0] as Number) <= t) { at++; }
        var a = samples[at];
        if (at + 1 >= n) { return reading(a, a, 0.0, a[0] as Number); }
        var b = samples[at + 1];
        var t0 = a[0] as Number;
        var f = (t - t0) / ((b[0] as Number) - t0);
        if (f < 0) { f = 0.0; }
        return reading(a, b, f, t.toNumber());
    }

    // The altitude of the entry the last reading was at, the first before any.
    function peek() as Float? {
        if (samples.size() == 0) { return null; }
        var a = samples[at][1] as Numeric?;
        return a != null ? a.toFloat() : null;
    }

    // The reading a fraction f of the way from entry a to entry b, at time t.
    function reading(a as Array, b as Array, f as Float, t as Number) as Reading {
        var alt = mix(a[1] as Numeric?, b[1] as Numeric?, f);
        // A position is both halves or none, in each entry.
        var hasA = a[2] != null && a[3] != null, hasB = b[2] != null && b[3] != null;
        if (!hasA) { return new Reading(alt, null, null, t); }
        var g = hasB ? f : 0.0;
        return new Reading(alt, mix(a[2] as Numeric, b[2] as Numeric?, g), mix(a[3] as Numeric, b[3] as Numeric?, g), t);
    }

    // A fraction f of the way from x to y; x when y is missing, none when x is.
    function mix(x as Numeric?, y as Numeric?, f as Float) as Float? {
        if (x == null) { return null; }
        if (y == null) { return x.toFloat(); }
        return x.toFloat() + (y.toFloat() - x.toFloat()) * f;
    }
}
