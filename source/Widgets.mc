using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

import Toybox.Lang;

// The widgets of design/widgets.md, laid out in shares of the screen's width. Each takes the
// climber's state and where to draw; a page places them.
module Widgets {

    const CLIMBER = 0xff6f3c;
    const REST = 0x3a86ff;
    const GREEN = 0x3fd77f;
    // Red is the route's top (end dots, the stop symbol); danger is yellow, a warning (WARNING).
    const RED = 0xff4b4b;
    const SCALE = 0x777777;
    const WHITE = Graphics.COLOR_WHITE;
    const BLACK = Graphics.COLOR_BLACK;

    // The climber's ring on the ascent line, and the space kept between it and the numbers beside it.
    const RING_R = 0.021635;
    const RING_OUTER = 0.02524;
    const NUMBER_SPACE = 0.012019;
    // The metres climbed and left beside the ascent, flat or as a gauge: their size, as a share of the
    // screen's width (22 px at 416).
    const NUMBER_SIZE = 0.0529;

    // The difficulty widget's boxes: codes 0 to 5 are walk and K1 to K5, then rest, exit and danger.
    const CODE_EXIT = -2;
    const CODE_DANGER = -3;
    const NONE = -99;
    const BOX_NAME = ["W", "K1", "K2", "K3", "K4", "K5"] as Array<String>;
    const BOX_H = 0.091346;
    // The letters' size (bold) in a box at size 1, as a share of the screen's width (26 px at 416).
    const BOX_FS = 0.0625;
    const SATELLITE = 0.72;
    const BOX_GAP = 0.012019;

    // ---------------------------------------------------------------- profile

    // The route from the side, from x0 at the start to x0 + w at the top, in its real height, down as
    // well as up (net): from y0 at its lowest point to y0 - h at its highest. Without descents those are
    // the start and the top.
    function profile(d as Draw, st as Climb.State, x0 as Float, w as Float, y0 as Float, h as Float) as Void {
        var td = Climb.totalD().toFloat();
        // The climber: an orange outline around the stretch they could be on, a wide orange line
        // with a narrower black one inside it, under the sections.
        var around = st.stretch(), lo = around[0], hi = around[1];
        stretch(d, lo, hi, x0, w, y0, h, CLIMBER, 0.033654);
        stretch(d, lo, hi, x0, w, y0, h, BLACK, 0.026442);
        // The sections, round-ended, climbed parts dimmed; rests are left as gaps for their rings.
        var cx = x0 + st.d / td * w, cy = profileY(st.d, y0, h);
        for (var i = 0; i < Climb.count(); i++) {
            var g = Climb.GRADE[i];
            if (g < 0) { continue; }
            var ax = x0 + Climb.dAt(i) / td * w, ay = profileNetY(Climb.netAt(i).toFloat(), y0, h);
            var bx = x0 + Climb.dAt(i + 1) / td * w, by = profileNetY(Climb.netAt(i + 1).toFloat(), y0, h);
            if (Climb.dAt(i + 1) <= st.d) {
                d.brush(ax, ay, bx, by, 0.012019, d.grade(g, true));
            } else if (Climb.dAt(i) >= st.d) {
                d.brush(ax, ay, bx, by, 0.012019, d.grade(g, false));
            } else {
                d.brush(ax, ay, cx, cy, 0.012019, d.grade(g, true));
                d.brush(cx, cy, bx, by, 0.012019, d.grade(g, false));
            }
        }
        // The points, as hollow rings, dimmed once passed.
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var md = (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0;
                point(d, x0 + md / td * w, profileY(md, y0, h), REST, md <= st.d);
            }
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var dd = Climb.DANGER_AT[e].toFloat();
            point(d, x0 + dd / td * w, profileY(dd, y0, h), WARNING, dd <= st.d);
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var i = Climb.EXIT_AT[e];
            point(d, x0 + Climb.dAt(i) / td * w, profileNetY(Climb.netAt(i).toFloat(), y0, h), GREEN, Climb.dAt(i) <= st.d);
        }
        d.top(x0 + w, profileNetY(Climb.netAt(Climb.count()).toFloat(), y0, h));
    }

    // The profile's y at a distance along the route, in the box from y0 (the route's lowest point) up
    // to y0 - h (its highest).
    function profileY(dist as Float, y0 as Float, h as Float) as Float {
        return profileNetY(Climb.netAtDistance(dist), y0, h);
    }

    // The same for a net height.
    function profileNetY(net as Float, y0 as Float, h as Float) as Float {
        var lo = Climb.netLow(), span = Climb.netHigh() - lo;
        // A part that neither rises nor falls draws level along the bottom.
        return y0 - (span > 0 ? (net - lo) / span : 0.0) * h;
    }

    // The route between two distances, painted with a round brush of radius r.
    function stretch(d as Draw, lo as Float, hi as Float, x0 as Float, w as Float, y0 as Float, h as Float,
            c as Number, r as Float) as Void {
        var td = Climb.totalD().toFloat();
        var px = x0 + lo / td * w, py = profileY(lo, y0, h);
        var dd = lo;
        // Every 8 m: smooth at this scale, and half the circles of every 4 m.
        while (dd < hi) {
            dd += 8;
            if (dd > hi) { dd = hi; }
            var nx = x0 + dd / td * w, ny = profileY(dd, y0, h);
            d.brush(px, py, nx, ny, r, c);
            px = nx; py = ny;
        }
    }

    // A point on the route: a ring, black inside so the route breaks there.
    function point(d as Draw, x as Float, y as Float, c as Number, passed as Boolean) as Void {
        d.dot(x, y, 0.021635, BLACK);
        d.ring(x, y, 0.019231, passed ? d.darken(c, 0.33) : c, 0.007212);
    }

    // ---------------------------------------------------------------- ascent

    // The route's height as a line at x, from y0 (the start) up to y0 - h, with the climber on it.
    function ascent(d as Draw, st as Climb.State, x as Float, y0 as Float, h as Float, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat();
        var top = y0 - h, ty = y0 - st.u / tu * h, up = st.climbed();
        // Back to front: the line, the ring's black inside, the end dots, the ring's outline.
        d.line(x, y0, x, top, SCALE, 0.004808);
        d.dot(x, ty, RING_R, BLACK);
        // Each number centred on its stretch, kept clear of the ring, never past the line's end.
        var gap = 0.048077;
        var yb = (ty + y0) / 2;
        if (yb < ty + gap) { yb = ty + gap; }
        if (yb > y0) { yb = y0; }
        var ya = (top + ty) / 2;
        if (ya > ty - gap) { ya = ty - gap; }
        if (ya < top) { ya = top; }
        var nx = x - RING_OUTER - NUMBER_SPACE;
        d.textRight(nx, yb, d.semi(NUMBER_SIZE), up.format("%d"), WHITE);
        d.textRight(nx, ya, d.semi(NUMBER_SIZE), (Climb.totalU() - up).format("%d"), WHITE);
        if (ends) {
            d.dot(x, y0, 0.014423, GREEN);
            d.dot(x, top, 0.014423, RED);
        }
        d.ring(x, ty, RING_R, CLIMBER, 0.007212);
    }

    // Drops what is measured or laid out from the loaded part's sections, for Climb.use when the part
    // changes (Codex on #88).
    function forgetRoute() as Void {
        ascentWidest = null;
        widest = [null, null];
        gaugeStarts = [null, null];
        front = null;
        frontScreen = null;
    }

    // The widest number the ascent widget can show, measured once per part.
    var ascentWidest as Float? = null;

    function ascentNumbersWidth(d as Draw) as Float {
        var w = ascentWidest;
        if (w == null) {
            // The digits are tabular, so every number with as many digits is as wide: the total stands for
            // them all. Measuring each number instead stopped the app on the watchdog (#94).
            w = d.width(d.semi(NUMBER_SIZE), Climb.totalU().format("%d"));
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
        return (code >= 1 ? 0.139423 : 0.110577) * k;
    }

    // One box, centred on x with its bottom at yb, at size k.
    function badge(d as Draw, x as Float, yb as Float, k as Float, code as Number) as Void {
        var text = "R", colour = REST, filled = false;
        if (code >= 0) {
            text = BOX_NAME[code]; colour = d.grade(code, false); filled = true;
        } else if (code == CODE_EXIT) {
            text = "E"; colour = GREEN;
        } else if (code == CODE_DANGER) {
            text = "D"; colour = WARNING;
        }
        // Whole pixels from the bottom up, so every box's bottom lands on the same row.
        var w = d.whole(boxWidth(code, k)), h = d.whole(BOX_H * k), top = yb - h;
        d.roundRect(x - w / 2, top, w, h, 0.019231 * k, colour);
        if (!filled) {
            // The outline is the box in its colour with a black box 0.0072 of the width inside it.
            d.roundRect(x - w / 2 + 0.007212, top + 0.007212, w - 0.014423, h - 0.014423, 0.014423 * k, BLACK);
        }
        d.textCapCentre(x, top + h / 2, d.bold(BOX_FS * k), text, filled ? BLACK : colour);
    }

    // The section the climber is estimated in, in a larger box centred on x; the nearest thing behind
    // and ahead within the uncertainty stretch in smaller boxes beside it. All share the bottom yb.
    // Without points, only sections count, and a rest shows as walking ground (W).
    function difficulty(d as Draw, st as Climb.State, x as Float, yb as Float, points as Boolean) as Void {
        var around = st.stretch(), lo = around[0], hi = around[1];
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

    // The altitude's size and its unit's, and the poi word's (bold), as shares of the screen's width
    // (46, 24 and 24 px at 416; the unit was 25 in the mocks, which take the table's 24).
    const ALT_SIZE = 0.1106;
    const ALT_UNIT = 0.0577;
    const POI_SIZE = 0.0577;

    function poiFont(d as Draw) as Graphics.FontType { return d.bold(POI_SIZE); }

    // The widest altitude the route can show in a font, per unit, measured once per font: slot 0 for
    // the altitude widget's, 1 for the column group's.
    var widest as Array<Float?> = [null, null];
    var widestFeet as Array<Boolean> = [false, false];

    function feet() as Boolean {
        return System.getDeviceSettings().elevationUnits == System.UNIT_STATUTE;
    }

    // The altitude at net height u above the part's start (Climb.netAt, State.net: the real height, not
    // the height gained), rounded to 10 m or 50 ft: the position is known only to within 25 m.
    function altitudeValue(u as Float, ft as Boolean) as Number {
        var m = Climb.START_ALT + u;
        if (ft) { return (Math.round(m * 3.28084 / 50) * 50).toNumber(); }
        return (Math.round(m / 10) * 10).toNumber();
    }

    // The altitudes the pages show: the climber's, and border b's (between sections b - 1 and b).
    function altitudeNow(st as Climb.State, ft as Boolean) as Number { return altitudeValue(st.net(), ft); }
    function borderAltitude(b as Number, ft as Boolean) as Number { return altitudeValue(Climb.netAt(b).toFloat(), ft); }

    // Section i's altitudes at its foot and its top, to the metre or foot (page 9).
    function sectionAltitudes(i as Number, ft as Boolean) as [Number, Number] {
        var k = ft ? 3.28084 : 1.0;
        return [Math.round((Climb.START_ALT + Climb.netAt(i)) * k).toNumber(),
            Math.round((Climb.START_ALT + Climb.netAt(i + 1)) * k).toNumber()];
    }

    function widestAltitude(d as Draw, ft as Boolean, font as Graphics.FontType, slot as Number) as Float {
        var w = widest[slot];
        if (w == null || widestFeet[slot] != ft) {
            // Tabular digits: the widest altitude is one of the two ends, the one with more digits or with a
            // minus sign; both are measured rather than reasoned about.
            var low = d.width(font, altitudeValue(Climb.netLow().toFloat(), ft).format("%d"));
            var high = d.width(font, altitudeValue(Climb.netHigh().toFloat(), ft).format("%d"));
            w = low > high ? low : high;
            widest[slot] = w;
            widestFeet[slot] = ft;
        }
        return w;
    }

    function altitudeBox(d as Draw, ft as Boolean) as Float {
        return widestAltitude(d, ft, d.semi(ALT_SIZE), 0);
    }

    // The approximate altitude, right-aligned in a box as wide as the route's widest, starting at x,
    // its top at yt; the unit follows the box.
    function altitude(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var ft = feet();
        var right = x + altitudeBox(d, ft), font = d.semi(ALT_SIZE), unit = d.semi(ALT_UNIT);
        d.textCapTop(right, yt, font, altitudeNow(st, ft).format("%d"), WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
        // The unit on the number's baseline.
        var baseline = yt + d.capHeight(font);
        d.textTop(right + 0.009615, baseline - d.ascent(unit), unit, ft ? "ft" : "m", d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // One word for the point of interest the uncertainty stretch covers, right-aligned at x, its top
    // at yt. The nearest wins; on a tie, danger before exit before rest.
    function poi(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var around = st.stretch(), lo = around[0], hi = around[1];
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
            if (p >= lo && p <= hi && dist <= best) { best = dist; rank = 0; word = "DANGER"; colour = WARNING; }
        }
        if (word.length() > 0) {
            d.textCapTop(x, yt, poiFont(d), word, colour, Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // The altitude centred on x, its digits' top at yt.
    function altitudeCentred(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var ft = feet();
        var w = altitudeBox(d, ft) + 0.009615 + d.width(d.semi(ALT_UNIT), ft ? "ft" : "m");
        altitude(d, st, x - d.half(w), yt);
    }

    // The altitude group: the altitude, with the poi word under it, right-aligned with the number.
    function altitudeGroup(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        altitude(d, st, x, yt);
        poi(d, st, x + altitudeBox(d, feet()), yt + d.capHeight(d.semi(ALT_SIZE)) + 0.028846);
    }

    // ---------------------------------------------------------------- difficulty column

    // Equal boxes, the current one larger by COL_BIG; those before the climber at COL_DIM of their colour.
    const COL_W = 0.153846;
    const COL_H = 0.096154;
    const COL_GAP = 0.019231;
    const COL_BIG = 1.08;
    const COL_DIM = 0.55;
    const COL_SPACE = 0.024038;
    // The letters' size (bold), and the altitudes' and their unit's, as shares of the screen's width
    // (26, 30 and 18 px at 416).
    const COL_FS = 0.0625;
    const COL_ALT = 0.0721;
    const COL_UNIT = 0.0433;

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
            var w = d.whole(COL_W * f), h = d.whole(COL_H * f);
            var y = slotY(k, cy), top = d.whole(y - h / 2);
            var colour = d.grade(g, false);
            if (k < 0) { colour = d.darken(colour, COL_DIM); }
            d.roundRect(cx - w / 2, top, w, h, 0.019231 * f, colour);
            if (!big) { d.roundRect(cx - w / 2 + 0.007212, top + 0.007212, w - 0.014423, h - 0.014423, 0.014423 * f, BLACK); }
            d.textCapCentre(cx, top + h / 2, d.bold(COL_FS * f), BOX_NAME[g], big ? BLACK : colour);
        }
    }

    // The widest altitude the route can show in the column's font.
    function columnAltitudeBox(d as Draw, ft as Boolean) as Float {
        return widestAltitude(d, ft, d.semi(COL_ALT), 1);
    }

    // The difficulty column group's width: the larger box, the space, the altitudes and the unit shown.
    function columnGroupWidth(d as Draw) as Float {
        var ft = feet();
        return COL_W * COL_BIG + COL_SPACE + columnAltitudeBox(d, ft) + 0.007212 + d.width(d.semi(COL_UNIT), ft ? "ft" : "m");
    }

    // How far the column reaches above and below its centre.
    function columnReach() as Float {
        return COL_H * COL_BIG / 2 + 2 * (COL_GAP + COL_H);
    }

    // The difficulty column group, centred on the screen as one group, at height cy.
    function columnGroup(d as Draw, st as Climb.State, cy as Float, outer as Boolean) as Void {
        columnGroupAt(d, st, 0.5 - columnGroupWidth(d) / 2, cy, outer);
    }

    // The difficulty column group: the column, with the altitudes where the difficulty changes to its
    // right, each level with a border between two boxes (and at the column's outer edges if outer),
    // right-aligned in a box as wide as the route's widest, its unit after it. Its left edge at left,
    // centred vertically on cy.
    function columnGroupAt(d as Draw, st as Climb.State, left as Float, cy as Float, outer as Boolean) as Void {
        var ft = feet(), unit = ft ? "ft" : "m", font = d.semi(COL_ALT), small = d.semi(COL_UNIT);
        var bw = COL_W * COL_BIG, altW = columnAltitudeBox(d, ft);
        var cx = left + bw / 2;
        var ax = cx + bw / 2 + COL_SPACE + altW;
        column(d, st, cx, cy);
        // Border b lies between sections b - 1 and b, at its real altitude.
        for (var b = st.cur - 2; b <= st.cur + 3; b++) {
            var above = inColumn(b, st.cur), below = inColumn(b - 1, st.cur);
            if (!(above && below) && !(outer && (above || below))) { continue; }
            var y = above
                ? slotY(b - st.cur, cy) + slotHalf(b - st.cur) + COL_GAP / 2.0
                : slotY(b - 1 - st.cur, cy) - slotHalf(b - 1 - st.cur) - COL_GAP / 2.0;
            var v = borderAltitude(b, ft);
            d.textCapMiddle(ax, y, font, v.format("%d"), WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
            // The unit on the number's baseline.
            var baseline = y + d.capHeight(font) / 2;
            d.textTop(ax + 0.007212, baseline - d.ascent(small), small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ---------------------------------------------------------------- difficulty stack

    // The sections as boxes to scale, in a window from top to bottom that moves with the climber, who
    // stays a quarter of the way up from its bottom: by ascent (byUp) each box as tall as the metres
    // its section climbs, by path as tall as its length along the route.
    const STACK_W = 0.144231;
    const STACK_NAMES = 0.192308;

    // The points' names, by rank.
    const POI_WORDS = ["Danger", "Exit", "Rest", "Top"] as Array<String>;

    // The section names' distance from the column, clear of the points' rings on its right edge.
    const NAME_GAP = 0.043269;

    // The tick labels' width, as wide as the larger label of the next altitude can be.
    function stackLabels(d as Draw) as Float {
        var top = altitudeValue(Climb.netHigh().toFloat(), feet()) + 50;
        return d.width(d.semi(TICK_SIZE * BIG_SCALE[0]), top.format("%d")) + 0.033654;
    }

    // The points of interest on the stack: rings on the column's right edge (x) at their place on it,
    // rests blue (the middle of the rest), exits green, dangers yellow, the top red, dimmed once
    // passed. A point is in the climber's range from one tick step (stepM metres along the stack's
    // axis) before it to half a step after it. Points whose rings would touch show one ring: of those
    // in range, the first of danger, exit, rest, top, with its name ("Danger", "Exit", "Rest", "Top")
    // beside it in its colour; with none in range, the one nearest the climber, unnamed. Returns the
    // y of each name shown.
    function stackPoints(d as Draw, st as Climb.State, byUp as Boolean, top as Float, bottom as Float, cy as Float,
            here as Float, scale as Float, x as Float, nameR as Float, stepM as Float) as Array<Float> {
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
            at.add(de); lo.add(de); hi.add(de); colour.add(WARNING); rank.add(0);
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
            if (ys[p] < top + 0.014423 || ys[p] > bottom - 0.014423) { continue; }
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
            while (end < order.size() && ys[order[end]] - ys[order[end - 1]] < 0.043269) { end++; }
            for (var m = g; m < end; m++) {
                var p = order[m];
                var better = near[p] && !near[best] ||
                    near[p] == near[best] && (near[p] ? rank[p] < rank[best] || rank[p] == rank[best] && away[p] < away[best] : away[p] < away[best]);
                if (better) { best = p; }
            }
            var c = colour[best], y = ys[best];
            d.dot(x, y, 0.019231, BLACK);
            d.ring(x, y, 0.016827, at[best] <= st.d ? d.darken(c, 0.33) : c, 0.007212);
            if (near[best]) {
                var half = nameR * nameR - (y - 0.5) * (y - 0.5);
                var room = (0.5 + Math.sqrt(half > 0 ? half : 0) - (x + 0.033654)).toFloat();
                // Not within 0.0481 of the width of a name already shown, as in the mock. A strict limit is
                // rounded down, so a distance of exactly that is clear, as it was in whole pixels.
                var clear = true;
                for (var q = 0; q < named.size(); q++) { if ((named[q] - y).abs() < 0.048076) { clear = false; } }
                if (room >= 0.072115 && clear) {
                    d.textCapMiddle(x + 0.033654, y, d.semi(NAME_SIZE), fitName(d, POI_WORDS[rank[best]], room), c, Graphics.TEXT_JUSTIFY_LEFT);
                    named.add(y);
                }
            }
            g = end;
        }
        return named;
    }

    // Where boundary i sits along the stack's axis, and section i's size on it: by ascent the height
    // it gains, so a section that loses height is flat there.
    function stackAt(i as Number, byUp as Boolean) as Float {
        return (byUp ? Climb.uAt(i) : Climb.dAt(i)).toFloat();
    }

    function stackSize(i as Number, byUp as Boolean) as Number {
        return byUp ? Climb.gain(i) : Climb.LEN[i];
    }

    // The altitude ticks in the stack's window from vLo to vHi along its axis (height gained byUp, else
    // distance), every step in the unit k turns metres into, as [altitudes, places on the axis], from
    // the bottom up. A tick sits where the route rises through its altitude: by path where it first
    // reaches it on a climb, and none on a descent, which is flat by ascent; a climb after a descent
    // marks again the altitudes it passes a second time. The start's altitude is marked at the start.
    function stackTicks(byUp as Boolean, vLo as Float, vHi as Float, step as Number, k as Float) as [Array<Number>, Array<Float>] {
        var alts = [] as Array<Number>, at = [] as Array<Float>;
        var a0 = Climb.START_ALT * k;
        if (vLo <= 0 && Math.ceil(a0 / step) * step <= a0) { alts.add(a0.toNumber()); at.add(0.0); }
        for (var i = 0; i < Climb.count(); i++) {
            var up = Climb.UP[i];
            if (up <= 0) { continue; }
            var p0 = stackAt(i, byUp), p1 = stackAt(i + 1, byUp);
            if (p1 < vLo || p0 > vHi) { continue; }
            var n0 = Climb.netAt(i);
            // The altitudes above the section's foot, up to its top.
            var top = (Climb.START_ALT + n0 + up) * k;
            for (var a = ((Math.floor((Climb.START_ALT + n0) * k / step) + 1) * step).toNumber(); a <= top; a += step) {
                var p = p0 + (a / k - Climb.START_ALT - n0) / up * (p1 - p0);
                if (p >= vLo && p <= vHi) { alts.add(a); at.add(p); }
            }
        }
        return [alts, at];
    }

    function stackColour(d as Draw, st as Climb.State, i as Number) as Number {
        var c = d.grade(section(i, false), false);
        return i < st.cur ? d.darken(c, COL_DIM) : c;
    }

    // A name cut to fit a width, ending in an ellipsis when cut.
    function fitName(d as Draw, name as String, w as Float) as String {
        return fitIn(d, d.semi(NAME_SIZE), name, w);
    }

    // The same in a given font. Compared in whole pixels, as text is measured: a name exactly as wide as
    // the room fits.
    function fitIn(d as Draw, font as Graphics.FontType, name as String, w as Float) as String {
        var room = d.s(w);
        if (d.dc.getTextWidthInPixels(name, font) <= room) { return name; }
        var n = name.length();
        while (n > 1 && d.dc.getTextWidthInPixels(name.substring(0, n) + "…", font) > room) { n--; }
        return name.substring(0, n) + "…";
    }

    // The tick labels' size, as a share of the screen's width (18 px at 416); the next altitude to
    // reach at twice it (36), the ones just above and below it at one and a half (27, drawn at the
    // table's nearest, 28). The names' size beside the stack (20 px at 416).
    const TICK_SIZE = 0.0433;
    const BIG_SCALE = [2.0, 1.5];
    const NAME_SIZE = 0.0481;

    // Tick label t's font, next being the next altitude's tick (or -1).
    function tickFont(d as Draw, t as Number, next as Number) as Graphics.FontType {
        var off = next < 0 ? 2 : (t - next).abs();
        return d.semi(off == 0 ? TICK_SIZE * BIG_SCALE[0] : off == 1 ? TICK_SIZE * BIG_SCALE[1] : TICK_SIZE);
    }

    // Ticks every stepM metres, or stepFt feet when the watch shows feet. Names stop at radius nameR
    // from the centre: the screen's edge, or inside a gauge around it.
    function stack(d as Draw, st as Climb.State, byUp as Boolean, left as Float, top as Float, bottom as Float,
            scale as Float, names as Boolean, stepM as Number, stepFt as Number, nameR as Float) as Void {
        var cy = bottom - (bottom - top) / 4, here = byUp ? st.u : st.d;
        var right = left + STACK_W, cx = left + STACK_W / 2;
        var n = Climb.count();
        d.clip(left - 0.004808, top, STACK_W + 0.009615, bottom - top);
        // The boxes: the current one filled, the others black with their sides in their colour.
        for (var i = 0; i < n; i++) {
            var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
            if (yt > bottom + 0.004808 || yb < top - 0.004808 || stackSize(i, byUp) == 0) { continue; }
            var c = stackColour(d, st, i), now = i == st.cur;
            if (now) {
                d.rect(left, yt, STACK_W, yb - yt, c);
            } else {
                d.rect(left, yt, STACK_W, yb - yt, BLACK);
                d.rect(left, yt, 0.007212, yb - yt, c);
                d.rect(right - 0.007212, yt, 0.007212, yb - yt, c);
            }
            // Letters centred on the part in view, left out when it is too short for them.
            var vt = yt > top ? yt : top, vb = yb < bottom ? yb : bottom;
            var font = d.bold(COL_FS * (now ? COL_BIG : 1));
            if (vb - vt >= d.capHeight(font) + 0.024038) {
                d.textCapCentre(cx, (vt + vb) / 2, font, BOX_NAME[section(i, false)], now ? BLACK : c);
            }
        }
        // The borders: between two boxes in the colour of the one closer to the current section; a
        // flat section is a line in its own colour; the start and the top close the column.
        for (var i = 0; i < n; i++) {
            var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
            if (yt > bottom + 0.004808 || yb < top - 0.004808) { continue; }
            if (stackSize(i, byUp) == 0) {
                d.rect(left, yb - 0.003606, STACK_W, 0.007212, stackColour(d, st, i));
                continue;
            }
            if (i == 0) {
                d.rect(left, yb - 0.007212, STACK_W, 0.007212, stackColour(d, st, i));
            } else if (stackSize(i - 1, byUp) > 0) {
                var closer = (i - st.cur).abs() <= (i - 1 - st.cur).abs() ? i : i - 1;
                d.rect(left, yb - 0.003606, STACK_W, 0.007212, stackColour(d, st, closer));
            }
            if (i == n - 1) { d.rect(left, yt, STACK_W, 0.007212, stackColour(d, st, i)); }
        }
        d.unclip();
        var ft = feet(), step = ft ? stepFt : stepM;
        // The points of interest, one ring for each group whose rings would touch; the y of each one
        // that shows its name, for the section names to give way to.
        var named = stackPoints(d, st, byUp, top, bottom, cy, here, scale, right, nameR, ft ? stepFt / 3.28084 : stepM.toFloat());
        // The names on the right, centred on the part in view, cut to fit the round screen, each 0.0481 of
        // the width clear of the points' names and of the section names already shown.
        if (names) {
            for (var i = 0; i < n; i++) {
                var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
                if (yt > bottom || yb < top) { continue; }
                var vt = yt > top ? yt : top, vb = yb < bottom ? yb : bottom;
                var flat = stackSize(i, byUp) == 0;
                if (!flat && vb - vt < 0.038461) { continue; }
                var ny = flat ? yb : (vt + vb) / 2;
                var touches = false;
                for (var p = 0; p < named.size(); p++) { if ((named[p] - ny).abs() < 0.048076) { touches = true; } }
                if (touches) { continue; }
                named.add(ny);
                var half = nameR * nameR - (ny - 0.5) * (ny - 0.5);
                var room = (0.5 + Math.sqrt(half > 0 ? half : 0) - (right + NAME_GAP)).toFloat();
                if (room < 0.072115) { continue; }
                d.textCapMiddle(right + NAME_GAP, ny, d.semi(NAME_SIZE), fitName(d, Climb.NAME[i], room),
                    i < st.cur ? 0x7d8a8a : WHITE, Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
        // Altitude ticks on the left, every step, only along the route, where it rises (stackTicks); a
        // label touching the one below is left out.
        var vLo = here - (bottom - cy) / scale, vHi = here + (cy - top) / scale;
        if (vLo < 0) { vLo = 0.0; }
        var vMax = (byUp ? Climb.totalU() : Climb.totalD()).toFloat();
        if (vHi > vMax) { vHi = vMax; }
        var marks = stackTicks(byUp, vLo, vHi, step, ft ? 3.28084 : 1.0);
        var ticks = [] as Array<Number>, ys = [] as Array<Float>, places = [] as Array<Float>;
        for (var t = 0; t < marks[0].size(); t++) {
            var y = cy - (marks[1][t] - here) * scale;
            if (y < top || y > bottom) { continue; }
            d.rect(left - 0.021635, y - 0.002404, 0.014423, 0.004808, SCALE);
            ticks.add(marks[0][t]);
            ys.add(y);
            places.add(marks[1][t]);
        }
        // The label of the next altitude to reach is twice as large and always shown, the ones just
        // above and below it one and a half times; the others are left out around it, each kept clear
        // of the last one shown. It is the first tick above the climber on the stack: by path it may
        // sit further along the route than the climber, and after a descent its altitude may be below
        // the one now.
        var next = -1;
        for (var t = 0; t < ticks.size() && next < 0; t++) { if (places[t] > here) { next = t; } }
        var from = next >= 0 ? next : 0;
        for (var dir = 1; dir >= -1; dir -= 2) {
            var last = dir < 0 && next >= 0 ? next : -1;
            for (var t = dir > 0 ? from : from - 1; t >= 0 && t < ticks.size(); t += dir) {
                var font = tickFont(d, t, next);
                if (last >= 0) {
                    var lastFont = tickFont(d, last, next);
                    var gap = (ys[last] - ys[t]).abs();
                    if (gap < (d.capHeight(font) + d.capHeight(lastFont)) / 2 + 0.014423) { continue; }
                }
                d.textCapMiddle(left - 0.033654, ys[t], font, ticks[t].format("%d"), d.MUTED, Graphics.TEXT_JUSTIFY_RIGHT);
                last = t;
            }
        }
        // The climber: the orange ring on the column's left edge, with no line across the column, which
        // hid the letters.
        d.dot(left, cy, RING_R, BLACK);
        d.ring(left, cy, RING_R, CLIMBER, 0.007212);
    }

    // ---------------------------------------------------------------- gauge, page 6

    // The route around the screen's edge, from its start at the lower left over the top to its top at
    // the lower right, each section's arc its length along the route, or the metres it climbs (byUp);
    // climbed parts dimmed; rests, exits and dangers as rings, dimmed once passed; the climber as a
    // thicker orange line on the gauge's inner side over the stretch they could be on, rounded at its
    // ends, clear of the sections.
    const G_R = 0.461538;
    const G_FROM = 232;
    const G_SPAN = 284;
    const G_PEN = 0.028846;
    // The climber's line: its width, and its radius 0.0072 of the width inside the sections.
    const G_INNER = 0.014423;
    const G_INNER_R = G_R - G_PEN / 2 - 0.007212 - G_INNER / 2;

    // Each section gets at least G_MIN degrees of the sweep, the others sharing the rest in proportion
    // to their length (or, byUp, the metres they climb), so no section is too short to draw or see.
    // Within a section, angles follow the distance along it. Worked out once per kind.
    const G_MIN = 3.0;
    var gaugeStarts as Array<Array<Float>?> = [null, null];

    function gaugeLayout(byUp as Boolean) as Array<Float> {
        var kind = byUp ? 1 : 0, cached = gaugeStarts[kind];
        if (cached != null) { return cached; }
        var n = Climb.count(), fixed = new [n] as Array<Boolean>, span = new [n] as Array<Float>;
        for (var i = 0; i < n; i++) { fixed[i] = false; }
        var changed = true;
        while (changed) {
            changed = false;
            var count = 0, total = 0.0;
            for (var i = 0; i < n; i++) {
                if (fixed[i]) { count++; } else { total += byUp ? Climb.gain(i) : Climb.LEN[i]; }
            }
            var free = G_SPAN - count * G_MIN;
            for (var i = 0; i < n; i++) {
                // An entirely flat route by ascent: what is left is shared evenly. By ascent a section that
                // loses height gains none, so it takes the least, as a flat one.
                var share = total > 0 ? (byUp ? Climb.gain(i) : Climb.LEN[i]) / total : 1.0 / (n - count);
                span[i] = fixed[i] ? G_MIN : share * free;
                if (!fixed[i] && span[i] < G_MIN) { fixed[i] = true; changed = true; }
            }
        }
        // The angle at each boundary, from the start at G_FROM.
        var starts = new [n + 1] as Array<Float>;
        starts[0] = G_FROM.toFloat();
        for (var i = 0; i < n; i++) { starts[i + 1] = starts[i] - span[i]; }
        gaugeStarts[kind] = starts;
        return starts;
    }

    function gaugeAngle(dist as Float, byUp as Boolean) as Float {
        var starts = gaugeLayout(byUp), n = Climb.count(), i = 0;
        while (i < n - 1 && dist > Climb.dAt(i + 1)) { i++; }
        var f = Climb.LEN[i] > 0 ? (dist - Climb.dAt(i)) / Climb.LEN[i] : 0.0;
        return starts[i] - f * (starts[i] - starts[i + 1]);
    }

    // Section i's arc on whole degrees, its two ends [from, to] with to < from: each boundary rounded
    // once, and the arc stopping 1° short of the next section's start, so every gap is one degree.
    function sectionArc(i as Number, byUp as Boolean) as Array<Number> {
        var s0 = Math.round(gaugeAngle(Climb.dAt(i).toFloat(), byUp)).toNumber();
        var s1 = Math.round(gaugeAngle(Climb.dAt(i + 1).toFloat(), byUp)).toNumber() + 1;
        return [s0, s1] as Array<Number>;
    }

    function gauge(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var around = st.stretch(), lo = around[0], hi = around[1];
        // On whole degrees, as the watch draws arcs, so the round ends sit on the line's ends.
        var a0 = Math.round(gaugeAngle(lo, byUp)), a1 = Math.round(gaugeAngle(hi, byUp));
        // The climber: an orange line inside the gauge, with round ends.
        var p0 = d.onCircle(G_INNER_R, a0), p1 = d.onCircle(G_INNER_R, a1);
        d.arc(G_INNER_R, a0, a1, CLIMBER, G_INNER);
        d.dot(p0[0], p0[1], G_INNER / 2, CLIMBER);
        d.dot(p1[0], p1[1], G_INNER / 2, CLIMBER);
        // The sections, a hair apart.
        var ac = Math.round(gaugeAngle(st.d, byUp)).toNumber();
        for (var i = 0; i < Climb.count(); i++) {
            var g = section(i, false), arc = sectionArc(i, byUp), s0 = arc[0], s1 = arc[1];
            if (Climb.dAt(i + 1) <= st.d) {
                d.arc(G_R, s0, s1, d.grade(g, true), G_PEN);
            } else if (Climb.dAt(i) >= st.d) {
                d.arc(G_R, s0, s1, d.grade(g, false), G_PEN);
            } else {
                // The climber's section, climbed part dimmed. A part under a degree is not drawn on
                // its own: the whole section takes the other part's colour instead of leaving a sliver.
                var a = ac < s1 ? s1 : (ac > s0 ? s0 : ac);
                if (s0 - a < 1) {
                    d.arc(G_R, s0, s1, d.grade(g, false), G_PEN);
                } else if (a - s1 < 1) {
                    d.arc(G_R, s0, s1, d.grade(g, true), G_PEN);
                } else {
                    d.arc(G_R, s0, a, d.grade(g, true), G_PEN);
                    d.arc(G_R, a, s1, d.grade(g, false), G_PEN);
                }
            }
        }
        // The points.
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) { gaugePoint(d, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, st, byUp); }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { gaugePoint(d, Climb.dAt(Climb.EXIT_AT[e]).toFloat(), GREEN, st, byUp); }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { gaugePoint(d, Climb.DANGER_AT[e].toFloat(), WARNING, st, byUp); }
    }

    function gaugePoint(d as Draw, dist as Float, c as Number, st as Climb.State, byUp as Boolean) as Void {
        var p = d.onCircle(G_R, gaugeAngle(dist, byUp));
        d.dot(p[0], p[1], 0.019231, BLACK);
        d.ring(p[0], p[1], 0.016827, dist <= st.d ? d.darken(c, 0.33) : c, 0.007212);
    }

    // The current difficulty in a large filled box centred on (x, y), its letters bold at size (a share
    // of the screen's width); a rest shows as W.
    function bigDifficulty(d as Draw, st as Climb.State, x as Float, y as Float, w as Float, h as Float, size as Float) as Void {
        bigDifficultyOf(d, section(st.cur, false), x, y, w, h, size);
    }

    // The same box for difficulty g, the letters centred on their capitals.
    function bigDifficultyOf(d as Draw, g as Number, x as Float, y as Float, w as Float, h as Float, size as Float) as Void {
        d.roundRect(x - w / 2, y - h / 2, w, h, h / 6.5, d.grade(g, false));
        d.textCapCentre(x, y, d.bold(size), BOX_NAME[g], BLACK);
    }

    // ---------------------------------------------------------------- selection gauge (page 9)

    // The points' rings inside the gauge, 0.0096 of the width clear of the sections.
    const SEL_POI_R = G_R - G_PEN / 2 - 0.009615 - 0.020433;

    // Whether the point at distance dist is in section i or at its foot or top.
    function holds(i as Number, dist as Float) as Boolean {
        return dist >= Climb.dAt(i) && dist <= Climb.dAt(i + 1);
    }

    // The gauge by ascent showing section sel, not the climber: sel at full colour, the others dimmed,
    // no climber line; the points as rings inside the gauge, lit where sel shows their symbol
    // (sectionPoints), dimmed elsewhere.
    function selectionGauge(d as Draw, sel as Number) as Void {
        for (var i = 0; i < Climb.count(); i++) {
            var arc = sectionArc(i, true);
            d.arc(G_R, arc[0], arc[1], d.grade(section(i, false), i != sel), G_PEN);
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                selectionPoint(d, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, (i - sel).abs() <= 1);
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var de = Climb.dAt(Climb.EXIT_AT[e]).toFloat();
            selectionPoint(d, de, GREEN, holds(sel, de));
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var de = Climb.DANGER_AT[e].toFloat();
            selectionPoint(d, de, WARNING, holds(sel, de));
        }
    }

    function selectionPoint(d as Draw, dist as Float, c as Number, lit as Boolean) as Void {
        var p = d.onCircle(SEL_POI_R, gaugeAngle(dist, true));
        d.dot(p[0], p[1], 0.019231, BLACK);
        d.ring(p[0], p[1], 0.016827, lit ? c : d.darken(c, 0.33), 0.007212);
    }

    // The points section i includes or is next to, as poiSymbol kinds, danger first, then exit, rest,
    // top: a point in it or at its foot or top; a rest that is the section itself or right before or
    // after it; the route's top for the last section.
    function sectionPoints(i as Number) as Array<Number> {
        var kinds = [] as Array<Number>, n = Climb.count();
        var danger = false, exit = false;
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { if (holds(i, Climb.DANGER_AT[e].toFloat())) { danger = true; } }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { if (holds(i, Climb.dAt(Climb.EXIT_AT[e]).toFloat())) { exit = true; } }
        if (danger) { kinds.add(0); }
        if (exit) { kinds.add(1); }
        if (Climb.GRADE[i] < 0 || i > 0 && Climb.GRADE[i - 1] < 0 || i < n - 1 && Climb.GRADE[i + 1] < 0) { kinds.add(2); }
        if (i == n - 1) { kinds.add(POI_TOP); }
        return kinds;
    }

    // A chevron centred on (x, y) pointing left (dir -1) or right (1), round-ended; dimmed when there
    // is nothing that way.
    function chevron(d as Draw, x as Float, y as Float, dir as Number, on as Boolean) as Void {
        var c = on ? WHITE : 0x444444, tip = x + dir * 0.016827, back = x - dir * 0.016827;
        d.brush(back, y - 0.03125, tip, y, 0.00601, c);
        d.brush(tip, y, back, y + 0.03125, 0.00601, c);
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
        var font = d.bold(0.0673);  // 28 px at 416
        var w1 = d.width(font, what), w = w1 + d.width(font, rest);
        d.textCapMiddle(x - d.half(w), y, font, what, c, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapMiddle(x - d.half(w) + w1, y, font, rest, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The ascent widget laid flat: a line from the start (x0) to the top (x1) at y, the climber's ring
    // on it, the metres climbed under its left stretch and the metres left under its right one, each
    // centred on its stretch, kept clear of the ring, never past the line's end.
    function ascentFlat(d as Draw, st as Climb.State, x0 as Float, x1 as Float, y as Float, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat(), rx = x0 + st.u / tu * (x1 - x0), up = st.climbed();
        d.rect(x0, y - 0.002404, x1 - x0, 0.004808, SCALE);
        d.dot(rx, y, RING_R, BLACK);
        var gap = 0.0625, ny = y + 0.057692;
        var lx = (x0 + rx) / 2;
        if (lx > rx - gap) { lx = rx - gap; }
        if (lx < x0) { lx = x0; }
        var rxn = (rx + x1) / 2;
        if (rxn < rx + gap) { rxn = rx + gap; }
        if (rxn > x1) { rxn = x1; }
        d.textCapCentre(lx, ny, d.semi(NUMBER_SIZE), up.format("%d"), WHITE);
        d.textCapCentre(rxn, ny, d.semi(NUMBER_SIZE), (Climb.totalU() - up).format("%d"), WHITE);
        if (ends) {
            d.dot(x0, y, 0.014423, GREEN);
            d.dot(x1, y, 0.014423, RED);
        }
        d.ring(rx, y, RING_R, CLIMBER, 0.007212);
    }

    // ---------------------------------------------------------------- ascent gauge

    // The ascent as a gauge: a thin arc around the screen's edge from the start (lower left) over the
    // top to the route's top (lower right), the climber's orange ring at the height climbed, the start
    // and top as green and red dots, and the metres climbed and left just past the arc's two ends, in
    // the gap at the bottom.
    const AG_R = 0.461538;
    const AG_FROM = 232;
    const AG_SPAN = 284;

    function ascentGauge(d as Draw, st as Climb.State, ends as Boolean) as Void {
        var tu = Climb.totalU().toFloat(), up = st.climbed();
        d.dc.setColor(SCALE, Graphics.COLOR_TRANSPARENT);
        d.dc.setPenWidth(d.s(0.004808));
        d.dc.drawArc(d.s(0.5), d.s(0.5), d.s(AG_R), Graphics.ARC_CLOCKWISE, AG_FROM, (AG_FROM - AG_SPAN + 360) % 360);
        var r = d.onCircle(AG_R, AG_FROM - st.u / tu * AG_SPAN);
        d.dot(r[0], r[1], RING_R, BLACK);
        if (ends) {
            var p0 = d.onCircle(AG_R, AG_FROM), p1 = d.onCircle(AG_R, AG_FROM - AG_SPAN);
            d.dot(p0[0], p0[1], 0.014423, GREEN);
            d.dot(p1[0], p1[1], 0.014423, RED);
        }
        d.ring(r[0], r[1], RING_R, CLIMBER, 0.007212);
        var n0 = d.onCircle(AG_R, AG_FROM + 11), n1 = d.onCircle(AG_R, AG_FROM - AG_SPAN - 11);
        d.textCapCentre(n0[0], n0[1], d.semi(NUMBER_SIZE), up.format("%d"), WHITE);
        d.textCapCentre(n1[0], n1[1], d.semi(NUMBER_SIZE), (Climb.totalU() - up).format("%d"), WHITE);
    }

    // ---------------------------------------------------------------- front view, page 7

    // The route seen from the front, as on a topo photo of the face (Climb.SIDE): up is height, across
    // is sideways travel. Points every few metres as [x across, y up, distance along], built once,
    // and fitted once into a box keeping one scale across and up.
    var front as Array<Array<Float>>? = null;

    function frontPoints() as Array<Array<Float>> {
        var pts = front;
        if (pts == null) {
            pts = [[0.0, 0.0, 0.0] as Array<Float>] as Array<Array<Float>>;
            var x = 0.0;
            for (var i = 0; i < Climb.count(); i++) {
                var len = Climb.LEN[i], up = Climb.UP[i];
                var steps = ((len > up ? len : up) / 4.0 + 0.5).toNumber();
                if (steps < 2) { steps = 2; }
                for (var k = 1; k <= steps; k++) {
                    var t = k.toFloat() / steps, t0 = (k - 1).toFloat() / steps;
                    // A wall wanders a few metres either way as it climbs.
                    var wander = up > len ? 4 * (Math.sin(t * up / 9) - Math.sin(t0 * up / 9)) : 0.0;
                    x += Climb.SIDE[i] * len / steps + wander;
                    // The real height, down as well as up, as a photo shows it.
                    pts.add([x, Climb.netAt(i) + up * t, Climb.dAt(i) + len * t] as Array<Float>);
                }
            }
            front = pts;
        }
        return pts;
    }

    // The view's points on the screen, fitted once into [x0, x1] by [y0, y1], as [x, y, distance].
    // One box only: page 7's. The box is fixed at the first call; the model points are then let go.
    var frontScreen as Array<Array<Float>>? = null;

    function frontOnScreen(x0 as Float, x1 as Float, y0 as Float, y1 as Float) as Array<Array<Float>> {
        var out = frontScreen;
        if (out == null) {
            var pts = frontPoints();
            var minX = pts[0][0], maxX = pts[0][0], minY = pts[0][1], maxY = pts[0][1];
            for (var j = 1; j < pts.size(); j++) {
                if (pts[j][0] < minX) { minX = pts[j][0]; }
                if (pts[j][0] > maxX) { maxX = pts[j][0]; }
                if (pts[j][1] < minY) { minY = pts[j][1]; }
                if (pts[j][1] > maxY) { maxY = pts[j][1]; }
            }
            // One scale across and up, the smaller. A route with no sideways travel (every SIDE 0) has
            // no width and a level one no height: the other way alone sets it, and with neither the
            // points sit in the box's middle.
            var spanX = maxX - minX, spanY = maxY - minY, k = 0.0;
            if (spanX > 0 && spanY > 0) {
                var kx = (x1 - x0) / spanX, ky = (y1 - y0) / spanY;
                k = kx < ky ? kx : ky;
            } else if (spanX > 0) {
                k = (x1 - x0) / spanX;
            } else if (spanY > 0) {
                k = (y1 - y0) / spanY;
            }
            var ox = (x0 + x1) / 2 - k * (minX + maxX) / 2, oy = (y0 + y1) / 2 + k * (minY + maxY) / 2;
            out = [] as Array<Array<Float>>;
            for (var j = 0; j < pts.size(); j++) {
                out.add([ox + k * pts[j][0], oy - k * pts[j][1], pts[j][2]] as Array<Float>);
            }
            frontScreen = out;
            front = null;
        }
        return out;
    }

    // The first point at or past a distance along the route.
    function frontIndex(pts as Array<Array<Float>>, dist as Float) as Number {
        var lo = 0, hi = pts.size() - 1;
        while (lo < hi) {
            var mid = (lo + hi) / 2;
            if (pts[mid][2] < dist) { lo = mid + 1; } else { hi = mid; }
        }
        return lo;
    }

    // The screen point at a distance along the route.
    function frontAt(pts as Array<Array<Float>>, dist as Float) as Array<Float> {
        var j = frontIndex(pts, dist);
        if (j == 0) { return pts[0]; }
        var a = pts[j - 1], b = pts[j], span = b[2] - a[2];
        var t = span > 0 ? (dist - a[2]) / span : 0.0;
        if (t > 1) { t = 1.0; }
        return [a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])] as Array<Float>;
    }

    // The route between two distances as a thick line with round ends and joints.
    function frontStretch(d as Draw, pts as Array<Array<Float>>, d0 as Float, d1 as Float, pen as Float, c as Number) as Void {
        if (d1 <= d0) { return; }
        var dc = d.dc, r = d.s(pen) / 2;
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(d.s(pen));
        var p = frontAt(pts, d0);
        dc.fillCircle(d.s(p[0]), d.s(p[1]), r);
        for (var j = frontIndex(pts, d0); j < pts.size(); j++) {
            var last = pts[j][2] >= d1;
            var q = last ? frontAt(pts, d1) : pts[j];
            dc.drawLine(d.s(p[0]), d.s(p[1]), d.s(q[0]), d.s(q[1]));
            dc.fillCircle(d.s(q[0]), d.s(q[1]), r);
            p = q;
            if (last) { break; }
        }
    }

    // The front view in the box [x0, x1] by [y0, y1]: the sections in their colours, climbed parts
    // dimmed; rests, exits and dangers as rings, dimmed once passed; the start and the top as a green
    // and a red dot; the climber as the orange outline of the stretch they could be on.
    function frontView(d as Draw, st as Climb.State, x0 as Float, x1 as Float, y0 as Float, y1 as Float) as Void {
        var pts = frontOnScreen(x0, x1, y0, y1);
        var around = st.stretch(), lo = around[0], hi = around[1];
        // The outline with a round brush: thick lines end square on the watch. It is short, so cheap.
        frontBrush(d, pts, lo, hi, 0.026442, CLIMBER);
        frontBrush(d, pts, lo, hi, 0.019231, BLACK);
        for (var i = 0; i < Climb.count(); i++) {
            var g = section(i, false), a = Climb.dAt(i).toFloat(), b = Climb.dAt(i + 1).toFloat();
            if (b <= st.d) {
                frontStretch(d, pts, a, b, 0.019231, d.grade(g, true));
            } else if (a >= st.d) {
                frontStretch(d, pts, a, b, 0.019231, d.grade(g, false));
            } else {
                frontStretch(d, pts, a, st.d, 0.019231, d.grade(g, true));
                frontStretch(d, pts, st.d, b, 0.019231, d.grade(g, false));
            }
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) { frontPoint(d, pts, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, st); }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { frontPoint(d, pts, Climb.dAt(Climb.EXIT_AT[e]).toFloat(), GREEN, st); }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { frontPoint(d, pts, Climb.DANGER_AT[e].toFloat(), WARNING, st); }
        var s0 = pts[0], s1 = pts[pts.size() - 1];
        d.dot(s0[0], s0[1], 0.014423, GREEN);
        d.dot(s1[0], s1[1], 0.014423, RED);
    }

    // The route between two distances, painted with a round brush of radius r.
    function frontBrush(d as Draw, pts as Array<Array<Float>>, d0 as Float, d1 as Float, r as Float, c as Number) as Void {
        if (d1 <= d0) { return; }
        var p = frontAt(pts, d0);
        for (var j = frontIndex(pts, d0); j < pts.size(); j++) {
            var last = pts[j][2] >= d1;
            var q = last ? frontAt(pts, d1) : pts[j];
            d.brush(p[0], p[1], q[0], q[1], r, c);
            p = q;
            if (last) { break; }
        }
    }

    function frontPoint(d as Draw, pts as Array<Array<Float>>, dist as Float, c as Number, st as Climb.State) as Void {
        var p = frontAt(pts, dist);
        d.dot(p[0], p[1], 0.019231, BLACK);
        d.ring(p[0], p[1], 0.016827, dist <= st.d ? d.darken(c, 0.33) : c, 0.007212);
    }

    // ---------------------------------------------------------------- current difficulty group

    // The point of interest within the uncertainty stretch: 0 danger, 1 exit, 2 rest, and with ends
    // also 3 the top and 4 the start; -1 for none. The nearest wins; on a tie, danger, exit, top,
    // rest, start.
    const POI_TOP = 3;
    const POI_START = 4;

    function poiKind(st as Climb.State, ends as Boolean) as Number {
        var around = st.stretch(), lo = around[0], hi = around[1];
        var best = 1.0e9, kind = -1;
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0 && Climb.dAt(i) <= hi && Climb.dAt(i + 1) >= lo) {
                var dist = 0.0;
                if (st.d < Climb.dAt(i)) { dist = Climb.dAt(i) - st.d; }
                if (st.d > Climb.dAt(i + 1)) { dist = st.d - Climb.dAt(i + 1); }
                if (dist < best) { best = dist; kind = 2; }
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var p = Climb.dAt(Climb.EXIT_AT[e]).toFloat(), dist = (p - st.d).abs();
            if (p >= lo && p <= hi && (dist < best || (dist == best && kind > 1))) { best = dist; kind = 1; }
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var p = Climb.DANGER_AT[e].toFloat(), dist = (p - st.d).abs();
            if (p >= lo && p <= hi && dist <= best) { best = dist; kind = 0; }
        }
        if (ends) {
            var top = Climb.totalD().toFloat();
            if (hi >= top - 0.001 && (top - st.d < best || (top - st.d == best && kind > 1))) { best = top - st.d; kind = POI_TOP; }
            if (lo <= 0.001 && st.d < best) { best = st.d; kind = POI_START; }
        }
        return kind;
    }

    // A point's symbol, filled, size across, its left edge at x and its bottom at yb, after safety
    // signs and media controls: danger a yellow triangle (a warning), exit a green arrow pointing down
    // to the right (a way off), a rest a pause (two blue bars), the start play (a green triangle
    // pointing right), the top stop (a red square).
    const WARNING = 0xffd60a;

    function poiSymbol(d as Draw, kind as Number, x as Float, yb as Float, size as Float) as Void {
        var h = size / 2, cx = x + h;
        if (kind == 0) {
            var top = yb - h * 1.8;
            d.dc.setColor(WARNING, Graphics.COLOR_TRANSPARENT);
            d.dc.fillPolygon([[d.s(cx), d.s(top)], [d.s(cx + h * 1.1), d.s(yb)], [d.s(cx - h * 1.1), d.s(yb)]]);
        } else if (kind == 2) {
            d.roundRect(cx - h * 0.8, yb - h * 1.8, h * 0.6, h * 1.8, h * 0.12, REST);
            d.roundRect(cx + h * 0.2, yb - h * 1.8, h * 0.6, h * 1.8, h * 0.12, REST);
        } else if (kind == POI_START) {
            d.dc.setColor(GREEN, Graphics.COLOR_TRANSPARENT);
            d.dc.fillPolygon([[d.s(cx - h * 0.7), d.s(yb - h * 1.6)], [d.s(cx + h * 0.9), d.s(yb - h * 0.8)], [d.s(cx - h * 0.7), d.s(yb)]]);
        } else if (kind == POI_TOP) {
            d.rect(cx - h * 0.8, yb - h * 1.6, h * 1.6, h * 1.6, RED);
        } else if (kind == 1) {
            // The arrow across the square the cross took, round-ended: its shaft from the upper left,
            // its head's two strokes back from the tip, along the bottom and up the right side.
            var k = h * 0.75, a = k * 1.1, cy = yb - k - 0.004808;
            d.brush(cx - k, cy - k, cx + k, cy + k, 0.004808, GREEN);
            d.brush(cx + k - a, cy + k, cx + k, cy + k, 0.004808, GREEN);
            d.brush(cx + k, cy + k - a, cx + k, cy + k, 0.004808, GREEN);
        }
    }

    // The current difficulty group, all sizes times k: the current difficulty in a filled box centred
    // on (cx, by); above it on one baseline the altitude, unit included, right-aligned with the box's
    // right edge, and the point of interest as a filled symbol (10 % smaller) starting where the box's
    // corner rounding ends; below it what comes next, "K4 125 m", centred.
    // With fit (page 7), the box widens to the line above; without it (page 8) it keeps 0.2115 by 0.1490
    // of the width times k and the symbol moves left only if the altitude would touch it.
    function currentDifficultyGroup(d as Draw, st as Climb.State, cx as Float, by as Float, k as Float,
            fit as Boolean) as Void {
        var bh = 0.149038 * k, rx = bh / 6.5, size = 0.043269 * k, ft = feet();
        // The box is at least as wide as the line above needs: the corner rounding, the symbol, a gap,
        // the route's widest altitude and its unit, so the symbol always starts at the rounding.
        // Sizes as shares of the screen's width, times k: 26, 16, 46 and (nextShort) 24 px at 416.
        var font = d.semi(0.0625 * k), small = d.semi(0.0385 * k);
        var need = rx + size + 0.014423 + columnAltitudeBox(d, ft) + 0.007212 + d.width(small, ft ? "ft" : "m");
        var bw = fit && need > 0.211538 * k ? need : 0.211538 * k;
        bigDifficulty(d, st, cx, by, bw, bh, 0.1106 * k);
        var base = by - bh / 2 - 0.028846 * k;
        var alt = altitudeNow(st, ft).format("%d"), unit = ft ? "ft" : "m";
        var right = cx + bw / 2 - d.width(small, unit) - 0.007212;
        d.textCapTop(right, base - d.capHeight(font), font, alt, WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
        d.textTop(right + 0.007212, base - d.ascent(small), small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        // The symbol starts where the box's corner rounding ends (or, without fit, further left if the
        // altitude would touch it).
        var kind = poiKind(st, true);
        if (kind >= 0) {
            // The danger triangle, the widest symbol, spans 1.1 times its size.
            var x = cx - bw / 2 + rx, clear = right - d.width(font, alt) - 0.014423 - 1.1 * size;
            poiSymbol(d, kind, fit || x < clear ? x : clear, base, size);
        }
        nextShort(d, st, cx, by + bh / 2 + 0.0625 * k, k);
    }

    // What comes next without "in": "K4 125 m", the grade in its colour, centred on x.
    function nextShort(d as Draw, st as Climb.State, x as Float, y as Float, k as Float) as Void {
        var here = section(st.cur, false), i = st.cur + 1;
        while (i < Climb.count() && section(i, false) == here) { i++; }
        var dist = (i < Climb.count() ? Climb.dAt(i) : Climb.totalD()) - st.d;
        var m = (Math.round(dist / 5) * 5).toNumber();
        if (m < 0) { m = 0; }
        var what = i < Climb.count() ? BOX_NAME[section(i, false)] : "Top";
        var c = i < Climb.count() ? d.grade(section(i, false), false) : WHITE;
        var rest = " " + m.format("%d") + " m";
        var font = d.bold(0.0577 * k);
        var w1 = d.width(font, what), w = w1 + d.width(font, rest);
        d.textCapMiddle(x - d.half(w), y, font, what, c, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapMiddle(x - d.half(w) + w1, y, font, rest, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
