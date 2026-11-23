using Toybox.Graphics;
using Toybox.System;

import Toybox.Lang;
import Toybox.Test;

// Pages 1 to 9 as the mocks draw them (#95): what the widgets work out, apart from the drawing itself.
module PagesTest {

    function draw() as Draw {
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => w}).get() as Graphics.BufferedBitmap;
        return new Draw(bitmap.getDc());
    }

    function at(d as Float) as Climb.State {
        return Climb.State.placed(d, Climb.heightAtDistance(d), 30.0, 1.0, 480.0, 25);
    }

    // Page 9 names the ferrata's head on its first section and the route's top on its last, and
    // neither on the approach, which starts elsewhere and ends at the head.
    (:test)
    function headAndTopOnlyOnTheFerrata(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        var n = Climb.count(), first = Widgets.sectionPoints(0), last = Widgets.sectionPoints(n - 1);
        Test.assertEqualMessage(first[0], Widgets.POI_HEAD, "HEAD first on the first section");
        Test.assertEqualMessage(last[last.size() - 1], Widgets.POI_TOP, "TOP last on the last section");
        Test.assertEqualMessage(Widgets.poiNear(at(0.0), true), Widgets.POI_HEAD, "page 8 at the head");
        Climb.use(RouteTest.demo(), :approach);
        var only = Widgets.sectionPoints(0);
        Test.assertMessage(only.indexOf(Widgets.POI_HEAD) < 0 && only.indexOf(Widgets.POI_TOP) < 0, "none on the approach");
        Test.assertMessage(Widgets.poiNear(at(0.0), true) != Widgets.POI_HEAD, "no HEAD at the approach's start");
        Test.assertMessage(Widgets.poiNear(at(Climb.totalD().toFloat()), true) != Widgets.POI_TOP, "no TOP at the head");
        return true;
    }

    // Page 1a draws the placement made for the climber's window, not one kept from an earlier window
    // (review of #99): the climber stays on the zoomed profile as the window moves on.
    (:test, :noreplay)
    function zoomFollowsTheWindow(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        var d = draw(), places = [100.0, 150.0, 151.0, 400.0, 600.0] as Array<Float>;
        for (var p = 0; p < places.size(); p++) {
            var st = at(places[p]);
            // A few frames at each place, so a search across frames runs too.
            for (var frame = 0; frame < 3; frame++) { Pages.draw(1, d, st); }
            var f = Widgets.zoomFit as Array<Float>, win = Widgets.zoomWindow(st);
            Test.assertMessage(RouteTest.near(f[3], win[0]), "at " + places[p] + ": the window drawn starts at " + f[3] + ", not " + win[0]);
            var x = f[0] + (st.d - f[3]) * f[2];
            Test.assertMessage(x > 0.2 && x < 0.9, "at " + places[p] + ": the climber at " + x + ", off the profile");
        }
        return true;
    }

    // A long flat stretch, as the Daubenhorn's 600 m traverse at its start: pages 1a and 7a draw only what
    // can be on the screen (review of #99, finding 2), and draw everywhere on it.
    (:test, :noreplay)
    function zoomedPagesDrawOnALongTraverse(logger as Logger) as Boolean {
        var r = RouteTest.made([[600, 0], [60, 40], [40, 97], [60, 10]] as Array<Array<Number> >);
        DescentTest.drawsEverywhere(r, 1, 1);
        return DescentTest.drawsEverywhere(r, 12, 12);
    }

    // Page 9's words, measured once, are as wide as measured each time.
    (:test)
    function pageNineWordsMeasuredOnce(logger as Logger) as Boolean {
        var d = draw(), font = d.bold(0.0673);
        for (var k = 0; k < Widgets.POI_WORD.size(); k++) {
            Test.assertEqualMessage(Pages.wordWidth(d, font, k), d.spacedWidth(font, Widgets.POI_WORD[k]), Widgets.POI_WORD[k]);
        }
        Test.assertEqualMessage(Pages.wordWidth(d, font, Pages.SEPARATOR), d.spacedWidth(font, " · "), "the dot");
        return true;
    }

    // Page 7's group placement is worked out per size and height, not one for all.
    (:test)
    function groupPlaceFollowsItsSize(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        var d = draw(), big = Widgets.groupPlace(d, 0.5, 1.5)[1], small = Widgets.groupPlace(d, 0.5, 1.0)[1];
        Test.assertMessage(small != big, "a smaller group is placed anew: " + small + " against " + big);
        Test.assertEqualMessage(Widgets.groupPlace(d, 0.5, 1.5)[1], big, "the same again");
        return true;
    }
}
