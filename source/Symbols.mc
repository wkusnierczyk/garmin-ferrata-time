using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The climb flow's symbols as the flow mock draws them (#121), with Dc primitives in proportion: the
// rows' symbols (page 16's path, ascent and stopwatch, the peak and the drift's arrow), the pause
// symbol, and the marks beside the buttons on the right (play, check, cross) on their half-transparent
// squares. A row symbol is drawn in a unit box of size k centred on (cx, cy), its strokes 0.1 of k
// wide with round ends and joints. The curves' points are worked out once.
module Symbols {

    const PATH = 0x3a86ff;
    const PAUSE = 0x3a86ff;
    const STROKE = 0.1;

    // A unit-box coordinate (0 to 1 across a symbol of size k centred on c).
    function u(c as Float, k as Float, v as Float) as Float { return c + (v - 0.5) * k; }

    // A round-ended stroke through unit-box points [x0, y0, x1, y1 ...], pen a share of k.
    function stroke(d as Draw, cx as Float, cy as Float, k as Float, pts as Array<Float>, pen as Float, c as Number) as Void {
        for (var i = 2; i + 1 < pts.size(); i += 2) {
            d.seg(u(cx, k, pts[i - 2]), u(cy, k, pts[i - 1]), u(cx, k, pts[i]), u(cy, k, pts[i + 1]), pen * k, c, false);
        }
        for (var i = 0; i + 1 < pts.size(); i += 2) { d.dot(u(cx, k, pts[i]), u(cy, k, pts[i + 1]), pen * k / 2, c); }
    }

    // A filled polygon through unit-box points.
    function fill(d as Draw, cx as Float, cy as Float, k as Float, pts as Array<Float>, c as Number) as Void {
        var a = new Array<Array<Float>>[pts.size() / 2];
        for (var i = 0; i < a.size(); i++) { a[i] = [u(cx, k, pts[2 * i]), u(cy, k, pts[2 * i + 1])] as Array<Float>; }
        d.poly(a, c);
    }

    // Points on a circle around (x, y), radius r, from screen degree a0 to a1 (y down), added to out.
    function arcPts(out as Array<Float>, x as Float, y as Float, r as Float, a0 as Float, a1 as Float, n as Number) as Void {
        for (var i = 0; i <= n; i++) {
            var a = Math.toRadians(a0 + (a1 - a0) * i / n.toFloat());
            out.add((x + r * Math.cos(a)).toFloat());
            out.add((y + r * Math.sin(a)).toFloat());
        }
    }

    // A cubic Bezier from p0 through controls p1, p2 to p3 (unit box), its points after p0 added to out.
    function cubic(out as Array<Float>, p as Array<Float>, n as Number) as Void {
        for (var i = 1; i <= n; i++) {
            var t = i / n.toFloat(), s = 1 - t;
            var a = s * s * s, b = 3 * s * s * t, c = 3 * s * t * t, e = t * t * t;
            out.add(a * p[0] + b * p[2] + c * p[4] + e * p[6]);
            out.add(a * p[1] + b * p[3] + c * p[5] + e * p[7]);
        }
    }

    // The path's winding line and the stopwatch's filled part, worked out once.
    var pathLine as Array<Float>? = null;
    var watchPie as Array<Float>? = null;

    function shapes() as Void {
        if (pathLine != null) { return; }
        var p = [0.3, 0.18, 0.6, 0.18] as Array<Float>;
        cubic(p, [0.6, 0.18, 0.86, 0.18, 0.86, 0.5, 0.6, 0.5] as Array<Float>, 6);
        p.addAll([0.4, 0.5] as Array<Float>);
        cubic(p, [0.4, 0.5, 0.14, 0.5, 0.14, 0.82, 0.4, 0.82] as Array<Float>, 6);
        p.addAll([0.72, 0.82] as Array<Float>);
        pathLine = p;
        // From twelve o'clock clockwise to (0.33, 0.68), radius 0.2 round (0.5, 0.58).
        var w = [0.5, 0.58] as Array<Float>;
        arcPts(w, 0.5, 0.58, 0.2, -90.0, 149.53, 12);
        watchPie = w;
    }

    // A row's symbol: :path (blue: an open start, a winding line, a filled end), :ascent (orange: stairs
    // and an arrow up to the right), :watch (a green stopwatch), :peak (white: a mountain's outline over
    // its base) or :drift (calibration's light blue: a vertical double-headed arrow).
    function row(d as Draw, kind as Symbol, cx as Float, cy as Float, k as Float) as Void {
        shapes();
        if (kind == :path) {
            stroke(d, cx, cy, k, pathLine as Array<Float>, STROKE, PATH);
            d.dot(u(cx, k, 0.18), u(cy, k, 0.18), 0.15 * k, PATH);
            d.dot(u(cx, k, 0.18), u(cy, k, 0.18), 0.05 * k, Graphics.COLOR_BLACK);
            d.dot(u(cx, k, 0.82), u(cy, k, 0.82), 0.14 * k, PATH);
        } else if (kind == :ascent) {
            stroke(d, cx, cy, k, [0.08, 0.9, 0.36, 0.9, 0.36, 0.7, 0.58, 0.7, 0.58, 0.5, 0.86, 0.5] as Array<Float>, STROKE, Widgets.CLIMBER);
            stroke(d, cx, cy, k, [0.22, 0.52, 0.84, 0.1] as Array<Float>, STROKE, Widgets.CLIMBER);
            stroke(d, cx, cy, k, [0.56, 0.1, 0.84, 0.1, 0.84, 0.36] as Array<Float>, STROKE, Widgets.CLIMBER);
        } else if (kind == :peak) {
            stroke(d, cx, cy, k, [0.06, 0.86, 0.38, 0.26, 0.56, 0.56, 0.7, 0.4, 0.94, 0.86, 0.06, 0.86] as Array<Float>,
                STROKE, Flow.WHITE);
        } else if (kind == :drift) {
            stroke(d, cx, cy, k, [0.5, 0.12, 0.5, 0.88] as Array<Float>, STROKE, Flow.SYNC);
            stroke(d, cx, cy, k, [0.28, 0.32, 0.5, 0.1, 0.72, 0.32] as Array<Float>, STROKE, Flow.SYNC);
            stroke(d, cx, cy, k, [0.28, 0.68, 0.5, 0.9, 0.72, 0.68] as Array<Float>, STROKE, Flow.SYNC);
        } else {
            var c = Widgets.GREEN;
            d.ring(u(cx, k, 0.5), u(cy, k, 0.58), 0.32 * k, c, STROKE * k);
            // The crown's corners rounded only where their radius makes a pixel (the 280 px screens'
            // smaller sizes do not), as the demo drew it (#67).
            if (0.03 * k * d.w >= 1) {
                d.roundRect(u(cx, k, 0.4), u(cy, k, 0.04), 0.2 * k, 0.1 * k, 0.03 * k, c);
            } else {
                d.rect(u(cx, k, 0.4), u(cy, k, 0.04), 0.2 * k, 0.1 * k, c);
            }
            stroke(d, cx, cy, k, [0.5, 0.14, 0.5, 0.24] as Array<Float>, STROKE, c);
            stroke(d, cx, cy, k, [0.79, 0.27, 0.86, 0.2] as Array<Float>, STROKE, c);
            fill(d, cx, cy, k, watchPie as Array<Float>, c);
        }
    }

    // The pause symbol (owner, 2026-11-26, in place of the word PAUSED): two blue bars spanning what a
    // disk of radius r would, 1.4 r tall, each 0.42 r wide, 0.36 r apart. No disk: on the watch the
    // bars, rounded to pixels apart from it, stood a pixel off its middle (owner, 2026-11-26).
    function pause(d as Draw, cx as Float, cy as Float, r as Float) as Void {
        var bw = r * 0.42, bh = r * 1.4, g = r * 0.18;
        d.roundRect(cx - g - bw, cy - bh / 2, bw, bh, bw * 0.25, PAUSE);
        d.roundRect(cx + g, cy - bh / 2, bw, bh, bw * 0.25, PAUSE);
    }

    // ---------------------------------------------------------------- the button marks

    // Where a mark beside a button on the right stands (owner, 2026-11-26): as near the button as the
    // round screen allows, at its angle (Start 30 degrees above three o'clock, Back 30 below), 0.435 of
    // the width from the centre, on a half-transparent black square 0.085 wide, 60 % opaque, so what runs
    // under it shows dimmed.
    const MARK_R = 0.435;
    const MARK_BOX = 0.085;

    function markX() as Float { return 0.5 + MARK_R * Math.cos(Math.PI / 6).toFloat(); }

    function markY(start as Boolean) as Float { return 0.5 + (start ? -1 : 1) * MARK_R * 0.5; }

    function box(d as Draw, cx as Float, cy as Float) as Void {
        d.shade(cx - MARK_BOX / 2, cy - MARK_BOX / 2, MARK_BOX, MARK_BOX, 0.018, 0x99);
    }

    // A thin arc along the edge by Start, as Garmin's own activities mark Start before one begins (the
    // ready screen's; owner, 2026-11-26, in place of a play symbol): centred on the button's 30
    // degrees, 24 degrees long, 0.012 thick with round ends, its outer edge 0.02 in from the screen's.
    function startArc(d as Draw, c as Number) as Void {
        var pen = 0.012, r = 0.5 - 0.02 - pen / 2;
        d.arc(r, 42, 18, c, pen);
        var p0 = d.onCircle(r, 42), p1 = d.onCircle(r, 18);
        d.dot(p0[0], p0[1], pen / 2, c);
        d.dot(p1[0], p1[1], pen / 2, c);
    }

    // A check by Start (set, calibrate or end there).
    function check(d as Draw, c as Number) as Void {
        var cx = markX(), cy = markY(true), r = 0.028, pen = 0.012;
        box(d, cx, cy);
        d.seg(cx - r, cy, cx - r * 0.3, cy + r * 0.7, pen, c, true);
        d.seg(cx - r * 0.3, cy + r * 0.7, cx + r, cy - r * 0.7, pen, c, true);
    }

    // A cross by Back (cancel).
    function cross(d as Draw, c as Number) as Void {
        var cx = markX(), cy = markY(false), r = 0.023, pen = 0.012;
        box(d, cx, cy);
        d.seg(cx - r, cy - r, cx + r, cy + r, pen, c, true);
        d.seg(cx + r, cy - r, cx - r, cy + r, pen, c, true);
    }
}
