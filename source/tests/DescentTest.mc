using Toybox.Graphics;
using Toybox.System;

import Toybox.Lang;
import Toybox.Test;

// Descents on the pages (#56): the profile draws the real height, down as well as up; the pages that
// stack sections by height stack by height gained, so a section that loses height draws as flat.
module DescentTest {

    // Up 100 m over 100 m, down 50 m over 50 m, up 100 m over 100 m: the head at 1000 m.
    function downRoute() as Route {
        return RouteTest.made([[100, 100], [50, -50], [100, 100]] as Array<Array<Number> >);
    }

    // A harder route for drawing: a dip below the head first, grades, a rest, a descent with a danger
    // on it, and an exit at the foot of a descent.
    function dipRoute() as Route {
        var steps = [[50, -20, 0], [100, 100, 9], [40, 0, -1], [60, -30, 4], [80, 20, 7]] as Array<Array<Number> >;
        var sections = [] as Array<Dictionary>;
        for (var i = 0; i < steps.size(); i++) {
            sections.add({"len" => steps[i][0], "up" => steps[i][1], "grade" => steps[i][2], "min" => 10,
                "name" => "S" + i, "side" => i % 2 == 0 ? 0.5 : -0.5});
        }
        return Route.fromJson({"format" => 1, "id" => "dip", "name" => "Dip", "short" => "Dip",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 2070, "name" => "Head"},
                {"kind" => "exit", "at" => 190, "name" => "Exit"},
                {"kind" => "danger", "at" => 220, "name" => "Danger"},
                {"kind" => "top", "at" => 330, "name" => "Top"}]}) as Route;
    }

    (:test)
    function profileGoesDown(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // Lower on the screen is a larger y.
        var at100 = Widgets.profileY(100.0, 1.0, 1.0), at125 = Widgets.profileY(125.0, 1.0, 1.0);
        Test.assertMessage(at125 > at100, "the profile at 125 m is below the one at 100 m");
        Test.assertMessage(RouteTest.near(Widgets.profileY(150.0, 1.0, 1.0), 1.0 - 50.0 / 150), "the descent's foot");
        // The box spans the lowest point to the highest, here the start and the top.
        Test.assertMessage(RouteTest.near(Widgets.profileY(0.0, 1.0, 1.0), 1.0), "the start at the bottom");
        Test.assertMessage(RouteTest.near(Widgets.profileY(250.0, 1.0, 1.0), 0.0), "the top at the top");
        return true;
    }

    (:test)
    function profileFitsADipBelowTheHead(logger as Logger) as Boolean {
        Climb.use(dipRoute(), :ferrata);
        // Lowest 20 m below the head, highest 80 m above: a span of 100 m.
        Test.assertMessage(RouteTest.near(Widgets.profileY(50.0, 1.0, 1.0), 1.0), "the dip at the bottom");
        Test.assertMessage(RouteTest.near(Widgets.profileY(0.0, 1.0, 1.0), 0.8), "the head above it");
        Test.assertMessage(RouteTest.near(Widgets.profileY(150.0, 1.0, 1.0), 0.0), "the high point at the top");
        Test.assertMessage(RouteTest.near(Widgets.profileY(330.0, 1.0, 1.0), 0.1), "the end below it");
        return true;
    }

    (:test)
    function stackFlatForDescent(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        Test.assertEqualMessage(Widgets.stackSize(1, true), 0, "no height by ascent");
        Test.assertMessage(Widgets.stackAt(1, true) == Widgets.stackAt(2, true), "a line across the stack");
        Test.assertEqualMessage(Widgets.stackSize(1, false), 50, "its length by path");
        Test.assertEqualMessage(Climb.totalU(), 200, "gained height");
        return true;
    }

    (:test)
    function gaugeByAscentGivesDescentTheLeast(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        Widgets.forgetRoute();
        var starts = Widgets.gaugeLayout(true);
        Test.assertMessage(RouteTest.near(starts[1] - starts[2], Widgets.G_MIN), "the descent's arc is the least");
        Test.assertMessage(RouteTest.near(starts[0] - starts[1], starts[2] - starts[3]), "the climbs share the rest");
        Test.assertMessage(RouteTest.near(starts[0] - starts[3], Widgets.G_SPAN.toFloat()), "the whole sweep");
        return true;
    }

    (:test)
    function altitudesAreReal(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // At the descent's foot: 50 m above the head, though 100 m have been climbed.
        var st = Climb.State.placed(150.0, Climb.heightAtDistance(150.0), 0.0, 1.0, 0.0, 25);
        Test.assertEqualMessage(st.climbed(), 100, "climbed");
        Test.assertEqualMessage(st.altitude(), 1050, "altitude");
        Test.assertEqualMessage(Widgets.altitudeValue(st.net(), false), 1050, "the altitude widget's");
        return true;
    }

    (:test)
    function stackTicksOnlyWhereTheRouteRises(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // By ascent, every 20 m: 1000 to 1100 on the first climb, none on the descent, then from 1060
        // again on the second climb (1060 to 1100 a second time) to 1140.
        var t = Widgets.stackTicks(true, 0.0, 200.0, 20, 1.0);
        Test.assertEqualMessage(t[0].toString(),
            [1000, 1020, 1040, 1060, 1080, 1100, 1060, 1080, 1100, 1120, 1140].toString(), "altitudes");
        Test.assertMessage(RouteTest.near(t[1][6], 110.0), "1060 again 10 m into the second climb");
        // By path, the same altitudes at their distances.
        t = Widgets.stackTicks(false, 0.0, 250.0, 20, 1.0);
        Test.assertMessage(RouteTest.near(t[1][6], 160.0), "1060 again 10 m along the second climb");
        // Only within the window.
        t = Widgets.stackTicks(true, 90.0, 130.0, 20, 1.0);
        Test.assertEqualMessage(t[0].toString(), [1100, 1060, 1080].toString(), "in the window");
        return true;
    }

    // Every page at every 10 m of the route, each in turn, into a bitmap: a throw fails the test. As
    // wide as the screen, since the pens are shares of it and a pen under a pixel wide throws; two
    // colours, so it takes a bit a pixel.
    function drawsEverywhere(r as Route, from as Number, to as Number) as Boolean {
        Climb.use(r, :ferrata);
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => w,
            :palette => [Graphics.COLOR_BLACK, Graphics.COLOR_WHITE] as Array<Graphics.ColorValue>}).get() as Graphics.BufferedBitmap;
        var dc = bitmap.getDc();
        for (var page = from; page <= to; page++) {
            for (var dist = 0; dist <= Climb.totalD(); dist += 10) {
                var st = Climb.State.placed(dist.toFloat(), Climb.heightAtDistance(dist.toFloat()), 30.0, 1.0, 480.0, 25);
                Pages.draw(page, new Draw(dc), st);
            }
        }
        return true;
    }

    (:test)
    function pagesOneToNineDrawAtADescent(logger as Logger) as Boolean {
        return drawsEverywhere(downRoute(), 0, Pages.SECTION_PAGE);
    }

    (:test)
    function demoPagesDrawAtADescent(logger as Logger) as Boolean {
        return drawsEverywhere(downRoute(), Pages.SECTION_PAGE + 1, Pages.COUNT - 1);
    }

    (:test)
    function pagesOneToNineDrawOnADip(logger as Logger) as Boolean {
        return drawsEverywhere(dipRoute(), 0, Pages.SECTION_PAGE);
    }

    (:test)
    function demoPagesDrawOnADip(logger as Logger) as Boolean {
        return drawsEverywhere(dipRoute(), Pages.SECTION_PAGE + 1, Pages.COUNT - 1);
    }
}
