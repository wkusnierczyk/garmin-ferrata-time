using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The pages, as in the design sketch, drawn in its 416 px coordinates.
module Pages {

    const COUNT = 20;
    // Page 9, the section preview, and the section it shows (-1: the climber's).
    const SECTION_PAGE = 9;
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
            pen as Number, exitTo as Float) as Void {
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        // Exits drop away, dashed.
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var i = Climb.EXIT_AT[e];
            var ex = x0 + Climb.dAt(i) / td * w, ey = y0 - Climb.uAt(i) / tu * h;
            d.dashed(ex, ey, ex + 24, exitTo, d.EXIT, 2);
            d.exitMark(ex + 28, exitTo + 12);
        }
        // How sure the position is: the route between the heights it could be at.
        var lo = Climb.firstDistanceAt(st.u - Climb.UNCERTAINTY);
        var hi = Climb.lastDistanceAt(st.u + Climb.UNCERTAINTY);
        var band = 0x474747;
        var px = x0 + lo / td * w, py = y0 - Climb.heightAtDistance(lo) / tu * h;
        for (var dd = lo + 4; dd <= hi; dd += 4) {
            var nx = x0 + dd / td * w, ny = y0 - Climb.heightAtDistance(dd) / tu * h;
            d.line(px, py, nx, ny, band, 22);
            px = nx; py = ny;
        }
        // The sections: grade colours, climbed parts dimmed, rests as blue stretches beneath.
        var cx = x0 + st.d / td * w, cy = y0 - st.u / tu * h;
        for (var i = 0; i < Climb.count(); i++) {
            var ax = x0 + Climb.dAt(i) / td * w, ay = y0 - Climb.uAt(i) / tu * h;
            var bx = x0 + Climb.dAt(i + 1) / td * w, by = y0 - Climb.uAt(i + 1) / tu * h;
            var g = Climb.GRADE[i];
            if (g < 0) { d.line(ax, ay + 11, bx, by + 11, d.REST, 4); continue; }
            if (Climb.dAt(i + 1) <= st.d) {
                d.line(ax, ay, bx, by, d.grade(g, true), pen);
            } else if (Climb.dAt(i) >= st.d) {
                d.line(ax, ay, bx, by, d.grade(g, false), pen);
            } else {
                d.line(ax, ay, cx, cy, d.grade(g, true), pen);
                d.line(cx, cy, bx, by, d.grade(g, false), pen);
            }
        }
        d.dot(cx, cy, 7, WHITE);
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
            if (ya - yb < 4) { yb = ya - 4; }
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

    function profile(d as Draw, st as Climb.State) as Void {
        route(d, st, 62.0, 292.0, 262.0, 150.0, 8, 284.0);
        var td = Climb.totalD().toFloat(), tu = Climb.totalU().toFloat();
        for (var i = st.cur + 1; i < Climb.count(); i++) {
            if (Climb.GRADE[i] >= 3 && Climb.UP[i] >= 60) {
                var mx = 62 + (Climb.dAt(i) + Climb.dAt(i + 1)) / 2.0 / td * 292;
                var my = 262 - (Climb.uAt(i) + Climb.uAt(i + 1)) / 2.0 / tu * 150;
                d.textRight(mx - 12, my, Graphics.FONT_XTINY, angle(i), 0xbbbbbb);
            }
        }
        d.text(208, 48, Graphics.FONT_SMALL, Climb.clockText(st.clock()), WHITE);
        d.text(208, 76, Graphics.FONT_XTINY, st.altitude().format("%d") + " m", d.MUTED);
        d.upMark(104, 324, 7, WHITE);
        d.textLeft(116, 322, Graphics.FONT_MEDIUM, st.climbed().format("%d"), WHITE);
        d.text(136, 352, Graphics.FONT_XTINY, "of " + Climb.totalU().format("%d") + " m", d.MUTED);
        d.text(284, 322, Graphics.FONT_MEDIUM, Climb.durationText(st.left()), WHITE);
        d.text(284, 352, Graphics.FONT_XTINY, "top " + Climb.clockText(st.finish()), d.MUTED);
        d.text(208, 380, Graphics.FONT_XTINY, "~" + ((st.d / 10).toNumber() * 10).format("%d") + "/" +
            Climb.totalD().format("%d") + " m along", d.MUTED);
    }

    // ---------------------------------------------------------------- page 1, version 1: the profile alone

    // design/page-1.md: profile and ascent share the start and span a rectangle; the difficulty
    // boxes in its lower right, the altitude group in its upper left.
    function profileAlone(d as Draw, st as Climb.State) as Void {
        var x0 = 92.0, w = 260.0, y0 = 318.0, h = 226.0;
        Widgets.profile(d, st, x0, w, y0, h);
        Widgets.ascent(d, st, x0, y0, h, true);
        Widgets.difficulty(d, st, x0 + w - Widgets.difficultyReach(), y0, false);
        Widgets.altitudeGroup(d, st, x0 + Widgets.RING_OUTER + 8, y0 - h);
    }

    // ---------------------------------------------------------------- page 2, version 1: the difficulty column

    // design/page-2.md: the difficulty column group, centred, with altitudes at the outer edges too.
    function columnPage(d as Draw, st as Climb.State) as Void {
        Widgets.columnGroup(d, st, 208.0, true);
    }

    // ---------------------------------------------------------------- page 3, version 1: side by side

    // design/page-3.md: the ascent on the left and the difficulty column group on the right, with equal
    // space before, between and after them across 56 to 360 px; the ascent as tall as the column; the
    // current altitude centred at the top.
    function sideBySide(d as Draw, st as Climb.State) as Void {
        var left = 56.0, right = 360.0, cy = 228.0;
        var ascLeft = Widgets.ascentLeft(d), ascW = ascLeft + Widgets.RING_OUTER;
        // Never negative: with wider fonts the widgets would touch rather than overlap.
        var gap = (right - left - ascW - Widgets.columnGroupWidth(d)) / 3;
        if (gap < 0) { gap = 0.0; }
        var lx = left + gap + ascLeft, reach = Widgets.columnReach();
        Widgets.ascent(d, st, lx, cy + reach, 2 * reach, true);
        Widgets.columnGroupAt(d, st, lx + Widgets.RING_OUTER + gap, cy, true);
        Widgets.altitudeCentred(d, st, 208.0, 40.0);
    }

    // ---------------------------------------------------------------- pages 4 and 5: the difficulty stack

    // Page 4: the stack by ascent, 3 px per metre climbed, altitudes every 20 m (100 ft).
    function stackByAscent(d as Draw, st as Climb.State) as Void {
        Widgets.stack(d, st, true, 164.0, 64.0, 352.0, 3.0, true, 20, 100, 200);
    }

    // Page 5: the stack by path, 1 px per metre along the route, centred as a group (its tick labels,
    // its column, the names' gap and room for names), with the ascent as a gauge around the edge;
    // names stop inside it.
    function stackByPath(d as Draw, st as Climb.State) as Void {
        var labels = Widgets.stackLabels(d);
        var left = 208 - (labels + Widgets.STACK_W + Widgets.NAME_GAP + Widgets.STACK_NAMES) / 2 + labels;
        Widgets.ascentGauge(d, st, true);
        Widgets.stack(d, st, false, left, 64.0, 352.0, 1.0, true, 10, 50, Widgets.AG_R - 14);
    }

    // ---------------------------------------------------------------- pages 6a and 6b, version 1: the gauge

    // design/page-6.md: the gauge, each section's arc its length along the route (6a) or the metres it
    // climbs (byUp, 6b); the current difficulty large in the middle; above it the poi word
    // (ending left of centre) and the altitude (its number ending at the box's right edge, the unit past
    // it) on one baseline; below it what comes next; at the bottom the ascent laid flat.
    function gaugePage(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var bw = 132.0, bh = 92.0, by = 186.0;
        Widgets.gauge(d, st, byUp);
        Widgets.bigDifficulty(d, st, 208.0, by, bw, bh, 64);
        var font = Graphics.FONT_TINY, base = 100 + d.capHeight(font);
        Widgets.poi(d, st, 200.0, base - d.capHeight(Graphics.FONT_XTINY));
        var ft = Widgets.feet(), ax = 208 + bw / 2;
        d.textCapTop(ax, base - d.capHeight(font), font, Widgets.altitudeValue(st.u, ft).format("%d"), WHITE,
            Graphics.TEXT_JUSTIFY_RIGHT);
        d.textTop(ax + 3, base - d.ascent(Graphics.FONT_XTINY), Graphics.FONT_XTINY, ft ? "ft" : "m", d.MUTED,
            Graphics.TEXT_JUSTIFY_LEFT);
        Widgets.nextUp(d, st, 208.0, 262.0);
        Widgets.ascentFlat(d, st, 124.0, 292.0, 314.0, true);
    }

    // ---------------------------------------------------------------- page 9, version 1: a section preview

    // design/page-9.md: page 6b's gauge showing the selected section (the climber's until the user
    // steps), its difficulty in the middle between chevrons, its altitudes from foot to top above, its
    // name and its points' symbols below; the flat ascent at the bottom shows the climber.
    function sectionPage(d as Draw, st as Climb.State) as Void {
        var i = selected >= 0 ? selected : st.cur, n = Climb.count();
        var bw = 132.0, bh = 92.0, by = 186.0;
        Widgets.selectionGauge(d, i);
        Widgets.bigDifficultyOf(d, Widgets.section(i, false), 208.0, by, bw, bh, 64);
        Widgets.chevron(d, 208 - bw / 2 - 40, by, -1, i > 0);
        Widgets.chevron(d, 208 + bw / 2 + 40, by, 1, i < n - 1);
        // Above: "1380 to 1490 m", "to" and the unit grey, centred.
        var ft = Widgets.feet(), k = ft ? 3.28084 : 1.0, font = Graphics.FONT_TINY, small = Graphics.FONT_XTINY;
        var a0 = Math.round((Climb.START_ALT + Climb.uAt(i)) * k).toNumber().format("%d");
        var a1 = Math.round((Climb.START_ALT + Climb.uAt(i + 1)) * k).toNumber().format("%d");
        var to = " to ", unit = ft ? "ft" : "m";
        var w0 = d.width(font, a0), wt = d.width(font, to), w1 = d.width(font, a1);
        var x = 208 - (w0 + wt + w1 + 3 + d.width(small, unit)) / 2.0;
        var base = 100 + d.capHeight(font), top = base - d.capHeight(font);
        d.textCapTop(x, top, font, a0, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapTop(x + w0, top, font, to, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapTop(x + w0 + wt, top, font, a1, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        d.textTop(x + w0 + wt + w1 + 3, base - d.ascent(small), small, unit, d.MUTED, Graphics.TEXT_JUSTIFY_LEFT);
        // Below: the name and the symbols of its points, standing on the name's baseline, centred.
        var kinds = Widgets.sectionPoints(i), ss = 20.0, sg = 8.0;
        var name = Climb.NAME[i], nw = d.width(font, name);
        var nx = 208 - (nw + kinds.size() * (ss + sg)) / 2, nb = 262 + d.capHeight(font) / 2;
        d.textCapTop(nx, nb - d.capHeight(font), font, name, WHITE, Graphics.TEXT_JUSTIFY_LEFT);
        for (var p = 0; p < kinds.size(); p++) {
            Widgets.poiSymbol(d, kinds[p], nx + nw + sg + p * (ss + sg), nb, ss);
        }
        Widgets.ascentFlat(d, st, 124.0, 292.0, 314.0, true);
    }

    // ---------------------------------------------------------------- page 7, version 1: from the front

    // design/page-7.md: the front view on the right; on the left the current difficulty group, 15 %
    // larger, its box centred vertically on the screen.
    function frontPage(d as Draw, st as Climb.State) as Void {
        Widgets.frontView(d, st, 184.0, 368.0, 64.0, 352.0);
        Widgets.currentDifficultyGroup(d, st, 116.0, 208.0, 1.15, true);
    }

    // ---------------------------------------------------------------- page 8, version 1: the centre

    // design/page-8.md: the current difficulty group in the middle, 50 % larger, with point symbols after
    // safety signs; the ascent as a gauge around the edge.
    function centrePage(d as Draw, st as Climb.State) as Void {
        Widgets.ascentGauge(d, st, true);
        Widgets.currentDifficultyGroup(d, st, 208.0, 208.0, 1.5, false);
    }

    // ---------------------------------------------------------------- E. ladder and profile

    function combined(d as Draw, st as Climb.State) as Void {
        var tu = Climb.totalU().toFloat(), td = Climb.totalD().toFloat();
        ladder(d, st, 78.0, 18.0, 300.0, 190.0);
        route(d, st, 132.0, 226.0, 300.0, 190.0, 7, 322.0);
        var yp = 300 - st.u / tu * 190;
        d.dashed(102, yp, 132 + st.d / td * 226 - 10, yp, 0x555555, 1);
        d.pointer(74, yp, 7, WHITE);
        d.text(208, 44, Graphics.FONT_XTINY, Climb.clockText(st.clock()), d.MUTED);
        var head = st.climbed().format("%d") + " / " + Climb.totalU().format("%d") + " m";
        d.upMark(214 - d.width(Graphics.FONT_MEDIUM, head) / 2 - 14, 82, 7, WHITE);
        d.text(214, 80, Graphics.FONT_MEDIUM, head, WHITE);
        d.text(146, 350, Graphics.FONT_SMALL, st.altitude().format("%d") + " m", WHITE);
        d.text(146, 376, Graphics.FONT_XTINY, "altitude", d.MUTED);
        d.text(272, 350, Graphics.FONT_SMALL, Climb.durationText(st.left()), WHITE);
        d.text(272, 376, Graphics.FONT_XTINY, "to top", d.MUTED);
    }

    // ---------------------------------------------------------------- B. vertical ladder

    function ladderPage(d as Draw, st as Climb.State) as Void {
        var tu = Climb.totalU().toFloat();
        var x0 = 96.0, y0 = 356.0, h = 292.0;
        ladder(d, st, x0, 26.0, y0, h);
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            var y = y0 - Climb.uAt(Climb.EXIT_AT[e]) / tu * h;
            d.dashed(x0 - 4, y, x0 + 30, y, d.EXIT, 2);
            d.exitMark(x0 + 42, y);
        }
        for (var i = 0; i < Climb.count(); i++) {
            if (Climb.GRADE[i] < 0) {
                var y = y0 - Climb.uAt(i) / tu * h;
                d.line(x0 + 34, y - 6, x0 + 34, y + 6, d.REST, 4);
            }
        }
        var yt = y0 - (st.u + Climb.UNCERTAINTY) / tu * h, yb = y0 - (st.u - Climb.UNCERTAINTY) / tu * h;
        d.frame(x0 - 6, yt, 38, yb - yt, 0x888888, 2);
        d.pointer(x0 - 12, y0 - st.u / tu * h, 8, WHITE);
        d.textLeft(170, 62, Graphics.FONT_SMALL, Climb.clockText(st.clock()), d.MUTED);
        d.textLeft(170, 112, Graphics.FONT_NUMBER_MEDIUM, st.climbed().format("%d"), WHITE);
        d.textLeft(170, 152, Graphics.FONT_XTINY, "of " + Climb.totalU().format("%d") + ", " +
            (Climb.totalU() - st.climbed()).format("%d") + " to go", d.MUTED);
        d.textLeft(170, 200, Graphics.FONT_MEDIUM, st.altitude().format("%d") + " m", WHITE);
        d.textLeft(170, 226, Graphics.FONT_XTINY, "altitude", d.MUTED);
        d.textLeft(170, 270, Graphics.FONT_MEDIUM, Climb.durationText(st.left()), WHITE);
        d.textLeft(170, 296, Graphics.FONT_XTINY, "top at " + Climb.clockText(st.finish()), d.MUTED);
        var nh = st.nextHard();
        if (nh >= 0) {
            d.rect(170, 318, 14, 14, d.grade(Climb.GRADE[nh], false));
            d.textLeft(190, 325, Graphics.FONT_XTINY, Climb.NAME[nh] + " " + minutesText(st.untilStart(nh)) + "'", WHITE);
        }
    }

    // ---------------------------------------------------------------- C. where am I

    function whereAmI(d as Draw, st as Climb.State) as Void {
        d.text(208, 56, Graphics.FONT_XTINY, "WHERE AM I", d.MUTED);
        d.text(208, 94, Graphics.FONT_LARGE, st.altitude().format("%d") + " m", WHITE);
        var tu = Climb.totalU(), td = Climb.totalD();
        d.upMark(104, 132, 6, WHITE);
        d.textLeft(116, 132, Graphics.FONT_XTINY, st.climbed().format("%d") + " m", WHITE);
        d.textRight(320, 132, Graphics.FONT_XTINY, (tu - st.climbed()).format("%d") + " to go", d.MUTED);
        d.roundRect(96, 146, 224, 8, 4, 0x222222);
        d.bar(96, 146, 224 * st.u / tu, 8, WHITE);
        var da = (st.d / 10).toNumber() * 10;
        d.textLeft(96, 178, Graphics.FONT_XTINY, "~" + da.format("%d") + " m along", WHITE);
        d.textRight(320, 178, Graphics.FONT_XTINY, "~" + (td - da).format("%d") + " to go", d.MUTED);
        d.roundRect(96, 192, 224, 8, 4, 0x222222);
        d.bar(96, 192, 224 * st.d / td, 8, d.DIM_GREY);
        d.text(208, 232, Graphics.FONT_TINY, Climb.durationText(st.left()) + " to top, " + Climb.clockText(st.finish()), WHITE);
        var e = st.nextExit();
        var exitLine = "no exits left";
        if (e >= 0) {
            exitLine = (st.exitsLeft() == 1 ? "Last exit " : "Exit ") + minutesText(st.untilStart(Climb.EXIT_AT[e])) + " min";
        }
        d.exitMark(124, 264);
        d.textLeft(138, 264, Graphics.FONT_XTINY, exitLine, d.EXIT);
        d.text(150, 304, Graphics.FONT_XTINY, "so far", d.MUTED);
        d.text(266, 304, Graphics.FONT_XTINY, "ahead", d.MUTED);
        var done = st.hardestDone(), ahead = st.hardestAhead();
        if (done >= 0) {
            d.roundRect(122, 320, 56, 30, 6, d.grade(done, false));
            d.text(150, 335, Graphics.FONT_SMALL, Climb.GRADE_NAME[done], BLACK);
        } else {
            d.text(150, 335, Graphics.FONT_SMALL, "-", d.MUTED);
        }
        if (ahead >= 0) {
            d.roundRect(238, 320, 56, 30, 6, d.grade(ahead, false));
            d.text(266, 335, Graphics.FONT_SMALL, Climb.GRADE_NAME[ahead], BLACK);
        }
        d.text(208, 335, Graphics.FONT_SMALL, ">", d.MUTED);
        if (ahead > done) {
            d.text(208, 374, Graphics.FONT_XTINY, "harder ahead", d.MUTED);
        } else {
            d.text(208, 374, Graphics.FONT_XTINY, "nothing harder", d.MUTED);
        }
    }

    // ---------------------------------------------------------------- G. what's next, the top at the top

    function whatsNext(d as Draw, st as Climb.State) as Void {
        d.text(208, 52, Graphics.FONT_XTINY, "NEXT", d.MUTED);
        var y = 80.0;
        d.top(111, y + 8);
        d.textLeft(130, y + 8, Graphics.FONT_TINY, "Top", WHITE);
        d.textRight(334, y + 8, Graphics.FONT_TINY, Climb.clockText(st.finish()), WHITE);
        y += 30;
        // The climber's section comes first; above it, as many of the next ones as fit.
        var last = st.cur, used = 0.0;
        for (var i = st.cur; i < Climb.count(); i++) {
            var hi = rowHeight(st, i);
            if (used + hi + 4 > 270) { break; }
            used += hi + 4;
            last = i;
        }
        if (last < Climb.count() - 1) {
            d.text(111, y + 2, Graphics.FONT_XTINY, ":", d.MUTED);
            y += 18;
        }
        for (var i = last; i >= st.cur; i--) {
            var now = i == st.cur;
            var h = rowHeight(st, i);
            var g = Climb.GRADE[i];
            if (g < 0) {
                d.frame(104, y, 14, h, d.REST, 3);
            } else {
                d.rect(104, y, 14, h, d.grade(g, now));
            }
            for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
                if (Climb.EXIT_AT[e] == i) { d.exitMark(92, y + h + 2); }
            }
            var label = (g < 0 ? "rest" : Climb.GRADE_NAME[g]) + " " + Climb.NAME[i];
            d.textLeft(130, y + h / 2, Graphics.FONT_XTINY, label, now ? d.MUTED : WHITE);
            d.textRight(334, y + h / 2, Graphics.FONT_XTINY, now ? "now" : "+" + minutesText(st.untilStart(i)) + "'", d.MUTED);
            if (now) { d.pointer(98, y + h / 2, 7, WHITE); }
            y += h + 4;
        }
    }

    // A row's height on the what's next page: its minutes, the climber's own section only what is left.
    function rowHeight(st as Climb.State, i as Number) as Float {
        var mins = i == st.cur ? (Climb.mAt(i + 1) - st.m) : Climb.MIN[i].toFloat();
        var h = mins * 3.6;
        return h < 26 ? 26.0 : h;
    }

    // ---------------------------------------------------------------- F. time strip

    function timeStrip(d as Draw, st as Climb.State) as Void {
        var tm = Climb.totalM().toFloat(), tu = Climb.totalU().toFloat();
        d.text(208, 56, Graphics.FONT_XTINY, "TIMELINE", d.MUTED);
        d.text(208, 92, Graphics.FONT_MEDIUM, Climb.durationText(st.elapsed()) + " / ~" +
            Climb.durationText(st.elapsed() + st.left()), WHITE);
        d.text(208, 120, Graphics.FONT_XTINY, "done / expected", d.MUTED);
        var x0 = 58.0, w = 300.0;
        var xn = x0 + st.m / tm * w;
        for (var i = 0; i < Climb.count(); i++) {
            var a = x0 + Climb.mAt(i) / tm * w, b = x0 + Climb.mAt(i + 1) / tm * w;
            var g = Climb.GRADE[i];
            if (g < 0) { d.frame(a, 150, b - a, 14, d.REST, 3); continue; }
            if (Climb.mAt(i + 1) <= st.m) {
                d.rect(a, 172, b - a, 26, d.grade(g, true));
            } else if (Climb.mAt(i) >= st.m) {
                d.rect(a, 172, b - a, 26, d.grade(g, false));
            } else {
                d.rect(a, 172, xn - a, 26, d.grade(g, true));
                d.rect(xn, 172, b - xn, 26, d.grade(g, false));
            }
        }
        // Height over time: planned in grey, climbed so far in white.
        for (var i = 0; i < Climb.count(); i++) {
            var a = x0 + Climb.mAt(i) / tm * w, b = x0 + Climb.mAt(i + 1) / tm * w;
            var ya = 286 - Climb.uAt(i) / tu * 72, yb = 286 - Climb.uAt(i + 1) / tu * 72;
            d.line(a, ya, b, yb, d.DIM_GREY, 2);
            if (Climb.mAt(i) < st.m) {
                if (Climb.mAt(i + 1) <= st.m) {
                    d.line(a, ya, b, yb, WHITE, 3);
                } else {
                    d.line(a, ya, xn, 286 - st.u / tu * 72, WHITE, 3);
                }
            }
        }
        for (var e = 0; e < Climb.EXIT_AT.size(); e++) {
            d.exitMark(x0 + Climb.mAt(Climb.EXIT_AT[e]) / tm * w, 312);
        }
        d.line(xn, 140, xn, 296, WHITE, 2);
        var nh = st.nextHard();
        if (nh >= 0) {
            d.text(208, 340, Graphics.FONT_XTINY, Climb.GRADE_NAME[Climb.GRADE[nh]] + " " + Climb.NAME[nh] +
                " " + minutesText(st.untilStart(nh)) + " min", WHITE);
        }
        var nr = st.nextRest();
        d.text(208, 364, Graphics.FONT_XTINY, nr < 0 ? "no rest left" :
            "rest in " + minutesText(st.untilStart(nr)) + " min", d.MUTED);
    }

    // ---------------------------------------------------------------- large type

    function bigHeight(d as Draw, st as Climb.State) as Void {
        d.text(208, 110, Graphics.FONT_SMALL, "CLIMBED", d.MUTED);
        d.text(208, 214, Graphics.FONT_NUMBER_THAI_HOT, st.climbed().format("%d"), WHITE);
        d.text(208, 306, Graphics.FONT_MEDIUM, "m of " + Climb.totalU().format("%d"), d.MUTED);
        d.roundRect(98, 340, 220, 12, 6, 0x333333);
        d.bar(98, 340, 220 * st.u / Climb.totalU(), 12, WHITE);
    }

    function bigNextHard(d as Draw, st as Climb.State) as Void {
        var nh = st.nextHard();
        if (nh < 0) {
            d.text(208, 190, Graphics.FONT_LARGE, "No more", WHITE);
            d.text(208, 240, Graphics.FONT_LARGE, "hard parts", WHITE);
            return;
        }
        d.roundRect(128, 70, 160, 96, 14, d.grade(Climb.GRADE[nh], false));
        d.text(208, 118, Graphics.FONT_LARGE, Climb.GRADE_NAME[Climb.GRADE[nh]], BLACK);
        d.textRight(240, 252, Graphics.FONT_NUMBER_HOT, minutesText(st.untilStart(nh)), WHITE);
        d.textLeft(252, 270, Graphics.FONT_LARGE, "min", WHITE);
        d.text(208, 340, Graphics.FONT_MEDIUM, Climb.NAME[nh], d.MUTED);
    }

    function bigTop(d as Draw, st as Climb.State) as Void {
        d.text(208, 110, Graphics.FONT_SMALL, "TO THE TOP", d.MUTED);
        d.text(208, 214, Graphics.FONT_NUMBER_THAI_HOT, Climb.durationText(st.left()), WHITE);
        d.text(208, 312, Graphics.FONT_LARGE, "at " + Climb.clockText(st.finish()), d.MUTED);
    }

    function bigExit(d as Draw, st as Climb.State) as Void {
        var e = st.nextExit();
        if (e < 0) {
            d.text(208, 170, Graphics.FONT_SMALL, "EXITS", d.EXIT);
            d.text(208, 230, Graphics.FONT_LARGE, "none left", 0xef476f);
            return;
        }
        var last = st.exitsLeft() == 1;
        d.text(208, 110, Graphics.FONT_SMALL, last ? "LAST EXIT" : "NEXT EXIT", d.EXIT);
        d.textRight(240, 214, Graphics.FONT_NUMBER_HOT, minutesText(st.untilStart(Climb.EXIT_AT[e])), WHITE);
        d.textLeft(252, 232, Graphics.FONT_LARGE, "min", WHITE);
        if (last) { d.text(208, 312, Graphics.FONT_LARGE, "then none", 0xef476f); }
    }
}
