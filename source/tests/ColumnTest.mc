using Toybox.Math;

import Toybox.Lang;
import Toybox.Test;

// Pages 5 and 6 on the ferrata (#160): the difficulty column group as large as fits the round screen,
// its farthest corner 4 % of the width from the bezel, measured with the fonts it is drawn in.
module ColumnTest {

    // A route high enough for five-digit feet (10 170 ft at its head): the widest altitudes there are.
    function high() as Route {
        return Route.fromJson({"format" => 1, "id" => "h", "name" => "High", "short" => "High",
            "sections" => [
                {"len" => 100, "up" => 100, "grade" => 5, "min" => 10, "name" => "S0", "side" => 0.0},
                {"len" => 100, "up" => -40, "grade" => 7, "min" => 10, "name" => "S1", "side" => 0.0},
                {"len" => 100, "up" => 140, "grade" => 9, "min" => 10, "name" => "S2", "side" => 0.0}],
            "points" => [
                {"kind" => "head", "at" => 0, "alt" => 3100, "name" => "Head"},
                {"kind" => "top", "at" => 300, "name" => "Top"}]}) as Route;
    }

    // How far the group's top right corner reaches from the centre, where columnFilled places it: the
    // unit's end after the widest altitude, the top altitude's capitals. The widths in the fit are
    // checked against the route's every altitude (page 5) or every difference (page 6), measured here.
    function corner(d as Draw, fit as Array<Float>, ft as Boolean, relative as Boolean) as Float {
        var font = d.semi(fit[1]);
        var altW = relative ? Widgets.relativeWidestIn(d, ft, font) : WidthTest.widestByHand(d, ft, font);
        Test.assertEqualMessage(fit[3], altW, "the altitudes' box");
        Test.assertEqualMessage(fit[4], d.width(d.semi(fit[2]), ft ? "ft" : "m"), "the unit");
        var c = Widgets.columnFilledCorner(d, fit), x = c[0] - 0.5, y = c[1] - 0.5;
        return Math.sqrt(x * x + y * y).toFloat();
    }

    // On every route, unit and page: the corner within the margin, and as close to it as the fonts allow
    // (within a pixel and a half, unless the next font up was refused); each font the nearest to its
    // size times the factor, or the one below it when the nearest would not fit.
    (:test)
    function fitsAtTheMargin(logger as Logger) as Boolean {
        var routes = [RouteTest.demo(), PagesTest.daubenhorn(false), high()] as Array<Route>;
        var d = PagesTest.draw(), px = 1 / d.w, t = FontSizes.SEMI;
        for (var r = 0; r < routes.size(); r++) {
            Climb.use(routes[r], :ferrata);
            for (var c = 0; c < 4; c++) {
                var ft = c % 2 == 1, relative = c >= 2;
                var fit = Widgets.columnFitFound(d, ft, relative), k = fit[0];
                var where = "route " + r + (ft ? ", feet" : ", metres") + (relative ? ", page 6" : ", page 5") + ", factor " + k + ": ";
                var reach = corner(d, fit, ft, relative);
                logger.debug(where + "fonts " + fit[1] + ", " + fit[2] + ", the corner at " + reach);
                Test.assertMessage(reach <= Widgets.COL_FILL_R + 0.00001, where + "the corner at " + reach);
                var a = Fonts.nearest(fit[1], t), u = Fonts.nearest(fit[2], t);
                var na = Fonts.nearest(Widgets.COL_ALT * k, t), nu = Fonts.nearest(Widgets.COL_UNIT * k, t);
                var top = Fonts.nearest(Widgets.COL_FILL_TOP, t);
                if (na > top) { na = top; }
                Test.assertMessage((a == na || a == na - 1) && (u == nu || u == nu - 1), where + "fonts " + fit[1] + ", " + fit[2]);
                Test.assertMessage(reach >= Widgets.COL_FILL_R - 2.5 * px || a < na || u < nu,
                    where + "as large as fits, the corner at " + reach);
                Test.assertMessage(fit[3] > 0.0 && fit[4] > 0.0, where + "widths");
            }
        }
        return true;
    }

    // Today's group is well inside the margin on the demo route: the pages draw it larger.
    (:test)
    function largerThanToday(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        var d = PagesTest.draw();
        for (var c = 0; c < 4; c++) {
            var fit = Widgets.columnFitFound(d, c % 2 == 1, c >= 2);
            Test.assertMessage(fit[0] > 1.05, "factor " + fit[0]);
        }
        return true;
    }

    // On the approach pages 5 and 6 keep today's size (the HEAD line needs the room): no fit is worked
    // out. On the ferrata it is, once, and it holds still along the climb.
    (:test, :noreplay)
    function onlyOnTheFerrataAndStill(logger as Logger) as Boolean {
        var d = PagesTest.draw();
        Climb.use(RouteTest.demo(), :approach);
        Pages.drawPage(4, d, PagesTest.at(10.0));
        Pages.drawPage(5, d, PagesTest.at(10.0));
        Test.assertMessage(Widgets.columnFits[0] == null && Widgets.columnFits[1] == null, "none on the approach");
        Climb.use(RouteTest.demo(), :ferrata);
        var total = Climb.totalD().toFloat(), first = null as Array<Float>?;
        for (var p = 0; p <= 4; p++) {
            Pages.drawPage(4, d, PagesTest.at(total * p / 4));
            Pages.drawPage(5, d, PagesTest.at(total * p / 4));
            var fit = Widgets.columnFits[0] as Array<Float>;
            if (first == null) { first = fit; }
            Test.assertMessage(fit[0] == (first as Array<Float>)[0] && fit[1] == (first as Array<Float>)[1], "the same size at " + p);
            Test.assertMessage(Widgets.columnFits[1] != null, "page 6's worked out");
        }
        return true;
    }
}
