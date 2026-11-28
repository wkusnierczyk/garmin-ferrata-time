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
    // Red is the route's top only (end dots, the stop symbol); danger is yellow, a warning, on every
    // page (owner, 2026-11-23).
    const RED = 0xff4b4b;
    const WARNING = 0xffd60a;
    const SCALE = 0x777777;
    const WHITE = Graphics.COLOR_WHITE;
    const BLACK = Graphics.COLOR_BLACK;

    // The climber's ring on the ascent line (its radius and its outer edge, a pen of 0.0072), its start
    // and top dots, and the space kept between the ring and the numbers beside it.
    const RING_R = 0.026442;
    const RING_OUTER = 0.030048;
    const ASC_DOT = 0.018029;
    const NUMBER_SPACE = 0.012019;
    // The two numbers beside the ascent, on its line or a gauge (ascentNumbers): their size, as a share
    // of the screen's width (28 px at 416).
    const NUMBER_SIZE = 0.0673;

    // The difficulty widget's boxes: codes 0 to 12 are walking and the route file's half steps, A to
    // F/G (Climb.GRADE), then rest, exit and danger.
    const CODE_EXIT = -2;
    const CODE_DANGER = -3;
    const NONE = -99;
    const BOX_NAME = ["W", "A", "A/B", "B", "B/C", "C", "C/D", "D", "D/E", "E", "E/F", "F", "F/G"] as Array<String>;
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

    // ---------------------------------------------------------------- profile, zoomed (page 2)

    // The zoom window (zoomWindow) drawn at one scale across and up, the largest that fits the box,
    // centred in it. No search for a place clear of the widgets around it (owner, 2026-11-23: too much
    // computation on the watch, #102): where the route runs under the altitude, the altitude's
    // half-transparent box dims it (altitudeGround). Worked out once per window. A rest is drawn as
    // walking here (its stretch is too long to leave out), its ring kept.
    // The window's start, and its [from, to, lowest net height, highest, the scale].
    var zoomKey as Float = -1.0;
    var zoomArgs as Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0] as Array<Float>;
    // The placement drawn, [x, y, scale, distance, net height]: the screen point of that place on the
    // route, and the scale in shares of the width per metre.
    var zoomFit as Array<Float>? = null;
    // The rectangle zoomFit was placed in, [x0, w, y0, h]: the ascent's inset differs by unit, so a
    // change of units moves it while the window stays (Codex on #150).
    var zoomBox as Array<Float> = [0.0, 0.0, 0.0, 0.0] as Array<Float>;

    function profileZoom(d as Draw, st as Climb.State, x0 as Float, w as Float, y0 as Float, h as Float) as Void {
        var win = zoomWindow(st);
        // Again when either end has moved half a metre: near the top the end moves faster than the start.
        // Again too in a new rectangle.
        var b = zoomBox, moved = b[0] != x0 || b[1] != w || b[2] != y0 || b[3] != h;
        if (zoomKey < 0 || moved || (win[0] - zoomKey).abs() > 0.5 || (win[1] - zoomArgs[1]).abs() > 0.5) {
            zoomStart(win[0], win[1], w, h);
            zoomFit = zoomCentred(x0, w, y0, h);
            zoomBox = [x0, w, y0, h] as Array<Float>;
        }
        var f = zoomFit;
        if (f == null) { return; }
        // Cut just right of the ascent widget on the left edge, so the route never runs over its ring.
        var cl = x0 + RING_OUTER + 0.014423;
        d.clip(cl, y0 - h - 0.033654, x0 + w + 0.033654 - cl, h + 0.067308);
        profileAt(d, st, f, cl, x0 + w + 0.033654);
        d.unclip();
    }

    // A new window: its heights and the largest scale that fits the box. The route is straight between
    // section ends, so its lowest and highest points are at the window's ends or at a section end in
    // it (a crest between samples would run out of the box; review of #103).
    function zoomStart(d0 as Float, d1 as Float, w as Float, h as Float) as Void {
        zoomKey = d0;
        var n0 = Climb.netAtDistance(d0), n1 = n0, e = Climb.netAtDistance(d1);
        if (e < n0) { n0 = e; }
        if (e > n1) { n1 = e; }
        for (var i = Climb.sectionAt(d0) + 1; i <= Climb.count() && Climb.dAt(i) < d1; i++) {
            var n = Climb.netAt(i).toFloat();
            if (n < n0) { n0 = n; }
            if (n > n1) { n1 = n; }
        }
        var ka = w / (d1 - d0 > 1 ? d1 - d0 : 1.0), kb = h / (n1 - n0 > 1 ? n1 - n0 : 1.0);
        zoomArgs = [d0, d1, n0, n1, ka < kb ? ka : kb] as Array<Float>;
    }

    // The window at that scale, centred in the box.
    function zoomCentred(x0 as Float, w as Float, y0 as Float, h as Float) as Array<Float> {
        var a = zoomArgs, k = a[4];
        var W = (a[1] - a[0]) * k, H = (a[3] - a[2]) * k;
        return [x0 + (w - W) / 2, y0 - (h - H) / 2, k, a[0], a[2]] as Array<Float>;
    }

    // The profile through a placement, as the profile widget draws it, the sections whose ends lie
    // left of xl or right of xr left out.
    function profileAt(d as Draw, st as Climb.State, f as Array<Float>, xl as Float, xr as Float) as Void {
        var ox = f[0], oy = f[1], k = f[2], d0 = f[3], n0 = f[4];
        // The climber's outline, every 4 m along the stretch, as far as it can be on the screen (between
        // xl and xr): a long flat stretch reaches far past the zoomed box.
        var around = st.stretch(), lo = around[0], hi = around[1];
        var dl = d0 + (xl - ox) / k - 4, dr = d0 + (xr - ox) / k + 4;
        if (lo < dl) { lo = dl; }
        if (hi > dr) { hi = dr; }
        for (var pass = 0; pass < 2; pass++) {
            var pen = pass == 0 ? 0.067308 : 0.052885, c = pass == 0 ? CLIMBER : BLACK;
            var px = ox + (lo - d0) * k, py = oy - (Climb.netAtDistance(lo) - n0) * k, dd = lo;
            while (dd < hi) {
                dd += 4;
                if (dd > hi) { dd = hi; }
                var nx = ox + (dd - d0) * k, ny = oy - (Climb.netAtDistance(dd) - n0) * k;
                d.seg(px, py, nx, ny, pen, c, true);
                px = nx; py = ny;
            }
        }
        var cx = ox + (st.d - d0) * k, cy = oy - (st.net() - n0) * k;
        for (var i = 0; i < Climb.count(); i++) {
            var ax = ox + (Climb.dAt(i) - d0) * k, bx = ox + (Climb.dAt(i + 1) - d0) * k;
            if (bx < xl || ax > xr) { continue; }
            var g = section(i, false);
            var ay = oy - (Climb.netAt(i) - n0) * k, by = oy - (Climb.netAt(i + 1) - n0) * k;
            if (Climb.dAt(i + 1) <= st.d) {
                d.seg(ax, ay, bx, by, 0.024038, d.grade(g, true), true);
            } else if (Climb.dAt(i) >= st.d) {
                d.seg(ax, ay, bx, by, 0.024038, d.grade(g, false), true);
            } else {
                d.seg(ax, ay, cx, cy, 0.024038, d.grade(g, true), true);
                d.seg(cx, cy, bx, by, 0.024038, d.grade(g, false), true);
            }
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var md = (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0;
                point(d, ox + (md - d0) * k, oy - (Climb.netAtDistance(md) - n0) * k, REST, md <= st.d);
            }
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var dd = Climb.DANGER_AT[e].toFloat();
            point(d, ox + (dd - d0) * k, oy - (Climb.netAtDistance(dd) - n0) * k, WARNING, dd <= st.d);
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var i = Climb.EXIT_AT[e];
            point(d, ox + (Climb.dAt(i) - d0) * k, oy - (Climb.netAt(i) - n0) * k, GREEN, Climb.dAt(i) <= st.d);
        }
        var n = Climb.count();
        d.top(ox + (Climb.totalD() - d0) * k, oy - (Climb.netAt(n) - n0) * k);
    }

    // ---------------------------------------------------------------- ascent

    // The ascent widgets (this line, the ascent gauge, the ascent along the gauge's gap) show a position,
    // not an amount (#100; owner, 2026-11-23): the climber's real (net) height on the way from the head
    // (0) to the top's net height, so the ring pulls back down on a descent. Its share of the way, kept
    // on the line where the route dips below the head or rises above its top before coming down to it.
    function ascentShare(st as Climb.State) as Float {
        return shareAt(st.net());
    }

    // The share at a net height above the head.
    function shareAt(net as Float) as Float {
        var top = Climb.netAt(Climb.count());
        // A part whose top is at or below its start (an approach going down) has no way up to show: the
        // ring stays at the start (the review of #101), until the approach pages hide the height (#90).
        if (top <= 0) { return 0.0; }
        var f = net / top;
        return f < 0 ? 0.0 : (f > 1 ? 1.0 : f);
    }

    // Their numbers: the net height above the head now, to the metre or to 5 ft (#148, as the relative
    // heights), and the top's net height less it. Amounts climbed stay height gained (State.climbed):
    // the stacks, the gauge by ascent, the totals. A part whose top is at or below its start shows
    // none, 0 and 0, as its ring stays at the start.
    function ascentNumbers(st as Climb.State, ft as Boolean) as [Number, Number] {
        return numbersAt(st.net(), ft);
    }

    // The numbers at a net height above the head.
    function numbersAt(net as Float, ft as Boolean) as [Number, Number] {
        var top = Climb.netAt(Climb.count());
        if (top <= 0) { return [0, 0]; }
        var up = ascentHeight(net, ft);
        return [up, ascentHeight(top.toFloat(), ft) - up];
    }

    // A net height as the ascent's numbers show it: to the metre, or to 5 ft.
    function ascentHeight(m as Float, ft as Boolean) as Number {
        return (ft ? Math.round(m * 3.28084 / 5) * 5 : Math.round(m)).toNumber();
    }

    // Where the two numbers stand, their middles, with the ring at ty on the line from y0 up to y0 - h:
    // each centred on its stretch, kept clear of the ring, never past the line's end. Below it the
    // metres above the head, above it the metres to the top.
    function numberYs(ty as Float, y0 as Float, h as Float) as [Float, Float] {
        var gap = 0.057692, top = y0 - h;
        var yb = (ty + y0) / 2;
        if (yb < ty + gap) { yb = ty + gap; }
        if (yb > y0) { yb = y0; }
        var ya = (top + ty) / 2;
        if (ya > ty - gap) { ya = ty - gap; }
        if (ya < top) { ya = top; }
        return [yb, ya];
    }

    // The route's height as a line at x, from y0 (the start) up to y0 - h, with the climber on it.
    function ascent(d as Draw, st as Climb.State, x as Float, y0 as Float, h as Float, ends as Boolean) as Void {
        var top = y0 - h, ty = y0 - ascentShare(st) * h, nums = ascentNumbers(st, feet()), ys = numberYs(ty, y0, h);
        // Back to front: the line, the ring's black inside, the end dots, the ring's outline.
        d.line(x, y0, x, top, SCALE, 0.004808);
        d.dot(x, ty, RING_R, BLACK);
        var nx = x - RING_OUTER - NUMBER_SPACE;
        d.textRight(nx, ys[0], d.semi(NUMBER_SIZE), nums[0].format("%d"), WHITE);
        d.textRight(nx, ys[1], d.semi(NUMBER_SIZE), nums[1].format("%d"), WHITE);
        if (ends) {
            d.dot(x, y0, ASC_DOT, GREEN);
            d.dot(x, top, ASC_DOT, RED);
        }
        d.ring(x, ty, RING_R, CLIMBER, 0.007212);
    }

    // Drops what is measured or laid out from the loaded part's sections, for Climb.use when the part
    // changes (Codex on #88).
    function forgetRoute() as Void {
        ascentWidest = null;
        ascentInsetFor = null;
        widest = [null, null];
        gaugeStarts = [null, null];
        front = null;
        frontScreen = null;
        frontZoomed = null;
        pathCum = null;
        zoomKey = -1.0;
        zoomFit = null;
        stackSideWidest = null;
        groupPlaced = null;
        relativeWidest = null;
        Numbers.forget();
    }

    // The widest number the ascent widget can show in the unit shown, measured once per part and unit:
    // a change of units may lay the page out anew (#148, as the owner decided for the summary, #144).
    var ascentWidest as Float? = null;
    var ascentWidestFeet as Boolean = false;

    function ascentNumbersWidth(d as Draw) as Float { return ascentNumbersWidthIn(d, feet()); }

    function ascentNumbersWidthIn(d as Draw, ft as Boolean) as Float {
        var w = ascentWidest;
        if (w == null || ascentWidestFeet != ft) {
            // The digits are tabular, so every number with as many digits is as wide: the widest is one of
            // the ends of the two numbers' ranges (ascentNumbers: the net height from the route's lowest to
            // its highest, and the top's less that), the one with more digits or a minus sign; those four
            // are measured, in the unit shown. Measuring each number instead stopped the app on the
            // watchdog (#94).
            var font = d.semi(NUMBER_SIZE), top = ascentHeight(Climb.netAt(Climb.count()).toFloat(), ft);
            var lo = ascentHeight(Climb.netLow().toFloat(), ft), hi = ascentHeight(Climb.netHigh().toFloat(), ft);
            var ends = [lo, hi, top - lo, top - hi] as Array<Number>;
            w = 0.0;
            for (var i = 0; i < ends.size(); i++) {
                var e = d.width(font, ends[i].format("%d"));
                if (e > w) { w = e; }
            }
            ascentWidest = w;
            ascentWidestFeet = ft;
        }
        return w;
    }

    // How far the ascent widget reaches left of its line.
    function ascentLeft(d as Draw) as Float {
        return ascentNumbersWidth(d) + NUMBER_SPACE + RING_OUTER;
    }

    // How far right of x the ascent's line from y0 up to y0 - h must stand for the ink of each of its
    // numbers, wherever the climber is, to stay on the round screen: 0 where it all fits (#109). Barlow
    // Semi Condensed's numbers are wider than Condensed's, and on the Daubenhorn a 100 near the line's
    // top end reached past the edge. In whole pixels, worked out once per part.
    var ascentInsetFor as Array<Float>? = null;

    function ascentInset(d as Draw, x as Float, y0 as Float, h as Float) as Float {
        return ascentInsetIn(d, x, y0, h, feet());
    }

    // The inset for the numbers of one unit, the one shown: a change of units may move the line (#148,
    // as the owner decided for the summary, #144: not jitter, which is values changing as one climbs).
    function ascentInsetIn(d as Draw, x as Float, y0 as Float, h as Float, ft as Boolean) as Float {
        var c = ascentInsetFor, f = ft ? 1.0 : 0.0;
        if (c != null && c[0] == x && c[1] == y0 && c[2] == h && c[4] == f) { return c[3]; }
        var font = d.semi(NUMBER_SIZE), nx = x - RING_OUTER - NUMBER_SPACE;
        var digit = d.dc.getTextWidthInPixels("0", font), minus = d.dc.getTextWidthInPixels("-", font);
        // Each number's y falls as the climber rises, and its first glyph, the one whose ink reaches
        // furthest left, changes only where it gains a digit or a sign or its first digit changes; the
        // screen's edge is convex, so the ink of a number of one width and first glyph reaches furthest
        // past it at an end of the stretch of heights it is drawn over. The heights checked: the route's
        // lowest and highest, and either side of each such change (0, 1, 2 ... 9, 10, 19, 20 ... 99, 100,
        // 199, 200 ... above the head and below it, and as far from the top's height; #148: checking only
        // the changes of width missed the Daubenhorn's 2000 ft, its 2 reaching further left than a 1).
        // Each height once: the route's ends exactly, and the sides of a change only within the route
        // (clamped to an end, they repeated it many times over, and the first frame tripped the watchdog
        // on the watch, #119). Next to an end needs no check of its own: lo + 0.49 and hi - 0.49 are
        // either the sides of a change (the head's 0, the top) or drawn as the end itself, the climber's
        // share clamped and the number rounded. In feet (#148) the same, the numbers in steps of 5 ft
        // (0, 5, 10, 15, 20 ... 95, 100 ...), the sides of each 2.45 ft from it, in metres: the line
        // stands where the numbers in feet need it.
        var top = Climb.netAt(Climb.count()), lo = Climb.netLow(), hi = Climb.netHigh(), need = 0.0;
        var step = ft ? 5 : 1, k = ft ? 3.28084 : 1.0, topU = ascentHeight(top.toFloat(), ft);
        // Each number at the changes of its own text: the one below the climber where its height above
        // the head changes, the one above where the height left to the top does. Checking both numbers at
        // every height, two hundred heights or more on the real routes, tripped the watchdog on page 1's
        // first frame on the watch (#153).
        var heights = [[lo.toFloat(), hi.toFloat()], [lo.toFloat(), hi.toFloat()]] as Array<Array<Float>>;
        var pts = [0] as Array<Number>;
        for (var t = 1; t <= 10000; t *= 10) {
            for (var g = 1; g <= 9; g++) {
                // Each first digit's first number and the one before it, once: the step's own number
                // follows the head's 0.
                var v = g * t;
                if (v % step != 0) { continue; }
                pts.addAll(v == step ? [v, -v] : [v, v - step, -v, step - v]);
            }
        }
        for (var i = 0; i < pts.size(); i++) {
            for (var j = 0; j < 2; j++) {
                var a = j == 0 ? pts[i] : topU + pts[i];
                for (var side = -1; side <= 1; side += 2) {
                    var n = (a + side * 0.49 * step) / k;
                    if (n > lo && n < hi) { heights[j].add(n.toFloat()); }
                }
            }
        }
        // Each number's box first (inkBox), from its width, without the text: the ink is inside the box
        // and reaches no further, so only a number whose box reaches further than the furthest ink so
        // far is traced.
        var em = Graphics.getFontAscent(font) / 1000.0, r = d.w / 2, right = d.s(nx);
        var lift = Graphics.getFontAscent(font) - Graphics.getFontHeight(font) / 2;
        for (var e = 0; e < 2; e++) {
            var hs = heights[e];
            for (var q = 0; q < hs.size(); q++) {
                var n = hs[q];
                var num = numbersAt(n, ft)[e], base = d.s(numberYs(y0 - shareAt(n) * h, y0, h)[e]) + lift;
                var pen = right - numberWidth(num, digit, minus);
                if (inkBox(r, em, pen, base) <= need) { continue; }
                var over = inkTrace(num.format("%d").toCharArray(), em, r, pen, base, digit, minus, -d.w);
                if (over > need) { need = over; }
            }
        }
        var inset = (Math.ceil(need - 0.0001) / d.w).toFloat();
        ascentInsetFor = [x, y0, h, inset, f] as Array<Float>;
        return inset;
    }

    // How far the ink of a number reaches past the round screen's left edge, in pixels across (below
    // 0: inside), drawn as Draw.textRight draws it at (nx, y): its right end on the pixel Draw.s(nx),
    // the font's line height centred on the pixel Draw.s(y), each glyph one advance (digit, minus, in
    // pixels) after the one before. The ink is each glyph's left side (DigitInk, from the font's
    // outlines), in ems: the bitmap's base, its ascent, is one em.
    function inkPastEdge(d as Draw, font as Graphics.FontType, nx as Float, y as Float, text as String,
            digit as Number, minus as Number, boxFirst as Boolean) as Float {
        var cs = text.toCharArray(), width = 0;
        for (var i = 0; i < cs.size(); i++) { width += cs[i] == '-' ? minus : digit; }
        var em = Graphics.getFontAscent(font) / 1000.0, r = d.w / 2;
        var pen = d.s(nx) - width, base = d.s(y) - Graphics.getFontHeight(font) / 2 + Graphics.getFontAscent(font);
        // The ink lies within a box INK_LEFT right of the pen, from INK_FOOT to INK_TOP above the
        // baseline, in font units (a test holds DigitInk inside it). When the box's left corners are on
        // the screen so is the ink, and the box's overshoot (below 0) stands for it without tracing the
        // outlines (#119); the edge cuts in furthest at one of those corners, as it does more the
        // further a row is from the screen's middle.
        if (!boxFirst) { return inkTrace(cs, em, r, pen, base, digit, minus, -d.w); }
        var box = inkBox(r, em, pen, base);
        if (box < 0) { return box; }
        return inkTrace(cs, em, r, pen, base, digit, minus, -d.w);
    }

    // How far the box round a number's ink reaches past the edge of a screen of radius r, in pixels
    // across (below 0: inside), the pen at its first glyph's left and the baseline at base, as
    // inkPastEdge has them: the edge cuts in furthest at the box's corner further from the screen's
    // middle.
    function inkBox(r as Float, em as Float, pen as Numeric, base as Numeric) as Float {
        var foot = base - INK_FOOT * em - r, top = base - INK_TOP * em - r;
        var dy = foot.abs() > top.abs() ? foot : top, q = r * r - dy * dy;
        return (r - Math.sqrt(q > 0 ? q : 0.0) - (pen + INK_LEFT * em)).toFloat();
    }

    // A whole number's width as drawn, in pixels: an advance per digit and one for a minus.
    function numberWidth(n as Number, digit as Number, minus as Number) as Number {
        var wd = n < 0 ? minus : 0, a = n.abs();
        do {
            wd += digit;
            a /= 10;
        } while (a > 0);
        return wd;
    }

    // A box round every number glyph's ink, in font units: DigitInk's x from 19 and y from -11 to 712,
    // with room to spare.
    const INK_LEFT = -5;
    const INK_FOOT = -20;
    const INK_TOP = 1000;

    // The ink's overshoot traced along each glyph's outline (DigitInk), the pen at the first glyph's
    // left and the baseline at base, in pixels; worst is the floor to start from.
    function inkTrace(cs as Array<Char>, em as Float, r as Float, pen as Numeric, base as Numeric,
            digit as Number, minus as Number, worst as Float) as Float {
        for (var i = 0; i < cs.size(); i++) {
            var k = DigitInk.CHARS.find(cs[i].toString());
            if (k != null) {
                var p = DigitInk.LEFT[k];
                for (var j = 0; j < p.size(); j += 2) {
                    var dy = base - p[j + 1] * em - r, q = r * r - dy * dy;
                    var over = (r - Math.sqrt(q > 0 ? q : 0.0) - (pen + p[j] * em)).toFloat();
                    if (over > worst) { worst = over; }
                }
            }
            pen += cs[i] == '-' ? minus : digit;
        }
        return worst;
    }

    // ---------------------------------------------------------------- difficulty

    // As wide as its letters: one 0.1106 of the width, more 0.1394 (46 and 58 px at 416).
    function boxWidth(code as Number, k as Float) as Float {
        return (code >= 0 && BOX_NAME[code].length() > 1 ? BOX_WIDE : 0.110577) * k;
    }

    const BOX_WIDE = 0.139423;

    // A section that loses height (Climb.descends) has its grade box drawn as a trapezium whose foot is
    // TRAP_FOOT of its top's width (#100; owner, 2026-11-23), so a descent is not taken for a climb: the
    // rectangle's top, height, rounded corners and colour, on every page with grade boxes.
    const TRAP_FOOT = 0.8;
    // The outline of an outlined box: the box in its colour with a black one this far inside it.
    const OUTLINE = 0.007212;

    // The centres of the trapezium's corners' rounding, x and y in turn, clockwise from the top left: a
    // box centred on x with its top at top, w wide at its top and h tall, its corners rounded to r.
    function trapeziumCorners(x as Float, top as Float, w as Float, h as Float, r as Float) as Array<Float> {
        var t = w / 2 - r, f = w / 2 * TRAP_FOOT - r, y0 = top + r, y1 = top + h - r;
        return [x - t, y0, x + t, y0, x + f, y1, x - f, y1] as Array<Float>;
    }

    // That trapezium in colour c, filled or outlined (a black one OUTLINE inside it).
    function trapezium(d as Draw, x as Float, top as Float, w as Float, h as Float, r as Float, c as Number,
            filled as Boolean) as Void {
        var k = trapeziumCorners(x, top, w, h, r);
        var pts = [[k[0], k[1]], [k[2], k[3]], [k[4], k[5]], [k[6], k[7]]] as Array<Array<Float>>;
        d.roundPoly(pts, r, c);
        if (!filled) { d.roundPoly(pts, r - OUTLINE, BLACK); }
    }

    // One box, centred on x with its bottom at yb, at size k; a trapezium for a section that descends.
    function badge(d as Draw, x as Float, yb as Float, k as Float, code as Number, down as Boolean) as Void {
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
        if (down) {
            trapezium(d, x, top, w, h, 0.019231 * k, colour, filled);
        } else {
            d.roundRect(x - w / 2, top, w, h, 0.019231 * k, colour);
        }
        if (!filled && !down) {
            // The outline is the box in its colour with a black box 0.0072 of the width inside it.
            d.roundRect(x - w / 2 + 0.007212, top + 0.007212, w - 0.014423, h - 0.014423, 0.014423 * k, BLACK);
        }
        d.textCapCentre(x, top + h / 2, d.bold(BOX_FS * k), text, filled ? BLACK : colour);
    }

    // The section the climber is estimated in, in a larger box centred on x; the nearest thing behind
    // and ahead within the uncertainty stretch in smaller boxes beside it, all at size k. All share the
    // top yt (owner, 2026-11-23: they shared the bottom; under the profile the round screen narrows
    // below them). Without points, only sections count, and a rest shows as walking ground (W).
    function difficulty(d as Draw, st as Climb.State, x as Float, yt as Float, points as Boolean, k as Float) as Void {
        var around = st.stretch(), lo = around[0], hi = around[1];
        var cur = st.cur;
        var left = NONE, right = NONE, leftDist = 1.0e9, rightDist = 1.0e9;
        // Whether the box beside is a section that descends; a point's box never is.
        var leftDown = false, rightDown = false;
        // The neighbouring sections; a point at the same distance wins over them.
        if (cur > 0 && Climb.dAt(cur) >= lo) {
            left = section(cur - 1, points); leftDist = st.d - Climb.dAt(cur) + 0.01; leftDown = Climb.descends(cur - 1);
        }
        if (cur < Climb.count() - 1 && Climb.dAt(cur + 1) <= hi) {
            right = section(cur + 1, points); rightDist = Climb.dAt(cur + 1) - st.d + 0.01; rightDown = Climb.descends(cur + 1);
        }
        var n = points ? Climb.EXIT_AT.size() + Climb.DANGER_AT.size() : 0;
        for (var j = 0; j < n; j++) {
            var p = 0.0, code = CODE_EXIT;
            if (j < Climb.EXIT_AT.size()) {
                p = Climb.dAt(Climb.EXIT_AT[j]).toFloat();
            } else {
                p = Climb.DANGER_AT[j - Climb.EXIT_AT.size()].toFloat(); code = CODE_DANGER;
            }
            if (p >= lo && p <= st.d && st.d - p < leftDist) { left = code; leftDist = st.d - p; leftDown = false; }
            if (p > st.d && p <= hi && p - st.d < rightDist) { right = code; rightDist = p - st.d; rightDown = false; }
        }
        var mid = section(cur, points), half = boxWidth(mid, k) / 2, ks = SATELLITE * k;
        badge(d, x, yt + d.whole(BOX_H * k), k, mid, Climb.descends(cur));
        var yb = yt + d.whole(BOX_H * ks);
        if (left != NONE) { badge(d, x - half - BOX_GAP - boxWidth(left, ks) / 2, yb, ks, left, leftDown); }
        if (right != NONE) { badge(d, x + half + BOX_GAP + boxWidth(right, ks) / 2, yb, ks, right, rightDown); }
    }

    // A section's box code; a rest is walking ground when points are left out.
    function section(i as Number, points as Boolean) as Number {
        var g = Climb.GRADE[i];
        return g < 0 && !points ? 0 : g;
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

    // Section i's altitudes at its foot and its top, to the metre or foot (page 15).
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

    // One word for the point of interest the uncertainty stretch covers (poiNear), right-aligned at x,
    // the top of its capitals at yt, letter-spaced, in its colour.
    function poi(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var kind = poiNear(st, false);
        if (kind >= 0) {
            d.spaced(x, yt + 0.7 * POI_SIZE, poiFont(d), POI_WORD[kind], POI_COLOUR[kind], Graphics.TEXT_JUSTIFY_RIGHT);
        }
    }

    // The altitude group: the altitude, with the poi word under it, right-aligned with the number.
    function altitudeGroup(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        altitude(d, st, x, yt);
        poi(d, st, x + altitudeBox(d, feet()), yt + d.capHeight(d.semi(ALT_SIZE)) + 0.028846);
    }

    // The altitude group's extent as altitudeGroup draws it at x and yt, in units ft: [left, right, down]
    // from x and yt. Across, from the number's box, or the poi word's start when it is wider (the word
    // is right-aligned with the number: on a route of three-digit altitudes "DANGER" runs past them),
    // to the unit's end; down, the digits' capitals and, with a poi word, the gap and its capitals.
    function altitudeGroupExtent(d as Draw, st as Climb.State, ft as Boolean) as [Float, Float, Float] {
        var box = altitudeBox(d, ft), left = 0.0;
        var right = box + 0.009615 + d.width(d.semi(ALT_UNIT), ft ? "ft" : "m");
        var down = d.capHeight(d.semi(ALT_SIZE)), kind = poiNear(st, false);
        if (kind >= 0) {
            down += 0.028846 + 0.7 * POI_SIZE;
            var start = box - d.spacedWidth(poiFont(d), POI_WORD[kind]);
            if (start < left) { left = start; }
        }
        return [left, right, down];
    }

    // Page 2: a half-transparent black box under the altitude group at x and yt (owner, 2026-11-23,
    // #102), ALT_PAD round it and rounded by as much, so the zoomed route running under the group shows
    // through half-dimmed. Drawn after the profile, before the group.
    const ALT_PAD = 0.014423;

    function altitudeGround(d as Draw, st as Climb.State, x as Float, yt as Float) as Void {
        var e = altitudeGroupExtent(d, st, feet());
        d.shade(x + e[0] - ALT_PAD, yt - ALT_PAD, e[1] - e[0] + 2 * ALT_PAD, e[2] + 2 * ALT_PAD, ALT_PAD, 0x80);
    }

    // ---------------------------------------------------------------- difficulty column

    // Equal boxes, the current one larger by COL_BIG; those before the climber at COL_DIM of their colour.
    const COL_W = 0.153846;
    const COL_H = 0.096154;
    const COL_GAP = 0.019231;
    // The current box 35 % larger, its letters Bold 36 px at 416 (owner, 2026-11-23: it was 8 %).
    const COL_BIG = 1.35;
    const COL_DIM = 0.55;
    const COL_SPACE = 0.024038;
    // The letters' size (bold), and the altitudes' and their unit's, as shares of the screen's width
    // (26, 30 and 18 px at 416).
    const COL_FS = 0.0625;
    const COL_ALT = 0.0721;
    const COL_UNIT = 0.0433;

    // The column's slots around the current one (owner, 2026-11-23): one section before it below, three
    // after it above. The column keeps its height and is centred on the group's height; the current box
    // sits one slot step below its middle.
    const COL_BELOW = 1;
    const COL_ABOVE = 3;

    // The centre of slot k (0 the climber's, positive above), the current box's centre at cc, and the
    // half height of its box.
    function slotY(k as Number, cc as Float) as Float {
        if (k == 0) { return cc; }
        var off = COL_H * COL_BIG / 2 + COL_GAP + COL_H / 2.0 + (k.abs() - 1) * (COL_H + COL_GAP);
        return k > 0 ? cc - off : cc + off;
    }

    function slotHalf(k as Number) as Float {
        return (k == 0 ? COL_H * COL_BIG : COL_H.toFloat()) / 2;
    }

    // The current box's centre in a column centred on cy.
    function columnCurrentY(cy as Float) as Float {
        return cy + columnReach() - COL_BELOW * (COL_GAP + COL_H) - COL_H * COL_BIG / 2;
    }

    // Whether section i has a box in the column around section cur.
    function inColumn(i as Number, cur as Number) as Boolean {
        return i >= 0 && i < Climb.count() && i - cur >= -COL_BELOW && i - cur <= COL_ABOVE;
    }

    // The sections around the climber's as a column of boxes, the current one centred on (cx, cc): it
    // filled and larger, the one before below (dimmed) and three after above, outlined. Empty slots near
    // the route's start or top stay empty. A rest shows as W; a section that descends, filled or
    // outlined, as a trapezium.
    function column(d as Draw, st as Climb.State, cx as Float, cc as Float) as Void {
        for (var k = -COL_BELOW; k <= COL_ABOVE; k++) {
            var i = st.cur + k;
            if (!inColumn(i, st.cur)) { continue; }
            var g = section(i, false);
            var big = k == 0, f = big ? COL_BIG : 1.0;
            var w = d.whole(COL_W * f), h = d.whole(COL_H * f);
            var y = slotY(k, cc), top = d.whole(y - h / 2);
            var colour = d.grade(g, false);
            if (k < 0) { colour = d.darken(colour, COL_DIM); }
            if (Climb.descends(i)) {
                trapezium(d, cx, top, w, h, 0.019231 * f, colour, big);
            } else {
                d.roundRect(cx - w / 2, top, w, h, 0.019231 * f, colour);
                if (!big) { d.roundRect(cx - w / 2 + 0.007212, top + 0.007212, w - 0.014423, h - 0.014423, 0.014423 * f, BLACK); }
            }
            d.textCapCentre(cx, top + h / 2, d.bold(COL_FS * f), BOX_NAME[g], big ? BLACK : colour);
        }
    }

    // The widest altitude the route can show in the column's font.
    function columnAltitudeBox(d as Draw, ft as Boolean) as Float {
        return widestAltitude(d, ft, d.semi(COL_ALT), 1);
    }

    // Page 6: border b's height above the bottom of section cur, signed ("+137", "0", "-20"): the
    // route's own heights, not the climber's estimate, so to the metre, or to 5 ft.
    function relativeValue(b as Number, cur as Number, ft as Boolean) as Number {
        var du = (Climb.netAt(b) - Climb.netAt(cur)).toFloat();
        return (ft ? Math.round(du * 3.28084 / 5) * 5 : Math.round(du)).toNumber();
    }

    function relativeText(v as Number) as String {
        return v > 0 ? "+" + v.format("%d") : v.format("%d");
    }

    // The widest relative altitude the column can show on the route, per unit, measured once: the
    // differences from each section's bottom to the borders shown above it. Tabular digits: the widest
    // is the largest rise or the deepest fall (its minus sign), or 0; at most three numbers measured.
    var relativeWidest as Float? = null;
    var relativeFeet as Boolean = false;

    function columnRelativeBox(d as Draw, ft as Boolean) as Float {
        var w = relativeWidest;
        if (w == null || relativeFeet != ft) {
            var hi = 0, lo = 0, n = Climb.count();
            for (var c = 0; c < n; c++) {
                for (var b = c; b <= n && b <= c + COL_ABOVE + 1; b++) {
                    var v = relativeValue(b, c, ft);
                    if (v > hi) { hi = v; }
                    if (v < lo) { lo = v; }
                }
            }
            var font = d.semi(COL_ALT);
            w = d.width(font, "0");
            var wh = d.width(font, relativeText(hi)), wl = d.width(font, relativeText(lo));
            if (wh > w) { w = wh; }
            if (wl > w) { w = wl; }
            relativeWidest = w;
            relativeFeet = ft;
        }
        return w;
    }

    // The difficulty column group's width: the larger box, the space, the altitudes (relative on page
    // 6) and the unit shown.
    function columnGroupWidth(d as Draw, relative as Boolean) as Float {
        var ft = feet(), altW = relative ? columnRelativeBox(d, ft) : columnAltitudeBox(d, ft);
        return COL_W * COL_BIG + COL_SPACE + altW + 0.007212 + d.width(d.semi(COL_UNIT), ft ? "ft" : "m");
    }

    // How far the column reaches above and below its centre: half its height.
    function columnReach() as Float {
        return (COL_H * COL_BIG + (COL_BELOW + COL_ABOVE) * (COL_GAP + COL_H)) / 2;
    }

    // The difficulty column group, centred on the screen as one group, the column centred at height cy.
    function columnGroup(d as Draw, st as Climb.State, cy as Float, outer as Boolean, relative as Boolean) as Void {
        columnGroupAt(d, st, 0.5 - columnGroupWidth(d, relative) / 2, cy, outer, relative);
    }

    // The difficulty column group: the column, with the altitudes where the difficulty changes to its
    // right, from the current section's bottom up (owner, 2026-11-23: no longer the bottom of the one
    // before): the current's bottom always, even with no box below it; the others level with a border
    // between two boxes, and at the column's top edge if outer. Right-aligned in a box as wide as the
    // route's widest, its unit after it. Page 6 (relative): each the height above the current section's
    // bottom. Its left edge at left, the column centred vertically on cy.
    function columnGroupAt(d as Draw, st as Climb.State, left as Float, cy as Float, outer as Boolean,
            relative as Boolean) as Void {
        var ft = feet(), unit = ft ? "ft" : "m", font = d.semi(COL_ALT), small = d.semi(COL_UNIT);
        var bw = COL_W * COL_BIG, altW = relative ? columnRelativeBox(d, ft) : columnAltitudeBox(d, ft);
        var cx = left + bw / 2, cc = columnCurrentY(cy);
        var ax = cx + bw / 2 + COL_SPACE + altW;
        column(d, st, cx, cc);
        // Border b lies between sections b - 1 and b, at its real altitude.
        for (var b = st.cur; b <= st.cur + COL_ABOVE + 1; b++) {
            var above = inColumn(b, st.cur), below = inColumn(b - 1, st.cur);
            if (b != st.cur && !(above && below) && !(outer && (above || below))) { continue; }
            var y = above
                ? slotY(b - st.cur, cc) + slotHalf(b - st.cur) + COL_GAP / 2.0
                : slotY(b - 1 - st.cur, cc) - slotHalf(b - 1 - st.cur) - COL_GAP / 2.0;
            var text = relative ? relativeText(relativeValue(b, st.cur, ft)) : borderAltitude(b, ft).format("%d");
            d.textCapMiddle(ax, y, font, text, WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
            // The unit on the number's baseline.
            var baseline = y + d.capHeight(font) / 2;
            d.textTop(ax + 0.007212, baseline - d.ascent(small), small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        }
    }

    // ---------------------------------------------------------------- difficulty stack

    // The sections as boxes to scale in a narrow column centred on the screen, in a window from top to
    // bottom that moves with the climber, who stays a quarter of the way up from its bottom: by ascent
    // (byUp) each box as tall as the metres its section gains, by path as tall as its length along the
    // route. Every section's letters beside the column, the points as symbols beside the letters, three
    // altitude labels on its left; all within radius fitR of the screen's centre.
    const STACK_W = 0.105769;
    // The letters beside the column, Bold, the climber's section's as large as the next altitude's label
    // (owner, 2026-11-23); the symbols' size (28, 52 and 22 px at 416).
    const SIDE_FS = 0.0673;
    const SIDE_FS_NOW = 0.125;
    const SYM_SIZE = 0.052885;
    // The labels: the next altitude to reach, and the two beside it (52 and 36 px at 416).
    const LABEL_NEXT = 0.125;
    const LABEL_NEAR = 0.0865;

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

    // A section's colour on the stack: walking for a rest, dimmed before the climber's.
    function stackColour(d as Draw, st as Climb.State, i as Number) as Number {
        var c = d.grade(section(i, false), false);
        return i < st.cur ? d.darken(c, COL_DIM) : c;
    }

    // The width of a grade's letters beside the stack, the climber's size or the others', measured once.
    var letterWidths as Array<Float?> = new Array<Float?>[2 * 13];

    function letterWidth(d as Draw, g as Number, now as Boolean) as Float {
        var slot = 2 * g + (now ? 1 : 0), w = letterWidths[slot];
        if (w == null) {
            w = d.width(d.bold(now ? SIDE_FS_NOW : SIDE_FS), BOX_NAME[g]);
            letterWidths[slot] = w;
        }
        return w;
    }

    // The widest letters the route's sections show at the climber's size: where the symbols start.
    var stackSideWidest as Float? = null;

    function stackSideWidth(d as Draw) as Float {
        var w = stackSideWidest;
        if (w == null) {
            w = 0.0;
            for (var i = 0; i < Climb.count(); i++) {
                var lw = letterWidth(d, section(i, false), true);
                if (lw > w) { w = lw; }
            }
            stackSideWidest = w;
        }
        return w;
    }

    // Whether the box from (x0, y0) to (x1, y1) lies within radius r of the screen's centre.
    function within(x0 as Float, y0 as Float, x1 as Float, y1 as Float, r as Float) as Boolean {
        var xs = [x0, x1] as Array<Float>, ys = [y0, y1] as Array<Float>;
        for (var i = 0; i < 2; i++) {
            for (var j = 0; j < 2; j++) {
                var dx = xs[i] - 0.5, dy = ys[j] - 0.5;
                if (dx * dx + dy * dy > r * r) { return false; }
            }
        }
        return true;
    }

    // Ticks every stepM metres, or stepFt feet when the watch shows feet.
    function stack(d as Draw, st as Climb.State, byUp as Boolean, top as Float, bottom as Float,
            scale as Float, stepM as Number, stepFt as Number, fitR as Float) as Void {
        var cy = bottom - (bottom - top) / 4, here = byUp ? st.u : st.d;
        var left = 0.5 - STACK_W / 2, right = left + STACK_W;
        var n = Climb.count();
        d.clip(0, top, 1, bottom - top);
        // The boxes: the current one filled, the others black with their sides in their colour.
        for (var i = 0; i < n; i++) {
            var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
            if (yt > bottom + 0.004808 || yb < top - 0.004808 || stackSize(i, byUp) == 0) { continue; }
            var c = stackColour(d, st, i);
            if (i == st.cur) {
                d.rect(left, yt, STACK_W, yb - yt, c);
            } else {
                d.rect(left, yt, STACK_W, yb - yt, BLACK);
                d.rect(left, yt, 0.007212, yb - yt, c);
                d.rect(right - 0.007212, yt, 0.007212, yb - yt, c);
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
        // Every section's letters right of the column, at the middle of its box's part in view (a flat
        // section's at its line), in its colour: placed from the climber's section outwards (the one
        // before first on a tie), and left out where they would touch letters already placed or leave
        // the screen.
        var sideX = right + 0.024038;
        var placed = [] as Array<Float>;
        for (var off = 0; off < n; off++) {
            for (var sign = -1; sign <= 1; sign += 2) {
                if (off == 0 && sign > 0) { continue; }
                var i = st.cur + sign * off;
                if (i < 0 || i >= n) { continue; }
                var yb = cy - (stackAt(i, byUp) - here) * scale, yt = cy - (stackAt(i + 1, byUp) - here) * scale;
                if (yt > bottom || yb < top) { continue; }
                var vt = yt > top ? yt : top, vb = yb < bottom ? yb : bottom;
                var now = i == st.cur, g = section(i, false), h = 0.7 * (now ? SIDE_FS_NOW : SIDE_FS);
                var y = stackSize(i, byUp) == 0 ? yb : (vt + vb) / 2;
                var t0 = y - h / 2 - 0.007212, b0 = y + h / 2 + 0.007212, clash = false;
                for (var q = 0; q < placed.size(); q += 2) { if (t0 < placed[q + 1] && b0 > placed[q]) { clash = true; } }
                if (clash || !within(sideX, y - h / 2, sideX + letterWidth(d, g, now), y + h / 2, fitR)) { continue; }
                placed.add(t0);
                placed.add(b0);
                d.textBase(sideX, y + h / 2, d.bold(now ? SIDE_FS_NOW : SIDE_FS), BOX_NAME[g], stackColour(d, st, i),
                    Graphics.TEXT_JUSTIFY_LEFT);
            }
        }
        var ft = feet(), step = ft ? stepFt : stepM;
        stackSymbols(d, st, byUp, sideX + stackSideWidth(d) + 0.028846 + SYM_SIZE / 2, top, bottom, cy, here, scale,
            ft ? stepFt / 3.28084 : stepM.toFloat(), fitR);
        // Altitude ticks on the left, every step, only along the route, where it rises (stackTicks).
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
        // Three labels: the next altitude to reach, larger, and the nearest above and below it that keep
        // clear of it. It is the first tick above the climber on the stack (by path it may sit further
        // along the route than the climber, and after a descent its altitude may be below the one now);
        // near the top, past the last, the topmost tick stands for it.
        var next = -1;
        for (var t = 0; t < ticks.size() && next < 0; t++) { if (places[t] > here) { next = t; } }
        if (next < 0) { next = ticks.size() - 1; }
        if (next < 0) { stackRing(d, left, cy); return; }
        stackLabel(d, left, ys[next], ticks[next], LABEL_NEXT, fitR);
        for (var dir = 1; dir >= -1; dir -= 2) {
            for (var t = next + dir; t >= 0 && t < ticks.size(); t += dir) {
                if ((ys[next] - ys[t]).abs() >= (LABEL_NEXT + LABEL_NEAR) / 2) {
                    stackLabel(d, left, ys[t], ticks[t], LABEL_NEAR, fitR);
                    break;
                }
            }
        }
        stackRing(d, left, cy);
    }

    // The climber: the orange ring on the column's left edge.
    function stackRing(d as Draw, left as Float, cy as Float) as Void {
        d.dot(left, cy, 0.021635, BLACK);
        d.ring(left, cy, 0.021635, CLIMBER, 0.007212);
    }

    // A tick's label, its capitals centred on y, ending 0.0337 of the width left of the column; left
    // out where it would leave the screen.
    function stackLabel(d as Draw, left as Float, y as Float, v as Number, fs as Float, fitR as Float) as Void {
        var font = d.semi(fs), text = v.format("%d"), x = left - 0.033654;
        if (!within(x - d.width(font, text), y - 0.35 * fs, x, y + 0.35 * fs, fitR)) { return; }
        d.textBase(x, y + 0.35 * fs, font, text, d.MUTED, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // The points of interest on the stack as symbols centred on x at their place on it (rests at
    // their middle), dimmed once passed. A point is in the climber's range from one tick step (stepM
    // metres along the stack's axis) before it to half a step after it. Points whose symbols would
    // touch show one: of those in range the first of danger, exit, rest, top, then the nearest; with
    // none in range, the nearest to the climber.
    function stackSymbols(d as Draw, st as Climb.State, byUp as Boolean, x as Float, top as Float, bottom as Float,
            cy as Float, here as Float, scale as Float, stepM as Float, fitR as Float) as Void {
        // Each point: where it sits, its stretch (lo to hi metres along the route), its kind.
        var at = [] as Array<Float>, lo = [] as Array<Float>, hi = [] as Array<Float>, kind = [] as Array<Number>;
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var d0 = Climb.dAt(i).toFloat(), d1 = Climb.dAt(i + 1).toFloat();
                at.add((d0 + d1) / 2); lo.add(d0); hi.add(d1); kind.add(2);
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var de = Climb.dAt(Climb.EXIT_AT[e]).toFloat();
            at.add(de); lo.add(de); hi.add(de); kind.add(1);
        }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var de = Climb.DANGER_AT[e].toFloat();
            at.add(de); lo.add(de); hi.add(de); kind.add(0);
        }
        // The route's top, on the ferrata.
        if (Climb.FERRATA) {
            var td = Climb.totalD().toFloat();
            at.add(td); lo.add(td); hi.add(td); kind.add(POI_TOP);
        }
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
        // Group the symbols that would touch, each closer than its size and a gap to the one before, and
        // draw one per group.
        var g = 0, half = SYM_SIZE / 2;
        while (g < order.size()) {
            var best = -1, end = g;
            while (end < order.size() && (end == g || ys[order[end]] - ys[order[end - 1]] < SYM_SIZE + 0.009615)) { end++; }
            for (var m = g; m < end; m++) {
                var p = order[m];
                if (best < 0) { best = p; continue; }
                var better = near[p] && !near[best] ||
                    near[p] == near[best] && (near[p] ? kind[p] < kind[best] || kind[p] == kind[best] && away[p] < away[best] : away[p] < away[best]);
                if (better) { best = p; }
            }
            var y = ys[best];
            if (within(x - half * 1.1, y - half, x + half * 1.1, y + half, fitR)) {
                symbol(d, kind[best], x, y, SYM_SIZE, at[best] <= st.d);
            }
            g = end;
        }
    }

    // ---------------------------------------------------------------- gauge, pages 12 and 13

    // The route around the screen's edge, from its start at the lower left over the top to its top at
    // the lower right, each section's arc its length along the route, or the metres it climbs (byUp);
    // climbed parts dimmed; rests, exits and dangers as rings, dimmed once passed; the climber as a
    // thicker orange line on the gauge's inner side over the stretch they could be on, rounded at its
    // ends, clear of the sections.
    const G_R = 0.461538;
    const G_FROM = 232;
    const G_SPAN = 284;
    const G_PEN = 0.028846;
    // The climber's line: its width, the sections' own (owner, 2026-11-28: twice the first 0.0144,
    // #156), and its radius 0.0072 of the width inside the sections.
    const G_INNER = 0.028846;
    const G_INNER_R = G_R - G_PEN / 2 - 0.007212 - G_INNER / 2;
    // The line's ends at least this many degrees inside the gauge's own ends, so its round caps (half
    // its width, about 2° at G_INNER_R) stay within the gauge and clear of the ascent numbers in the
    // gap below them (#156: at twice the width a cap at the very end touched them).
    const G_CAP = 2;

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
    // once, and the arc stopping 1° short of the next section's start, so every gap is one degree; the
    // last runs to the route's top, so the gauge ends where the ascent's top dot is.
    function sectionArc(i as Number, byUp as Boolean) as Array<Number> {
        var s0 = Math.round(gaugeAngle(Climb.dAt(i).toFloat(), byUp)).toNumber();
        var s1 = Math.round(gaugeAngle(Climb.dAt(i + 1).toFloat(), byUp)).toNumber() + (i == Climb.count() - 1 ? 0 : 1);
        return [s0, s1] as Array<Number>;
    }

    function gauge(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var around = st.stretch(), lo = around[0], hi = around[1];
        // On whole degrees, as the watch draws arcs, so the round ends sit on the line's ends.
        var a0 = Math.round(gaugeAngle(lo, byUp)), a1 = Math.round(gaugeAngle(hi, byUp));
        // Both ends into the allowed range, each clamped both ways: a stretch wholly within the last
        // (or first) G_CAP degrees collapses onto the limit rather than past it.
        var hiA = G_FROM - G_CAP, loA = G_FROM - G_SPAN + G_CAP;
        a0 = a0 > hiA ? hiA : (a0 < loA ? loA : a0);
        a1 = a1 > hiA ? hiA : (a1 < loA ? loA : a1);
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

    // The difficulty g in a large filled box centred on (x, y), its letters bold at size (a share of
    // the screen's width), centred on their capitals; a trapezium for a section that descends (down).
    function bigDifficultyOf(d as Draw, g as Number, x as Float, y as Float, w as Float, h as Float, size as Float,
            down as Boolean) as Void {
        if (down) {
            trapezium(d, x, y - h / 2, w, h, h / 6.5, d.grade(g, false), true);
        } else {
            d.roundRect(x - w / 2, y - h / 2, w, h, h / 6.5, d.grade(g, false));
        }
        d.textCapCentre(x, y, d.bold(size), BOX_NAME[g], BLACK);
    }

    // ---------------------------------------------------------------- selection gauge (page 15)


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
        // Most important first, so it takes the lane nearest the gauge where two meet: dangers, exits,
        // then rests (a rest lights up with the section itself and the ones right before and after it).
        var lanes = [] as Array<Array<Float>>;
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) {
            var de = Climb.DANGER_AT[e].toFloat();
            selectionMark(d, lanes, de, WARNING, holds(sel, de));
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var de = Climb.dAt(Climb.EXIT_AT[e]).toFloat();
            selectionMark(d, lanes, de, GREEN, holds(sel, de));
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                selectionMark(d, lanes, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, (i - sel).abs() <= 1);
            }
        }
    }

    // A point on the selection gauge as a filled disk just inside it (owner, 2026-11-23: the rings were
    // small and hard to read, and short arcs read as sections), SEL_DISK across, SEL_GAP clear of the
    // sections; a point that would come within SEL_GAP of one already placed moves one lane further
    // in, so each stays on its own angle.
    const SEL_DISK = 0.043269;
    const SEL_GAP = 0.009615;

    function selectionLane(k as Number) as Float {
        return G_R - G_PEN / 2 - SEL_GAP - SEL_DISK / 2 - k * (SEL_DISK + SEL_GAP);
    }

    function selectionMark(d as Draw, lanes as Array<Array<Float>>, dist as Float, c as Number, lit as Boolean) as Void {
        var a = gaugeAngle(dist, true), k = 0;
        while (k < lanes.size()) {
            var clear = true, lane = lanes[k];
            for (var j = 0; j < lane.size(); j++) {
                if ((lane[j] - a).abs() * Math.PI / 180 * selectionLane(k) < SEL_DISK + SEL_GAP) { clear = false; break; }
            }
            if (clear) { break; }
            k++;
        }
        if (k == lanes.size()) { lanes.add([] as Array<Float>); }
        lanes[k].add(a);
        var p = d.onCircle(selectionLane(k), a);
        d.dot(p[0], p[1], SEL_DISK / 2, lit ? c : d.darken(c, 0.33));
    }

    // The points section i includes or is next to, as poiNear's kinds: the ferrata's head for the first
    // section, then danger, exit, rest, and the route's top for the last section: a point in it or at
    // its foot or top; a rest that is the section itself or right before or after it.
    function sectionPoints(i as Number) as Array<Number> {
        var kinds = [] as Array<Number>, n = Climb.count();
        // The head and the top only on the ferrata (the approach ends at the head).
        if (i == 0 && Climb.FERRATA) { kinds.add(POI_HEAD); }
        var danger = false, exit = false;
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { if (holds(i, Climb.DANGER_AT[e].toFloat())) { danger = true; } }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { if (holds(i, Climb.dAt(Climb.EXIT_AT[e]).toFloat())) { exit = true; } }
        if (danger) { kinds.add(0); }
        if (exit) { kinds.add(1); }
        if (Climb.GRADE[i] < 0 || i > 0 && Climb.GRADE[i - 1] < 0 || i < n - 1 && Climb.GRADE[i + 1] < 0) { kinds.add(2); }
        if (i == n - 1 && Climb.FERRATA) { kinds.add(POI_TOP); }
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
    // the route, rounded to 5 m or 20 ft ("C/D 125 m", the grade in its colour), or the top; centred on
    // x, its baseline at base, Bold at size (a share of the screen's width).
    function nextUp(d as Draw, st as Climb.State, x as Float, base as Float, size as Float) as Void {
        var ft = feet(), next = nextSection(st, ft), i = next[0];
        var what = i >= 0 ? BOX_NAME[section(i, false)] : "Top";
        var c = i >= 0 ? d.grade(section(i, false), false) : WHITE;
        var rest = nextText(next[1], ft);
        var font = d.bold(size);
        var w1 = d.width(font, what), w = w1 + d.width(font, rest);
        d.textBase(x - d.half(w), base, font, what, c, Graphics.TEXT_JUSTIFY_LEFT);
        d.textBase(x - d.half(w) + w1, base, font, rest, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // The next section of a different difficulty (-1 for the top) and the distance to its start along
    // the route, in the unit shown.
    function nextSection(st as Climb.State, ft as Boolean) as [Number, Number] {
        var here = section(st.cur, false), i = st.cur + 1;
        while (i < Climb.count() && section(i, false) == here) { i++; }
        var dist = (i < Climb.count() ? Climb.dAt(i) : Climb.totalD()) - st.d;
        return [i < Climb.count() ? i : -1, nextDistance(dist.toFloat(), ft)];
    }

    // A distance along the route as the next line shows it: metres rounded to 5 m, or converted to
    // feet and rounded to 20 ft, the round step at or above 5 m (16.4 ft) as the pages' other steps in
    // feet are (10 m to 50 ft, 1 m to 5 ft; #148); never below 0.
    function nextDistance(m as Float, ft as Boolean) as Number {
        var v = (ft ? Math.round(m * 3.28084 / 20) * 20 : Math.round(m / 5) * 5).toNumber();
        return v < 0 ? 0 : v;
    }

    // The next line's distance and its unit, after the grade (" 125 m", " 420 ft").
    function nextText(v as Number, ft as Boolean) as String { return " " + v.format("%d") + (ft ? " ft" : " m"); }

    // The ascent along the gauge's gap at the bottom (pages 12, 13 and 15): the start and top dots on
    // the gauge's two ends, the ascent's two numbers beside them, facing inwards, and between the
    // numbers a line the climber's ring travels, reaching up to each number as drawn (it grows when a
    // number is short: the mocks give up the no-jitter rule here on purpose).
    function ascentGap(d as Draw, st as Climb.State) as Void {
        var p0 = d.onCircle(G_R, G_FROM), p1 = d.onCircle(G_R, G_FROM - G_SPAN), y = p0[1];
        var gap = 0.014423, nums = ascentNumbers(st, feet()), font = d.semi(NUMBER_SIZE);
        var l = nums[0].format("%d"), r = nums[1].format("%d");
        var tl = p0[0] + ASC_DOT + gap + d.width(font, l) + gap + RING_R;
        var tr = p1[0] - ASC_DOT - gap - d.width(font, r) - gap - RING_R;
        var rx = tl + ascentShare(st) * (tr - tl);
        d.rect(tl - RING_R, y - 0.002404, tr - tl + 2 * RING_R, 0.004808, SCALE);
        d.dot(p0[0], y, ASC_DOT, GREEN);
        d.dot(p1[0], y, ASC_DOT, RED);
        var base = y + 0.35 * NUMBER_SIZE;
        d.textBase(p0[0] + ASC_DOT + gap, base, font, l, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textBase(p1[0] - ASC_DOT - gap, base, font, r, WHITE, Graphics.TEXT_JUSTIFY_RIGHT);
        d.dot(rx, y, RING_R, BLACK);
        d.ring(rx, y, RING_R, CLIMBER, 0.007212);
    }

    // ---------------------------------------------------------------- ascent gauge

    // The ascent as a gauge: a thin arc around the screen's edge from the start (lower left) over the
    // top to the route's top (lower right), the climber's orange ring at the real height (ascentShare),
    // the start and top as green and red dots, and in the gap at the bottom the ascent's two numbers
    // beside the arc's two ends, facing inwards.
    const AG_R = 0.461538;
    const AG_FROM = 232;
    const AG_SPAN = 284;

    function ascentGauge(d as Draw, st as Climb.State, ends as Boolean) as Void {
        var nums = ascentNumbers(st, feet());
        d.dc.setColor(SCALE, Graphics.COLOR_TRANSPARENT);
        d.dc.setPenWidth(d.s(0.004808));
        d.dc.drawArc(d.s(0.5), d.s(0.5), d.s(AG_R), Graphics.ARC_CLOCKWISE, AG_FROM, (AG_FROM - AG_SPAN + 360) % 360);
        var r = d.onCircle(AG_R, AG_FROM - ascentShare(st) * AG_SPAN);
        var p0 = d.onCircle(AG_R, AG_FROM), p1 = d.onCircle(AG_R, AG_FROM - AG_SPAN);
        d.dot(r[0], r[1], RING_R, BLACK);
        if (ends) {
            d.dot(p0[0], p0[1], ASC_DOT, GREEN);
            d.dot(p1[0], p1[1], ASC_DOT, RED);
        }
        d.ring(r[0], r[1], RING_R, CLIMBER, 0.007212);
        var font = d.semi(NUMBER_SIZE), dx = ASC_DOT + 0.019231;
        d.textBase(p0[0] + dx, p0[1] + 0.35 * NUMBER_SIZE, font, nums[0].format("%d"), WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textBase(p1[0] - dx, p1[1] + 0.35 * NUMBER_SIZE, font, nums[1].format("%d"), WHITE,
            Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---------------------------------------------------------------- front view, pages 3 and 4

    // The route seen from the front, as on a topo photo of the face (Climb.SIDE): up is height, across
    // is sideways travel. Points as [x across, y up, distance along], every few metres of height on a
    // wall and at the ends of any other section, built once, and fitted once into a box keeping one scale
    // across and up.
    var front as Array<Array<Float>>? = null;

    // The most points the walls get together: page 3 draws every point each frame, and about 460 tripped
    // the watchdog (#105).
    const FRONT_BUDGET = 200;

    function frontPoints() as Array<Array<Float>> {
        var pts = front;
        if (pts == null) {
            pts = [[0.0, 0.0, 0.0] as Array<Float>] as Array<Array<Float>>;
            // A wall (more height than length) wanders, so it takes a point every 4 m of height, or more
            // metres apart when the route's walls together would pass FRONT_BUDGET; any other section is
            // a straight line, one step. A point every 4 m along the whole route tripped the watchdog on
            // the Daubenhorn's 1545 m, whose first section alone is a 600 m traverse (#105).
            var walls = 0;
            for (var i = 0; i < Climb.count(); i++) {
                if (Climb.UP[i] > Climb.LEN[i]) { walls += Climb.UP[i]; }
            }
            var step = walls / FRONT_BUDGET.toFloat() > 4 ? walls / FRONT_BUDGET.toFloat() : 4.0;
            var x = 0.0;
            for (var i = 0; i < Climb.count(); i++) {
                var len = Climb.LEN[i], up = Climb.UP[i], wall = up > len;
                var steps = wall ? (up / step + 0.5).toNumber() : 1;
                if (steps < 1) { steps = 1; }
                for (var k = 1; k <= steps; k++) {
                    var t = k.toFloat() / steps, t0 = (k - 1).toFloat() / steps;
                    // A wall wanders a few metres either way as it climbs.
                    var wander = wall ? 4 * (Math.sin(t * up / 9) - Math.sin(t0 * up / 9)) : 0.0;
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
    // One box only: page 3's. The box is fixed at the first call; the model points are kept for page
    // 4, which fits a part of them into it every frame.
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
        frontDraw(d, st, frontOnScreen(x0, x1, y0, y1), 0.0, Climb.totalD().toFloat());
    }

    // The front view through the screen points pts, between the distances from and to along the route
    // (page 4 draws only the part around its window).
    function frontDraw(d as Draw, st as Climb.State, pts as Array<Array<Float>>, from as Float, to as Float) as Void {
        var around = st.stretch(), lo = around[0] > from ? around[0] : from, hi = around[1] < to ? around[1] : to;
        // The outline with a round brush: thick lines end square on the watch. It is short, so cheap.
        frontBrush(d, pts, lo, hi, 0.026442, CLIMBER);
        frontBrush(d, pts, lo, hi, 0.019231, BLACK);
        for (var i = 0; i < Climb.count(); i++) {
            var g = section(i, false), a = Climb.dAt(i).toFloat(), b = Climb.dAt(i + 1).toFloat();
            if (a < from) { a = from; }
            if (b > to) { b = to; }
            if (b <= a) { continue; }
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
            if (Climb.GRADE[i] < 0) { frontPoint(d, pts, (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0, REST, st, from, to); }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) { frontPoint(d, pts, Climb.dAt(Climb.EXIT_AT[e]).toFloat(), GREEN, st, from, to); }
        for (var e = 0; e < Climb.DANGER_AT.size(); e++) { frontPoint(d, pts, Climb.DANGER_AT[e].toFloat(), WARNING, st, from, to); }
        if (from <= 0) { var s0 = pts[0]; d.dot(s0[0], s0[1], 0.014423, GREEN); }
        if (to >= Climb.totalD()) { var s1 = pts[pts.size() - 1]; d.dot(s1[0], s1[1], 0.014423, RED); }
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

    function frontPoint(d as Draw, pts as Array<Array<Float>>, dist as Float, c as Number, st as Climb.State,
            from as Float, to as Float) as Void {
        if (dist < from || dist > to) { return; }
        var p = frontAt(pts, dist);
        d.dot(p[0], p[1], 0.019231, BLACK);
        d.ring(p[0], p[1], 0.016827, dist <= st.d ? d.darken(c, 0.33) : c, 0.007212);
    }

    // Page 4: the front view zoomed to the zoom window (zoomWindow), fitted into [x0, x1] by [y0, y1]
    // keeping its shape, at least 20 m each way so a straight stretch does not blow up; the route runs
    // on past the box, cut on the left at clipX, short of the difficulty group. The screen points are
    // written into one array kept per route, not made anew every frame.
    var frontZoomed as Array<Array<Float>>? = null;

    function frontZoom(d as Draw, st as Climb.State, x0 as Float, x1 as Float, y0 as Float, y1 as Float, clipX as Float) as Void {
        var model = frontPoints(), win = zoomWindow(st), d0 = win[0], d1 = win[1];
        var a = frontAt(model, d0), b = frontAt(model, d1);
        var minX = a[0] < b[0] ? a[0] : b[0], maxX = a[0] < b[0] ? b[0] : a[0];
        var minY = a[1] < b[1] ? a[1] : b[1], maxY = a[1] < b[1] ? b[1] : a[1];
        for (var j = frontIndex(model, d0); j < model.size() && model[j][2] < d1; j++) {
            var p = model[j];
            if (p[0] < minX) { minX = p[0]; }
            if (p[0] > maxX) { maxX = p[0]; }
            if (p[1] < minY) { minY = p[1]; }
            if (p[1] > maxY) { maxY = p[1]; }
        }
        var sx = maxX - minX > 20 ? maxX - minX : 20.0, sy = maxY - minY > 20 ? maxY - minY : 20.0;
        var kx = (x1 - x0) / sx, ky = (y1 - y0) / sy, k = kx < ky ? kx : ky;
        var ox = (x0 + x1) / 2 - k * (minX + maxX) / 2, oy = (y0 + y1) / 2 + k * (minY + maxY) / 2;
        var pts = frontZoomed;
        if (pts == null) {
            pts = new Array<Array<Float>>[model.size()];
            for (var j = 0; j < model.size(); j++) { pts[j] = [0.0, 0.0, model[j][2]] as Array<Float>; }
            frontZoomed = pts;
        }
        // Only the part around the window can be on the screen: the window and one and a half of its
        // lengths either side. Its points, and one past each end, are worked out; the rest is not drawn.
        var ext = 1.5 * (d1 - d0), from = d0 - ext, to = d1 + ext;
        if (from < 0) { from = 0.0; }
        if (to > Climb.totalD()) { to = Climb.totalD().toFloat(); }
        var j0 = frontIndex(model, from) - 1, j1 = frontIndex(model, to) + 1;
        if (j0 < 0) { j0 = 0; }
        if (j1 > model.size() - 1) { j1 = model.size() - 1; }
        for (var j = j0; j <= j1; j++) {
            var q = pts[j];
            q[0] = ox + k * model[j][0];
            q[1] = oy - k * model[j][1];
        }
        d.clip(clipX, 0, 1 - clipX, 1);
        frontDraw(d, st, pts, from, to);
        d.unclip();
    }

    // ---------------------------------------------------------------- zoom (pages 2 and 4)

    // The zoom window: 100 m along the path (each section's length and height combined), a fifth of it
    // behind the climber, slid inside the route near its ends, as [from, to] in metres along the route.
    const ZOOM = 100.0;
    const ZOOM_BEHIND = 0.2;
    var pathCum as Array<Float>? = null;

    // The path at each boundary, worked out once per part.
    function pathAt(i as Number) as Float {
        var c = pathCum;
        if (c == null) {
            c = new Array<Float>[Climb.count() + 1];
            c[0] = 0.0;
            for (var j = 0; j < Climb.count(); j++) {
                var l = Climb.LEN[j].toFloat(), u = Climb.UP[j].toFloat();
                c[j + 1] = c[j] + Math.sqrt(l * l + u * u).toFloat();
            }
            pathCum = c;
        }
        return c[i];
    }

    function pathAtDistance(dist as Float) as Float {
        var i = Climb.sectionAt(dist), l = Climb.LEN[i];
        var f = l > 0 ? (dist - Climb.dAt(i)) / l : 0.0;
        return pathAt(i) + (f < 0 ? 0.0 : (f > 1 ? 1.0 : f)) * (pathAt(i + 1) - pathAt(i));
    }

    function distanceAtPath(p as Float) as Float {
        for (var i = 0; i < Climb.count(); i++) {
            if (p <= pathAt(i + 1)) {
                var span = pathAt(i + 1) - pathAt(i);
                return Climb.dAt(i) + (span > 0 ? (p - pathAt(i)) / span : 0.0) * Climb.LEN[i];
            }
        }
        return Climb.totalD().toFloat();
    }

    function zoomWindow(st as Climb.State) as [Float, Float] {
        var total = pathAt(Climb.count()), len = total < ZOOM ? total : ZOOM;
        var p0 = pathAtDistance(st.d) - ZOOM_BEHIND * len;
        if (p0 > total - len) { p0 = total - len; }
        if (p0 < 0) { p0 = 0.0; }
        return [distanceAtPath(p0), distanceAtPath(p0 + len)];
    }

    // ---------------------------------------------------------------- current difficulty group

    // The point of interest within the uncertainty stretch: 0 danger, 1 exit, 2 rest, and with ends
    // also 3 the top and 4 the ferrata's head (HEAD, never START: the climb may start on the approach;
    // owner, 2026-11-23); -1 for none. The nearest wins; on a tie, in that order.
    const POI_TOP = 3;
    const POI_HEAD = 4;
    const POI_WORD = ["DANGER", "EXIT", "REST", "TOP", "HEAD"] as Array<String>;
    const POI_COLOUR = [WARNING, GREEN, REST, RED, GREEN] as Array<Number>;

    function poiNear(st as Climb.State, ends as Boolean) as Number {
        var around = st.stretch(), lo = around[0], hi = around[1];
        var best = 1.0e9, kind = -1;
        // From the last kind to the first, so a tie goes to the earlier one.
        // The head and the top only on the ferrata: the approach starts elsewhere and ends at the head.
        if (ends && Climb.FERRATA && lo <= 0.001) { best = st.d; kind = POI_HEAD; }
        var top = Climb.totalD().toFloat();
        if (ends && Climb.FERRATA && hi >= top - 0.001 && top - st.d <= best) { best = top - st.d; kind = POI_TOP; }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0 && Climb.dAt(i) <= hi && Climb.dAt(i + 1) >= lo) {
                var dist = 0.0;
                if (st.d < Climb.dAt(i)) { dist = Climb.dAt(i) - st.d; }
                if (st.d > Climb.dAt(i + 1)) { dist = st.d - Climb.dAt(i + 1); }
                if (dist < best || (dist == best && kind > 2)) { best = dist; kind = 2; }
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
        return kind;
    }

    // A point's symbol, filled, size across, centred on (x, y), dimmed once passed, after safety signs
    // and media controls: danger a yellow triangle (a warning), exit a green arrow pointing down to the
    // right (a way off), a rest a pause (two blue bars), the top stop (a red square).

    function symbol(d as Draw, kind as Number, x as Float, y as Float, size as Float, passed as Boolean) as Void {
        var h = size / 2;
        var c = kind == 0 ? WARNING : kind == 1 ? GREEN : kind == 2 ? REST : RED;
        if (passed) { c = d.darken(c, 0.33); }
        if (kind == 0) {
            d.poly([[x, y - h], [x + h * 1.1, y + h * 0.8], [x - h * 1.1, y + h * 0.8]] as Array<Array<Float>>, c);
        } else if (kind == 2) {
            d.roundRect(x - h * 0.8, y - h, h * 0.6, h * 1.8, h * 0.12, c);
            d.roundRect(x + h * 0.2, y - h, h * 0.6, h * 1.8, h * 0.12, c);
        } else if (kind == 1) {
            // The arrow across the square the cross took, round-ended: its shaft from the upper left,
            // its head's two strokes back from the tip, along the bottom and up the right side.
            var k = h * 0.75, a = k * 1.1;
            d.seg(x - k, y - k, x + k, y + k, 0.009615, c, true);
            d.seg(x + k - a, y + k, x + k, y + k, 0.009615, c, true);
            d.seg(x + k, y + k - a, x + k, y + k, 0.009615, c, true);
        } else {
            d.rect(x - h * 0.8, y - h * 0.8, h * 1.6, h * 1.6, c);
        }
    }

    // The space above and below the large difficulty boxes (pages 3, 4 and 12 to 15), the same on
    // every page (owner, 2026-11-23): the altitude's baseline this far above the box, the capitals of
    // the line below it this far below.
    const GROUP_GAP = 0.028846;

    // The current difficulty group, all sizes times k: the current difficulty in a filled box centred
    // on (cx, by), 0.2115 by 0.1490 of the width; above it the altitude with its unit; below it what
    // comes next, "C/D 125 m", GROUP_GAP from the box; all centred on the box (owner, 2026-11-23: the
    // altitude's unit ended at the box's right edge). Pages 3 and 4: the altitude at SemiBold 40 and its
    // unit 24 (px at 416) whatever k, no point of interest. Page 14 (points): the altitude at 26 and the
    // unit 16 times k, and the point of interest the stretch covers (the ferrata's head and the route's
    // top too) as a word under the next line, centred, the top of its capitals 0.0288 below that line's
    // baseline.
    function group(d as Draw, st as Climb.State, cx as Float, by as Float, k as Float, points as Boolean) as Void {
        var bw = 0.211538 * k, bh = 0.149038 * k;
        bigDifficultyOf(d, section(st.cur, false), cx, by, bw, bh, 0.1106 * k, Climb.descends(st.cur));
        var base = by - bh / 2 - GROUP_GAP, alt = altitudeNow(st, feet());
        if (points) {
            altitudeCentred(d, cx, base, alt, d.semi(0.0625 * k), d.semi(0.0385 * k), 0.007212 * k);
        } else {
            altitudeCentred(d, cx, base, alt, d.semi(0.0962), d.semi(0.0577), 0.007212);
        }
        var nextBase = by + bh / 2 + GROUP_GAP + 0.7 * 0.0577 * k;
        nextUp(d, st, cx, nextBase, 0.0577 * k);
        if (points) {
            var kind = poiNear(st, true);
            if (kind >= 0) {
                d.spaced(cx, nextBase + 0.028846 + 0.7 * 0.0673, d.bold(0.0673), POI_WORD[kind], POI_COLOUR[kind],
                    Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    // An altitude v and its unit (grey, gap after the number) centred on x together, on the baseline base.
    function altitudeCentred(d as Draw, x as Float, base as Float, v as Number, font as Graphics.FontType,
            small as Graphics.FontType, gap as Float) as Void {
        var text = v.format("%d"), unit = feet() ? "ft" : "m";
        var wn = d.width(font, text), left = x - d.half(wn + gap + d.width(small, unit));
        d.textBase(left, base, font, text, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textBase(left + wn + gap, base, small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Pages 3 and 4's group (they draw it at size k, its box centred at height by) as far left as the
    // round screen allows (owner, 2026-11-23): each of its rows keeps GROUP_MARGIN clear of the round
    // edge at its outer corner, and the row needing the most room sets the group's centre. The rows:
    // the altitude, at the route's widest; the box, the centres of its corners' rounding; the next line
    // at its longest on the route. Returns [the group's centre, its right edge]: the zoomed front view
    // keeps clear of it. Worked out once per part and unit, for the unit shown (#148, as the owner decided
    // for the summary, #144: a change of units may move it); nothing in it changes as the climber moves.
    const GROUP_MARGIN = 0.019231;
    var groupPlaced as Array<Float>? = null;
    var groupFeet as Boolean = false;
    var groupAt as Array<Float> = [0.0, 0.0] as Array<Float>;

    function groupPlace(d as Draw, by as Float, k as Float) as Array<Float> {
        var ft = feet(), placed = groupPlaced;
        if (placed != null && groupFeet == ft && groupAt[0] == by && groupAt[1] == k) { return placed; }
        var bw = 0.211538 * k, bh = 0.149038 * k, rx = 0.024038 * k, r = 0.5 - GROUP_MARGIN;
        // The altitude: the top of its digits, and half its width at the route's widest end.
        var aTop = by - bh / 2 - GROUP_GAP - 0.7 * 0.0962, altHalf = groupAltitudeHalf(d, ft);
        // The next line: its baseline, and half its longest width.
        var nextBase = by + bh / 2 + GROUP_GAP + 0.7 * 0.0577 * k;
        var nextHalf = longestNext(d, d.bold(0.0577 * k), ft) / 2;
        // The box: its corners' rounding within r - rx of the centre.
        var cy = by - bh / 2 + rx - 0.5, inner = (r - rx) * (r - rx) - cy * cy;
        var box = 0.5 - Math.sqrt(inner > 0 ? inner : 0) - rx + bw / 2;
        var cx = box, a = edgeAt(aTop, r) + altHalf, n = edgeAt(nextBase, r) + nextHalf;
        if (a > cx) { cx = a; }
        if (n > cx) { cx = n; }
        var half = bw / 2;
        if (altHalf > half) { half = altHalf; }
        if (nextHalf > half) { half = nextHalf; }
        placed = [cx.toFloat(), (cx + half).toFloat()] as Array<Float>;
        groupPlaced = placed;
        groupFeet = ft;
        groupAt = [by, k] as Array<Float>;
        return placed;
    }

    // Half the group's altitude row, its number and its unit, at the route's widest end, in the unit
    // shown.
    function groupAltitudeHalf(d as Draw, ft as Boolean) as Float {
        var font = d.semi(0.0962);
        var low = d.width(font, altitudeValue(Climb.netLow().toFloat(), ft).format("%d"));
        var high = d.width(font, altitudeValue(Climb.netHigh().toFloat(), ft).format("%d"));
        return ((low > high ? low : high) + 0.007212 + d.width(d.semi(0.0577), ft ? "ft" : "m")) / 2;
    }

    // The round edge's left side at height y, r from the centre.
    function edgeAt(y as Float, r as Float) as Float {
        var q = r * r - (y - 0.5) * (y - 0.5);
        return (0.5 - Math.sqrt(q > 0 ? q : 0)).toFloat();
    }

    // The widest next line on the part: for each run of sections of one difficulty, the next difficulty
    // and its distance from the run's start, rounded as nextUp rounds it, in the unit shown (#148).
    function longestNext(d as Draw, font as Graphics.FontType, ft as Boolean) as Float {
        var n = Climb.count(), widest = 0.0;
        for (var i = 0; i < n; i++) {
            if (i > 0 && section(i, false) == section(i - 1, false)) { continue; }
            var j = i + 1;
            while (j < n && section(j, false) == section(i, false)) { j++; }
            var dist = ((j < n ? Climb.dAt(j) : Climb.totalD()) - Climb.dAt(i)).toFloat();
            var what = j < n ? BOX_NAME[section(j, false)] : "Top";
            var w = d.width(font, what + nextText(nextDistance(dist, ft), ft));
            if (w > widest) { widest = w; }
        }
        return widest;
    }
}
