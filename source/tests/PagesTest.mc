using Toybox.Math;
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
            // A few frames at each place: the window is worked out on the first, kept on the others.
            for (var frame = 0; frame < 3; frame++) { Pages.draw(1, d, st); }
            var f = Widgets.zoomFit as Array<Float>, win = Widgets.zoomWindow(st);
            Test.assertMessage(RouteTest.near(f[3], win[0]), "at " + places[p] + ": the window drawn starts at " + f[3] + ", not " + win[0]);
            var x = f[0] + (st.d - f[3]) * f[2];
            Test.assertMessage(x > 0.2 && x < 0.9, "at " + places[p] + ": the climber at " + x + ", off the profile");
        }
        return true;
    }

    // Page 1a draws each window at the largest scale that fits the rectangle, centred in it (#102: no
    // search for a place clear of the widgets), on the demo route and on one with a crest a metre wide,
    // narrower than the window's height samples.
    (:test, :noreplay)
    function zoomLargestCentred(logger as Logger) as Boolean {
        var routes = [RouteTest.demo(), RouteTest.made([[60, 0], [1, 30], [1, -30], [60, 0]] as Array<Array<Number> >)] as Array<Route>;
        var d = draw(), x0 = Pages.PROFILE_X0, w = Pages.PROFILE_W, y0 = Pages.PROFILE_Y0, h = Pages.PROFILE_H;
        for (var r = 0; r < routes.size(); r++) {
            Climb.use(routes[r], :ferrata);
            var total = Climb.totalD().toFloat();
            var places = [0.0, total / 4, total / 2, total * 3 / 4, total] as Array<Float>;
            for (var p = 0; p < places.size(); p++) {
                Pages.draw(1, d, at(places[p]));
                var f = Widgets.zoomFit as Array<Float>, a = Widgets.zoomArgs, k = f[2];
                var W = (a[1] - a[0]) * k, H = (a[3] - a[2]) * k, where = "route " + r + " at " + places[p] + ": ";
                Test.assertMessage(W <= w + 0.0001 && H <= h + 0.0001, where + "fits, " + W + " by " + H);
                Test.assertMessage(RouteTest.near(W, w) || RouteTest.near(H, h), where + "as large as fits, " + W + " by " + H);
                Test.assertMessage(RouteTest.near(f[0] - x0, x0 + w - (f[0] + W)), where + "centred across");
                Test.assertMessage(RouteTest.near(y0 - f[1], f[1] - H - (y0 - h)), where + "centred up");
                zoomInside(where);
            }
        }
        return true;
    }

    // The route page 1a draws, at the window's ends and every section end between them, inside the
    // profile's rectangle.
    function zoomInside(where as String) as Void {
        var f = Widgets.zoomFit as Array<Float>, a = Widgets.zoomArgs, k = f[2], e = 0.0001;
        var x0 = Pages.PROFILE_X0, w = Pages.PROFILE_W, y0 = Pages.PROFILE_Y0, h = Pages.PROFILE_H;
        var ds = [a[0], a[1]] as Array<Float>;
        for (var i = 0; i <= Climb.count(); i++) {
            var b = Climb.dAt(i).toFloat();
            if (b > a[0] && b < a[1]) { ds.add(b); }
        }
        for (var q = 0; q < ds.size(); q++) {
            var x = f[0] + (ds[q] - f[3]) * k, y = f[1] - (Climb.netAtDistance(ds[q]) - f[4]) * k;
            Test.assertMessage(x >= x0 - e && x <= x0 + w + e && y >= y0 - h - e && y <= y0 + e,
                where + "the route at " + ds[q] + " m drawn at " + x + ", " + y + ", outside the rectangle");
        }
    }

    // Page 1a's zoomed profile frame by frame as the demo plays the route at its pace, the whole climb:
    // every frame draws the climber's window, worked out anew only when the window moves, inside the
    // rectangle, the climber on it.
    (:test, :noreplay)
    function zoomDrawsTheDemoFrameByFrame(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false), d = draw(), moves = 0, frames = DemoInput.LOOP_MS / Feed.DEMO_TICK_MS;
        f.start(:head);
        var before = null as Array<Float>?;
        for (var frame = 0; frame < frames; frame++) {
            f.tick();
            var st = f.tracker.state(), win = Widgets.zoomWindow(st), key = Widgets.zoomKey, end = Widgets.zoomArgs[1];
            var where = "frame " + frame + ": ";
            // The zoomed profile alone: the whole page every frame takes minutes in the simulator.
            Widgets.profileZoom(d, st, Pages.PROFILE_X0, Pages.PROFILE_W, Pages.PROFILE_Y0, Pages.PROFILE_H);
            var fit = Widgets.zoomFit as Array<Float>;
            if (key >= 0 && (win[0] - key).abs() <= 0.5 && (win[1] - end).abs() <= 0.5) {
                Test.assertMessage(fit == before, where + "the window stayed, its placement worked out again");
            } else {
                Test.assertMessage(RouteTest.near(fit[3], win[0]), where + "the window drawn starts at " + fit[3] + ", not " + win[0]);
                moves++;
            }
            before = fit;
            zoomInside(where);
            // Within the half metre the window may move before it is worked out again.
            var x = fit[0] + (st.d - fit[3]) * fit[2], e = 0.5 * fit[2];
            Test.assertMessage(x >= Pages.PROFILE_X0 - e && x <= Pages.PROFILE_X0 + Pages.PROFILE_W + e, where + "the climber at " + x + ", off the profile");
        }
        logger.debug("the window moved on " + moves + " of " + frames + " frames");
        Test.assertMessage(moves > 1 && moves < frames, "the window moved on " + moves + " of " + frames + " frames");
        return true;
    }

    // Page 1a's half-transparent box under the altitude group (#102), in metres and in feet: it spans
    // the number's box and its unit; with a poi word it reaches down over the word, and left to the
    // word's start when the word is wider than the number, as "DANGER" is over three-digit altitudes
    // (the review of #103); without one it stops at the digits.
    (:test)
    function altitudeGroundFitsTheGroup(logger as Logger) as Boolean {
        var sections = [] as Array<Dictionary>;
        for (var i = 0; i < 2; i++) {
            sections.add({"len" => 100, "up" => 100, "grade" => 3, "min" => 10, "name" => "S" + i, "side" => 0.0});
        }
        Climb.use(Route.fromJson({"format" => 1, "id" => "low", "name" => "Low", "short" => "Low",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 500, "name" => "Head"},
                {"kind" => "danger", "at" => 100, "name" => "Danger"},
                {"kind" => "top", "at" => 200, "name" => "Top"}]}) as Route, :ferrata);
        var d = draw(), digits = d.capHeight(d.semi(Widgets.ALT_SIZE));
        var word = d.spacedWidth(Widgets.poiFont(d), "DANGER"), danger = at(100.0), none = at(200.0);
        Test.assertEqualMessage(Widgets.poiNear(danger, false), 0, "DANGER at 100 m");
        Test.assertEqualMessage(Widgets.poiNear(none, false), -1, "no word at 200 m");
        Test.assertMessage(word > Widgets.altitudeBox(d, false), "DANGER wider than three digits");
        for (var u = 0; u < 2; u++) {
            var ft = u == 1, unit = ft ? "ft: " : "m: ", box = Widgets.altitudeBox(d, ft);
            var right = box + 0.009615 + d.width(d.semi(Widgets.ALT_UNIT), ft ? "ft" : "m");
            var a = Widgets.altitudeGroupExtent(d, none, ft), b = Widgets.altitudeGroupExtent(d, danger, ft);
            Test.assertMessage(RouteTest.near(a[1], right) && RouteTest.near(b[1], right), unit + "to the unit's end");
            Test.assertMessage(RouteTest.near(a[0], 0.0), unit + "from the number's box without a word: " + a[0]);
            Test.assertMessage(RouteTest.near(a[2], digits), unit + "the digits alone: " + a[2]);
            var start = box - word;
            Test.assertMessage(RouteTest.near(b[0], start < 0 ? start : 0.0), unit + "from the word's start or the box's: " + b[0]);
            Test.assertMessage(RouteTest.near(b[2], digits + 0.028846 + 0.7 * Widgets.POI_SIZE), unit + "down over the word: " + b[2]);
        }
        Test.assertMessage(Widgets.altitudeGroupExtent(d, danger, false)[0] < 0, "m: left of the number, over DANGER");
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

    // The Daubenhorn's ferrata, its sections' lengths and heights from the pages mock (make_route_mocks.py),
    // and the mock's stand-in with its fifth section a descent of its own height: three-digit numbers
    // high up the ascent's line (#109).
    function daubenhorn(standIn as Boolean) as Route {
        var len = [600, 60, 40, 60, 30, 25, 80, 60, 120, 40, 100, 200, 120, 10] as Array<Number>;
        var up = [0, 40, 97, 10, standIn ? -85 : 85, 67, 0, 140, 80, 105, 30, 142, 15, 30] as Array<Number>;
        var steps = [] as Array<Array<Number> >;
        for (var i = 0; i < len.size(); i++) { steps.add([len[i], up[i]] as Array<Number>); }
        return RouteTest.made(steps);
    }

    // How far, in pixels across, the ink of the ascent's numbers reaches past the round screen's edge at
    // most (below 0: how near it comes), with the line at x from y0 up to y0 - h and the climber at every
    // net height of the route, either side of each metre, the line's ends included; each number's ink
    // as the watch draws it (Widgets.inkPastEdge). A number whose box, as wide as its advances and from
    // the digits' highest ink to their lowest, is inside the screen has its ink inside too: only the
    // others are traced, or the brute force trips the watchdog.
    function inkPastEdge(d as Draw, x as Float, y0 as Float, h as Float) as Float {
        var font = d.semi(Widgets.NUMBER_SIZE), nx = x - Widgets.RING_OUTER - Widgets.NUMBER_SPACE;
        var digit = d.dc.getTextWidthInPixels("0", font), minus = d.dc.getTextWidthInPixels("-", font);
        var em = Graphics.getFontAscent(font) / 1000.0, r = d.w / 2, lo = Climb.netLow(), hi = Climb.netHigh();
        var worst = -d.w, inkTop = 0, inkFoot = 0;
        for (var g = 0; g < DigitInk.LEFT.size(); g++) {
            for (var j = 1; j < DigitInk.LEFT[g].size(); j += 2) {
                var v = DigitInk.LEFT[g][j];
                if (v > inkTop) { inkTop = v; }
                if (v < inkFoot) { inkFoot = v; }
            }
        }
        for (var i = lo; i <= hi; i++) {
            for (var side = -1; side <= 1; side += 2) {
                var n = i + side * 0.49;
                if (n < lo) { n = lo.toFloat(); }
                if (n > hi) { n = hi.toFloat(); }
                var nums = Widgets.numbersAt(n), ys = Widgets.numberYs(y0 - Widgets.shareAt(n) * h, y0, h);
                for (var k = 0; k < 2; k++) {
                    var t = nums[k].format("%d"), w = (t.length() - (nums[k] < 0 ? 1 : 0)) * digit + (nums[k] < 0 ? minus : 0);
                    var base = d.s(ys[k]) - Graphics.getFontHeight(font) / 2 + Graphics.getFontAscent(font);
                    var box = -d.w, rows = [base - inkTop * em, base - inkFoot * em] as Array<Float>;
                    for (var b = 0; b < 2; b++) {
                        var dy = rows[b] - r, q = r * r - dy * dy;
                        var over = (r - Math.sqrt(q > 0 ? q : 0.0) - (d.s(nx) - w)).toFloat();
                        if (over > box) { box = over; }
                    }
                    // The outlines traced in full (boxFirst false): the brute force has its own box, from
                    // the ink's real extent, so a wrong box in Widgets cannot hide here.
                    var over = box <= 0 ? box : Widgets.inkPastEdge(d, font, nx, ys[k], t, digit, minus, false);
                    if (over > worst) { worst = over; }
                }
            }
        }
        return worst;
    }

    // The box Widgets.inkPastEdge checks before tracing holds every number glyph's ink (#119): were
    // DigitInk made again with ink outside it, the box would pass numbers whose ink crosses the edge.
    (:test)
    function digitInkInsideTheBox(logger as Logger) as Boolean {
        for (var g = 0; g < DigitInk.LEFT.size(); g++) {
            var p = DigitInk.LEFT[g];
            for (var j = 0; j < p.size(); j += 2) {
                var at = DigitInk.CHARS.substring(g, g + 1) + " at " + p[j] + ", " + p[j + 1];
                Test.assertMessage(p[j] >= Widgets.INK_LEFT, at + ": left of the box");
                Test.assertMessage(p[j + 1] >= Widgets.INK_FOOT && p[j + 1] <= Widgets.INK_TOP, at + ": above or below the box");
            }
        }
        return true;
    }

    // With the box first or the outlines traced in full, the overshoot is the same wherever the ink
    // reaches the edge, and below 0 in both where it does not (#119): numbers of every width and sign,
    // along the left edge from top to bottom and either side of it.
    (:test)
    function inkBoxAgreesWithTrace(logger as Logger) as Boolean {
        var d = draw(), font = d.semi(Widgets.NUMBER_SIZE);
        var digit = d.dc.getTextWidthInPixels("0", font), minus = d.dc.getTextWidthInPixels("-", font);
        var texts = ["1", "7", "10", "100", "1000", "-1", "-10", "-100", "48", "350"] as Array<String>;
        for (var x = 0.02; x < 0.3; x += 0.02) {
            for (var y = 0.0; y <= 1.0; y += 0.05) {
                for (var i = 0; i < texts.size(); i++) {
                    var a = Widgets.inkPastEdge(d, font, x, y, texts[i], digit, minus, true);
                    var b = Widgets.inkPastEdge(d, font, x, y, texts[i], digit, minus, false);
                    var at = texts[i] + " at " + x + ", " + y + ": box first " + a + ", traced " + b;
                    Test.assertMessage(b < 0 ? a < 0 : a == b, at);
                }
            }
        }
        return true;
    }

    // Pages 1 and 1a place the ascent from its numbers' ink (#109, design/page-1.md): on the demo route
    // and the mock's Daubenhorn stand-in where the mock has it, the ink on the screen; on the Daubenhorn,
    // in Barlow Semi Condensed, the ink crosses the edge there, and the line moves right by whole pixels
    // just until it does not, the profile's right end where it was.
    (:test, :noreplay)
    function ascentNumbersStayOnTheScreen(logger as Logger) as Boolean {
        var d = draw(), y0 = Pages.PROFILE_Y0, h = Pages.PROFILE_H, px = 1.0 / d.w;
        var routes = [RouteTest.demo(), daubenhorn(true)] as Array<Route>, names = ["the demo: ", "the mock's Daubenhorn: "];
        for (var r = 0; r < routes.size(); r++) {
            Climb.use(routes[r], :ferrata);
            Test.assertEqualMessage(Pages.profileLeft(d), Pages.PROFILE_X0, names[r] + "the profile's left where the mock has it");
            var at0 = inkPastEdge(d, Pages.PROFILE_X0, y0, h);
            logger.debug(names[r] + "the ink comes within " + (-at0) + " px of the edge");
            Test.assertMessage(at0 <= 0, names[r] + "the ink past the edge by " + at0 + " px");
        }
        Climb.use(daubenhorn(false), :ferrata);
        var x = Pages.profileLeft(d), moved = (x - Pages.PROFILE_X0) * d.w, where = "the Daubenhorn: ";
        var at0 = inkPastEdge(d, Pages.PROFILE_X0, y0, h), atX = inkPastEdge(d, x, y0, h), less = inkPastEdge(d, x - px, y0, h);
        logger.debug(where + "the ink " + at0 + " px past the edge where the mock has the line; moved " + moved + " px");
        Test.assertMessage(at0 > 0, where + "the ink on the screen at the mock's place, " + at0 + " px past the edge");
        Test.assertMessage(atX <= 0, where + "moved " + moved + " px, the ink still past the edge by " + atX + " px");
        Test.assertMessage(less > 0, where + "moved " + moved + " px, one fewer would do: the ink " + less + " px past the edge");
        for (var p = 0; p < 2; p++) { Pages.draw(p, d, at(Climb.totalD() / 2.0)); }
        return true;
    }

    // A route of sections [len, up, grade], from a head at 1000 m, with the points given.
    function route(steps as Array<Array<Number> >, points as Array<Dictionary>) as Route {
        var sections = [] as Array<Dictionary>, len = 0;
        for (var i = 0; i < steps.size(); i++) {
            sections.add({"len" => steps[i][0], "up" => steps[i][1], "grade" => steps[i][2], "min" => 10,
                "name" => "S" + i, "side" => 0.0});
            len += steps[i][0];
        }
        var all = [{"kind" => "head", "at" => 0, "alt" => 1000, "name" => "Head"},
            {"kind" => "top", "at" => len, "name" => "Top"}] as Array<Dictionary>;
        all.addAll(points);
        return Route.fromJson({"format" => 1, "id" => "p", "name" => "P", "short" => "P",
            "sections" => sections, "points" => all}) as Route;
    }

    // The half steps' colours: a full grade its colour of the map (A to E; F and F/G as E), a half step
    // the rounded mean of its neighbours, channel by channel.
    (:test)
    function halfStepColours(logger as Logger) as Boolean {
        var t = Palette.halfSteps(), c = Palette.HEAT_AMBER;
        Test.assertEqualMessage(t.size(), 13, "walking and twelve half steps");
        Test.assertEqualMessage(t[0], c[0], "walking");
        for (var k = 1; k <= 5; k++) { Test.assertEqualMessage(t[2 * k - 1], c[k], "full grade " + k); }
        for (var g = 10; g <= 12; g++) { Test.assertEqualMessage(t[g], c[5], "E/F to F/G as E"); }
        // C/D (6) between C (amber yellow) and D (amber).
        var mix = 0;
        for (var sh = 0; sh <= 16; sh += 8) {
            mix |= Math.round((((c[3] >> sh) & 0xff) + ((c[4] >> sh) & 0xff)) / 2.0).toNumber() << sh;
        }
        Test.assertEqualMessage(t[6], mix, "C/D");
        return true;
    }

    // The point of interest: the nearest; on a tie danger, then exit, then rest.
    (:test)
    function poiNearestThenInOrder(logger as Logger) as Boolean {
        var at100 = [{"kind" => "exit", "at" => 100, "name" => "Exit"}] as Array<Dictionary>;
        var both = [{"kind" => "exit", "at" => 100, "name" => "Exit"},
            {"kind" => "danger", "at" => 100, "name" => "Danger"}] as Array<Dictionary>;
        var steps = [[100, 100, 3], [20, 0, -1], [100, 100, 5]] as Array<Array<Number> >;
        Climb.use(route(steps, both), :ferrata);
        Test.assertEqualMessage(Widgets.poiNear(at(100.0), false), 0, "danger before exit and rest");
        Climb.use(route(steps, at100), :ferrata);
        Test.assertEqualMessage(Widgets.poiNear(at(100.0), false), 1, "exit before rest");
        Climb.use(route(steps, [] as Array<Dictionary>), :ferrata);
        Test.assertEqualMessage(Widgets.poiNear(at(100.0), false), 2, "the rest");
        Test.assertEqualMessage(Widgets.poiNear(at(220.0), true), Widgets.POI_TOP, "the top within the stretch");
        Test.assertEqualMessage(Widgets.poiNear(at(220.0), false), -1, "nothing without the ends");
        return true;
    }

    // What comes next: the next section of a different difficulty and its distance to 5 m, or the
    // top; page 7 places its group by the widest such line on the route.
    (:test)
    function nextAndTheLongestNext(logger as Logger) as Boolean {
        Climb.use(route([[100, 100, 1], [50, 0, 1], [100, 100, 3]] as Array<Array<Number> >, [] as Array<Dictionary>), :ferrata);
        var n = Widgets.nextSection(at(12.0));
        Test.assertEqualMessage(n[0], 2, "B after the two A sections");
        Test.assertEqualMessage(n[1], 140, "138 m, to 5 m");
        n = Widgets.nextSection(at(200.0));
        Test.assertEqualMessage(n[0], -1, "the top");
        Test.assertEqualMessage(n[1], 50, "50 m to the top");
        var d = draw(), font = d.bold(0.0577);
        var a = d.width(font, "B 150 m"), b = d.width(font, "Top 100 m");
        Test.assertEqualMessage(Widgets.longestNext(d, font), a > b ? a : b, "the longer of the two runs' lines");
        return true;
    }

    // The stack's ticks in feet: every step in feet, where the route rises through them.
    (:test)
    function stackTicksInFeet(logger as Logger) as Boolean {
        Climb.use(DescentTest.downRoute(), :ferrata);
        // 1000 m is 3281 ft: 3300 to 3600 on the first climb, none down to 1050 m (3445 ft), then 3500
        // to 3700 on the second climb to 1150 m (3773 ft).
        var t = Widgets.stackTicks(true, 0.0, 200.0, 100, 3.28084);
        Test.assertEqualMessage(t[0].toString(), [3300, 3400, 3500, 3600, 3500, 3600, 3700].toString(), "altitudes in feet");
        Test.assertMessage(RouteTest.near(t[1][0], 3300 / 3.28084 - 1000), "3300 ft about 5.8 m up");
        return true;
    }

    // The front view on a long route like the Daubenhorn's 1545 m (#105): a point every 4 m of height on
    // the walls and one step on every other section, not a point every 4 m along the route (462 points,
    // which tripped the watchdog on the front page's first frame). The test runner does not enforce the
    // watchdog, so the point count stands in for it; the check on the watch stays the acceptance.
    (:test, :noreplay)
    function frontViewLight(logger as Logger) as Boolean {
        var steps = [[600, 0], [60, 40], [40, 97], [60, 10], [30, 85], [25, 67], [80, 0], [60, 140], [120, 80],
            [40, 105], [100, 30], [200, 142], [120, 15], [10, 30]] as Array<Array<Number> >;
        useLong(steps);
        var pts = Widgets.frontPoints(), n = Climb.count();
        // The start, the walls' 131 points, one for each of the 8 other sections.
        Test.assertEqualMessage(pts.size(), 1 + 131 + 8, "points");
        // The points follow the route: distance never goes back, and the last is at the top's height.
        for (var j = 1; j < pts.size(); j++) { Test.assertMessage(pts[j][2] >= pts[j - 1][2], "distance at point " + j); }
        Test.assertMessage(RouteTest.near(pts[pts.size() - 1][1], Climb.netAt(n).toFloat()), "the top's height");
        var d = draw(), len = Climb.totalD().toFloat(), places = [0.0, 300.0, 700.0, len] as Array<Float>;
        for (var p = 0; p < places.size(); p++) {
            Pages.draw(11, d, at(places[p]));
            Pages.draw(12, d, at(places[p]));
        }
        return true;
    }

    // However much wall a route has, the walls together get at most FRONT_BUDGET points, a few more for
    // rounding (one per wall): 20 walls of 300 m would be 1500 points at one every 4 m.
    (:test)
    function frontViewWithinBudget(logger as Logger) as Boolean {
        var steps = [] as Array<Array<Number> >;
        for (var i = 0; i < 20; i++) { steps.add([50, 300] as Array<Number>); steps.add([200, 0] as Array<Number>); }
        useLong(steps);
        var pts = Widgets.frontPoints();
        Test.assertMessage(pts.size() <= 1 + Widgets.FRONT_BUDGET + 20 + 20, pts.size() + " points");
        Test.assertMessage(pts.size() >= Widgets.FRONT_BUDGET, pts.size() + " points: the walls still get their share");
        return true;
    }

    // A route of [length, height] sections, sideways alternately, grade C.
    function useLong(steps as Array<Array<Number> >) as Void {
        var sections = [] as Array<Dictionary>, len = 0;
        for (var i = 0; i < steps.size(); i++) {
            sections.add({"len" => steps[i][0], "up" => steps[i][1], "grade" => 3, "min" => 10, "name" => "S" + i,
                "side" => i % 2 == 0 ? -0.6 : 0.4});
            len += steps[i][0];
        }
        Climb.use(Route.fromJson({"format" => 1, "id" => "long", "name" => "Long", "short" => "Long",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 2100, "name" => "Head"},
                {"kind" => "top", "at" => len, "name" => "Top"}]}) as Route, :ferrata);
    }
}
