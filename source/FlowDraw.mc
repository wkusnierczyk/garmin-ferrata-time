using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The climb flow's screens as the revised flow mock draws them (#121; F1 to F26), in shares of the
// screen's width: the ready screen, the approach, the menus (the selected row in a large outlined
// pill), the altitude entry, a point's details, the summary, the CALIBRATED confirmation and the
// toasts; the pause symbol at the top of every paused screen. Sizes are the mock's, each at the size
// table's nearest (FontSizes); text that does not fit its room is drawn in a smaller size, as the mock
// shrinks it. Nothing here grows with the route, and text is measured once (widths, below).
module FlowDraw {

    const CENTRE = Graphics.TEXT_JUSTIFY_CENTER;
    const LEFT = Graphics.TEXT_JUSTIFY_LEFT;
    const RIGHT = Graphics.TEXT_JUSTIFY_RIGHT;

    // Every screen's title as F1's (owner, 2026-11-26): centred at 0.19 of the height, 0.087 of the
    // width, bold, narrowed to fit the round screen there.
    const TITLE_Y = 0.19;
    const TITLE = 0.087;

    // Draws the flow's screen when it has one; false when the pages have the screen.
    function draw(d as Draw, f as FlowMenus) as Boolean {
        var drew = true;
        var dt = f.detail, e = f.entry, m = f.menu;
        if (dt != null) {
            d.clear();
            detail(d, f, dt);
        } else if (e != null) {
            d.clear();
            entry(d, f, e);
        } else if (m != null) {
            d.clear();
            if (m.id == :summary) { summary(d, f, m); } else { menu(d, m); }
        } else if (f.phase() == Tracker.IDLE) {
            d.clear();
            ready(d, f);
        } else if (f.onApproach()) {
            d.clear();
            approach(d, f);
        } else {
            drew = false;
        }
        // Every paused screen but the pause menu, whose title it is, has the pause symbol at the top.
        if (drew && f.feed.paused() && !onPauseMenu(f)) { band(d); }
        var c = f.calibrated;
        if (c != null) {
            d.clear();
            calibrated(d, f, c);
            drew = true;
        }
        var t = f.toast;
        if (t != null) {
            if (!drew) { d.clear(); }
            d.shade(0, 0, 1, 1, 0, 0xd9);
            d.textCapCentre(0.5, 0.5, font(d, true, size(true, 0.1)), t, f.toastColour);
            drew = true;
        }
        return drew;
    }

    // Whether the pause menu itself is on the screen. (One test a line: the type checker, as in
    // FlowMenus.onScreen.)
    function onPauseMenu(f as FlowMenus) as Boolean {
        if (f.detail != null) { return false; }
        if (f.entry != null) { return false; }
        var m = f.menu;
        return m != null && m.id == :paused;
    }

    // ---------------------------------------------------------------- the screens

    // F1: the route's name, then its path, ascent and guidebook time after their symbols, and a green
    // play mark by Start.
    function ready(d as Draw, f as FlowMenus) as Void {
        title(d, f.feed.route.name.toUpper(), Flow.WHITE);
        symbolRows(d, [new SymRow(:path, f.figures[0], "m"), new SymRow(:ascent, f.figures[1], "m"),
            new SymRow(:watch, f.figures[2], "")] as Array<SymRow>, 0.4);
        Symbols.play(d, Widgets.GREEN);
    }

    // F4, F20: on the approach, the distance and the time left to the head, then "to HEAD", HEAD green
    // at the values' left and "to" right-aligned with the symbols; the two values at F26's place.
    function approach(d as Draw, f as FlowMenus) as Void {
        var st = f.feed.tracker.state(), left = Climb.totalD() - st.d, minutes = st.left();
        title(d, "APPROACH", Flow.WHITE);
        var to = new SymRow(null, "HEAD", "");
        to.colour = Widgets.GREEN;
        to.bold = true;
        to.word = "to";
        to.share = 0.065;
        symbolRows(d, [new SymRow(:path, ((left > 0 ? left : 0) / 1000.0).format("%.1f"), "km"),
            new SymRow(:watch, Flow.hours(Math.round(minutes > 0 ? minutes : 0).toNumber()), ""), to] as Array<SymRow>, 0.44);
    }

    // A menu: its title (the pause menu's the pause symbol), the selected row in the large pill with a
    // row above and two below, and a dot per row on the right edge, the selected one lit.
    function menu(d as Draw, m as FlowMenu) as Void {
        var id = m.id;
        if (id == :paused) {
            Symbols.pause(d, 0.5, TITLE_Y, 0.06);
        } else if (id == :head) {
            titleParts(d, [["HEAD", Widgets.GREEN, true], ["?", Flow.GREY, true]]);
        } else if (id == :confirm) {
            titleParts(d, [["DISCARD", Flow.WHITE, true], ["?", Flow.GREY, true]]);
        } else if (id == :landmarks) {
            titleParts(d, [["at ", Flow.GREY, false], ["LANDMARK", Flow.WHITE, true]]);
        } else {
            titleParts(d, [[id == :start ? "START" : (id == :end ? "END" : "CALIBRATE"), Flow.WHITE, true],
                [" at", Flow.GREY, false]]);
        }
        rows(d, m, 0.53, 1, 2);
        var n = m.items.size(), step = dotStep(n);
        for (var i = 0; i < n; i++) {
            var a = Math.toRadians((i - (n - 1) / 2.0) * step);
            d.dot(0.5 + 0.455 * Math.cos(a), 0.5 + 0.455 * Math.sin(a), 0.009, i == m.sel ? Flow.WHITE : Flow.DIM);
        }
    }

    // Degrees between the menu's dots: 6, closer on a long list, so they keep within 60 degrees of
    // three o'clock, clear of the title.
    function dotStep(n as Number) as Float {
        return n > 21 ? 120.0 / (n - 1) : 6.0;
    }

    // A menu's rows (owner, 2026-11-26, F2 and F5): the selected one in a pill 0.2 of the screen tall and
    // 0.84 wide, its text 0.085, white, the outline alone in the row's colour (a destructive row's pill
    // filled in it, its text black); the rows beside it 0.18 away, white, the next ones smaller and dim.
    // The selected row's middle at yc.
    function rows(d as Draw, m as FlowMenu, yc as Float, above as Number, below as Number) as Void {
        for (var r = -above; r <= below; r++) {
            var i = m.sel + r;
            if (i < 0 || i >= m.items.size()) { continue; }
            var it = m.items[i], y = yc + r * 0.18, label = it.label.toUpper();
            if (r == 0) {
                var h = 0.2;
                if (it.fill) {
                    d.roundRect(0.08, y - h / 2, 0.84, h, h / 2, it.colour);
                } else {
                    outline(d, 0.08, y - h / 2, 0.84, h, h / 2, it.colour, 0.009);
                }
                var k = fit(d, true, 0.085, label, 0.72);
                d.textCapCentre(0.5, y, font(d, true, k), label, it.fill ? Graphics.COLOR_BLACK : Flow.WHITE);
            } else {
                var near = r == -1 || r == 1, ty = y + (r > 0 ? 0.02 : -0.02);
                var k = fit(d, true, near ? 0.055 : 0.044, label, chord(ty) * 0.8);
                d.textCapCentre(0.5, ty, font(d, true, k), label, near ? Flow.WHITE : Flow.DIM);
            }
        }
    }

    // F3, F10: "at ALTITUDE", going on from START at and CALIBRATE at; the altitude alone in the middle;
    // beside Up and Down the step each makes (to the next 10 m mark, then 10 m); a green check by
    // Start, a red cross by Back.
    function entry(d as Draw, f as FlowMenus, e as FlowEntry) as Void {
        titleParts(d, [["at ", Flow.GREY, false], ["ALTITUDE", Flow.WHITE, true]]);
        bigAltitude(d, e.value, 0.5);
        var up = Flow.altUp(e.value, f.range) - e.value, down = e.value - Flow.altDown(e.value, f.range);
        var big = font(d, true, size(true, 0.08));
        d.textCapMiddle(0.06, 0.5, big, "+" + up.format("%d"), up != 0 ? Flow.WHITE : Flow.DIM, LEFT);
        d.textCapMiddle(0.12, 0.72, big, "–" + down.format("%d"), down != 0 ? Flow.WHITE : Flow.DIM, LEFT);
        Symbols.check(d, Widgets.GREEN);
        Symbols.cross(d, Widgets.RED);
    }

    // F18, F24, F25, F26: a point's details. Titled by its type, a grey "at" then the type in its colour
    // (a name might not fit), a landmark's or an exit's own name under it; HERE keeps its plain title.
    // Then its altitude after the peak, and how far it is after the path (here: how far along the
    // route), the first at 0.44 of the height; the check by Start, the cross by Back.
    function detail(d as Draw, f as FlowMenus, dt as FlowDetail) as Void {
        var r = f.feed.route, p = dt.point;
        var second = null as SymRow?;
        if (p < 0) {
            title(d, "HERE", Flow.WHITE);
            second = new SymRow(:path, Math.round(dt.d).toNumber().format("%d"), "m along");
        } else {
            var pt = r.points[p], kind = pt["kind"] as String;
            titleParts(d, [["at ", Flow.GREY, false], [Flow.word(pt), Flow.colour(pt), true]]);
            if (kind.equals("landmark") || kind.equals("exit")) {
                var k = size(true, 0.055), shown = dt.shown;
                if (shown == null) {
                    shown = cut(d, font(d, true, k), (r.points[p]["name"] as String).toUpper(), chord(0.28) * 0.8);
                    dt.shown = shown;
                }
                d.textCapCentre(0.5, 0.28, font(d, true, k), shown, Flow.WHITE);
            }
            var how = Flow.ahead(dt.at, dt.d);
            second = new SymRow(:path, how[0], how[1]);
        }
        symbolRows(d, [new SymRow(:peak, dt.alt.format("%d"), "m"), second as SymRow] as Array<SymRow>, 0.44);
        Symbols.check(d, Widgets.GREEN);
        Symbols.cross(d, Widgets.RED);
    }

    // F14: the route's name; one line of three figures, each after its symbol (the height climbed, the
    // activity's time, the drift), units grey on the baseline; a rule; then Save, Resume and Discard.
    function summary(d as Draw, f as FlowMenus, m as FlowMenu) as Void {
        var t = f.feed.tracker;
        title(d, f.feed.route.name.toUpper(), Flow.WHITE);
        var climbed = Climb.FERRATA ? t.state().climbed() : 0;
        var syms = [:ascent, :watch, :drift] as Array<Symbol>;
        var values = [climbed.format("%d"), Flow.hours(t.activeS / 60), Flow.signed(Math.round(t.drift()).toNumber())] as Array<String>;
        var units = ["m", "", "m"] as Array<String>;
        var fs = 0.085, sym = fs * 0.87, sg = 0.013, ig = 0.045, ug = 0.007;
        var vk = size(false, fs), uk = size(false, fs * 0.616);
        var w = new Array<Float>[3], total = 2 * ig;
        for (var i = 0; i < 3; i++) {
            w[i] = sym + sg + width(d, false, vk, values[i]) + (units[i].length() > 0 ? ug + width(d, false, uk, units[i]) : 0.0);
            total += w[i];
        }
        var x = 0.5 - total / 2, y = 0.34, base = y + d.capHeight(font(d, false, vk)) / 2;
        for (var i = 0; i < 3; i++) {
            Symbols.row(d, syms[i], x + sym / 2, y, sym);
            var vx = x + sym + sg;
            d.textBase(vx, base, font(d, false, vk), values[i], Flow.WHITE, LEFT);
            if (units[i].length() > 0) {
                d.textBase(vx + width(d, false, vk, values[i]) + ug, base, font(d, false, uk), units[i], Flow.GREY, LEFT);
            }
            x += w[i] + ig;
        }
        d.line(0.18, 0.45, 0.82, 0.45, 0x333333, 0.0036);
        rows(d, m, 0.67, 1, 1);
    }

    // F11: "CALIBRATED at", the altitude calibrated to large in the middle, and under it the point's
    // name in its colour when the calibration was at one. No mark by Back: it plainly goes back.
    function calibrated(d as Draw, f as FlowMenus, alt as Number) as Void {
        titleParts(d, [["CALIBRATED", Flow.WHITE, true], [" at", Flow.GREY, false]]);
        bigAltitude(d, alt, 0.47);
        var p = f.calibratedPoint;
        if (p < 0) { return; }
        var pt = f.feed.route.points[p], name = (pt["name"] as String).toUpper();
        var k = fit(d, true, 0.06, name, chord(0.66) * 0.8);
        d.textCapCentre(0.5, 0.66, font(d, true, k), name, Flow.colour(pt));
    }

    // Over the pages, the approach and the screens under the pause menu while paused: the pause symbol
    // at the top, on a black disk so it reads over a page (owner, 2026-11-26, in place of PAUSED).
    function band(d as Draw) as Void {
        d.dot(0.5, 0.085, 0.055, Graphics.COLOR_BLACK);
        Symbols.pause(d, 0.5, 0.085, 0.045);
    }

    // ---------------------------------------------------------------- the parts

    // A title in parts, each [text, colour, bold], together centred at F1's title place and size; the
    // whole narrowed, both weights a size down at a time, until it fits the round screen there.
    function titleParts(d as Draw, parts as Array<Array>) as Void {
        var max = chord(TITLE_Y) * 0.85, b = size(true, TITLE), s = size(false, TITLE), total = 0.0;
        while (true) {
            total = 0.0;
            for (var i = 0; i < parts.size(); i++) {
                var bold = parts[i][2] as Boolean;
                total += width(d, bold, bold ? b : s, parts[i][0] as String);
            }
            if (total <= max || b == 0) { break; }
            b--;
            s = size(false, FontSizes.BOLD[b]);
        }
        var x = 0.5 - total / 2;
        for (var i = 0; i < parts.size(); i++) {
            var bold = parts[i][2] as Boolean, k = bold ? b : s, str = parts[i][0] as String;
            d.textCapMiddle(x, TITLE_Y, font(d, bold, k), str, parts[i][1] as Number, LEFT);
            x += width(d, bold, k, str);
        }
    }

    function title(d as Draw, text as String, colour as Number) as Void {
        titleParts(d, [[text, colour, true]]);
    }

    // Rows of a symbol and a value with its unit, as page 16 draws them at the size the owner gave
    // (2026-11-26): the values 0.1 of the width, the symbols 0.87 of that, the units 0.616 of it, grey,
    // on the values' baseline, rows 1.4 values apart; the block centred on its widest row, the first
    // row's middle at y0. A row without a symbol is a word row: its value at the values' left, its word
    // grey and right-aligned with the symbols, 0.75 of a pitch under the row before.
    const ROW = 0.1;

    function symbolRows(d as Draw, list as Array<SymRow>, y0 as Float) as Void {
        var sym = ROW * 0.87, gap = 0.023, pitch = ROW * 1.4, ugap = 0.008;
        var vk = size(false, ROW), uk = size(false, ROW * 0.616), widest = 0.0;
        for (var i = 0; i < list.size(); i++) {
            var r = list[i];
            var w = sym + gap + width(d, r.bold, size(r.bold, r.share), r.value)
                + (r.unit.length() > 0 ? ugap + width(d, false, uk, r.unit) : 0.0);
            if (w > widest) { widest = w; }
        }
        var left = 0.5 - widest / 2, y = y0 - pitch, half = d.capHeight(font(d, false, vk)) / 2;
        for (var i = 0; i < list.size(); i++) {
            var r = list[i], k = size(r.bold, r.share);
            y += i > 0 && r.sym == null ? pitch * 0.75 : pitch;
            var vx = left + sym + gap, base = y + half;
            var s = r.sym;
            if (s != null) { Symbols.row(d, s, left + sym / 2, y, sym); }
            var word = r.word;
            if (word != null) { d.textBase(left + sym, base, font(d, false, uk), word, Flow.GREY, RIGHT); }
            d.textBase(vx, base, font(d, r.bold, k), r.value, r.colour, LEFT);
            if (r.unit.length() > 0) {
                d.textBase(vx + width(d, r.bold, k, r.value) + ugap, base, font(d, false, uk), r.unit, Flow.GREY, LEFT);
            }
        }
    }

    // An altitude large (F3, F10, F11): the number 0.2 of the width, bold, white (the table's largest
    // bold, 0.1683), its digits centred on cy; the unit right after it, grey, 0.07, on its baseline.
    function bigAltitude(d as Draw, v as Number, cy as Float) as Void {
        var vk = size(true, 0.2), uk = size(false, 0.07), str = v.format("%d");
        var vw = width(d, true, vk, str), uw = width(d, false, uk, "m");
        var vx = 0.5 - (vw + 0.01 + uw) / 2, base = cy + d.capHeight(font(d, true, vk)) / 2;
        d.textBase(vx, base, font(d, true, vk), str, Flow.WHITE, LEFT);
        d.textBase(vx + vw + 0.01, base, font(d, false, uk), "m", Flow.GREY, LEFT);
    }

    // A name cut to max (a share of the width), with an ellipsis where it does not fit (F18's): measured
    // letter by letter, so done once, when the screen opens.
    function cut(d as Draw, f as Graphics.FontType, t as String, max as Float) as String {
        if (d.width(f, t) <= max) { return t; }
        var n = t.length();
        while (n > 1) {
            n--;
            while (n > 1 && " ".equals(t.substring(n - 1, n))) { n--; }
            var u = (t.substring(0, n) as String) + "…";
            if (d.width(f, u) <= max) { return u; }
        }
        return (t.substring(0, 1) as String) + "…";
    }

    // A rounded rectangle's outline, pen wide.
    function outline(d as Draw, x as Float, y as Float, w as Float, h as Float, r as Float, c as Number, pen as Float) as Void {
        d.dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        d.dc.setPenWidth(d.s(pen) < 1 ? 1 : d.s(pen));
        d.dc.drawRoundedRectangle(d.s(x), d.s(y), d.s(w), d.s(h), d.s(r));
    }

    // ---------------------------------------------------------------- fonts and widths

    // The size table's index nearest share, in a weight.
    function size(bold as Boolean, share as Float) as Number {
        return Fonts.nearest(share, bold ? FontSizes.BOLD : FontSizes.SEMI);
    }

    function font(d as Draw, bold as Boolean, k as Number) as Graphics.FontType {
        return bold ? d.bold(FontSizes.BOLD[k]) : d.semi(FontSizes.SEMI[k]);
    }

    // The index of the size nearest share, or the largest smaller one in which str fits in max.
    function fit(d as Draw, bold as Boolean, share as Float, str as String, max as Float) as Number {
        var k = size(bold, share);
        while (k > 0 && width(d, bold, k, str) > max) { k--; }
        return k;
    }

    // Text widths, measured once each and kept (a few dozen at most, then started again): a screen
    // measures its strings on its first frame, and later frames look them up.
    const KEPT = 48;
    var widths as Dictionary<String, Float> = {} as Dictionary<String, Float>;

    function width(d as Draw, bold as Boolean, k as Number, str as String) as Float {
        var key = (bold ? "b" : "s") + k.format("%d") + "~" + str;
        var w = widths[key];
        if (w == null) {
            if (widths.size() >= KEPT) { widths = {} as Dictionary<String, Float>; }
            w = d.width(font(d, bold, k), str);
            widths[key] = w;
        }
        return w;
    }

    // The width of the round screen at height y: text there must stay inside it.
    function chord(y as Float) as Float {
        var dy = y - 0.5;
        return 2 * Math.sqrt(0.25 - dy * dy).toFloat();
    }
}

// One of symbolRows' rows: its symbol (null for a word row), value and unit; the value's colour, weight
// and size; a word row's word.
class SymRow {

    var sym as Symbol?;
    var value as String;
    var unit as String;
    var colour as Number = Flow.WHITE;
    var bold as Boolean = false;
    var word as String? = null;
    var share as Float = FlowDraw.ROW;

    function initialize(s as Symbol?, v as String, u as String) {
        sym = s;
        value = v;
        unit = u;
    }
}
