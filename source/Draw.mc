using Toybox.Graphics;
using Toybox.Math;
using Toybox.WatchUi;

import Toybox.Lang;

// The app's typeface (#62): Barlow Condensed, the mocks' face, with tabular figures, in SemiBold and
// Bold, as bitmap fonts. A size is a share of the screen's width, from the size table
// (resources/fonts/sizes.json, as FontSizes); garmin-font-scaler makes each font at its share of
// every resolution. Each font is loaded on first use and kept.
module Fonts {

    var semiLoaded as Array<Graphics.FontType?> = new Array<Graphics.FontType?>[FontSizes.SEMI.size()];
    var boldLoaded as Array<Graphics.FontType?> = new Array<Graphics.FontType?>[FontSizes.BOLD.size()];

    // The size nearest share, the larger on a tie (within the table's rounding). A page asks for a
    // size in the table, so this finds it; a widget drawn at a factor gets the nearest.
    function nearest(share as Numeric, sizes as Array<Float>) as Number {
        var best = 0;
        for (var i = 1; i < sizes.size(); i++) {
            if ((sizes[i] - share).abs() <= (sizes[best] - share).abs() + 0.0001) { best = i; }
        }
        return best;
    }

    // SemiBold, the pages' text and numbers, at the size nearest share (of the screen's width).
    function semi(share as Numeric) as Graphics.FontType {
        var i = nearest(share, FontSizes.SEMI), f = semiLoaded[i];
        if (f == null) {
            f = WatchUi.loadResource(FontSizes.semiId(i)) as Graphics.FontType;
            semiLoaded[i] = f;
        }
        return f;
    }

    // Bold, the letters in the difficulty boxes and the words beside them, at the size nearest share.
    function bold(share as Numeric) as Graphics.FontType {
        var i = nearest(share, FontSizes.BOLD), f = boldLoaded[i];
        if (f == null) {
            f = WatchUi.loadResource(FontSizes.boldId(i)) as Graphics.FontType;
            boldLoaded[i] = f;
        }
        return f;
    }
}

// The difficulty colours (design/widgets.md): heat with amber, for walking and A to E, F taking E's.
// The pages draw the route file's half steps (1 A, 2 A/B ... 11 F, 12 F/G; 0 walking), each with its
// own colour, as the mocks' halfSteps do: a full grade its colour of the map, a half step the rounded
// mean of its two neighbours, channel by channel. Worked out once.
module Palette {

    const HEAT_AMBER = [0x6b7280, 0x8ecae6, 0xffe14d, 0xffb000, 0xff7a1a, 0xe63946] as Array<Number>;
    var half as Array<Number>? = null;

    function halfSteps() as Array<Number> {
        var t = half;
        if (t == null) {
            t = new Array<Number>[13];
            t[0] = HEAT_AMBER[0];
            for (var g = 1; g <= 12; g++) {
                // Grade g sits at (g + 1) / 2 on the map: A 1, B 2 ... E 5; past it, E.
                var k = (g + 1) / 2.0, lo = Math.floor(k).toNumber(), hi = Math.ceil(k).toNumber();
                if (lo > 5) { lo = 5; }
                if (hi > 5) { hi = 5; }
                var a = HEAT_AMBER[lo], b = HEAT_AMBER[hi], m = 0;
                for (var sh = 0; sh <= 16; sh += 8) {
                    m |= Math.round((((a >> sh) & 0xff) + ((b >> sh) & 0xff)) / 2.0).toNumber() << sh;
                }
                t[g] = m;
            }
            half = t;
        }
        return t;
    }
}

// Drawing helpers in shares of the screen: a position or size is a fraction of the screen's width
// (the screen is round, so of its height too), scaled to pixels here.
class Draw {

    const MUTED = 0x99aaaa;

    var dc as Graphics.Dc;
    // The screen's width in pixels.
    var w as Float;

    function initialize(target as Graphics.Dc) {
        dc = target;
        w = dc.getWidth().toFloat();
    }

    // A share of the screen's width in whole pixels, cut towards zero. The shares are decimals, a hair
    // either side of the pixel they stand for (to six places, within a five-thousandth of a pixel):
    // adding two thousandths of a pixel keeps them on it. That margin holds for a few constants added
    // up; a longer chain or a scale times hundreds of metres carries nine places.
    const NUDGE = 0.002;

    function s(v as Numeric) as Number {
        var p = v * w;
        return (p < 0 ? p - NUDGE : p + NUDGE).toNumber();
    }

    // Half a width, cut down to whole pixels, as a share: text centred on a point starts on a whole
    // pixel, as when widths were whole pixels.
    function half(v as Numeric) as Float {
        return (s(v) / 2) / w;
    }

    // A share rounded to whole pixels, as a share.
    function whole(v as Numeric) as Float {
        var p = v * w;
        return (Math.round(p < 0 ? p - NUDGE : p + NUDGE) / w).toFloat();
    }

    // A grade's colour, in half steps (Palette); climbed parts are drawn at a third of it.
    function grade(g as Number, dim as Boolean) as Number {
        var c = Palette.halfSteps()[g < 0 ? 0 : (g > 12 ? 12 : g)];
        return dim ? darken(c, 0.33) : c;
    }

    function darken(c as Number, f as Float) as Number {
        var r = ((c >> 16) & 0xff) * f;
        var g = ((c >> 8) & 0xff) * f;
        var b = (c & 0xff) * f;
        return (r.toNumber() << 16) | (g.toNumber() << 8) | b.toNumber();
    }

    function clear() as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
    }

    // Lines this wide or wider get round joints.
    const ROUND_PEN = 0.009615;

    function line(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, c as Number, pen as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(pen) < 1 ? 1 : s(pen));
        dc.drawLine(s(x1), s(y1), s(x2), s(y2));
        if (pen >= ROUND_PEN) {
            // Round the joints, as the design's round caps do.
            dc.fillCircle(s(x1), s(y1), s(pen) / 2);
            dc.fillCircle(s(x2), s(y2), s(pen) / 2);
        }
    }

    // A filled polygon through points [x, y].
    function poly(pts as Array<Array<Float>>, c as Number) as Void {
        var a = new Array<[Numeric, Numeric]>[pts.size()];
        for (var i = 0; i < pts.size(); i++) { a[i] = [s(pts[i][0]), s(pts[i][1])]; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(a);
    }

    // A stroke pen wide from (x1, y1) to (x2, y2), as a polygon (the watch's thick lines end square and
    // narrow at a slant), its ends round or cut square.
    function seg(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, pen as Numeric, c as Number, round as Boolean) as Void {
        var dx = x2 - x1, dy = y2 - y1, len = Math.sqrt(dx * dx + dy * dy);
        if (len > 0.00002) {
            var nx = -dy / len * pen / 2, ny = dx / len * pen / 2;
            poly([[x1 + nx, y1 + ny], [x2 + nx, y2 + ny], [x2 - nx, y2 - ny], [x1 - nx, y1 - ny]] as Array<Array<Float>>, c);
        }
        if (round) { dot(x1, y1, pen / 2, c); dot(x2, y2, pen / 2, c); }
    }

    function rect(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(s(x), s(y), s(wd) < 1 ? 1 : s(wd), s(h) < 1 ? 1 : s(h));
    }

    // A convex polygon through the points [x, y], in order around it, grown by r on every side, its
    // corners rounded to r (Connect IQ has no rounded polygon): a circle of radius r on each corner and
    // the polygon of the sides moved out by r. Worked out in whole pixels from the same corners, so the
    // sides meet the circles without a step.
    function roundPoly(pts as Array<Array<Float>>, r as Numeric, c as Number) as Void {
        var n = pts.size(), R = s(r), px = new Array<Number>[n], py = new Array<Number>[n], mx = 0.0, my = 0.0;
        for (var i = 0; i < n; i++) {
            px[i] = s(pts[i][0]); py[i] = s(pts[i][1]);
            mx += px[i]; my += py[i];
        }
        mx /= n; my /= n;
        var out = [] as Array<[Numeric, Numeric]>;
        for (var i = 0; i < n; i++) {
            var j = (i + 1) % n, dx = (px[j] - px[i]).toFloat(), dy = (py[j] - py[i]).toFloat();
            var len = Math.sqrt(dx * dx + dy * dy);
            if (len <= 0) { continue; }
            // The side's normal, turned away from the polygon's middle.
            var nx = -dy / len, ny = dx / len;
            if (((px[i] + px[j]) / 2.0 - mx) * nx + ((py[i] + py[j]) / 2.0 - my) * ny < 0) { nx = -nx; ny = -ny; }
            out.add([Math.round(px[i] + nx * R).toNumber(), Math.round(py[i] + ny * R).toNumber()]);
            out.add([Math.round(px[j] + nx * R).toNumber(), Math.round(py[j] + ny * R).toNumber()]);
        }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        if (out.size() >= 3) { dc.fillPolygon(out); }
        if (R > 0) {
            for (var i = 0; i < n; i++) { dc.fillCircle(px[i], py[i], R); }
        }
    }

    function roundRect(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(s(x), s(y), s(wd), s(h), s(r));
    }

    // A black rounded rectangle at alpha a (0 to 0xff) over what is drawn, which shows through dimmed
    // (Graphics.createColor and Dc.setFill, API 4.0; the epix's alphaBlendingSupport). The next
    // setColor sets an opaque fill again.
    function shade(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, r as Numeric, a as Number) as Void {
        dc.setFill(Graphics.createColor(a, 0, 0, 0));
        dc.fillRoundedRectangle(s(x), s(y), s(wd), s(h), s(r));
    }

    function dot(x as Numeric, y as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(s(x), s(y), s(r));
    }

    function ring(x as Numeric, y as Numeric, r as Numeric, c as Number, pen as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(pen));
        dc.drawCircle(s(x), s(y), s(r));
    }

    // The route's top: a hollow white ring.
    function top(x as Numeric, y as Numeric) as Void {
        dot(x, y, 0.014423, Graphics.COLOR_WHITE);
        dot(x, y, 0.007212, Graphics.COLOR_BLACK);
    }

    // Text centred on (x, y).
    function text(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(s(x), s(y), font, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function textRight(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(s(x), s(y), font, str, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // An arc of the circle of radius r around the screen's centre, clockwise from degree a0 to a1
    // (0 at three o'clock, counter-clockwise positive), ends cut square.
    function arc(r as Numeric, a0 as Numeric, a1 as Numeric, c as Number, pen as Numeric) as Void {
        // The watch draws arcs in whole degrees, and one whose ends fall on the same degree comes out
        // as a full circle: round both ends, and leave out an arc shorter than a degree.
        var i0 = Math.round(a0).toNumber(), i1 = Math.round(a1).toNumber();
        if (i0 - i1 < 1) { return; }
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(pen));
        dc.drawArc(s(0.5), s(0.5), s(r), Graphics.ARC_CLOCKWISE, i0, i1);
    }

    // A point on that circle at degree a.
    function onCircle(r as Numeric, a as Numeric) as Array<Float> {
        var t = Math.toRadians(a);
        return [0.5 + r * Math.cos(t), 0.5 - r * Math.sin(t)] as Array<Float>;
    }

    // Limit drawing to a rectangle, and lift the limit.
    function clip(x as Numeric, y as Numeric, wd as Numeric, h as Numeric) as Void {
        dc.setClip(s(x), s(y), s(wd), s(h));
    }

    function unclip() as Void {
        dc.clearClip();
    }

    // Text with its top at y, justified as given (Graphics.TEXT_JUSTIFY_LEFT, _RIGHT or _CENTER).
    function textTop(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number, justify as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(s(x), s(y), font, str, justify);
    }

    // Capital letters and digits stand 0.7 of the font's ascent above the baseline: Barlow's cap height
    // is 0.7 em, and ttf2bmp's ascent (the bitmap's base) is its ascender, 1 em; the rest of the
    // ascent is space above them.
    const CAP = 0.7;

    // The app's fonts at a size given as a share of the screen's width (Fonts): SemiBold and Bold.
    function semi(share as Numeric) as Graphics.FontType { return Fonts.semi(share); }

    function bold(share as Numeric) as Graphics.FontType { return Fonts.bold(share); }

    function ascent(font as Graphics.FontType) as Float {
        return Graphics.getFontAscent(font) / w;
    }

    function capHeight(font as Graphics.FontType) as Float {
        return ascent(font) * CAP;
    }

    // Text with its baseline at y, justified as given.
    function textBase(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number, justify as Number) as Void {
        textTop(x, y - ascent(font), font, str, c, justify);
    }

    // A word in letters spaced 0.0024 of the width apart (1 px at 416, the mocks' letter-spacing),
    // its baseline at y, starting at x (justify left), centred on it or ending there (right): the
    // spacing after its last letter counts, as in the mocks.
    function spaced(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number, justify as Number) as Void {
        var a = str.toCharArray(), cx = x;
        // Its width only when it is needed to place it.
        if (justify != Graphics.TEXT_JUSTIFY_LEFT) {
            var total = spacedWidth(font, str);
            cx = justify == Graphics.TEXT_JUSTIFY_RIGHT ? x - total : x - total / 2;
        }
        for (var i = 0; i < a.size(); i++) {
            var ch = a[i].toString();
            textBase(cx, y, font, ch, c, Graphics.TEXT_JUSTIFY_LEFT);
            cx += width(font, ch) + SPACING;
        }
    }

    const SPACING = 0.002404;

    function spacedWidth(font as Graphics.FontType, str as String) as Float {
        var a = str.toCharArray(), total = 0.0;
        for (var i = 0; i < a.size(); i++) { total += width(font, a[i].toString()) + SPACING; }
        return total;
    }

    // Text whose capitals start at y (their top), justified as given.
    function textCapTop(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number, justify as Number) as Void {
        textTop(x, y - ascent(font) * (1 - CAP), font, str, c, justify);
    }

    // Text whose capitals are centred on (x, y).
    function textCapCentre(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number) as Void {
        textCapMiddle(x, y, font, str, c, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Text whose capitals are centred vertically on y, justified as given.
    function textCapMiddle(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number, justify as Number) as Void {
        textTop(x, y + capHeight(font) / 2 - ascent(font), font, str, c, justify);
    }

    // A round brush along a line: filled circles every BRUSH_STEP, so ends and bends come out round.
    const BRUSH_STEP = 0.004807692;

    function brush(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        var dx = x2 - x1, dy = y2 - y1;
        var n = (Math.sqrt(dx * dx + dy * dy) / BRUSH_STEP).toNumber() + 1;
        for (var i = 0; i <= n; i++) {
            var f = i.toFloat() / n;
            dc.fillCircle(s(x1 + dx * f), s(y1 + dy * f), s(r));
        }
    }

    // Width of a string, as a share of the screen's width.
    function width(font as Graphics.FontType, str as String) as Float {
        return dc.getTextWidthInPixels(str, font) / w;
    }
}
