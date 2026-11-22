using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The pages, as in the design sketch, laid out in shares of the screen's width.
module Pages {

    const COUNT = 20;
    // Page 9, the section preview, and the section it shows (-1: the climber's).
    const SECTION_PAGE = 9;
    // Page 9's difficulty box: its centre's height and its size; the tap zone beside it uses them too.
    const SECTION_BY = 0.447115;
    const SECTION_BW = 0.317308;
    const SECTION_BH = 0.221154;
    var selected as Number = -1;
    const WHITE = Graphics.COLOR_WHITE;
    const BLACK = Graphics.COLOR_BLACK;

    function draw(page as Number, d as Draw, st as Climb.State) as Void {
        d.clear();
        switch (page) {
            // A page's colour map goes on this frame's Draw (View makes a new one every frame), so
            // the pages that set none keep heat.
            case 0: { d.colours = d.HEAT_AMBER; profileAlone(d, st); break; }
            case 1: { d.colours = d.HEAT_AMBER; columnPage(d, st); break; }
            case 2: { d.colours = d.HEAT_AMBER; sideBySide(d, st); break; }
            case 3: { d.colours = d.HEAT_AMBER; stackByAscent(d, st); break; }
            case 4: { d.colours = d.HEAT_AMBER; stackByPath(d, st); break; }
            // Pages 6a and 6b: the gauge by length along the route, and by ascent.
            case 5: { d.colours = d.HEAT_AMBER; gaugePage(d, st, false); break; }
            case 6: { d.colours = d.HEAT_AMBER; gaugePage(d, st, true); break; }
            case 7: { d.colours = d.HEAT_AMBER; frontPage(d, st); break; }
            case 8: { d.colours = d.HEAT_AMBER; centrePage(d, st); break; }
            case 9: { d.colours = d.HEAT_AMBER; sectionPage(d, st); break; }
            case 10: { profile(d, st); break; }
            case 11: { combined(d, st); break; }
            case 12: { ladderPage(d, st); break; }
            case 13: { whereAmI(d, st); break; }
            case 14: { whatsNext(d, st); break; }
            case 15: { timeStrip(d, st); break; }
            case 16: { bigHeight(d, st); break; }
            case 17: { bigNextHard(d, st); break; }
            case 18: { bigTop(d, st); break; }
            default: { bigExit(d, st); break; }
        }
    }

    // ---------------------------------------------------------------- shared parts

    // The route seen from the side, mapped into the box [x0, x0 + w] by [y0 - h, y0].
    function route(d as Draw, st as Climb.State, x0 as Float, w as Float, y0 as Float, h as Float,
            pen as Float, exitTo as Float) as Void {
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        // Exits drop away, dashed.
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var i = Climb.EXIT_AT[e];
            var ex = x0 + Climb.dAt(i) / td * w, ey = y0 - Climb.uAt(i) / tu * h;
            d.dashed(ex, ey, ex + 0.057692, exitTo, d.EXIT, 0.004808);
            d.exitMark(ex + 0.067308, exitTo + 0.028846);
        }
        // How sure the position is: the route between the heights it could be at.
        var lo = Climb.firstDistanceAt(st.u - st.band);
        var hi = Climb.lastDistanceAt(st.u + st.band);
        var band = 0x474747;
        var px = x0 + lo / td * w, py = y0 - Climb.heightAtDistance(lo) / tu * h;
        for (var dd = lo + 4; dd <= hi; dd += 4) {
            var nx = x0 + dd / td * w, ny = y0 - Climb.heightAtDistance(dd) / tu * h;
            d.line(px, py, nx, ny, band, 0.052885);
            px = nx; py = ny;
        }
        // The sections: grade colours, climbed parts dimmed, rests as blue stretches beneath.
        var cx = x0 + st.d / td * w, cy = y0 - st.u / tu * h;
        for (var i = 0; i < Climb.count(); i++) {
            var ax = x0 + Climb.dAt(i) / td * w, ay = y0 - Climb.uAt(i) / tu * h;
            var bx = x0 + Climb.dAt(i + 1) / td * w, by = y0 - Climb.uAt(i + 1) / tu * h;
            var g = Climb.GRADE[i];
            if (g < 0) { d.line(ax, ay + 0.026442, bx, by + 0.026442, d.REST, 0.009615); continue; }
            if (Climb.dAt(i + 1) <= st.d) {
                d.line(ax, ay, bx, by, d.grade(g, true), pen);
            } else if (Climb.dAt(i) >= st.d) {
                d.line(ax, ay, bx, by, d.grade(g, false), pen);
            } else {
                d.line(ax, ay, cx, cy, d.grade(g, true), pen);
                d.line(cx, cy, bx, by, d.grade(g, false), pen);
            }
        }
        d.dot(cx, cy, 0.016827, WHITE);
        d.top(x0 + w, y0 - h);
    }

    // The route by height alone: a column of grade blocks from the bottom up.
    function ladder(d as Draw, st as Climb.State, x as Float, wd as Float, y0 as Float, h as Float) as Void {
        var tu = Climb.totalU().toFloat();
        for (var i = 0; i < Climb.count(); i++) {
            var g = Climb.GRADE[i];
            if (g < 0) { continue; }
            var u0 = Climb.uAt(i), u1 = Climb.uAt(i + 1);
            var ya = y0 - u0 / tu * h, yb = y0 - u1 / tu * h;
            if (ya - yb < 0.009615) { yb = ya - 0.009615; }
            if (u1 <= st.u) {
                d.rect(x, yb, wd, ya - yb, d.grade(g, true));
            } else if (u0 >= st.u) {
                d.rect(x, yb, wd, ya - yb, d.grade(g, false));
            } else {
                var yp = y0 - st.u / tu * h;
                d.rect(x, yp, wd, ya - yp, d.grade(g, true));
                d.rect(x, yb, wd, yp - yb, d.grade(g, false));
            }
        }
    }

    function angle(i as Number) as String {
        var a = Math.toDegrees(Math.atan2(Climb.UP[i], Climb.LEN[i]));
        return a.toNumber().format("%d") + "°";
    }

    function minutesText(m as Float) as String {
        var n = (m + 0.5).toNumber();
        return (n < 0 ? 0 : n).format("%d");
    }

    // ---------------------------------------------------------------- A. side profile

    // The pages from here on are the 0.0.1 demo's, laid out for the system fonts. Each text is in the
    // SemiBold size, as a share of the screen's width, whose capitals stand as tall as the system
    // font's did (#62): 0.0529 (22 px at 416) for the smallest, 0.0865 (36) for the next two, 0.1106
    // (46) for medium and large, 0.2019 (84) for the large numbers.

    function profile(d as Draw, st as Climb.State) as Void {
        route(d, st, 0.149038, 0.701923, 0.629808, 0.360577, 0.019231, 0.682692);
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        for (var i = st.cur + 1; i < Climb.count(); i++) {
            if (Climb.GRADE[i] >= 3 && Climb.UP[i] >= 60) {
                var mx = 0.149038 + (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0 / td * 0.701923;
                var my = 0.629808 - (Climb.uAt(i) + Climb.uAt(i + 1)) / 2.0 / tu * 0.360577;
                d.textRight(mx - 0.028846, my, d.semi(0.0529), angle(i), 0xbbbbbb);
            }
        }
        d.text(0.5, 0.115385, d.semi(0.0865), Climb.clockText(st.clock()), WHITE);
        d.text(0.5, 0.182692, d.semi(0.0529), st.altitude().format("%d") + " m", d.MUTED);
        d.upMark(0.25, 0.778846, 0.016827, WHITE);
        d.textLeft(0.278846, 0.774038, d.semi(0.1106), st.climbed().format("%d"), WHITE);
        d.text(0.326923, 0.846154, d.semi(0.0529), "of " + Climb.totalU().format("%d") + " m", d.MUTED);
        d.text(0.682692, 0.774038, d.semi(0.1106), Climb.durationText(st.left()), WHITE);
        d.text(0.682692, 0.846154, d.semi(0.0529), "top " + Climb.clockText(st.finish()), d.MUTED);
        d.text(0.5, 0.913462, d.semi(0.0529), "~" + ((st.d / 10).toNumber() * 10).format("%d") + "/" +
            Climb.totalD().format("%d") + " m along", d.MUTED);
    }

    // ---------------------------------------------------------------- page 1, version 1: the profile alone

    // design/page-1.md: profile and ascent share the start and span a rectangle; the difficulty
    // boxes in its lower right, the altitude group in its upper left.
    function profileAlone(d as Draw, st as Climb.State) as Void {
        var x0 = 0.221154, w = 0.625, y0 = 0.764423, h = 0.543269;
        Widgets.profile(d, st, x0, w, y0, h);
        Widgets.ascent(d, st, x0, y0, h, true);
        Widgets.difficulty(d, st, x0 + w - Widgets.difficultyReach(), y0, false);
        Widgets.altitudeGroup(d, st, x0 + Widgets.RING_OUTER + 0.019231, y0 - h);
    }

    // ---------------------------------------------------------------- page 2, version 1: the difficulty column

    // design/page-2.md: the difficulty column group, centred, with altitudes at the outer edges too.
    function columnPage(d as Draw, st as Climb.State) as Void {
        Widgets.columnGroup(d, st, 0.5, true);
    }

    // ---------------------------------------------------------------- page 3, version 1: side by side

    // design/page-3.md: the ascent on the left and the difficulty column group on the right, with equal
    // space before, between and after them across 0.1346 to 0.8654 of the width; the ascent as tall as
    // the column; the current altitude centred at the top.
    function sideBySide(d as Draw, st as Climb.State) as Void {
        var left = 0.134615, right = 0.865385, cy = 0.548077;
        var ascLeft = Widgets.ascentLeft(d), ascW = ascLeft + Widgets.RING_OUTER;
        // Never negative: with wider fonts the widgets would touch rather than overlap.
        var gap = (right - left - ascW - Widgets.columnGroupWidth(d)) / 3;
        if (gap < 0) { gap = 0.0; }
        var lx = left + gap + ascLeft, reach = Widgets.columnReach();
        Widgets.ascent(d, st, lx, cy + reach, 2 * reach, true);
        Widgets.columnGroupAt(d, st, lx + Widgets.RING_OUTER + gap, cy, true);
        Widgets.altitudeCentred(d, st, 0.5, 0.096154);
    }

    // ---------------------------------------------------------------- pages 4 and 5: the difficulty stack

    // Page 4: the stack by ascent, 0.0072 of the width per metre climbed, altitudes every 20 m (100 ft).
    // A scale per metre carries nine decimals: it multiplies hundreds of metres.
    function stackByAscent(d as Draw, st as Climb.State) as Void {
        Widgets.stack(d, st, true, 0.394231, 0.153846, 0.846154, 0.007211538, true, 20, 100, 0.480769);
    }

    // Page 5: the stack by path, 0.0024 of the width per metre along the route, centred as a group (its
    // tick labels, its column, the names' gap and room for names), with the ascent as a gauge around the
    // edge; names stop inside it.
    function stackByPath(d as Draw, st as Climb.State) as Void {
        var labels = Widgets.stackLabels(d);
        var left = 0.5 - (labels + Widgets.STACK_W + Widgets.NAME_GAP + Widgets.STACK_NAMES) / 2 + labels;
        Widgets.ascentGauge(d, st, true);
        Widgets.stack(d, st, false, left, 0.153846, 0.846154, 0.002403846, true, 10, 50, Widgets.AG_R - 0.033654);
    }

    // ---------------------------------------------------------------- pages 6a and 6b, version 1: the gauge

    // design/page-6.md: the gauge, each section's arc its length along the route (6a) or the metres it
    // climbs (byUp, 6b); the current difficulty large in the middle; above it the poi word
    // (ending left of centre) and the altitude (its number ending at the box's right edge, the unit past
    // it) on one baseline; below it what comes next; at the bottom the ascent laid flat.
    function gaugePage(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var bw = 0.317308, bh = 0.221154, by = 0.447115;
        Widgets.gauge(d, st, byUp);
        Widgets.bigDifficulty(d, st, 0.5, by, bw, bh, 0.1683);
        // The altitude and its unit, as shares of the screen's width: 30 and 18 px at 416.
        var font = d.semi(0.0721), small = d.semi(0.0433), base = 0.240385 + d.capHeight(font);
        Widgets.poi(d, st, 0.480769, base - d.capHeight(Widgets.poiFont(d)));
        var ft = Widgets.feet(), ax = 0.5 + bw / 2;
        d.textCapTop(ax, base - d.capHeight(font), font, Widgets.altitudeValue(st.u, ft).format("%d"), WHITE,
            Graphics.TEXT_JUSTIFY_RIGHT);
        d.textTop(ax + 0.007212, base - d.ascent(small), small, ft ? "ft" : "m", d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        Widgets.nextUp(d, st, 0.5, 0.629808);
        Widgets.ascentFlat(d, st, 0.298077, 0.701923, 0.754808, true);
    }

    // ---------------------------------------------------------------- page 9, version 1: a section preview

    // design/page-9.md: page 6b's gauge showing the selected section (the climber's until the user
    // steps), its difficulty in the middle between chevrons, its altitudes from foot to top above, its
    // name and its points' symbols below; the flat ascent at the bottom shows the climber.
    function sectionPage(d as Draw, st as Climb.State) as Void {
        var i = selected >= 0 ? selected : st.cur, n = Climb.count();
        var bw = SECTION_BW, bh = SECTION_BH, by = SECTION_BY;
        Widgets.selectionGauge(d, i);
        Widgets.bigDifficultyOf(d, Widgets.section(i, false), 0.5, by, bw, bh, 0.1683);
        Widgets.chevron(d, 0.5 - bw / 2 - 0.096154, by, -1, i > 0);
        Widgets.chevron(d, 0.5 + bw / 2 + 0.096154, by, 1, i < n - 1);
        // Above: "1380 to 1490 m", "to" and the unit grey, centred.
        // The altitudes, their unit and the name, as shares of the screen's width: 30, 18 and 26 px at 416.
        var ft = Widgets.feet(), k = ft ? 3.28084 : 1.0, font = d.semi(0.0721), small = d.semi(0.0433), bold = d.bold(0.0625);
        var a0 = Math.round((Climb.START_ALT + Climb.uAt(i)) * k).toNumber().format("%d");
        var a1 = Math.round((Climb.START_ALT + Climb.uAt(i + 1)) * k).toNumber().format("%d");
        var to = " to ", unit = ft ? "ft" : "m";
        var w0 = d.width(font, a0), wt = d.width(font, to), w1 = d.width(font, a1);
        var x = 0.5 - (w0 + wt + w1 + 0.007212 + d.width(small, unit)) / 2.0;
        var top = 0.240385, base = top + d.capHeight(font);
        d.textCapTop(x, top, font, a0, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapTop(x + w0, top, font, to, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapTop(x + w0 + wt, top, font, a1, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textTop(x + w0 + wt + w1 + 0.007212, base - d.ascent(small), small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        // Below: the name and the symbols of its points, standing on the name's baseline, centred.
        var kinds = Widgets.sectionPoints(i), ss = 0.048077, sg = 0.019231;
        // Cut with an ellipsis to leave room for the symbols, as the mock does.
        var name = Widgets.fitIn(d, bold, Climb.NAME[i], 0.576923 - kinds.size() * (ss + sg)), nw = d.width(bold, name);
        var nx = 0.5 - (nw + kinds.size() * (ss + sg)) / 2, nb = 0.629808 + d.capHeight(bold) / 2;
        d.textCapTop(nx, nb - d.capHeight(bold), bold, name, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        for (var p = 0; p < kinds.size(); p++) {
            Widgets.poiSymbol(d, kinds[p], nx + nw + sg + p * (ss + sg), nb, ss);
        }
        Widgets.ascentFlat(d, st, 0.298077, 0.701923, 0.754808, true);
    }

    // ---------------------------------------------------------------- page 7, version 1: from the front

    // design/page-7.md: the front view on the right; on the left the current difficulty group, 15 %
    // larger, its box centred vertically on the screen.
    function frontPage(d as Draw, st as Climb.State) as Void {
        Widgets.frontView(d, st, 0.442308, 0.884615, 0.153846, 0.846154);
        Widgets.currentDifficultyGroup(d, st, 0.278846, 0.5, 1.15, true);
    }

    // ---------------------------------------------------------------- page 8, version 1: the centre

    // design/page-8.md: the current difficulty group in the middle, 50 % larger, with point symbols after
    // safety signs; the ascent as a gauge around the edge.
    function centrePage(d as Draw, st as Climb.State) as Void {
        Widgets.ascentGauge(d, st, true);
        Widgets.currentDifficultyGroup(d, st, 0.5, 0.5, 1.5, false);
    }

    // ---------------------------------------------------------------- E. ladder and profile

    function combined(d as Draw, st as Climb.State) as Void {
        var tu = Climb.totalU().toFloat(), td = Climb.totalD().toFloat();
        ladder(d, st, 0.1875, 0.043269, 0.721154, 0.456731);
        route(d, st, 0.317308, 0.543269, 0.721154, 0.456731, 0.016827, 0.774038);
        var yp = 0.721154 - st.u / tu * 0.456731;
        d.dashed(0.245192, yp, 0.317308 + st.d / td * 0.543269 - 0.024038, yp, 0x555555, 0.002404);
        d.pointer(0.177885, yp, 0.016827, WHITE);
        d.text(0.5, 0.105769, d.semi(0.0529), Climb.clockText(st.clock()), d.MUTED);
        var head = st.climbed().format("%d") + " / " + Climb.totalU().format("%d") + " m";
        d.upMark(0.514423 - d.half(d.width(d.semi(0.1106), head)) - 0.033654, 0.197115, 0.016827, WHITE);
        d.text(0.514423, 0.192308, d.semi(0.1106), head, WHITE);
        d.text(0.350962, 0.841346, d.semi(0.0865), st.altitude().format("%d") + " m", WHITE);
        d.text(0.350962, 0.903846, d.semi(0.0529), "altitude", d.MUTED);
        d.text(0.653846, 0.841346, d.semi(0.0865), Climb.durationText(st.left()), WHITE);
        d.text(0.653846, 0.903846, d.semi(0.0529), "to top", d.MUTED);
    }

    // ---------------------------------------------------------------- B. vertical ladder

    function ladderPage(d as Draw, st as Climb.State) as Void {
        var tu = Climb.totalU().toFloat();
        var x0 = 0.230769, y0 = 0.855769, h = 0.701923;
        ladder(d, st, x0, 0.0625, y0, h);
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var y = y0 - Climb.uAt(Climb.EXIT_AT[e]) / tu * h;
            d.dashed(x0 - 0.009615, y, x0 + 0.072115, y, d.EXIT, 0.004808);
            d.exitMark(x0 + 0.100962, y);
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var y = y0 - Climb.uAt(i) / tu * h;
                d.line(x0 + 0.081731, y - 0.014423, x0 + 0.081731, y + 0.014423, d.REST, 0.009615);
            }
        }
        var yt = y0 - (st.u + st.band) / tu * h, yb = y0 - (st.u - st.band) / tu * h;
        d.frame(x0 - 0.014423, yt, 0.091346, yb - yt, 0x888888, 0.004808);
        d.pointer(x0 - 0.028846, y0 - st.u / tu * h, 0.019231, WHITE);
        d.textLeft(0.408654, 0.149038, d.semi(0.0865), Climb.clockText(st.clock()), d.MUTED);
        d.textLeft(0.408654, 0.269231, d.semi(0.2019), st.climbed().format("%d"), WHITE);
        d.textLeft(0.408654, 0.365385, d.semi(0.0529), "of " + Climb.totalU().format("%d") + ", " +
            (Climb.totalU() - st.climbed()).format("%d") + " to go", d.MUTED);
        d.textLeft(0.408654, 0.480769, d.semi(0.1106), st.altitude().format("%d") + " m", WHITE);
        d.textLeft(0.408654, 0.543269, d.semi(0.0529), "altitude", d.MUTED);
        d.textLeft(0.408654, 0.649038, d.semi(0.1106), Climb.durationText(st.left()), WHITE);
        d.textLeft(0.408654, 0.711538, d.semi(0.0529), "top at " + Climb.clockText(st.finish()), d.MUTED);
        var nh = st.nextHard();
        if (nh >= 0) {
            d.rect(0.408654, 0.764423, 0.033654, 0.033654, d.grade(Climb.GRADE[nh], false));
            d.textLeft(0.456731, 0.78125, d.semi(0.0529), Climb.NAME[nh] + " " + minutesText(st.untilStart(nh)) + "'", WHITE);
        }
    }

    // ---------------------------------------------------------------- C. where am I

    function whereAmI(d as Draw, st as Climb.State) as Void {
        d.text(0.5, 0.134615, d.semi(0.0529), "WHERE AM I", d.MUTED);
        d.text(0.5, 0.225962, d.semi(0.1106), st.altitude().format("%d") + " m", WHITE);
        var tu = Climb.totalU(), td = Climb.totalD();
        d.upMark(0.25, 0.317308, 0.014423, WHITE);
        d.textLeft(0.278846, 0.317308, d.semi(0.0529), st.climbed().format("%d") + " m", WHITE);
        d.textRight(0.769231, 0.317308, d.semi(0.0529), (tu - st.climbed()).format("%d") + " to go", d.MUTED);
        d.roundRect(0.230769, 0.350962, 0.538462, 0.019231, 0.009615, 0x222222);
        d.bar(0.230769, 0.350962, 0.538462 * st.u / tu, 0.019231, WHITE);
        var da = (st.d / 10).toNumber() * 10;
        d.textLeft(0.230769, 0.427885, d.semi(0.0529), "~" + da.format("%d") + " m along", WHITE);
        d.textRight(0.769231, 0.427885, d.semi(0.0529), "~" + (td - da).format("%d") + " to go", d.MUTED);
        d.roundRect(0.230769, 0.461538, 0.538462, 0.019231, 0.009615, 0x222222);
        d.bar(0.230769, 0.461538, 0.538462 * st.d / td, 0.019231, d.DIM_GREY);
        d.text(0.5, 0.557692, d.semi(0.0865), Climb.durationText(st.left()) + " to top, " + Climb.clockText(st.finish()), WHITE);
        var e = st.nextExit();
        var exitLine = "no exits left";
        if (e >= 0) {
            exitLine = (st.exitsLeft() == 1 ? "Last exit " : "Exit ") + minutesText(st.untilStart(Climb.EXIT_AT[e])) + " min";
        }
        d.exitMark(0.298077, 0.634615);
        d.textLeft(0.331731, 0.634615, d.semi(0.0529), exitLine, d.EXIT);
        d.text(0.360577, 0.730769, d.semi(0.0529), "so far", d.MUTED);
        d.text(0.639423, 0.730769, d.semi(0.0529), "ahead", d.MUTED);
        var done = st.hardestDone(), ahead = st.hardestAhead();
        if (done >= 0) {
            d.roundRect(0.293269, 0.769231, 0.134615, 0.072115, 0.014423, d.grade(done, false));
            d.text(0.360577, 0.805288, d.semi(0.0865), Climb.GRADE_NAME[done], BLACK);
        } else {
            d.text(0.360577, 0.805288, d.semi(0.0865), "-", d.MUTED);
        }
        if (ahead >= 0) {
            d.roundRect(0.572115, 0.769231, 0.134615, 0.072115, 0.014423, d.grade(ahead, false));
            d.text(0.639423, 0.805288, d.semi(0.0865), Climb.GRADE_NAME[ahead], BLACK);
        }
        d.text(0.5, 0.805288, d.semi(0.0865), ">", d.MUTED);
        if (ahead > done) {
            d.text(0.5, 0.899038, d.semi(0.0529), "harder ahead", d.MUTED);
        } else {
            d.text(0.5, 0.899038, d.semi(0.0529), "nothing harder", d.MUTED);
        }
    }

    // ---------------------------------------------------------------- G. what's next, the top at the top

    function whatsNext(d as Draw, st as Climb.State) as Void {
        d.text(0.5, 0.125, d.semi(0.0529), "NEXT", d.MUTED);
        var y = 0.192308;
        d.top(0.266827, y + 0.019231);
        d.textLeft(0.3125, y + 0.019231, d.semi(0.0865), "Top", WHITE);
        d.textRight(0.802885, y + 0.019231, d.semi(0.0865), Climb.clockText(st.finish()), WHITE);
        y += 0.072115;
        // The climber's section comes first; above it, as many of the next ones as fit.
        var last = st.cur, used = 0.0;
        for (var i = st.cur; i < Climb.count(); i++) {
            var hi = rowHeight(st, i);
            if (used + hi + 0.009615 > 0.649038) { break; }
            used += hi + 0.009615;
            last = i;
        }
        if (last < Climb.count() - 1) {
            d.text(0.266827, y + 0.004808, d.semi(0.0529), ":", d.MUTED);
            y += 0.043269;
        }
        for (var i = last; i >= st.cur; i--) {
            var now = i == st.cur;
            var h = rowHeight(st, i);
            var g = Climb.GRADE[i];
            if (g < 0) {
                d.frame(0.25, y, 0.033654, h, d.REST, 0.007212);
            } else {
                d.rect(0.25, y, 0.033654, h, d.grade(g, now));
            }
            for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
                if (Climb.EXIT_AT[e] == i) { d.exitMark(0.221154, y + h + 0.004808); }
            }
            var label = (g < 0 ? "rest" : Climb.GRADE_NAME[g]) + " " + Climb.NAME[i];
            d.textLeft(0.3125, y + h / 2, d.semi(0.0529), label, now ? d.MUTED : WHITE);
            d.textRight(0.802885, y + h / 2, d.semi(0.0529), now ? "now" : "+" + minutesText(st.untilStart(i)) + "'", d.MUTED);
            if (now) { d.pointer(0.235577, y + h / 2, 0.016827, WHITE); }
            y += h + 0.009615;
        }
    }

    // A row's height on the what's next page: its minutes, the climber's own section only what is left.
    function rowHeight(st as Climb.State, i as Number) as Float {
        var mins = i == st.cur ? (Climb.mAt(i + 1) - st.m) : Climb.MIN[i].toFloat();
        var h = mins * 0.008653846;
        return h < 0.0625 ? 0.0625 : h;
    }

    // ---------------------------------------------------------------- F. time strip

    function timeStrip(d as Draw, st as Climb.State) as Void {
        var tm = Climb.totalM().toFloat(), tu = Climb.totalU().toFloat();
        d.text(0.5, 0.134615, d.semi(0.0529), "TIMELINE", d.MUTED);
        d.text(0.5, 0.221154, d.semi(0.1106), Climb.durationText(st.elapsed()) + " / ~" +
            Climb.durationText(st.elapsed() + st.left()), WHITE);
        d.text(0.5, 0.288462, d.semi(0.0529), "done / expected", d.MUTED);
        var x0 = 0.139423, w = 0.721154;
        var xn = x0 + st.m / tm * w;
        for (var i = 0; i < Climb.count(); i++) {
            var a = x0 + Climb.mAt(i) / tm * w, b = x0 + Climb.mAt(i + 1) / tm * w;
            var g = Climb.GRADE[i];
            if (g < 0) { d.frame(a, 0.360577, b - a, 0.033654, d.REST, 0.007212); continue; }
            if (Climb.mAt(i + 1) <= st.m) {
                d.rect(a, 0.413462, b - a, 0.0625, d.grade(g, true));
            } else if (Climb.mAt(i) >= st.m) {
                d.rect(a, 0.413462, b - a, 0.0625, d.grade(g, false));
            } else {
                d.rect(a, 0.413462, xn - a, 0.0625, d.grade(g, true));
                d.rect(xn, 0.413462, b - xn, 0.0625, d.grade(g, false));
            }
        }
        // Height over time: planned in grey, climbed so far in white.
        for (var i = 0; i < Climb.count(); i++) {
            var a = x0 + Climb.mAt(i) / tm * w, b = x0 + Climb.mAt(i + 1) / tm * w;
            var ya = 0.6875 - Climb.uAt(i) / tu * 0.173077, yb = 0.6875 - Climb.uAt(i + 1) / tu * 0.173077;
            d.line(a, ya, b, yb, d.DIM_GREY, 0.004808);
            if (Climb.mAt(i) < st.m) {
                if (Climb.mAt(i + 1) <= st.m) {
                    d.line(a, ya, b, yb, WHITE, 0.007212);
                } else {
                    d.line(a, ya, xn, 0.6875 - st.u / tu * 0.173077, WHITE, 0.007212);
                }
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            d.exitMark(x0 + Climb.mAt(Climb.EXIT_AT[e]) / tm * w, 0.75);
        }
        d.line(xn, 0.336538, xn, 0.711538, WHITE, 0.004808);
        var nh = st.nextHard();
        if (nh >= 0) {
            d.text(0.5, 0.817308, d.semi(0.0529), Climb.GRADE_NAME[Climb.GRADE[nh]] + " " + Climb.NAME[nh] +
                " " + minutesText(st.untilStart(nh)) + " min", WHITE);
        }
        var nr = st.nextRest();
        d.text(0.5, 0.875, d.semi(0.0529), nr < 0 ? "no rest left" :
            "rest in " + minutesText(st.untilStart(nr)) + " min", d.MUTED);
    }

    // ---------------------------------------------------------------- large type

    function bigHeight(d as Draw, st as Climb.State) as Void {
        d.text(0.5, 0.264423, d.semi(0.0865), "CLIMBED", d.MUTED);
        d.text(0.5, 0.514423, d.semi(0.2019), st.climbed().format("%d"), WHITE);
        d.text(0.5, 0.735577, d.semi(0.1106), "m of " + Climb.totalU().format("%d"), d.MUTED);
        d.roundRect(0.235577, 0.817308, 0.528846, 0.028846, 0.014423, 0x333333);
        d.bar(0.235577, 0.817308, 0.528846 * st.u / Climb.totalU(), 0.028846, WHITE);
    }

    function bigNextHard(d as Draw, st as Climb.State) as Void {
        var nh = st.nextHard();
        if (nh < 0) {
            d.text(0.5, 0.456731, d.semi(0.1106), "No more", WHITE);
            d.text(0.5, 0.576923, d.semi(0.1106), "hard parts", WHITE);
            return;
        }
        d.roundRect(0.307692, 0.168269, 0.384615, 0.230769, 0.033654, d.grade(Climb.GRADE[nh], false));
        d.text(0.5, 0.283654, d.semi(0.1106), Climb.GRADE_NAME[Climb.GRADE[nh]], BLACK);
        d.textRight(0.576923, 0.605769, d.semi(0.2019), minutesText(st.untilStart(nh)), WHITE);
        d.textLeft(0.605769, 0.649038, d.semi(0.1106), "min", WHITE);
        d.text(0.5, 0.817308, d.semi(0.1106), Climb.NAME[nh], d.MUTED);
    }

    function bigTop(d as Draw, st as Climb.State) as Void {
        d.text(0.5, 0.264423, d.semi(0.0865), "TO THE TOP", d.MUTED);
        d.text(0.5, 0.514423, d.semi(0.2019), Climb.durationText(st.left()), WHITE);
        d.text(0.5, 0.75, d.semi(0.1106), "at " + Climb.clockText(st.finish()), d.MUTED);
    }

    function bigExit(d as Draw, st as Climb.State) as Void {
        var e = st.nextExit();
        if (e < 0) {
            d.text(0.5, 0.408654, d.semi(0.0865), "EXITS", d.EXIT);
            d.text(0.5, 0.552885, d.semi(0.1106), "none left", 0xef476f);
            return;
        }
        var last = st.exitsLeft() == 1;
        d.text(0.5, 0.264423, d.semi(0.0865), last ? "LAST EXIT" : "NEXT EXIT", d.EXIT);
        d.textRight(0.576923, 0.514423, d.semi(0.2019), minutesText(st.untilStart(Climb.EXIT_AT[e])), WHITE);
        d.textLeft(0.605769, 0.557692, d.semi(0.1106), "min", WHITE);
        if (last) { d.text(0.5, 0.75, d.semi(0.1106), "then none", 0xef476f); }
    }
}
