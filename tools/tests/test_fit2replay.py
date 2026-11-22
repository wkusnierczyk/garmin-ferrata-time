"""Tests for tools/fit2replay.py, on small FIT files made here with the FIT SDK's own encoder (no
recording is checked in)."""
import json

from garmin_fit_sdk import Encoder, Profile, convert_timestamp_to_datetime as to_datetime

import fit2replay

MESG = Profile["mesg_num"]
# 2025-08-07 06:00:00 UTC, in seconds since the FIT epoch (1989-12-31 00:00 UTC).
T0 = 1123480800
SEMI = 2**31 / 180  # semicircles per degree


def semi(deg):
    return round(deg * SEMI)


def fit(tmp_path, records, local_offset=7200, name="t.fit"):
    """A FIT file of the records (dicts of record fields, timestamp in seconds since the FIT epoch),
    with an activity message whose local time is local_offset seconds ahead of UTC (None: no
    activity message)."""
    e = Encoder()
    e.write_mesg({"mesg_num": MESG["FILE_ID"], "type": "activity", "manufacturer": "development",
                  "product": 0, "serial_number": 1, "time_created": to_datetime(T0)})
    for r in records:
        m = dict(r, mesg_num=MESG["RECORD"])
        m["timestamp"] = to_datetime(r["timestamp"])
        e.write_mesg(m)
    if local_offset is not None:
        end = records[-1]["timestamp"]
        e.write_mesg({"mesg_num": MESG["ACTIVITY"], "timestamp": to_datetime(end),
                      "local_timestamp": end + local_offset, "num_sessions": 1})
    path = tmp_path / name
    path.write_bytes(e.close())
    return path


def climb(seconds=61, every=3):
    """A record every `every` seconds: 1 m up every 3 s from 1000 m, moving north-east."""
    return [{"timestamp": T0 + k, "enhanced_altitude": 1000.0 + k / 3,
             "position_lat": semi(46.38 + k * 1e-5), "position_long": semi(7.62 + k * 2e-5)}
            for k in range(0, seconds, every)]


def run(tmp_path, path):
    out = tmp_path / "replay.json"
    assert fit2replay.main([str(path), "-o", str(out)]) == 0
    return json.loads(out.read_text())


def test_fit2replay_samples_every_10s(tmp_path):
    entries = run(tmp_path, fit(tmp_path, climb()))
    # 0 to 60 s of the recording: seven entries, 10 s apart, at the local time of day (UTC+2: 08:00).
    t = [e[0] for e in entries]
    assert t == [8 * 3600 + s for s in range(0, 61, 10)]
    for e in entries:
        s = e[0] - 8 * 3600
        assert len(e) == 4
        # Interpolated between the records around it (one every 3 s), and rounded: whole metres,
        # degrees to 5 decimals.
        assert isinstance(e[1], int) and e[1] == round(1000 + s / 3)
        assert e[2] == round(46.38 + s * 1e-5, 5) and e[3] == round(7.62 + s * 2e-5, 5)


def test_ends_at_the_last_record(tmp_path):
    # Records to 64 s: entries every 10 s to 60, and one at 64.
    entries = run(tmp_path, fit(tmp_path, climb(seconds=65, every=4)))
    assert [e[0] - 8 * 3600 for e in entries] == [0, 10, 20, 30, 40, 50, 60, 64]
    assert entries[-1][1] == round(1000 + 64 / 3)


def test_written_compactly_one_entry_per_line(tmp_path):
    path = fit(tmp_path, climb())
    out = tmp_path / "replay.json"
    fit2replay.main([str(path), "-o", str(out)])
    lines = out.read_text().splitlines()
    assert lines[0] == "[" and lines[-1] == "]"
    assert lines[1] == "[28800,1000,46.38,7.62],"
    assert len(lines) == 2 + 7


def test_missing_values_are_null(tmp_path):
    # No GPS fix before 18 s, and no altitude before 6 s (records every 3 s).
    records = climb(seconds=31)
    for r in records:
        if r["timestamp"] - T0 < 18:
            del r["position_lat"], r["position_long"]
        if r["timestamp"] - T0 < 6:
            del r["enhanced_altitude"]
    entries = run(tmp_path, fit(tmp_path, records))
    assert [e[1] is None for e in entries] == [True, False, False, False]
    assert [e[2] is None and e[3] is None for e in entries] == [True, True, False, False]


def test_plain_altitude_when_no_enhanced(tmp_path):
    records = [{"timestamp": T0 + k, "altitude": 500.0 + k} for k in range(0, 21, 5)]
    entries = run(tmp_path, fit(tmp_path, records))
    assert [e[1] for e in entries] == [500, 510, 520]
    assert all(e[2] is None and e[3] is None for e in entries)


def test_time_of_day_counts_on_past_midnight(tmp_path):
    # 23:59:50 local at the start: the clock keeps counting, as the tracker's readings do.
    start = T0 - 6 * 3600 - 10  # 23:59:50 UTC the day before
    records = [{"timestamp": start + k, "enhanced_altitude": 1000.0} for k in range(0, 21, 2)]
    entries = run(tmp_path, fit(tmp_path, records, local_offset=0))
    assert [e[0] for e in entries] == [86390, 86400, 86410]


def test_utc_without_local_time(tmp_path, capsys):
    entries = run(tmp_path, fit(tmp_path, climb(seconds=11), local_offset=None))
    assert entries[0][0] == 6 * 3600
    assert "UTC" in capsys.readouterr().err


def test_no_records_is_an_error(tmp_path, capsys):
    e = Encoder()
    e.write_mesg({"mesg_num": MESG["FILE_ID"], "type": "activity", "manufacturer": "development",
                  "product": 0, "serial_number": 1, "time_created": to_datetime(T0)})
    path = tmp_path / "empty.fit"
    path.write_bytes(e.close())
    assert fit2replay.main([str(path), "-o", str(tmp_path / "r.json")]) == 1
    assert "no records" in capsys.readouterr().err
    assert not (tmp_path / "r.json").exists()
