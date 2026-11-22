"""Replay tool: turns a recorded climb, a FIT file, into the replay a replay build plays through the
tracker in the simulator (make run REPLAY=1; source/ReplayInput.mc; design/real-functionality.md,
section 9).

python3 tools/fit2replay.py track.fit -o resources-replay/replay.json

The output is a JSON array with one entry every 10 s of the recording from its first record, and one
at its last, so the replay ends where the recording does: [t, alt, lat, lon]. t is the local time of day in seconds, counting on past midnight (the
recording's local time, from its activity message; UTC, with a warning, without one); alt the
altitude in whole metres (enhanced_altitude, else altitude); lat and lon in degrees to 5 decimals
(about a metre). Each value is interpolated between the records around it that have it, across any
gap, and null before the first or after the last record that has it. Entries are written only where
the recording has records: none across a gap, which the replay interpolates across. More than
MAX_ENTRIES entries is a warning (the watch app's memory), not an error. One entry per line.

Needs Garmin's FIT SDK for Python: pip install -r tools/requirements.txt. A recording is the
climber's own track: keep it, and the replay made from it, out of the repository
(resources-replay/replay.json is ignored).
"""
import argparse
import bisect
import json
import sys

from garmin_fit_sdk import Decoder, Stream

STEP = 10  # seconds of the recording between entries
# Above this many entries the tool warns: about 14 hours of records, some 300 KB of the watch app's
# 768 KB once loaded (3051 entries took 181 KB in the simulator, #57).
MAX_ENTRIES = 5000
SEMI = 180 / 2**31  # degrees per semicircle
DAY = 86400
FIT_EPOCH = 631065600  # the FIT epoch, 1989-12-31 00:00 UTC, in Unix seconds


class ReplayError(Exception):
    pass


def series(records, *names):
    """The records' (timestamp, value) for the first field of names each has, in time order."""
    out = []
    for r in records:
        for n in names:
            v = r.get(n)
            if v is not None:
                out.append((r["timestamp"], float(v)))
                break
    return out


def at(s, times, t):
    """The value of series s (times its timestamps) at t, interpolated; None outside it."""
    if not s or t < times[0] or t > times[-1]:
        return None
    i = bisect.bisect_left(times, t)
    if times[i] == t:
        return s[i][1]
    (t0, v0), (t1, v1) = s[i - 1], s[i]
    return v0 + (v1 - v0) * (t - t0) / (t1 - t0)


def local_offset(messages):
    """Seconds the recording's local time is ahead of UTC, from its activity message; None without."""
    for a in messages.get("activity_mesgs", []):
        ts, local = a.get("timestamp"), a.get("local_timestamp")
        if isinstance(ts, int) and isinstance(local, int):
            return local - ts
    return None


def replay(path):
    """The replay entries of the FIT file at path."""
    if not Decoder(Stream.from_file(str(path))).is_fit():
        raise ReplayError(f"{path}: not a FIT file")
    messages, errors = Decoder(Stream.from_file(str(path))).read(convert_datetimes_to_dates=False)
    if errors:
        raise ReplayError(f"{path}: {errors[0]}")
    records = [r for r in messages.get("record_mesgs", []) if isinstance(r.get("timestamp"), int)]
    if not records:
        raise ReplayError(f"{path}: no records with a timestamp")
    records.sort(key=lambda r: r["timestamp"])
    offset = local_offset(messages)
    if offset is None:
        print(f"{path}: no local time in the recording; times are UTC", file=sys.stderr)
        offset = 0
    alt = series(records, "enhanced_altitude", "altitude")
    pos = [r for r in records if r.get("position_lat") is not None and r.get("position_long") is not None]
    lat, lon = series(pos, "position_lat"), series(pos, "position_long")
    alt_t, pos_t = [t for t, _ in alt], [t for t, _ in lat]

    first, last = records[0]["timestamp"], records[-1]["timestamp"]
    day = (first + FIT_EPOCH + offset) % DAY
    entries = []
    # A grid time only where the recording has a record in the 10 s from it: across a gap (the watch
    # stopped) there are none, and the replay interpolates across it.
    slots = sorted({(r["timestamp"] - first) // STEP for r in records})
    times = [first + k * STEP for k in slots]
    if times[-1] != last:
        times.append(last)
    if len(times) > MAX_ENTRIES:
        print(f"{path}: {len(times)} entries, more than {MAX_ENTRIES}: the replay may not fit the watch "
              "app's memory", file=sys.stderr)
    for t in times:
        a, la, lo = at(alt, alt_t, t), at(lat, pos_t, t), at(lon, pos_t, t)
        entries.append([
            day + t - first,
            None if a is None else round(a),
            None if la is None else round(la * SEMI, 5),
            None if lo is None else round(lo * SEMI, 5),
        ])
    return entries


def write(entries, out):
    lines = [json.dumps(e, separators=(",", ":")) for e in entries]
    with open(out, "w", encoding="utf-8") as f:
        f.write("[\n" + ",\n".join(lines) + "\n]\n")


def main(argv=None):
    p = argparse.ArgumentParser(description="Turn a recorded climb (FIT) into a replay resource.")
    p.add_argument("fit", help="the recording, a .fit file")
    p.add_argument("-o", "--output", required=True, help="the replay to write, a .json file")
    args = p.parse_args(argv)
    try:
        write(replay(args.fit), args.output)
    except (ReplayError, OSError) as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
