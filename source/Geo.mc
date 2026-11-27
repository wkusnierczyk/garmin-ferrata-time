using Toybox.Math;

import Toybox.Lang;

// Distances on the ground from GPS positions in degrees: straight between two, and along a track to
// its nearest point (#113). The track is short (an approach), so a flat map around the fix is close
// enough for which part of it is nearest.
module Geo {

    // The earth's mean radius, in metres.
    const R = 6371000.0;

    // Metres between two positions, along the ground (haversine).
    function distance(lat1 as Float, lon1 as Float, lat2 as Float, lon2 as Float) as Float {
        var p1 = Math.toRadians(lat1), p2 = Math.toRadians(lat2);
        var dp = p2 - p1, dl = Math.toRadians(lon2 - lon1);
        var a = Math.pow(Math.sin(dp / 2), 2) + Math.cos(p1) * Math.cos(p2) * Math.pow(Math.sin(dl / 2), 2);
        return (2 * R * Math.asin(Math.sqrt(a))).toFloat();
    }

    // The fix snapped to the track: the nearest point on the lines between its vertices, each
    // [lat, lon, along] in the order of along (metres along the route), and the along there,
    // interpolated. Null for a track of fewer than two vertices.
    function snap(lat as Float, lon as Float, track as Array<[Float, Float, Float]>) as Float? {
        if (track.size() < 2) { return null; }
        // A flat map in metres around the fix: x east, y north.
        var my = Math.toRadians(1.0) * R, mx = my * Math.cos(Math.toRadians(lat));
        var best = null, off = 0.0;
        for (var i = 0; i + 1 < track.size(); i++) {
            var a = track[i], b = track[i + 1];
            var ax = (a[1] - lon) * mx, ay = (a[0] - lat) * my;
            var bx = (b[1] - lon) * mx, by = (b[0] - lat) * my;
            var dx = bx - ax, dy = by - ay, len2 = dx * dx + dy * dy;
            // The share of the line nearest the fix (the origin), kept on it.
            var f = len2 > 0 ? -(ax * dx + ay * dy) / len2 : 0.0;
            if (f < 0) { f = 0.0; }
            if (f > 1) { f = 1.0; }
            var x = ax + f * dx, y = ay + f * dy, e = x * x + y * y;
            if (best == null || e < off) {
                best = a[2] + f * (b[2] - a[2]);
                off = e;
            }
        }
        return (best as Numeric).toFloat();
    }
}
