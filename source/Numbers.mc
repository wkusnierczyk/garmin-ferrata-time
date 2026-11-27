using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The number pages, 16 to 37 of the pages mock (design/demo/page-16.html and on; the Daubenhorn and
// Sulzfluh grids), one issue each (#67 on), ported from the demo the owner checked on the watch
// (2026-11-27): so far pages 16 to 19 (#67), progress as done and total (design/page-16.md). Sizes are
// shares of the screen's width, the mocks' px at 416 divided by 416. A size that depends on the route is
// chosen once per route, as the mocks choose it (the largest that keeps 6 % of the width clear of the
// edge), from widths scaled from one measured font, so the candidate sizes need not be loaded; the
// number fonts are tabular, so one digit stands for all, and a value's space is laid out from the widest
// it can get, so nothing moves as it changes.
module Numbers {

    const WHITE = Graphics.COLOR_WHITE;
    const GREY = 0x99aaaa;
    const TOTAL_GREY = 0xc8d0d0;

    // Font sizes (shares): SemiBold 104, 84, 64, 52, 40 and 32 px at 416.
    const F104 = 0.25;
    const F84 = 0.2019;
    const F64 = 0.1538;
    const F52 = 0.125;
    const F40 = 0.0962;
    const F32 = 0.0769;
    // Capitals and digits stand 0.71 of the size above the baseline (the mocks' CAP).
    const CAP = 0.71;
    // The content keeps 6 % of the width clear of the edge.
    const FIT_R = 0.44;

    // ---------------------------------------------------------------- per route

    // Sizes worked out once per route, by page (from 0 for page 16).
    var cache as Dictionary<Number, Array<Float>> = {} as Dictionary<Number, Array<Float>>;
    // Digit and colon widths of the 52 px font, from which other sizes are scaled.
    var digit52 as Float = 0.0;
    var colon52 as Float = 0.0;

    // Climb.use calls this, through Widgets.forgetRoute, on every change of route or part.
    function forget() as Void {
        cache = {} as Dictionary<Number, Array<Float>>;
    }

    function scaled(d as Draw) as Void {
        if (digit52 == 0.0) {
            var f = d.semi(F52);
            digit52 = d.width(f, "0");
            colon52 = d.width(f, ":");
        }
    }

    // A digit's and a colon's width at size f, scaled from the 52 px font.
    function dw(d as Draw, f as Float) as Float { scaled(d); return digit52 * f / F52; }
    function cw(d as Draw, f as Float) as Float { scaled(d); return colon52 * f / F52; }

    // The width of a number or an h:mm at size f, from the scaled digit and colon.
    function numberWidth(d as Draw, s as String, f as Float) as Float {
        return s.length() * dw(d, f) + (s.find(":") != null ? cw(d, f) - dw(d, f) : 0.0);
    }

    // Whether the box [x0, y0, x1, y1] keeps clear of the edge: every corner within FIT_R.
    function fits(x0 as Float, y0 as Float, x1 as Float, y1 as Float) as Boolean {
        return corner(x0, y0) && corner(x1, y0) && corner(x0, y1) && corner(x1, y1);
    }

    function corner(x as Float, y as Float) as Boolean {
        var dx = x - 0.5, dy = y - 0.5;
        return dx * dx + dy * dy <= FIT_R * FIT_R;
    }

    // ---------------------------------------------------------------- formats

    function hmm(m as Float) as String {
        var r = Math.round(m < 0 ? 0 : m).toNumber();
        return (r / 60).format("%d") + ":" + (r % 60).format("%02d");
    }

    function int(v as Float) as String { return Math.round(v).toNumber().format("%d"); }

    // ---------------------------------------------------------------- text

    function left(d as Draw, x as Float, y as Float, f as Graphics.FontType, s as String, c as Number) as Void {
        d.textBase(x, y, f, s, c, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function right(d as Draw, x as Float, y as Float, f as Graphics.FontType, s as String, c as Number) as Void {
        d.textBase(x, y, f, s, c, Graphics.TEXT_JUSTIFY_RIGHT);
    }

    // ---------------------------------------------------------------- pages 16 to 19: done of total

    // The rows' symbols, Symbols.row's (the flow's figures stand after the same): the path (blue), the
    // ascent (orange) and the stopwatch (green).
    const ROW_SYMBOL = [:path, :ascent, :watch] as Array<Symbol>;

    // A row's value done and total: [done, total, unit]. 0 the distance along the path (each section's
    // length and height combined), 1 the height gained, 2 the time passed (the clock, pauses included)
    // of the estimate: the time passed and what is left of the guidebook's at the pace so far.
    function row(st as Climb.State, kind as Number) as Array<String> {
        if (kind == 0) {
            return [int(Widgets.pathAtDistance(st.d)), int(Widgets.pathAt(Climb.count())), "m"] as Array<String>;
        }
        if (kind == 1) { return [st.climbed().format("%d"), Climb.totalU().format("%d"), "m"] as Array<String>; }
        var e = st.elapsed();
        return [hmm(e), hmm(e + st.left()), ""] as Array<String>;
    }

    // Page 16's size: 64 or 52, the larger at which the widest rows fit, both sides of the symbol as
    // wide as the widest total, so nothing moves through the climb. Chosen once per route, again only
    // should the time's estimate gain a digit (ten hours): [size, the estimate's length].
    function progressSize(d as Draw, st as Climb.State) as Float {
        var L = cache[0], timeLen = row(st, 2)[1].length();
        if (L == null || L[1].toNumber() != timeLen) {
            var unitW = d.width(d.semi(F32), "m"), size = F52;
            for (var t = 0; t < 2; t++) {
                var f = t == 0 ? F64 : F52, widest = 0.0;
                for (var k = 0; k < 3; k++) {
                    var tw = numberWidth(d, row(st, k)[1], f);
                    if (tw > widest) { widest = tw; }
                }
                var half = widest + 0.028846 + f * 0.87 / 2 + 0.009615 + unitW;
                var t0 = 0.5 - f * 1.4 - CAP * f / 2;
                if (fits(0.5 - half, t0, 0.5 + half, 1 - t0)) { size = f; break; }
            }
            L = [size, timeLen.toFloat()] as Array<Float>;
            cache[0] = L;
        }
        return L[0];
    }

    // Page 16: three rows, "{done} {symbol} {total} m", the symbol in place of "of", 0.87 of the size
    // across, the rows 1.4 of it apart and centred on the screen by their digits: the values done
    // right-aligned before the symbol, the totals left-aligned after it, so the rows align on the
    // symbols.
    function progress(d as Draw, st as Climb.State) as Void {
        var fs = progressSize(d, st), font = d.semi(fs), uf = d.semi(F32), ofW = d.whole(fs * 0.87), gap = 0.028846;
        var pitch = d.whole(fs * 1.4), top = 0.5 + CAP * fs / 2 - pitch;
        for (var k = 0; k < 3; k++) {
            var r = row(st, k), y = top + k * pitch;
            right(d, 0.5 - ofW / 2 - gap, y, font, r[0], WHITE);
            Symbols.row(d, ROW_SYMBOL[k], 0.5, y - fs * 0.36, ofW);
            var x = 0.5 + ofW / 2 + gap;
            left(d, x, y, font, r[1], TOTAL_GREY);
            if (r[2].length() > 0) { left(d, x + d.width(font, r[1]) + 0.009615, y, uf, r[2], GREY); }
        }
    }

    // Pages 17 to 19's layout for a row r: [the right edge, the symbol's centre across, the first line's
    // baseline, the second's, the symbol's size, the unit's width and gap]. The right edge is set by the
    // widest the value done can get (the total, at the large size), so it stays put as the value grows
    // and only the symbol moves; the group is centred on the screen, the lines by their digits' height.
    function oneLayout(d as Draw, r as Array<String>) as Array<Float> {
        var f1 = d.semi(F104), f2 = d.semi(F84), uf = d.semi(F32);
        var sym = d.whole(F104 * 0.7), gap = 0.038462, lineGap = 0.057692;
        var uw = r[2].length() > 0 ? 0.012019 + d.width(uf, r[2]) : 0.0;
        var vw = d.width(f1, r[0]), tw1 = d.width(f1, r[1]), vmax = vw > tw1 ? vw : tw1;
        var w2 = d.width(d.semi(F40), "of ") + d.width(f2, r[1]) + uw;
        var a = sym + gap + vmax + uw, xr = 0.5 + d.half(a > w2 ? a : w2);
        var y1 = 0.5 - (lineGap + CAP * F84 - CAP * F104) / 2, y2 = y1 + lineGap + CAP * F84;
        return [xr, xr - (sym + gap + vw + uw) + sym / 2, y1, y2, sym, uw] as Array<Float>;
    }

    // Pages 17, 18 and 19: the distance, the ascent or the time alone, large: the symbol and the value
    // done (104) above, "of" (40) and the total (84) below, right-aligned together, the units after both.
    function progressOne(d as Draw, st as Climb.State, kind as Number) as Void {
        var r = row(st, kind), L = oneLayout(d, r), f2 = d.semi(F84), uf = d.semi(F32);
        var xr = L[0], y1 = L[2], y2 = L[3], uw = L[5];
        Symbols.row(d, ROW_SYMBOL[kind], L[1], y1 - F104 * CAP / 2, L[4]);
        right(d, xr - uw, y1, d.semi(F104), r[0], WHITE);
        right(d, xr - uw, y2, f2, r[1], TOTAL_GREY);
        right(d, xr - uw - d.width(f2, r[1]), y2, d.semi(F40), "of ", GREY);
        if (uw > 0) {
            right(d, xr, y1, uf, r[2], GREY);
            right(d, xr, y2, uf, r[2], GREY);
        }
    }
}
