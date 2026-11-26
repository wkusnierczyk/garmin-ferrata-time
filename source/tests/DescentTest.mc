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
    function stretchFollowsTheRealHeight(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // Mid-descent at 75 m, sure to 10 m: from 85 m on the way down to 65 m, not the whole descent.
        var s = Climb.stretchAround(125.0, 10);
        Test.assertMessage(RouteTest.near(s[0], 115.0) && RouteTest.near(s[1], 135.0), "115 to 135, got " + s.toString());
        // At the high point between the climb and the descent: 10 m down either way.
        s = Climb.stretchAround(100.0, 10);
        Test.assertMessage(RouteTest.near(s[0], 90.0) && RouteTest.near(s[1], 110.0), "90 to 110, got " + s.toString());
        return true;
    }

    (:test)
    function stretchAsBeforeWithoutDescents(logger as Logger) as Boolean {
        // A climb, a flat stretch, a climb: the stretch the height gained gave, everywhere.
        Climb.use(RouteTest.made([[100, 100], [50, 0], [100, 100]] as Array<Array<Number> >), :ferrata);
        for (var d = 0; d <= 250; d += 5) {
            var u = Climb.heightAtDistance(d.toFloat()), s = Climb.stretchAround(d.toFloat(), 25);
            var lo = Climb.firstDistanceAt(u - 25), hi = Climb.lastDistanceAt(u + 25);
            if (!RouteTest.near(s[0], lo) || !RouteTest.near(s[1], hi)) {
                Test.assertMessage(false, "at " + d + ": " + s.toString() + " against " + [lo, hi].toString());
            }
        }
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
        var starts = Widgets.gaugeLayout(true);
        Test.assertMessage(RouteTest.near(starts[1] - starts[2], Widgets.G_MIN), "the descent's arc is the least");
        Test.assertMessage(RouteTest.near(starts[0] - starts[1], starts[2] - starts[3]), "the climbs share the rest");
        Test.assertMessage(RouteTest.near(starts[0] - starts[3], Widgets.G_SPAN.toFloat()), "the whole sweep");
        return true;
    }

    (:test)
    function altitudesAreReal(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // At the descent's foot: 50 m above the head, though 100 m have been climbed. What the pages show
        // (the altitude widget, pages 12 and 13, the difficulty group; the column's borders; page 15) is
        // the real altitude, not the head's plus the height gained (1100).
        var st = Climb.State.placed(150.0, Climb.heightAtDistance(150.0), 0.0, 1.0, 0.0, 25);
        Test.assertEqualMessage(st.climbed(), 100, "climbed");
        Test.assertEqualMessage(Widgets.altitudeNow(st, false), 1050, "the climber's altitude");
        Test.assertEqualMessage(Widgets.borderAltitude(2, false), 1050, "the descent's foot on the column");
        Test.assertEqualMessage(Widgets.sectionAltitudes(1, false).toString(), [1100, 1050].toString(), "page 15's foot and top");
        Test.assertEqualMessage(Widgets.altitudeNow(st, true), 3450, "in feet, to 50");
        return true;
    }

    // #100: a section descends when it loses height (UP < 0); its grade box is then a trapezium.
    (:test)
    function descendsWhenItLosesHeight(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        Test.assertMessage(!Climb.descends(0) && Climb.descends(1) && !Climb.descends(2), "only the middle section");
        Climb.use(RouteTest.made([[100, 0]] as Array<Array<Number> >), :ferrata);
        Test.assertMessage(!Climb.descends(0), "a flat section does not");
        return true;
    }

    // The trapezium: the rectangle's top, its foot TRAP_FOOT of the top's width, the corners' centres
    // inset by the corner radius.
    (:test)
    function trapeziumNarrowerAtItsFoot(logger as Logger) as Boolean {
        var c = Widgets.trapeziumCorners(0.5, 0.2, 0.2, 0.1, 0.02);
        Test.assertMessage(RouteTest.near(c[0], 0.42) && RouteTest.near(c[1], 0.22), "top left");
        Test.assertMessage(RouteTest.near(c[2], 0.58) && RouteTest.near(c[3], 0.22), "top right");
        Test.assertMessage(RouteTest.near(c[4], 0.56) && RouteTest.near(c[5], 0.28), "foot right, 0.8 of the top");
        Test.assertMessage(RouteTest.near(c[6], 0.44) && RouteTest.near(c[7], 0.28), "foot left");
        return true;
    }

    // #100: the ascent widgets show a position, the real (net) height, not an amount: the ring pulls back
    // down on a descent, its numbers the net height above the head and the top's net height less that.
    (:test)
    function ascentFollowsNetHeight(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        // The top is 150 m above the head; at the descent's foot the climber is 50 m above it, though
        // 100 m have been climbed.
        var places = [0.0, 100.0, 150.0, 250.0] as Array<Float>;
        var shares = [0.0, 100.0 / 150, 50.0 / 150, 1.0] as Array<Float>;
        var numbers = [[0, 150], [100, 50], [50, 100], [150, 0]] as Array<Array<Number> >;
        for (var p = 0; p < places.size(); p++) {
            var st = PagesTest.at(places[p]);
            Test.assertMessage(RouteTest.near(Widgets.ascentShare(st), shares[p]), "at " + places[p] + ": share " + Widgets.ascentShare(st));
            Test.assertEqualMessage(Widgets.ascentNumbers(st).toString(), numbers[p].toString(), "at " + places[p]);
        }
        Test.assertEqualMessage(PagesTest.at(150.0).climbed(), 100, "climbed stays gained height");
        return true;
    }

    // A route that dips below its head and climbs above its top before coming down to it: the ring stays
    // on the line, at its ends, while the numbers say how far past them.
    (:test)
    function ascentRingStaysOnTheLine(logger as Logger) as Boolean {
        Climb.use(dipRoute(), :ferrata);
        // Net -20 at 50 m, 80 at 150 m; the top 70.
        var st = PagesTest.at(50.0);
        Test.assertMessage(RouteTest.near(Widgets.ascentShare(st), 0.0), "the dip at the start");
        Test.assertEqualMessage(Widgets.ascentNumbers(st).toString(), [-20, 90].toString(), "below the head");
        st = PagesTest.at(150.0);
        Test.assertMessage(RouteTest.near(Widgets.ascentShare(st), 1.0), "the high point at the top");
        Test.assertEqualMessage(Widgets.ascentNumbers(st).toString(), [80, -10].toString(), "above the top");
        return true;
    }

    // A part whose top is at or below its start (an approach going down, or ending where it started):
    // no way up, so the ring stays at the start and the numbers are 0 (the review of #101: the ring
    // climbed as the climber went down, both numbers negative).
    (:test)
    function ascentWithNoWayUp(logger as Logger) as Boolean {
        var routes = [[[100, -20]], [[50, 10], [50, -10]], [[50, 10], [50, -30]]] as Array<Array<Array<Number> > >;
        for (var r = 0; r < routes.size(); r++) {
            Climb.use(RouteTest.made(routes[r]), :ferrata);
            var places = [0.0, 50.0, 75.0, 100.0] as Array<Float>;
            for (var p = 0; p < places.size(); p++) {
                var st = PagesTest.at(places[p]);
                Test.assertMessage(RouteTest.near(Widgets.ascentShare(st), 0.0),
                    "route " + r + " at " + places[p] + ": share " + Widgets.ascentShare(st));
                Test.assertEqualMessage(Widgets.ascentNumbers(st).toString(), [0, 0].toString(),
                    "route " + r + " at " + places[p]);
            }
        }
        return true;
    }

    // Page 15 (#100): a descent's start, the higher altitude, above its box and its end below; a climb's
    // end above and its start below, as before.
    (:test)
    function pageFifteenHigherAltitudeAbove(logger as Logger) as Boolean {
        Climb.use(downRoute(), :ferrata);
        Test.assertEqualMessage(Pages.sectionLines(0, false).toString(), [1100, 1000].toString(), "a climb");
        Test.assertEqualMessage(Pages.sectionLines(1, false).toString(), [1100, 1050].toString(), "the descent");
        Test.assertEqualMessage(Pages.sectionLines(2, false).toString(), [1150, 1050].toString(), "the climb after it");
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

    // Pages from to to drawn, each in turn, at each section's borders, 1 m either side of them and its
    // middle, into a bitmap: a throw fails the test. As wide as the screen, since the pens are shares of
    // it and a pen under a pixel wide throws; in full colour, since the fonts are anti-aliased and
    // cannot draw into a palette. Not in the replay build, whose pages are the same.
    function drawsEverywhere(r as Route, from as Number, to as Number) as Boolean {
        Climb.use(r, :ferrata);
        var places = [] as Array<Float>;
        for (var i = 0; i <= Climb.count(); i++) {
            var b = Climb.dAt(i).toFloat();
            if (i > 0) { places.add(b - 1); }
            places.add(b);
            if (i < Climb.count()) { places.add(b + 1); places.add((b + Climb.dAt(i + 1)) / 2); }
        }
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => w}).get() as Graphics.BufferedBitmap;
        var dc = bitmap.getDc();
        for (var page = from; page <= to; page++) {
            for (var p = 0; p < places.size(); p++) {
                var st = Climb.State.placed(places[p], Climb.heightAtDistance(places[p]), 30.0, 1.0, 480.0, 25);
                Pages.draw(page, new Draw(dc), st);
            }
        }
        return true;
    }

    // Every page on the route that dips below its head; pages 3 and 4 also on the one with no sideways
    // travel, whose fit divided by 0 (the other pages draw nothing there the dip does not).
    (:test, :noreplay)
    function pagesDrawOnADip(logger as Logger) as Boolean {
        return drawsEverywhere(dipRoute(), 0, Pages.COUNT - 1);
    }

    (:test, :noreplay)
    function frontPagesDrawWithoutSidewaysTravel(logger as Logger) as Boolean {
        return drawsEverywhere(downRoute(), 2, 3);
    }
}
