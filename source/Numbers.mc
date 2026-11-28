using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The number pages, 16 to 37 of the pages mock (design/demo/page-16.html and on; the Daubenhorn and
// Sulzfluh grids), one issue each (#67 on), ported from the demo the owner checked on the watch
// (2026-11-27): so far pages 16 to 19 (#67), progress as done and total (design/page-16.md). Sizes are
// shares of the screen's width, the mocks' px at 416 divided by 416. A size that depends on the route is
// chosen once per part: the page's own, or the largest below it in the size table (FontSizes.SEMI) at
// which the page fits (pages 17 to 19 6 % of the width clear of the edge, page 16 on the screen),
// measured in the fonts drawn. The number fonts are
// tabular, and a value's space is laid out from the widest it can get, so nothing moves as it changes.
module Numbers {

    const WHITE = Graphics.COLOR_WHITE;
    const GREY = 0x99aaaa;
    const TOTAL_GREY = 0xc8d0d0;

    // Font sizes (shares): SemiBold 104, 84, 52, 40 and 32 px at 416.
    const F104 = 0.25;
    const F84 = 0.2019;
    const F52 = 0.125;
    const F40 = 0.0962;
    const F32 = 0.0769;
    // Capitals and digits stand 0.71 of the size above the baseline (the mocks' CAP).
    const CAP = 0.71;
    // Pages 17 to 19 keep 6 % of the width clear of the edge; page 16's rows need only stay on the
    // screen (owner, 2026-11-28: its 52 px leave about 4 % beside four-digit totals).
    const FIT_R = 0.44;
    const SCREEN_R = 0.5;

    // ---------------------------------------------------------------- per part

    // Sizes worked out once per part, by page (0 for page 16, 1 to 3 for pages 17 to 19): [the size,
    // 1 if the time's estimate was ten hours or more].
    var cache as Dictionary<Number, Array<Float>> = {} as Dictionary<Number, Array<Float>>;

    // Climb.use calls this, through Widgets.forgetRoute, on every change of route or part.
    function forget() as Void {
        cache = {} as Dictionary<Number, Array<Float>>;
    }

    // Whether the box [x0, y0, x1, y1] keeps clear of the edge: every corner within r of the centre.
    function fits(b as Array<Float>, r as Float) as Boolean {
        return corner(b[0], b[1], r) && corner(b[2], b[1], r) && corner(b[0], b[3], r) && corner(b[2], b[3], r);
    }

    function corner(x as Float, y as Float, r as Float) as Boolean {
        var dx = x - 0.5, dy = y - 0.5;
        return dx * dx + dy * dy <= r * r;
    }

    // The table's SemiBold size at or below f, i places further down (from 0); -1.0 past the smallest.
    function sizeBelow(f as Float, i as Number) as Float {
        var sizes = FontSizes.SEMI, top = Fonts.nearest(f, sizes);
        return top - i >= 0 ? sizes[top - i] : -1.0;
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

    // The activity's active time in minutes, the approach and the ferrata, pauses left out (the tracker's
    // activeS, as the summary shows it): what the stopwatch always means (owner, 2026-11-27). Set by the
    // view before each frame; Climb.State carries only the part's clock.
    var activeMin as Float = 0.0;

    // The time's estimate: the active time and what is left of the guidebook's at the pace so far.
    function estimate(st as Climb.State) as Float { return activeMin + st.left(); }

    // The rows' symbols, Symbols.row's (the flow's figures stand after the same): the path (blue), the
    // ascent (orange) and the stopwatch (green).
    const ROW_SYMBOL = [:path, :ascent, :watch] as Array<Symbol>;

    // A row's value done and total: [done, total, unit], in the watch's elevation units (Widgets.feet,
    // as pages 1 to 15; owner, 2026-11-27): the app never overrides them.
    function row(st as Climb.State, kind as Number) as Array<String> {
        return rowIn(st, kind, Widgets.feet());
    }

    // A row in metres or feet (ft): 0 the distance along the path (each section's length and height
    // combined), 1 the height gained of the part's (0 on a part that gains none), each to the metre or
    // foot; 2 the active time (activeMin, pauses left out) of the estimate: the active time and what is
    // left of the guidebook's at the pace so far, the same in either unit. Done never passes the total.
    function rowIn(st as Climb.State, kind as Number, ft as Boolean) as Array<String> {
        var k = ft ? FEET : 1.0, unit = ft ? "ft" : "m";
        if (kind == 0) {
            return [int(Widgets.pathAtDistance(st.d) * k), int(Widgets.pathAt(Climb.count()) * k), unit] as Array<String>;
        }
        if (kind == 1) { return [int(st.u * k), int(Climb.uAt(Climb.count()) * k), unit] as Array<String>; }
        return [hmm(activeMin), hmm(estimate(st)), ""] as Array<String>;
    }

    const FEET = 3.28084;

    // Whether the time's estimate is ten hours or more, when h:mm gains a digit: the one change in width
    // a total can make within a part, so the sizes are chosen again then (and back).
    function longTime(st as Climb.State) as Boolean {
        return estimate(st) >= 599.5;
    }

    // A size chosen once per part for page key, again only when the estimate crosses ten hours.
    function cached(key as Number, st as Climb.State) as Float? {
        var L = cache[key];
        return L != null && (L[1] > 0.5) == longTime(st) ? L[0] : null;
    }

    function keep(key as Number, st as Climb.State, f as Float) as Float {
        cache[key] = [f, longTime(st) ? 1.0 : 0.0] as Array<Float>;
        return f;
    }

    // Page 16's extent at size f, [x0, y0, x1, y1], with the totals widest wide: the values done
    // right-aligned before the symbols as wide as the totals at most, the totals and the unit after.
    // The symbols reach 0.36 of the size plus half their own above the baseline, and as much below it
    // as that leaves.
    function progressBox(d as Draw, f as Float, widest as Float) as Array<Float> {
        var ofW = d.whole(f * 0.87), gap = 0.028846, pitch = d.whole(f * 1.4), top = 0.5 + CAP * f / 2 - pitch;
        var mW = d.width(d.semi(F32), "m"), ftW = d.width(d.semi(F32), "ft");
        var unitW = 0.009615 + (ftW > mW ? ftW : mW), up = 0.36 * f + ofW / 2, down = ofW / 2 - 0.36 * f;
        return [0.5 - ofW / 2 - gap - widest, top - (up > CAP * f ? up : CAP * f),
            0.5 + ofW / 2 + gap + widest + unitW, top + 2 * pitch + (down > 0 ? down : 0.0)] as Array<Float>;
    }

    // Page 16's size: 52, as the demo and the later pages' rows of figures (owner, 2026-11-28), or,
    // only where a row would leave the screen (a five-digit total, such as a 12 km approach's path), the
    // largest below it in the table at which the rows stay on it, with the widest totals in metres or
    // feet, whichever is wider (and the wider unit), so nothing moves through the climb; the smallest if
    // none does.
    function progressSize(d as Draw, st as Climb.State) as Float {
        var f = cached(0, st);
        if (f != null) { return f; }
        var last = F52;
        for (var i = 0; sizeBelow(F52, i) > 0; i++) {
            last = sizeBelow(F52, i);
            var font = d.semi(last), widest = 0.0;
            for (var k = 0; k < 6; k++) {
                var w = d.width(font, rowIn(st, k % 3, k >= 3)[1]);
                if (w > widest) { widest = w; }
            }
            if (fits(progressBox(d, last, widest), SCREEN_R)) { break; }
        }
        return keep(0, st, last);
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

    // Pages 17 to 19's layout for a row r at the value's size f1 (104 in the mock; the total's 84 and the
    // gaps in proportion): [the right edge, the symbol's centre across, the first line's baseline, the
    // second's, the symbol's size, the unit's width and gap, f1, the total's size, the left edge]. The
    // right edge is set by the widest the value done can get (the total, at f1), so it stays put as the
    // value grows and only the symbol moves; the group is centred on the screen, the lines by their
    // digits' height.
    function oneLayout(d as Draw, r as Array<String>, f1 as Float) as Array<Float> {
        var f2 = FontSizes.SEMI[Fonts.nearest(f1 * F84 / F104, FontSizes.SEMI)], k = f1 / F104;
        var big = d.semi(f1), mid = d.semi(f2), uf = d.semi(F32);
        var sym = d.whole(f1 * 0.7), gap = 0.038462 * k, lineGap = 0.057692 * k;
        var uw = r[2].length() > 0 ? 0.012019 + d.width(uf, r[2]) : 0.0;
        var vw = d.width(big, r[0]), tw1 = d.width(big, r[1]), vmax = vw > tw1 ? vw : tw1;
        var w2 = d.width(d.semi(F40), "of ") + d.width(mid, r[1]) + uw;
        var a = sym + gap + vmax + uw, wide = a > w2 ? a : w2, xr = 0.5 + d.half(wide);
        var y1 = 0.5 - (lineGap + CAP * f2 - CAP * f1) / 2, y2 = y1 + lineGap + CAP * f2;
        return [xr, xr - (sym + gap + vw + uw) + sym / 2, y1, y2, sym, uw, f1, f2, xr - wide] as Array<Float>;
    }

    // The extent of a layout L, [x0, y0, x1, y1]: the symbol stands no higher than the digits.
    function oneBox(L as Array<Float>) as Array<Float> {
        return [L[8], L[2] - CAP * L[6], L[0], L[3]] as Array<Float>;
    }

    // Pages 17 to 19's layout: at 104, the mock's size, or the largest below it at which the group fits
    // in metres and in feet, so the size is the same in either unit.
    function oneFitted(d as Draw, st as Climb.State, kind as Number) as Array<Float> {
        var r = row(st, kind), f = cached(1 + kind, st);
        if (f == null) {
            var m = rowIn(st, kind, false), ft = rowIn(st, kind, true);
            f = F104;
            for (var i = 1; !(fits(oneBox(oneLayout(d, m, f)), FIT_R) && fits(oneBox(oneLayout(d, ft, f)), FIT_R)) && sizeBelow(F104, i) > 0; i++) {
                f = sizeBelow(F104, i);
            }
            keep(1 + kind, st, f);
        }
        return oneLayout(d, r, f);
    }

    // Pages 17, 18 and 19: the distance, the ascent or the time alone, large: the symbol and the value
    // done (104) above, "of" (40) and the total (84) below, right-aligned together, the units after both.
    function progressOne(d as Draw, st as Climb.State, kind as Number) as Void {
        var r = row(st, kind), L = oneFitted(d, st, kind), f2 = d.semi(L[7]), uf = d.semi(F32);
        var xr = L[0], y1 = L[2], y2 = L[3], uw = L[5];
        Symbols.row(d, ROW_SYMBOL[kind], L[1], y1 - L[6] * CAP / 2, L[4]);
        right(d, xr - uw, y1, d.semi(L[6]), r[0], WHITE);
        right(d, xr - uw, y2, f2, r[1], TOTAL_GREY);
        right(d, xr - uw - d.width(f2, r[1]), y2, d.semi(F40), "of ", GREY);
        if (uw > 0) {
            right(d, xr, y1, uf, r[2], GREY);
            right(d, xr, y2, uf, r[2], GREY);
        }
    }
}
