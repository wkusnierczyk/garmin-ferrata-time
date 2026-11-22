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

// Drawing helpers in shares of the screen: a position or size is a fraction of the screen's width
// (the screen is round, so of its height too), scaled to pixels here.
class Draw {

    // Difficulty colours for walk and K1 to K5. The heat map, ending in purple, is the earlier pages';
    // the revised pages use heat with amber and no purple (design/widgets.md).
    const HEAT = [0x6b7280, 0x8ecae6, 0xffd166, 0xf79d3c, 0xef476f, 0xb05cff] as Array<Number>;
    const HEAT_AMBER = [0x6b7280, 0x8ecae6, 0xffe14d, 0xffb000, 0xff7a1a, 0xe63946] as Array<Number>;
    var colours as Array<Number> = HEAT;
    const REST = 0x4fc3f7;
    const EXIT = 0xcfd8dc;
    const MUTED = 0x99aaaa;
    const DIM_GREY = 0x777777;

    var dc as Graphics.Dc;
    // The screen's width in pixels.
    var w as Float;

    function initialize(target as Graphics.Dc) {
        dc = target;
        w = dc.getWidth().toFloat();
    }

    // A share of the screen's width in whole pixels, cut towards zero. The shares are decimals, a hair
    // either side of the pixel they stand for (to six places or more, within a five-thousandth of a pixel):
    // adding two thousandths of a pixel keeps them on it.
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

    // A grade's colour; climbed parts are drawn at a third of it.
    function grade(g as Number, dim as Boolean) as Number {
        var c = colours[g < 0 ? 0 : g];
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

    // A dash's length, and the gap's. It and BRUSH_STEP divide lengths into counts, so they carry nine
    // decimals.
    const DASH = 0.021634615;

    function dashed(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, c as Number, pen as Numeric) as Void {
        var dx = x2 - x1, dy = y2 - y1;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len <= 0) { return; }
        var steps = (len / DASH).toNumber();
        for (var i = 0; i < steps; i += 2) {
            var a = i / steps.toFloat(), b = (i + 1) / steps.toFloat();
            line(x1 + dx * a, y1 + dy * a, x1 + dx * b, y1 + dy * b, c, pen);
        }
    }

    function rect(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(s(x), s(y), s(wd) < 1 ? 1 : s(wd), s(h) < 1 ? 1 : s(h));
    }

    function roundRect(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(s(x), s(y), s(wd), s(h), s(r));
    }

    // A progress bar's fill: rounded ends once it is wide enough for them, nothing before.
    function bar(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, c as Number) as Void {
        if (wd >= h) { roundRect(x, y, wd, h, h / 2, c); }
    }

    function frame(x as Numeric, y as Numeric, wd as Numeric, h as Numeric, c as Number, pen as Numeric) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(pen));
        dc.drawRectangle(s(x), s(y), s(wd), s(h));
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

    // A small triangle pointing right, the "you are here" marker beside a ladder or list.
    function pointer(x as Numeric, y as Numeric, size as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[s(x - size * 2), s(y - size)], [s(x), s(y)], [s(x - size * 2), s(y + size)]]);
    }

    // A small triangle pointing up, standing for "climbed".
    function upMark(x as Numeric, y as Numeric, size as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[s(x), s(y - size)], [s(x + size), s(y + size * 0.6)], [s(x - size), s(y + size * 0.6)]]);
    }

    // The exit mark: a short arrow down and to the right.
    function exitMark(x as Numeric, y as Numeric) as Void {
        line(x - 0.012019, y - 0.012019, x + 0.009615, y + 0.009615, EXIT, 0.004808);
        line(x + 0.009615, y + 0.009615, x + 0.009615, y - 0.004808, EXIT, 0.004808);
        line(x + 0.009615, y + 0.009615, x - 0.004808, y + 0.009615, EXIT, 0.004808);
    }

    // Text centred on (x, y).
    function text(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(s(x), s(y), font, str, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function textLeft(x as Numeric, y as Numeric, font as Graphics.FontType, str as String, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.drawText(s(x), s(y), font, str, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
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
