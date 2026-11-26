using Toybox.Graphics;
using Toybox.System;

import Toybox.Lang;
import Toybox.Test;

// The number widths (#94): measured once per route from one or two strings, since the digits are tabular.
// Each must equal the widest of every number the pages can show, measured one by one.
module WidthTest {

    // Down 20 m, then up 100 m, from a head at 0 m: altitudes from -20 to 80 m, a minus sign at the low end.
    function belowZero() as Route {
        return Route.fromJson({"format" => 1, "id" => "z", "name" => "Zero", "short" => "Zero",
            "sections" => [
                {"len" => 50, "up" => -20, "grade" => 1, "min" => 10, "name" => "S0", "side" => 0.0},
                {"len" => 100, "up" => 100, "grade" => 1, "min" => 10, "name" => "S1", "side" => 0.0}],
            "points" => [
                {"kind" => "head", "at" => 0, "alt" => 0, "name" => "Head"},
                {"kind" => "top", "at" => 150, "name" => "Top"}]}) as Route;
    }

    function draw() as Draw {
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => w}).get() as Graphics.BufferedBitmap;
        return new Draw(bitmap.getDc());
    }

    // The widest altitude, every step from the low end to the high end measured.
    function widestByHand(d as Draw, ft as Boolean, font as Graphics.FontType) as Float {
        var w = 0.0;
        var last = Widgets.altitudeValue(Climb.netHigh().toFloat(), ft);
        for (var v = Widgets.altitudeValue(Climb.netLow().toFloat(), ft); v <= last; v += ft ? 50 : 10) {
            var vw = d.width(font, v.format("%d"));
            if (vw > w) { w = vw; }
        }
        return w;
    }

    function altitudesMatch(r as Route) as Boolean {
        Climb.use(r, :ferrata);
        var d = draw();
        for (var f = 0; f < 2; f++) {
            var ft = f == 1;
            Test.assertEqualMessage(Widgets.altitudeBox(d, ft), widestByHand(d, ft, d.semi(Widgets.ALT_SIZE)), "altitude box");
            Test.assertEqualMessage(Widgets.columnAltitudeBox(d, ft), widestByHand(d, ft, d.semi(Widgets.COL_ALT)), "column box");
        }
        return true;
    }

    // The ascent's numbers (#100: net height): the net height above the head now, from the route's
    // lowest to its highest, and the top's net height less that, every one measured.
    function ascentMatches(r as Route) as Boolean {
        Climb.use(r, :ferrata);
        var d = draw(), font = d.semi(Widgets.NUMBER_SIZE), w = 0.0, top = Climb.netAt(Climb.count());
        for (var n = Climb.netLow(); n <= Climb.netHigh(); n++) {
            var a = d.width(font, n.format("%d")), b = d.width(font, (top - n).format("%d"));
            if (a > w) { w = a; }
            if (b > w) { w = b; }
        }
        Test.assertEqual(Widgets.ascentNumbersWidth(d), w);
        return true;
    }

    (:test)
    function ascentWidthIsTheWidestNumber(logger as Logger) as Boolean {
        // The small route: measuring every number of the demo's ascent is what tripped the watchdog.
        return ascentMatches(belowZero());
    }

    // Below the head and above the top: the minus signs count.
    (:test)
    function ascentWidthCountsTheMinus(logger as Logger) as Boolean {
        return ascentMatches(DescentTest.dipRoute());
    }

    (:test)
    function altitudeWidthsAreTheWidest(logger as Logger) as Boolean {
        return altitudesMatch(RouteTest.demo());
    }

    // The minus sign: -20 is wider than 80 though both have two digits.
    (:test)
    function altitudeWidthsCountTheMinus(logger as Logger) as Boolean {
        return altitudesMatch(belowZero());
    }

    // Page 6: the relative altitudes' box is the widest of every difference the column can show, from
    // each section's bottom to the borders above it, measured one by one.
    function relativeMatches(r as Route) as Boolean {
        Climb.use(r, :ferrata);
        var d = draw(), font = d.semi(Widgets.COL_ALT), n = Climb.count();
        for (var f = 0; f < 2; f++) {
            var ft = f == 1, w = 0.0;
            for (var c = 0; c < n; c++) {
                for (var b = c; b <= n && b <= c + Widgets.COL_ABOVE + 1; b++) {
                    var vw = d.width(font, Widgets.relativeText(Widgets.relativeValue(b, c, ft)));
                    if (vw > w) { w = vw; }
                }
            }
            Test.assertEqualMessage(Widgets.columnRelativeBox(d, ft), w, "relative box");
        }
        return true;
    }

    (:test)
    function relativeWidthsAreTheWidest(logger as Logger) as Boolean {
        return relativeMatches(RouteTest.demo());
    }

    // A route that falls: the minus sign counts.
    (:test)
    function relativeWidthsCountTheMinus(logger as Logger) as Boolean {
        return relativeMatches(DescentTest.downRoute());
    }

    (:test)
    function relativeValuesAreSigned(logger as Logger) as Boolean {
        // Up 100, down 50, up 100: from section 1's bottom (100 m up), the descent's foot is -50 and the
        // top +50.
        Climb.use(DescentTest.downRoute(), :ferrata);
        Test.assertEqualMessage(Widgets.relativeText(Widgets.relativeValue(1, 1, false)), "0", "its own bottom");
        Test.assertEqualMessage(Widgets.relativeText(Widgets.relativeValue(2, 1, false)), "-50", "the descent's foot");
        Test.assertEqualMessage(Widgets.relativeText(Widgets.relativeValue(3, 1, false)), "+50", "the top");
        Test.assertEqualMessage(Widgets.relativeValue(3, 1, true), 165, "in feet, to 5");
        return true;
    }
}
