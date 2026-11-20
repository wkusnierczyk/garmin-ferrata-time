using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The pages, as in the design sketch, drawn in its 416 px coordinates.
module Pages {

    const COUNT = 13;
    const WHITE = Graphics.COLOR_WHITE;
    const BLACK = Graphics.COLOR_BLACK;

    function draw(page as Number, d as Draw, st as Climb.State) as Void {
        d.clear();
        switch (page) {
            case 0: { d.colours = d.HEAT_AMBER; profileAlone(d, st); break; }
            case 1: { d.colours = d.HEAT_AMBER; columnPage(d, st); break; }
            case 2: { d.colours = d.HEAT_AMBER; sideBySide(d, st); break; }
            case 3: { profile(d, st); break; }
            case 4: { combined(d, st); break; }
            case 5: { ladderPage(d, st); break; }
            case 6: { whereAmI(d, st); break; }
            case 7: { whatsNext(d, st); break; }
            case 8: { timeStrip(d, st); break; }
            case 9: { bigHeight(d, st); break; }
            case 10: { bigNextHard(d, st); break; }
            case 11: { bigTop(d, st); break; }
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
        var gap = (right - left - ascW - Widgets.columnGroupWidth(d)) / 3;
        var lx = left + gap + ascLeft, reach = Widgets.columnReach();
        Widgets.ascent(d, st, lx, cy + reach, 2 * reach, true);
        Widgets.columnGroupAt(d, st, lx + Widgets.RING_OUTER + gap, cy, true);
        Widgets.altitudeCentred(d, st, 208.0, 40.0);
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
