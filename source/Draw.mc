using Toybox.Graphics;
using Toybox.Math;

import Toybox.Lang;

// Drawing helpers in the design's 416 px coordinates, scaled to the screen.
class Draw {

    const GRADE_COLOUR = [0x6b7280, 0x8ecae6, 0xffd166, 0xf79d3c, 0xef476f, 0xb05cff] as Array<Number>;
    const REST = 0x4fc3f7;
    const EXIT = 0xcfd8dc;
    const MUTED = 0x99aaaa;
    const DIM_GREY = 0x777777;

    var dc as Graphics.Dc;
    var k as Float;

    function initialize(target as Graphics.Dc) {
        dc = target;
        k = dc.getWidth() / 416.0;
    }

    function s(v as Numeric) as Number { return (v * k).toNumber(); }

    // A grade's colour; climbed parts are drawn at a third of it.
    function grade(g as Number, dim as Boolean) as Number {
        var c = GRADE_COLOUR[g < 0 ? 0 : g];
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

    function line(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, c as Number, w as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(s(w) < 1 ? 1 : s(w));
        dc.drawLine(s(x1), s(y1), s(x2), s(y2));
        if (w >= 4) {
            // Round the joints, as the design's round caps do.
            dc.fillCircle(s(x1), s(y1), s(w) / 2);
            dc.fillCircle(s(x2), s(y2), s(w) / 2);
        }
    }

    function dashed(x1 as Numeric, y1 as Numeric, x2 as Numeric, y2 as Numeric, c as Number, w as Number) as Void {
        var dx = x2 - x1, dy = y2 - y1;
        var len = Math.sqrt(dx * dx + dy * dy);
        if (len <= 0) { return; }
        var steps = (len / 9.0).toNumber();
        for (var i = 0; i < steps; i += 2) {
            var a = i / steps.toFloat(), b = (i + 1) / steps.toFloat();
            line(x1 + dx * a, y1 + dy * a, x1 + dx * b, y1 + dy * b, c, w);
        }
    }

    function rect(x as Numeric, y as Numeric, w as Numeric, h as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(s(x), s(y), s(w) < 1 ? 1 : s(w), s(h) < 1 ? 1 : s(h));
    }

    function roundRect(x as Numeric, y as Numeric, w as Numeric, h as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(s(x), s(y), s(w), s(h), s(r));
    }

    // A progress bar's fill: rounded ends once it is wide enough for them, nothing before.
    function bar(x as Numeric, y as Numeric, w as Numeric, h as Numeric, c as Number) as Void {
        if (w >= h) { roundRect(x, y, w, h, h / 2, c); }
    }

    function frame(x as Numeric, y as Numeric, w as Numeric, h as Numeric, c as Number, pen as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawRectangle(s(x), s(y), s(w), s(h));
    }

    function dot(x as Numeric, y as Numeric, r as Numeric, c as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(s(x), s(y), s(r));
    }

    function ring(x as Numeric, y as Numeric, r as Numeric, c as Number, pen as Number) as Void {
        dc.setColor(c, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(pen);
        dc.drawCircle(s(x), s(y), s(r));
    }

    // The route's top: a hollow white ring.
    function top(x as Numeric, y as Numeric) as Void {
        dot(x, y, 6, Graphics.COLOR_WHITE);
        dot(x, y, 3, Graphics.COLOR_BLACK);
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
        line(x - 5, y - 5, x + 4, y + 4, EXIT, 2);
        line(x + 4, y + 4, x + 4, y - 2, EXIT, 2);
        line(x + 4, y + 4, x - 2, y + 4, EXIT, 2);
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

    // Width of a string in design pixels.
    function width(font as Graphics.FontType, str as String) as Number {
        return (dc.getTextWidthInPixels(str, font) / k).toNumber();
    }
}
