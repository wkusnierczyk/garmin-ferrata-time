using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

import Toybox.Lang;

// The widgets of design/widgets.md, drawn in the design's 416 px coordinates. Each takes the
// climber's state and where to draw; a page places them.
module Widgets {

    const CLIMBER = 0xff6f3c;
    const REST = 0x3a86ff;
    const GREEN = 0x3fd77f;
    const RED = 0xff4b4b;
    const SCALE = 0x777777;
    const WHITE = Graphics.COLOR_WHITE;
    const BLACK = Graphics.COLOR_BLACK;

    // The climber's ring on the ascent line, and the space kept between it and the numbers beside it.
    const RING_R = 9;
    const RING_OUTER = 10.5;
    const NUMBER_SPACE = 5;

    // The difficulty widget's boxes: codes 0 to 5 are walk and K1 to K5, then rest, exit and danger.
    const CODE_EXIT = -2;
    const CODE_DANGER = -3;
    const NONE = -99;
    const BOX_NAME = ["W", "K1", "K2", "K3", "K4", "K5"] as Array<String>;
    const BOX_H = 38;
    const SATELLITE = 0.72;
    const BOX_GAP = 5;

    // ---------------------------------------------------------------- profile

    // The route from the side, from (x0, y0) at the start to (x0 + w, y0 - h) at the top.
    function profile(d as Draw, st as Climb.State, x0 as Float, w as Float, y0 as Float, h as Float) as Void {
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        // The climber: an orange outline around the stretch they could be on, a wide orange line
        // with a narrower black one inside it, under the sections.
        var lo = Climb.firstDistanceAt(st.u - Climb.UNCERTAINTY);
        var hi = Climb.lastDistanceAt(st.u + Climb.UNCERTAINTY);
        stretch(d, lo, hi, x0, w, y0, h, CLIMBER, 14);
        stretch(d, lo, hi, x0, w, y0, h, BLACK, 11);
        // The sections, round-ended, climbed parts dimmed; rests are left as gaps for their rings.
        var cx = x0 + st.d / td * w, cy = y0 - st.u / tu * h;
        for (var i = 0; i < Climb.count(); i++) {
            var g = Climb.GRADE[i];
            if (g < 0) { continue; }
            var ax = x0 + Climb.dAt(i) / td * w, ay = y0 - Climb.uAt(i) / tu * h;
            var bx = x0 + Climb.dAt(i + 1) / td * w, by = y0 - Climb.uAt(i + 1) / tu * h;
            if (Climb.dAt(i + 1) <= st.d) {
                d.brush(ax, ay, bx, by, 5, d.grade(g, true));
            } else if (Climb.dAt(i) >= st.d) {
                d.brush(ax, ay, bx, by, 5, d.grade(g, false));
            } else {
                d.brush(ax, ay, cx, cy, 5, d.grade(g, true));
                d.brush(cx, cy, bx, by, 5, d.grade(g, false));
            }
        }
        // The points, as hollow rings, dimmed once passed.
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var md = (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0;
                point(d, x0 + md / td * w, y0 - Climb.heightAtDistance(md) / tu * h, REST, md <= st.d);
            }
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var dd = Climb.DANGER_AT[e].toFloat();
            point(d, x0 + dd / td * w, y0 - Climb.heightAtDistance(dd) / tu * h, RED, dd <= st.d);
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var i = Climb.EXIT_AT[e];
            point(d, x0 + Climb.dAt(i) / td * w, y0 - Climb.uAt(i) / tu * h, GREEN, Climb.dAt(i) <= st.d);
        }
        d.top(x0 + w, y0 - h);
    }

    // The route between two distances, painted with a round brush of radius r.
    function stretch(d as Draw, lo as Float, hi as Float, x0 as Float, w as Float, y0 as Float, h as Float,
            c as Number, r as Number) as Void {
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        var px = x0 + lo / td * w, py = y0 - Climb.heightAtDistance(lo) / tu * h;
        var dd = lo;
        // Every 8 m: smooth at this scale, and half the circles of every 4 m.
        while (dd < hi) {
            dd += 8;
            if (dd > hi) { dd = hi; }
            var nx = x0 + dd / td * w, ny = y0 - Climb.heightAtDistance(dd) / tu * h;
            d.brush(px, py, nx, ny, r, c);
            px = nx; py = ny;
        }
    }

    // A point on the route: a ring, black inside so the route breaks there.
    function point(d as Draw, x as Float, y as Float, c as Number, passed as Boolean) as Void {
        d.dot(x, y, 9, BLACK);
        d.ring(x, y, 8, passed ? d.darken(c, 0.33) : c, 3);
    }

    // ---------------------------------------------------------------- ascent

    // The route's height as a line at x, from y0 (the start) up to y0 - h, with the climber on it.
    function ascent(d as Draw, st as Climb.State, x as Float, y0 as Float, h as Float, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat();
        var top = y0 - h, ty = y0 - st.u / tu * h, up = st.climbed();
        // Back to front: the line, the ring's black inside, the end dots, the ring's outline.
        d.line(x, y0, x, top, SCALE, 2);
        d.dot(x, ty, RING_R, BLACK);
        // Each number centred on its stretch, kept clear of the ring, never past the line's end.
        var gap = 20;
        var yb = (ty + y0) / 2;
        if (yb < ty + gap) { yb = ty + gap; }
        if (yb > y0) { yb = y0; }
        var ya = (top + ty) / 2;
        if (ya > ty - gap) { ya = ty - gap; }
        if (ya < top) { ya = top; }
        var nx = x - RING_OUTER - NUMBER_SPACE;
        d.textRight(nx, yb, Graphics.FONT_XTINY, up.format("%d"), WHITE);
        d.textRight(nx, ya, Graphics.FONT_XTINY, (Climb.totalU() - up).format("%d"), WHITE);
        if (ends) {
            d.dot(x, y0, 6, GREEN);
            d.dot(x, top, 6, RED);
        }
        d.ring(x, ty, RING_R, CLIMBER, 3);
    }

    // The widest number the ascent widget can show, measured once.
    var ascentWidest as Number? = null;

    function ascentNumbersWidth(d as Draw) as Number {
        var w = ascentWidest;
        if (w == null) {
            // The widest is among those with the most digits, from the first such number up.
            w = 0;
            var from = 1;
            while (from * 10 <= Climb.totalU()) { from *= 10; }
            for (var n = from; n <= Climb.totalU(); n++) {
                var nw = d.width(Graphics.FONT_XTINY, n.format("%d"));
                if (nw > w) { w = nw; }
            }
            ascentWidest = w;
        }
        return w;
    }

    // How far the ascent widget reaches left of its line.
    function ascentLeft(d as Draw) as Float {
        return ascentNumbersWidth(d) + NUMBER_SPACE + RING_OUTER;
    }

    // ---------------------------------------------------------------- difficulty

    function boxWidth(code as Number, k as Float) as Float {
        return (code >= 1 ? 58 : 46) * k;
    }

    // One box, centred on x with its bottom at yb, at size k.
    function badge(d as Draw, x as Float, yb as Float, k as Float, code as Number) as Void {
        var text = "R", colour = REST, filled = false;
        if (code >= 0) {
            text = BOX_NAME[code]; colour = d.grade(code, false); filled = true;
        } else if (code == CODE_EXIT) {
            text = "E"; colour = GREEN;
        } else if (code == CODE_DANGER) {
            text = "D"; colour = RED;
        }
        // Whole pixels from the bottom up, so every box's bottom lands on the same row.
        var w = Math.round(boxWidth(code, k)), h = Math.round(BOX_H * k), top = yb - h;
        d.roundRect(x - w / 2, top, w, h, 8 * k, colour);
        if (!filled) {
            // The outline is the box in its colour with a black box 3 px inside it.
            d.roundRect(x - w / 2 + 3, top + 3, w - 6, h - 6, 6 * k, BLACK);
        }
        d.textCapCentre(x, top + h / 2, k < 1 ? Graphics.FONT_XTINY : Graphics.FONT_TINY, text, filled ? BLACK : colour);
    }

    // The section the climber is estimated in, in a larger box centred on x; the nearest thing behind
    // and ahead within the uncertainty stretch in smaller boxes beside it. All share the bottom yb.
    // Without points, only sections count, and a rest shows as walking ground (W).
    function difficulty(d as Draw, st as Climb.State, x as Float, yb as Float, points as Boolean) as Void {
        var lo = Climb.firstDistanceAt(st.u - Climb.UNCERTAINTY);
        var hi = Climb.lastDistanceAt(st.u + Climb.UNCERTAINTY);
        var cur = st.cur;
        var left = NONE, right = NONE, leftDist = 1.0e9, rightDist = 1.0e9;
        // The neighbouring sections; a point at the same distance wins over them.
        if (cur > 0 && Climb.dAt(cur) >= lo) {
            left = section(cur - 1, points); leftDist = st.d - Climb.dAt(cur) + 0.01;
        }
        if (cur < Climb.count() - 1 && Climb.dAt(cur + 1) <= hi) {
            right = section(cur + 1, points); rightDist = Climb.dAt(cur + 1) - st.d + 0.01;
        }
        var n = points ? Climb.EXIT_AT.size() + Climb.DANGER_AT.size() : 0;
        for (var j = 0; j < n; j++) {
            var p = 0.0, code = CODE_EXIT;
            if (j < Climb.EXIT_AT.size()) {
                p = Climb.dAt(Climb.EXIT_AT[j]).toFloat();
            } else {
                p = Climb.DANGER_AT[j - Climb.EXIT_AT.size()].toFloat(); code = CODE_DANGER;
            }
            if (p >= lo && p <= st.d && st.d - p < leftDist) { left = code; leftDist = st.d - p; }
            if (p > st.d && p <= hi && p - st.d < rightDist) { right = code; rightDist = p - st.d; }
        }
        var mid = section(cur, points), half = boxWidth(mid, 1.0) / 2;
        badge(d, x, yb, 1.0, mid);
        if (left != NONE) { badge(d, x - half - BOX_GAP - boxWidth(left, SATELLITE) / 2, yb, SATELLITE, left); }
        if (right != NONE) { badge(d, x + half + BOX_GAP + boxWidth(right, SATELLITE) / 2, yb, SATELLITE, right); }
    }

    // A section's box code; a rest is walking ground when points are left out.
    function section(i as Number, points as Boolean) as Number {
        var g = Climb.GRADE[i];
        return g < 0 && !points ? 0 : g;
    }

    // How far the difficulty widget can reach right of its centre: two-character boxes in every slot.
    function difficultyReach() as Float {
        return boxWidth(1, 1.0) / 2 + BOX_GAP + boxWidth(1, SATELLITE);
    }

    // ---------------------------------------------------------------- altitude, poi

    const ALT_FONT = Graphics.FONT_LARGE;

    // The widest altitude the route can show in a font, per unit, measured once per font: slot 0 for
    // the altitude widget's, 1 for the column group's.
    var widest as Array<Number?> = [null, null];
    var widestFeet as Array<Boolean> = [false, false];

    function feet() as Boolean {
        return System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE;
    }

    // Rounded to 10 m or 50 ft: the position is known only to within 25 m.
    function altitudeValue(u as Float, ft as Boolean) as Number {
        var m = Climb.START_ALT + u;
        if (ft) { return (Math.round(m * 3.28084 / 50) * 50).toNumber(); }
        return (Math.round(m / 10) * 10).toNumber();
    }

    function widestAltitude(d as Draw, ft as Boolean, font as Graphics.FontType, slot as Number) as Number {
        var w = widest[slot];
        if (w == null || widestFeet[slot] != ft) {
            w = 0;
            var step = ft ? 50 : 10;
            var last = altitudeValue(Climb.totalU().toFloat(), ft);
            for (var v = altitudeValue(0.0, ft); v <= last; v += step) {
                var vw = d.width(font, v.format("%d"));
                if (vw > w) { w = vw; }
            }
            widest[slot] = w;
            widestFeet[slot] = ft;
        }
        return w;
    }

    function altitudeBox(d as Draw, ft as Boolean) as Number {
        return widestAltitude(d, ft, ALT_FONT, 0);
    }

    // The approximate altitude, right-aligned in a box as wide as the route's widest, starting at x,
    // its top at yt; the unit follows the box.
    function altitude(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var ft = feet();
        var right = x + altitudeBox(d, ft);
        d.textCapTop(right, yt, ALT_FONT, altitudeValue(st.u, ft).format("%d"), WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
        // The unit on the number's baseline.
        var baseline = yt + d.capHeight(ALT_FONT);
        d.textTop(right + 4, baseline - d.ascent(Graphics.FONT_XTINY), Graphics.FONT_XTINY, ft ? "ft" : "m", d.MUTED,
            Graphics.TEXT_JUSTIFY_LEFT);
    }

    // One word for the point of interest the uncertainty stretch covers, right-aligned at x, its top
    // at yt. The nearest wins; on a tie, danger before exit before rest.
    function poi(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var lo = Climb.firstDistanceAt(st.u - Climb.UNCERTAINTY);
        var hi = Climb.lastDistanceAt(st.u + Climb.UNCERTAINTY);
        var best = 1.0e9, rank = 9, word = "", colour = WHITE;
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0 && Climb.dAt(i) <= hi && Climb.dAt(i + 1) >= lo) {
                var dist = 0.0;
                if (st.d < Climb.dAt(i)) { dist = Climb.dAt(i) - st.d; }
                if (st.d > Climb.dAt(i + 1)) { dist = st.d - Climb.dAt(i + 1); }
                if (dist < best || (dist == best && 2 < rank)) { best = dist; rank = 2; word = "REST"; colour = REST; }
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var p = Climb.dAt(Climb.EXIT_AT[e]).toFloat();
            var dist = (p - st.d).abs();
            if (p >= lo && p <= hi && (dist < best || (dist == best && 1 < rank))) { best = dist; rank = 1; word = "EXIT"; colour = GREEN; }
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var p = Climb.DANGER_AT[e].toFloat();
            var dist = (p - st.d).abs();
            if (p >= lo && p <= hi && dist <= best) { best = dist; rank = 0; word = "DANGER"; colour = RED; }
        }
        if (word.length() > 0) {
            d.textCapTop(x, yt, Graphics.FONT_XTINY, word, colour, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // The altitude centred on x, its digits' top at yt.
    function altitudeCentred(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var ft = feet();
        var w = altitudeBox(d, ft) + 4 + d.width(Graphics.FONT_XTINY, ft ? "ft" : "m");
        altitude(d, st, x - w / 2, yt);
    }

    // The altitude group: the altitude, with the poi word under it, right-aligned with the number.
    function altitudeGroup(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        altitude(d, st, x, yt);
        poi(d, st, x + altitudeBox(d, feet()), yt + d.capHeight(ALT_FONT) + 12);
    }

    // ---------------------------------------------------------------- difficulty column

    // Equal boxes, the current one larger by COL_BIG; those before the climber at COL_DIM of their colour.
    const COL_W = 64;
    const COL_H = 40;
    const COL_GAP = 8;
    const COL_BIG = 1.08;
    const COL_DIM = 0.55;
    const COL_SPACE = 10;
    const COL_ALT_FONT = Graphics.FONT_TINY;

    // The centre of slot k (0 the climber's, positive above), and the half height of its box.
    function slotY(k as Number, cy as Float) as Float {
        if (k == 0) { return cy; }
        var off = COL_H * COL_BIG / 2 + COL_GAP + COL_H / 2.0 + (k.abs() - 1) * (COL_H + COL_GAP);
        return k > 0 ? cy - off : cy + off;
    }

    function slotHalf(k as Number) as Float {
        return (k == 0 ? COL_H * COL_BIG : COL_H.toFloat()) / 2;
    }

    // Whether section i has a box in the column around section cur.
    function inColumn(i as Number, cur as Number) as Boolean {
        return i >= 0 && i < Climb.count() && (i - cur).abs() <= 2;
    }

    // The sections around the climber's as a column of boxes centred on (cx, cy): the current one
    // filled and larger, two before below (dimmed) and two after above, outlined. A rest shows as W.
    function column(d as Draw, st as Climb.State, cx as Float, cy as Float) as Void {
        for (var k = -2; k <= 2; k++) {
            var i = st.cur + k;
            if (!inColumn(i, st.cur)) { continue; }
            var g = section(i, false);
            var big = k == 0, f = big ? COL_BIG : 1.0;
            var w = Math.round(COL_W * f), h = Math.round(COL_H * f);
            var y = slotY(k, cy), top = Math.round(y - h / 2);
            var colour = d.grade(g, false);
            if (k < 0) { colour = d.darken(colour, COL_DIM); }
            d.roundRect(cx - w / 2, top, w, h, 8 * f, colour);
            if (!big) { d.roundRect(cx - w / 2 + 3, top + 3, w - 6, h - 6, 6 * f, BLACK); }
            d.textCapCentre(cx, top + h / 2, big ? Graphics.FONT_SMALL : Graphics.FONT_TINY, BOX_NAME[g], big ? BLACK : colour);
        }
    }

    // The widest altitude the route can show in the column's font.
    function columnAltitudeBox(d as Draw, ft as Boolean) as Number {
        return widestAltitude(d, ft, COL_ALT_FONT, 1);
    }

    // The difficulty column group's width: the larger box, the space, the altitudes and the unit shown.
    function columnGroupWidth(d as Draw) as Float {
        var ft = feet();
        return COL_W * COL_BIG + COL_SPACE + columnAltitudeBox(d, ft) + 3 + d.width(Graphics.FONT_XTINY, ft ? "ft" : "m");
    }

    // How far the column reaches above and below its centre.
    function columnReach() as Float {
        return COL_H * COL_BIG / 2 + 2 * (COL_GAP + COL_H);
    }

    // The difficulty column group, centred on the screen as one group, at height cy.
    function columnGroup(d as Draw, st as Climb.State, cy as Float, outer as Boolean) as Void {
        columnGroupAt(d, st, 208 - columnGroupWidth(d) / 2, cy, outer);
    }

    // The difficulty column group: the column, with the altitudes where the difficulty changes to its
    // right, each level with a border between two boxes (and at the column's outer edges if outer),
    // right-aligned in a box as wide as the route's widest, its unit after it. Its left edge at left,
    // centred vertically on cy.
    function columnGroupAt(d as Draw, st as Climb.State, left as Float, cy as Float, outer as Boolean) as Void {
        var ft = feet(), unit = ft ? "ft" : "m";
        var bw = COL_W * COL_BIG, altW = columnAltitudeBox(d, ft);
        var cx = left + bw / 2;
        var ax = cx + bw / 2 + COL_SPACE + altW;
        column(d, st, cx, cy);
        // Border b lies between sections b - 1 and b, at height U[b].
        for (var b = st.cur - 2; b <= st.cur + 3; b++) {
            var above = inColumn(b, st.cur), below = inColumn(b - 1, st.cur);
            if (!(above && below) && !(outer && (above || below))) { continue; }
            var y = above
                ? slotY(b - st.cur, cy) + slotHalf(b - st.cur) + COL_GAP / 2.0
                : slotY(b - 1 - st.cur, cy) - slotHalf(b - 1 - st.cur) - COL_GAP / 2.0;
            var v = altitudeValue(Climb.uAt(b).toFloat(), ft);
            d.textCapMiddle(ax, y, COL_ALT_FONT, v.format("%d"), WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
            // The unit on the number's baseline.
            var baseline = y + d.capHeight(COL_ALT_FONT) / 2;
            d.textTop(ax + 3, baseline - d.ascent(Graphics.FONT_XTINY), Graphics.FONT_XTINY, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }
}
