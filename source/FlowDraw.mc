using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// The climb flow's screens as the flow mock draws them (#51), in shares of the screen's width: the
// ready screen, the menus (the selected row an outlined pill in its colour, the list scrolling with it
// in the middle), the altitude entry, the summary, the CALIBRATED confirmation and the toast after
// Save or Discard. Sizes are the mock's, each at the size table's nearest (FontSizes); text that does
// not fit its room is drawn in a smaller size, as the mock shrinks it. Nothing here grows with the
// route: the menus' rows are worked out when they open.
module FlowDraw {

    const CENTRE = Graphics.TEXT_JUSTIFY_CENTER;

    // Draws the flow's screen when it has one; false when the pages have the screen.
    function draw(d as Draw, f as FlowMenus) as Boolean {
        var drew = true;
        var e = f.entry, m = f.menu;
        if (e != null) {
            d.clear();
            entry(d, f, e);
        } else if (m != null) {
            d.clear();
            if (m.id == :summary) { summary(d, f, m); } else { menu(d, m); }
        } else if (f.phase() == Tracker.IDLE) {
            d.clear();
            ready(d, f);
        } else {
            drew = false;
        }
        var c = f.calibrated;
        if (c != null) {
            d.clear();
            d.textCapCentre(0.5, 0.44, d.bold(0.0865), "CALIBRATED", Flow.SYNC);
            d.textCapCentre(0.5, 0.56, fit(d, false, 0.0577, c, chord(0.56) * 0.8), c, Flow.WHITE);
            drew = true;
        }
        var t = f.toast;
        if (t != null) {
            if (!drew) { d.clear(); }
            d.shade(0, 0, 1, 1, 0, 0xd9);
            d.textCapCentre(0.5, 0.5, d.bold(0.0865), t, f.toastColour);
            drew = true;
        }
        return drew;
    }

    // ---------------------------------------------------------------- the screens

    // Before Start: the route's name and place, its length, ascent and guidebook time, its hardest
    // grade, and the prompt beside the Start button.
    function ready(d as Draw, f as FlowMenus) as Void {
        var r = f.feed.route, name = r.name.toUpper();
        d.textCapCentre(0.5, 0.17, fit(d, true, 0.0865, name, chord(0.17) * 0.85), name, Flow.WHITE);
        var where = r.place.length() > 0 ? "Via ferrata · " + r.place : "Via ferrata";
        d.textCapCentre(0.5, 0.245, fit(d, false, 0.0481, where, chord(0.245) * 0.85), where, Flow.GREY);
        figure(d, 0.25, f.figures[0], "km", "LENGTH");
        figure(d, 0.5, f.figures[1], "m", "ASCENT");
        figure(d, 0.75, f.figures[2], "h:mm", "GUIDE");
        var g = f.hardest;
        outline(d, 0.39, 0.67, 0.22, 0.1, 0.012, Flow.DIM, 0.0048);
        var box = Widgets.BOX_NAME[g];
        d.textCapCentre(0.5, 0.72, fit(d, true, 0.0721, box, 0.19), box, d.grade(g, false));
        d.textCapCentre(0.5, 0.81, d.semi(0.0433), "hardest", Flow.DIM);
        buttonPrompt(d, "START", Widgets.CLIMBER, false);
    }

    // One of the ready screen's figures: the number, its unit and its label under it. The number's size
    // is the largest with letters too (the larger ones are digits only, and a length has a point).
    function figure(d as Draw, x as Float, value as String, unit as String, label as String) as Void {
        d.textCapCentre(x, 0.45, fit(d, false, 0.1106, value, 0.22), value, Flow.WHITE);
        d.textCapCentre(x, 0.545, d.semi(0.0481), unit, Flow.GREY);
        d.textCapCentre(x, 0.6, d.semi(0.0433), label, Flow.DIM);
    }

    // A menu: its title in its colour; the selected row in the middle, an outlined pill in the row's
    // colour, its second line under the label at the same size; a row above and two below, the farther
    // smaller and dim; a dot per row on the right edge, the selected one lit.
    function menu(d as Draw, m as FlowMenu) as Void {
        title(d, m.title, m.colour);
        for (var r = -1; r <= 2; r++) {
            var i = m.sel + r;
            if (i < 0 || i >= m.items.size()) { continue; }
            var it = m.items[i], y = 0.5 + r * 0.17, label = it.label.toUpper();
            var sub = it.sub;
            if (r == 0) {
                var h = sub != null ? 0.19 : 0.15;
                outline(d, 0.1, y - h / 2, 0.8, h, h / 2, it.colour, 0.0075);
                d.textCapCentre(0.5, sub != null ? y - 0.036 : y, fit(d, true, ROW, label, 0.68), label, it.colour);
                if (sub != null) { subLine(d, y + 0.04, it, sub); }
            } else {
                var near = r == -1 || r == 1, ty = y + (r > 0 ? 0.02 : -0.02);
                d.textCapCentre(0.5, ty, fit(d, true, near ? 0.0577 : 0.0433, label, chord(ty) * 0.8), label,
                    near ? it.colour : Flow.DIM);
            }
        }
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

    // The selected row's two lines, the same size (the mock's 0.062; both weights have 0.0673).
    const ROW = 0.0673;

    // The selected row's second line: grey, or for a landmark white with its kind's word in colour.
    function subLine(d as Draw, y as Float, it as FlowItem, sub as String) as Void {
        var font = fit(d, false, ROW, sub, 0.68);
        var kind = it.kind;
        if (kind == null) {
            d.textCapCentre(0.5, y, font, sub, Flow.GREY);
            return;
        }
        var rest = sub.substring(kind.length(), sub.length()) as String;
        var x = 0.5 - d.width(font, sub) / 2;
        d.textCapMiddle(x, y, font, kind, it.kindColour, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapMiddle(x + d.width(font, kind), y, font, rest, Flow.WHITE, Graphics.TEXT_JUSTIFY_LEFT);
    }

    function title(d as Draw, text as String, colour as Number) as Void {
        var max = chord(0.135) * 0.8, idx = Fonts.nearest(0.0577, FontSizes.BOLD);
        var font = d.bold(FontSizes.BOLD[idx]);
        while (idx > 0 && d.spacedWidth(font, text) > max) {
            idx--;
            font = d.bold(FontSizes.BOLD[idx]);
        }
        d.spaced(0.5, 0.135 + d.capHeight(font) / 2, font, text, colour, CENTRE);
    }

    // The altitude entry: the altitude large in the middle, how far it is from where it started, where
    // on the route it is; Up's and Down's next altitudes beside their buttons, Set and Cancel beside
    // Start and Back.
    function entry(d as Draw, f as FlowMenus, e as FlowEntry) as Void {
        title(d, "ALTITUDE", Flow.SYNC);
        var from = !e.known ? "No barometer reading" : (e.start ? "Barometer " : "Estimate ") + e.est.format("%d") + " m";
        d.textCapCentre(0.5, 0.215, fit(d, false, 0.0433, from, chord(0.215) * 0.8), from, Flow.GREY);
        var v = e.value.format("%d");
        d.textCapCentre(0.5, 0.42, fit(d, false, 0.2019, v, 0.5), v, Flow.WHITE);
        d.textCapCentre(0.5, 0.545, d.semi(0.0481), "m", Flow.GREY);
        var delta = e.value - e.est, what = e.start ? "the barometer" : "the estimate";
        var off = delta != 0 ? Flow.signed(delta) + " m from " + what : what;
        d.textCapCentre(0.5, 0.625, fit(d, false, 0.0433, off, 0.6), off, delta != 0 ? Flow.SYNC : Flow.DIM);
        var at = e.start && f.feed.route.hasApproach() ? "on the approach"
            : Flow.km(e.at) + " along · " + Flow.away(e.at, e.d0);
        d.textCapCentre(0.5, 0.78, fit(d, false, 0.0433, at, 0.52), at, Flow.GREY);
        var font = d.bold(0.0481);
        d.textCapMiddle(0.06, 0.5, font, Flow.altUp(e.value, f.range).format("%d"),
            e.value < f.range[1] ? Flow.WHITE : Flow.DIM, Graphics.TEXT_JUSTIFY_LEFT);
        d.textCapMiddle(0.12, 0.72, font, Flow.altDown(e.value, f.range).format("%d"),
            e.value > f.range[0] ? Flow.WHITE : Flow.DIM, Graphics.TEXT_JUSTIFY_LEFT);
        buttonPrompt(d, "SET", Flow.SYNC, false);
        buttonPrompt(d, "CANCEL", Flow.GREY, true);
    }

    // After an end: the route's name, the height climbed, the activity's time and the drift, then Save,
    // Resume and Discard.
    function summary(d as Draw, f as FlowMenus, m as FlowMenu) as Void {
        var t = f.feed.tracker, name = f.feed.route.name.toUpper();
        var font = fit(d, true, 0.0577, name, chord(0.13) * 0.8);
        d.spaced(0.5, 0.13 + d.capHeight(font) / 2, font, name, Flow.WHITE, CENTRE);
        var climbed = Climb.FERRATA ? t.state().climbed() : 0;
        var drift = Math.round(t.drift()).toNumber();
        stat(d, 0.24, climbed.format("%d") + " m", "climbed");
        stat(d, 0.5, Flow.hours(t.activeS / 60), "time");
        stat(d, 0.76, (drift >= 0 ? "+" : "-") + drift.abs().format("%d") + " m", "drift");
        d.line(0.18, 0.44, 0.82, 0.44, 0x333333, 0.0036);
        for (var i = 0; i < m.items.size(); i++) {
            var it = m.items[i], y = 0.53 + i * 0.115, on = i == m.sel, label = it.label.toUpper();
            if (on) { outline(d, 0.25, y - 0.052, 0.5, 0.104, 0.052, it.colour, 0.0075); }
            d.textCapCentre(0.5, y, fit(d, true, on ? 0.0673 : 0.0577, label, 0.4), label, it.colour);
        }
    }

    function stat(d as Draw, x as Float, value as String, label as String) as Void {
        d.textCapCentre(x, 0.29, fit(d, false, 0.0865, value, 0.24), value, Flow.WHITE);
        d.textCapCentre(x, 0.37, d.semi(0.0385), label, Flow.GREY);
    }

    // ---------------------------------------------------------------- helpers

    // A prompt beside a button on the right, START (at 2 o'clock) or, lower, BACK (at 4): its word and
    // a short stroke towards the button.
    function buttonPrompt(d as Draw, label as String, colour as Number, lower as Boolean) as Void {
        d.textCapMiddle(0.82, lower ? 0.685 : 0.315, d.bold(0.0433), label, colour, Graphics.TEXT_JUSTIFY_RIGHT);
        var y = lower ? 0.7 : 0.3;
        d.seg(0.835, y, 0.875, y + (lower ? 0.023 : -0.023), 0.0072, colour, true);
    }

    // A rounded rectangle's outline, pen wide.
    function outline(d as Draw, x as Float, y as Float, w as Float, h as Float, r as Float, c as Number, pen as Float) as Void {
        d.dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        d.dc.setPenWidth(d.s(pen) < 1 ? 1 : d.s(pen));
        d.dc.drawRoundedRectangle(d.s(x), d.s(y), d.s(w), d.s(h), d.s(r));
    }

    // The font of this weight at the size nearest share, or the largest smaller one in which str fits
    // in max (a share of the width).
    function fit(d as Draw, bold as Boolean, share as Float, str as String, max as Float) as Graphics.FontType {
        var sizes = bold ? FontSizes.BOLD : FontSizes.SEMI, idx = Fonts.nearest(share, sizes);
        var font = bold ? d.bold(sizes[idx]) : d.semi(sizes[idx]);
        while (idx > 0 && d.width(font, str) > max) {
            idx--;
            font = bold ? d.bold(sizes[idx]) : d.semi(sizes[idx]);
        }
        return font;
    }

    // The width of the round screen at height y: text there must stay inside it.
    function chord(y as Float) as Float {
        var dy = y - 0.5;
        return 2 * Math.sqrt(0.25 - dy * dy).toFloat();
    }
}
