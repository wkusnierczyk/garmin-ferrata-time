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

    // ---------------------------------------------------------------- difficulty stack

    // The sections as boxes to scale, in a window from top to bottom that moves with the climber, who
    // stays a quarter of the way up from its bottom: by ascent (byUp) each box as tall as the metres
    // its section climbs, by path as tall as its length along the route.
    const STACK_W = 60;
    const STACK_NAMES = 80;

    // The points' names, by rank.
    const POI_WORDS = ["Danger", "Exit", "Rest", "Top"] as Array<String>;

    // The section names' distance from the column, clear of the points' rings on its right edge.
    const NAME_GAP = 18;
    // Danger points are yellow on pages 1 to 8, red being kept for the route's top.
    const POI_DANGER = 0xffd60a;

    // The tick labels' width, as wide as the larger label of the next altitude can be.
    function stackLabels(d as Draw) as Float {
        var top = altitudeValue(Climb.totalU().toFloat(), feet()) + 50;
        return d.width(bigLabelFont(d, 0), top.format("%d")) + 14.0;
    }

    // The points of interest on the stack: rings on the column's right edge (x) at their place on it,
    // rests blue (the middle of the rest), exits green, dangers yellow, the top red, dimmed once
    // passed. A point is in the climber's range from one tick step (stepM metres along the stack's
    // axis) before it to half a step after it. Points whose rings would touch show one ring: of those
    // in range, the first of danger, exit, rest, top, with its name ("Danger", "Exit", "Rest", "Top")
    // beside it in its colour; with none in range, the one nearest the climber, unnamed. Returns the
    // y of each name shown.
    function stackPoints(d as Draw, st as Climb.State, byUp as Boolean, top as Float, bottom as Float, cy as Float,
            here as Float, scale as Float, x as Float, nameR as Number, stepM as Float) as Array<Float> {
        // Each point: where it sits, its stretch (lo to hi metres along the route), colour, rank.
        var at = [] as Array<Float>, lo = [] as Array<Float>, hi = [] as Array<Float>;
        var colour = [] as Array<Number>, rank = [] as Array<Number>;
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var d0 = Climb.dAt(i).toFloat(), d1 = Climb.dAt(i + 1).toFloat();
                at.add((d0 + d1) / 2); lo.add(d0); hi.add(d1); colour.add(REST); rank.add(2);
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var de = Climb.dAt(Climb.EXIT_AT[e]).toFloat();
            at.add(de); lo.add(de); hi.add(de); colour.add(GREEN); rank.add(1);
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var de = Climb.DANGER_AT[e].toFloat();
            at.add(de); lo.add(de); hi.add(de); colour.add(POI_DANGER); rank.add(0);
        }
        var td = Climb.totalD().toFloat();
        at.add(td); lo.add(td); hi.add(td); colour.add(RED); rank.add(3);
        // Their screen heights, distances from the climber and whether in range; the ones in view,
        // ordered from the top down.
        var n = at.size();
        var ys = new [n] as Array<Float>, away = new [n] as Array<Float>, near = new [n] as Array<Boolean>;
        var order = [] as Array<Number>;
        for (var p = 0; p < n; p++) {
            var a = byUp ? Climb.heightAtDistance(lo[p]) : lo[p], b = byUp ? Climb.heightAtDistance(hi[p]) : hi[p];
            var ahead = a - here, behind = here - b;
            near[p] = ahead <= stepM && behind <= stepM / 2;
            away[p] = ahead > behind ? (ahead > 0 ? ahead : 0.0) : (behind > 0 ? behind : 0.0);
            ys[p] = cy - ((byUp ? Climb.heightAtDistance(at[p]) : at[p]) - here) * scale;
            if (ys[p] < top + 6 || ys[p] > bottom - 6) { continue; }
            var k = order.size();
            order.add(p);
            while (k > 0 && ys[order[k - 1]] > ys[p]) { order[k] = order[k - 1]; k--; }
            order[k] = p;
        }
        // Group the rings that would touch, and draw one per group.
        var named = [] as Array<Float>;
        var g = 0;
        while (g < order.size()) {
            var best = order[g], end = g + 1;
            while (end < order.size() && ys[order[end]] - ys[order[end - 1]] < 18) { end++; }
            for (var m = g; m < end; m++) {
                var p = order[m];
                var better = near[p] && !near[best] ||
                    near[p] == near[best] && (near[p] ? rank[p] < rank[best] || rank[p] == rank[best] && away[p] < away[best] : away[p] < away[best]);
                if (better) { best = p; }
            }
            var c = colour[best], y = ys[best];
            d.dot(x, y, 8, BLACK);
            d.ring(x, y, 7, at[best] <= st.d ? d.darken(c, 0.33) : c, 3);
            if (near[best]) {
                var half = nameR * nameR - (y - 208) * (y - 208);
                var room = (208 + Math.sqrt(half > 0 ? half : 0) - (x + 14)).toFloat();
                // Not within 20 px of a name already shown, as in the mock.
                var clear = true;
                for (var q = 0; q < named.size(); q++) { if ((named[q] - y).abs() < 20) { clear = false; } }
                if (room >= 30 && clear) {
                    d.textCapMiddle(x + 14, y, Graphics.FONT_XTINY, fitName(d, POI_WORDS[rank[best]], room), c, Graphics.TEXT_JUSTIFY_LEFT);
                    named.add(y);
                }
            }
            g = end;
        }
        return named;
    }

    // Where boundary i sits along the stack's axis, and section i's size on it.
    function stackAt(i as Number, byUp as Boolean) as Float {
        return (byUp ? Climb.uAt(i) : Climb.dAt(i)).toFloat();
    }

    function stackSize(i as Number, byUp as Boolean) as Number {
        return byUp ? Climb.UP[i] : Climb.LEN[i];
    }

    function stackColour(d as Draw, st as Climb.State, i as Number) as Number {
        var c = d.grade(section(i, false), false);
        return i < st.cur ? d.darken(c, COL_DIM) : c;
    }

    // A name cut to fit a width, ending in an ellipsis when cut.
    function fitName(d as Draw, name as String, w as Float) as String {
        if (d.width(Graphics.FONT_XTINY, name) <= w) { return name; }
        var n = name.length();
        while (n > 1 && d.width(Graphics.FONT_XTINY, name.substring(0, n) + "…") > w) { n--; }
        return name.substring(0, n) + "…";
    }

    // The larger tick labels by ascent: the next altitude to reach at twice the other labels' height,
    // the ones just above and below it at one and a half. In a scalable font where the watch has one
    // (sized once, then corrected by the height it measures), a fixed larger system font otherwise.
    const BIG_SCALE = [2.0, 1.5];
    var bigFonts as Array<Graphics.FontType?> = [null, null];

    function bigLabelFont(d as Draw, which as Number) as Graphics.FontType {
        if (bigFonts[which] == null) {
            var want = d.dc.getFontHeight(Graphics.FONT_XTINY) * BIG_SCALE[which];
            var size = Math.round(want).toNumber();
            var vf = (Graphics has :getVectorFont) ? Graphics.getVectorFont({:face => ["RobotoCondensedBold"], :size => size}) : null;
            if (vf != null) {
                var h = d.dc.getFontHeight(vf);
                if (h > 0) { vf = Graphics.getVectorFont({:face => ["RobotoCondensedBold"], :size => Math.round(size * want / h).toNumber()}); }
            }
            bigFonts[which] = vf != null ? vf : (which == 0 ? Graphics.FONT_LARGE : Graphics.FONT_SMALL);
        }
        return bigFonts[which] as Graphics.FontType;
    }

    // Tick label t's font, next being the next altitude's tick (or -1).
    function tickFont(d as Draw, t as Number, next as Number) as Graphics.FontType {
        if (next < 0) { return Graphics.FONT_XTINY; }
        var off = (t - next).abs();
        return off == 0 ? bigLabelFont(d, 0) : off == 1 ? bigLabelFont(d, 1) : Graphics.FONT_XTINY;
    }

    // Ticks every stepM metres, or stepFt feet when the watch shows feet. Names stop at radius nameR
    // from the centre: the screen's edge, or inside a gauge around it.
    function stack(d as Draw, st as Climb.State, byUp as Boolean, left as Float, top as Float, bottom as Float,
            scale as Float, names as Boolean, stepM as Number, stepFt as Number, nameR as Number) as Void {
        var cy = bottom - (bottom - top) / 4, here = byUp ? st.u : st.d;
        var right = left + STACK_W, cx = left + STACK_W / 2;
        var n = Climb.count();
        d.clip(left - 2, top, STACK_W + 4, bottom - top);
        // The boxes: the current one filled, the others black with their sides in their colour.
        for (var i = 0; i < n; i++) {
            var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
            if (yt > bottom + 2 || yb < top - 2 || stackSize(i, byUp) == 0) { continue; }
            var c = stackColour(d, st, i), now = i == st.cur;
            if (now) {
                d.rect(left, yt, STACK_W, yb - yt, c);
            } else {
                d.rect(left, yt, STACK_W, yb - yt, BLACK);
                d.rect(left, yt, 3, yb - yt, c);
                d.rect(right - 3, yt, 3, yb - yt, c);
            }
            // Letters centred on the part in view, left out when it is too short for them.
            var vt = yt > top ? yt : top, vb = yb < bottom ? yb : bottom;
            var font = now ? Graphics.FONT_SMALL : Graphics.FONT_TINY;
            if (vb - vt >= d.capHeight(font) + 10) {
                d.textCapCentre(cx, (vt + vb) / 2, font, BOX_NAME[section(i, false)], now ? BLACK : c);
            }
        }
        // The borders: between two boxes in the colour of the one closer to the current section; a
        // flat section is a line in its own colour; the start and the top close the column.
        for (var i = 0; i < n; i++) {
            var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
            if (yt > bottom + 2 || yb < top - 2) { continue; }
            if (stackSize(i, byUp) == 0) {
                d.rect(left, yb - 1.5, STACK_W, 3, stackColour(d, st, i));
                continue;
            }
            if (i == 0) {
                d.rect(left, yb - 3, STACK_W, 3, stackColour(d, st, i));
            } else if (stackSize(i - 1, byUp) > 0) {
                var closer = (i - st.cur).abs() <= (i - 1 - st.cur).abs() ? i : i - 1;
                d.rect(left, yb - 1.5, STACK_W, 3, stackColour(d, st, closer));
            }
            if (i == n - 1) { d.rect(left, yt, STACK_W, 3, stackColour(d, st, i)); }
        }
        d.unclip();
        var ft = feet(), step = ft ? stepFt : stepM;
        // The points of interest, one ring for each group whose rings would touch; the y of each one
        // that shows its name, for the section names to give way to.
        var named = stackPoints(d, st, byUp, top, bottom, cy, here, scale, right, nameR, ft ? stepFt / 3.28084 : stepM.toFloat());
        // The names on the right, centred on the part in view, cut to fit the round screen, each 20 px
        // clear of the points' names and of the section names already shown.
        if (names) {
            for (var i = 0; i < n; i++) {
                var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
                if (yt > bottom || yb < top) { continue; }
                var vt = yt > top ? yt : top, vb = yb < bottom ? yb : bottom;
                var flat = stackSize(i, byUp) == 0;
                if (!flat && vb - vt < 16) { continue; }
                var ny = flat ? yb : (vt + vb) / 2;
                var touches = false;
                for (var p = 0; p < named.size(); p++) { if ((named[p] - ny).abs() < 20) { touches = true; } }
                if (touches) { continue; }
                named.add(ny);
                var half = nameR * nameR - (ny - 208) * (ny - 208);
                var room = (208 + Math.sqrt(half > 0 ? half : 0) - (right + NAME_GAP)).toFloat();
                if (room < 30) { continue; }
                d.textCapMiddle(right + NAME_GAP, ny, Graphics.FONT_XTINY, fitName(d, Climb.NAME[i], room),
                    i < st.cur ? 0x7d8a8a : WHITE, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
        // Altitude ticks on the left, every step, only along the route. By path a tick sits
        // where the route first reaches its altitude; a label touching the one below is left out.
        var vLo = here - (bottom - cy) / scale, vHi = here + (cy - top) / scale;
        if (vLo < 0) { vLo = 0.0; }
        var vMax = (byUp ? Climb.totalU() : Climb.totalD()).toFloat();
        if (vHi > vMax) { vHi = vMax; }
        var uLo = byUp ? vLo : Climb.heightAtDistance(vLo), uHi = byUp ? vHi : Climb.heightAtDistance(vHi);
        var k = ft ? 3.28084 : 1.0;
        var aLo = (Climb.START_ALT + uLo) * k, aHi = (Climb.START_ALT + uHi) * k;
        var ticks = [] as Array<Number>, ys = [] as Array<Float>;
        for (var a = (Math.ceil(aLo / step) * step).toNumber(); a <= aHi; a += step) {
            var u = a / k - Climb.START_ALT;
            var y = cy - ((byUp ? u : Climb.firstDistanceAt(u)) - here) * scale;
            // By path a flat stretch at this altitude may be reached before the window's bottom.
            if (y < top || y > bottom) { continue; }
            d.rect(left - 9, y - 1, 6, 2, SCALE);
            ticks.add(a);
            ys.add(y);
        }
        // The label of the next altitude to reach is twice as large and always shown, the ones just
        // above and below it one and a half times; the others are left out around it, each kept clear
        // of the last one shown. By path it is the first tick above the altitude now, which may sit
        // further along the route than the climber.
        var next = -1, now = (Climb.START_ALT + st.u) * k;
        for (var t = 0; t < ticks.size() && next < 0; t++) { if (ticks[t] > now) { next = t; } }
        var from = next >= 0 ? next : 0;
        for (var dir = 1; dir >= -1; dir -= 2) {
            var last = dir < 0 && next >= 0 ? next : -1;
            for (var t = dir > 0 ? from : from - 1; t >= 0 && t < ticks.size(); t += dir) {
                var font = tickFont(d, t, next);
                if (last >= 0) {
                    var lastFont = tickFont(d, last, next);
                    var gap = (ys[last] - ys[t]).abs();
                    if (gap < (d.capHeight(font) + d.capHeight(lastFont)) / 2 + 6) { continue; }
                }
                d.textCapMiddle(left - 14, ys[t], font, ticks[t].format("%d"), d.MUTED, Graphics.TEXT_JUSTIFY_RIGHT);
                last = t;
            }
        }
        // The climber: the orange ring on the column's left edge, with no line across the column, which
        // hid the letters.
        d.dot(left, cy, RING_R, BLACK);
        d.ring(left, cy, RING_R, CLIMBER, 3);
    }

    // ---------------------------------------------------------------- gauge, page 6

    // The route around the screen's edge, from its start at the lower left over the top to its top at
    // the lower right, each section's arc its length along the route, or the metres it climbs (byUp);
    // climbed parts dimmed; rests, exits and dangers as rings, dimmed once passed; the climber as a
    // thicker orange line on the gauge's inner side over the stretch they could be on, rounded at its
    // ends, clear of the sections.
    const G_R = 192;
    const G_FROM = 232;
    const G_SPAN = 284;
    const G_PEN = 12;
    // The climber's line: its width, and its radius 3 px inside the sections.
    const G_INNER = 6;
    const G_INNER_R = G_R - G_PEN / 2 - 3 - G_INNER / 2;

    function gaugeAngle(dist as Float, byUp as Boolean) as Float {
        return G_FROM - (byUp ? Climb.heightAtDistance(dist) / Climb.totalU() : dist / Climb.totalD()) * G_SPAN;
    }

    function gauge(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var lo = Climb.firstDistanceAt(st.u - Climb.UNCERTAINTY);
        var hi = Climb.lastDistanceAt(st.u + Climb.UNCERTAINTY);
        var a0 = gaugeAngle(lo, byUp), a1 = gaugeAngle(hi, byUp);
        // The climber: an orange line inside the gauge, with round ends.
        var p0 = d.onCircle(G_INNER_R, a0), p1 = d.onCircle(G_INNER_R, a1);
        d.arc(G_INNER_R, a0, a1, CLIMBER, G_INNER);
        d.dot(p0[0], p0[1], G_INNER / 2, CLIMBER);
        d.dot(p1[0], p1[1], G_INNER / 2, CLIMBER);
        // The sections, a hair apart.
        var ac = gaugeAngle(st.d, byUp);
        for (var i = 0; i < Climb.count(); i++) {
            var g = section(i, false);
            var s0 = gaugeAngle(Climb.dAt(i).toFloat(), byUp), s1 = gaugeAngle(Climb.dAt(i + 1).toFloat(), byUp) + 0.5;
            if (Climb.dAt(i + 1) <= st.d) {
                d.arc(G_R, s0, s1, d.grade(g, true), G_PEN);
            } else if (Climb.dAt(i) >= st.d) {
                d.arc(G_R, s0, s1, d.grade(g, false), G_PEN);
            } else {
                // Within the hair gap at the section's end, the climbed part stops at the gap.
                var a = ac < s1 ? s1 : ac;
                d.arc(G_R, s0, a, d.grade(g, true), G_PEN);
                d.arc(G_R, a, s1, d.grade(g, false), G_PEN);
            }
        }
        // The points.
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) { gaugePoint(d, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, st, byUp); }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { gaugePoint(d, Climb.dAt(Climb.EXIT_AT[e]).toFloat(), GREEN, st, byUp); }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { gaugePoint(d, Climb.DANGER_AT[e].toFloat(), RED, st, byUp); }
    }

    function gaugePoint(d as Draw, dist as Float, c as Number, st as Climb.State, byUp as Boolean) as Void {
        var p = d.onCircle(G_R, gaugeAngle(dist, byUp));
        d.dot(p[0], p[1], 8, BLACK);
        d.ring(p[0], p[1], 7, dist <= st.d ? d.darken(c, 0.33) : c, 3);
    }

    // The scalable bold font for big letters, per size in device pixels, loaded once each: the
    // system's number fonts have no letters. Null where the watch has none.
    var bigLetterFonts as Dictionary<Number, Graphics.VectorFont> = {};

    function bigLetterFont(px as Number) as Graphics.VectorFont? {
        var f = bigLetterFonts[px];
        if (f == null && (Graphics has :getVectorFont)) {
            f = Graphics.getVectorFont({:face => ["RobotoCondensedBold", "RobotoBold"], :size => px});
            if (f != null) { bigLetterFonts[px] = f; }
        }
        return f;
    }

    // The current difficulty in a large filled box centred on (x, y); a rest shows as W.
    function bigDifficulty(d as Draw, st as Climb.State, x as Float, y as Float, w as Float, h as Float) as Void {
        var g = section(st.cur, false);
        d.roundRect(x - w / 2, y - h / 2, w, h, 14, d.grade(g, false));
        // A scalable bold font where the watch has one, the largest text font otherwise; the letters
        // centred on their capitals, as textCapMiddle does.
        var vf = bigLetterFont(d.s(64));
        if (vf != null) {
            var asc = Graphics.getFontAscent(vf);
            d.dc.setColor(BLACK, Graphics.COLOR_TRANSPARENT);
            d.dc.drawText(d.s(x), d.s(y) - asc * (1 - d.CAP / 2), vf, BOX_NAME[g], Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            d.textCapCentre(x, y, Graphics.FONT_LARGE, BOX_NAME[g], BLACK);
        }
    }

    // What comes next: the next section of a different difficulty and the distance to its start along
    // the route, rounded to 5 m ("K4 in 125 m", the grade in its colour), or the top. Centred on x.
    function nextUp(d as Draw, st as Climb.State, x as Float, y as Float) as Void {
        var here = section(st.cur, false), i = st.cur + 1;
        while (i < Climb.count() && section(i, false) == here) { i++; }
        var dist = (i < Climb.count() ? Climb.dAt(i) : Climb.totalD()) - st.d;
        var m = (Math.round(dist / 5) * 5).toNumber();
        if (m < 0) { m = 0; }
        var what = i < Climb.count() ? BOX_NAME[section(i, false)] : "Top";
        var c = i < Climb.count() ? d.grade(section(i, false), false) : WHITE;
        var rest = " in " + m.format("%d") + " m";
        var font = Graphics.FONT_TINY;
        var w1 = d.width(font, what), w = w1 + d.width(font, rest);
        d.textCapMiddle(x - w / 2, y, font, what, c, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapMiddle(x - w / 2 + w1, y, font, rest, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The ascent widget laid flat: a line from the start (x0) to the top (x1) at y, the climber's ring
    // on it, the metres climbed under its left stretch and the metres left under its right one, each
    // centred on its stretch, kept clear of the ring, never past the line's end.
    function ascentFlat(d as Draw, st as Climb.State, x0 as Float, x1 as Float, y as Float, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat(), rx = x0 + st.u / tu * (x1 - x0), up = st.climbed();
        d.rect(x0, y - 1, x1 - x0, 2, SCALE);
        d.dot(rx, y, RING_R, BLACK);
        var gap = 26, ny = y + 24;
        var lx = (x0 + rx) / 2;
        if (lx > rx - gap) { lx = rx - gap; }
        if (lx < x0) { lx = x0; }
        var rxn = (rx + x1) / 2;
        if (rxn < rx + gap) { rxn = rx + gap; }
        if (rxn > x1) { rxn = x1; }
        d.textCapCentre(lx, ny, Graphics.FONT_XTINY, up.format("%d"), WHITE);
        d.textCapCentre(rxn, ny, Graphics.FONT_XTINY, (Climb.totalU() - up).format("%d"), WHITE);
        if (ends) {
            d.dot(x0, y, 6, GREEN);
            d.dot(x1, y, 6, RED);
        }
        d.ring(rx, y, RING_R, CLIMBER, 3);
    }

    // ---------------------------------------------------------------- ascent gauge

    // The ascent as a gauge: a thin arc around the screen's edge from the start (lower left) over the
    // top to the route's top (lower right), the climber's orange ring at the height climbed, the start
    // and top as green and red dots, and the metres climbed and left just past the arc's two ends, in
    // the gap at the bottom.
    const AG_R = 192;
    const AG_FROM = 232;
    const AG_SPAN = 284;

    function ascentGauge(d as Draw, st as Climb.State, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat(), up = st.climbed();
        d.dc.setColor(SCALE, Graphics.COLOR_TRANSPARENT);
        d.dc.setPenWidth(d.s(2));
        d.dc.drawArc(d.s(208), d.s(208), d.s(AG_R), Graphics.ARC_CLOCKWISE, AG_FROM, (AG_FROM - AG_SPAN + 360) % 360);
        var r = d.onCircle(AG_R, AG_FROM - st.u / tu * AG_SPAN);
        d.dot(r[0], r[1], RING_R, BLACK);
        if (ends) {
            var p0 = d.onCircle(AG_R, AG_FROM), p1 = d.onCircle(AG_R, AG_FROM - AG_SPAN);
            d.dot(p0[0], p0[1], 6, GREEN);
            d.dot(p1[0], p1[1], 6, RED);
        }
        d.ring(r[0], r[1], RING_R, CLIMBER, 3);
        var n0 = d.onCircle(AG_R, AG_FROM + 11), n1 = d.onCircle(AG_R, AG_FROM - AG_SPAN - 11);
        d.textCapCentre(n0[0], n0[1], Graphics.FONT_XTINY, up.format("%d"), WHITE);
        d.textCapCentre(n1[0], n1[1], Graphics.FONT_XTINY, (Climb.totalU() - up).format("%d"), WHITE);
    }
}
