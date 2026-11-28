using Toybox.Math;
using Toybox.System;

import Toybox.Lang;
import Toybox.Test;

// Pages 16 to 19 (#67, design/page-16.md): progress as done and total, from the tracker's state, in
// the watch's units, laid out from the widest values so nothing moves, 6 % of the width clear of the
// edge at every size the app builds for.
module NumbersTest {

    // A route with an approach of len metres, up gained, and a short ferrata.
    function withApproach(len as Number, up as Number) as Route {
        return Route.fromJson({"format" => 1, "units" => "m", "id" => "a", "name" => "A", "short" => "A",
            "approach" => [{"len" => len, "up" => up, "grade" => 0, "min" => 180, "name" => "Walk", "side" => 0.0}],
            "sections" => [{"len" => 100, "up" => 100, "grade" => 3, "min" => 10, "name" => "Wall", "side" => 0.0}],
            "points" => [{"kind" => "approach", "at" => -len, "type" => "Car park", "name" => "Car park"},
                {"kind" => "head", "at" => 0, "alt" => 1000, "name" => "Head"},
                {"kind" => "top", "at" => 100, "name" => "Top"}]}) as Route;
    }

    // The parts the fit is checked on, [route, part]: the demo's ferrata and approach, the Daubenhorn's
    // ferrata (four-digit path, three-digit ascent), and an approach of 12 km (a five-digit path in
    // metres, 39370 ft).
    function parts() as Array<Array> {
        return [[RouteTest.demo(), :ferrata], [RouteTest.demo(), :approach], [PagesTest.daubenhorn(false), :ferrata],
            [withApproach(12000, 0), :approach]] as Array<Array>;
    }

    // States along the part in use: the start, every section's end and middle, and the end; the active
    // time a quarter of the metres done, the pace 1, and at the end once more with an estimate past
    // ten hours (h:mm a digit wider).
    function states() as Array<Climb.State> {
        var out = [] as Array<Climb.State>;
        for (var i = 0; i <= Climb.count(); i++) {
            var b = Climb.dAt(i).toFloat();
            out.add(at(b, b / 4, 1.0));
            if (i < Climb.count()) { var m = (b + Climb.dAt(i + 1)) / 2; out.add(at(m, m / 4, 1.0)); }
        }
        out.add(at(Climb.totalD().toFloat(), 605.0, 1.0));
        return out;
    }

    // The state at distance d, active minutes in at pace (the clock as the active time: no pause), the
    // active time set for the pages as the view sets it.
    function at(d as Float, active as Float, pace as Float) as Climb.State {
        Numbers.activeMin = active;
        return Climb.State.placed(d, Climb.heightAtDistance(d), active, pace, 480.0, 25);
    }

    // The state st as the view hands it to the pages: its active time set (the states here have no pause).
    function shown(st as Climb.State) as Climb.State {
        Numbers.activeMin = st.elapsed();
        return st;
    }

    function text(r as Array<String>) as String { return r[0] + " of " + r[1] + " " + r[2]; }

    // Pages 16 to 19 follow page 15 in the cycle, page 19 the last; the tap zone stays page 15's.
    (:test)
    function progressPagesFollowPageFifteen(logger as Logger) as Boolean {
        Test.assertEqualMessage(Pages.pageAt(Pages.SECTION_PAGE), 14, "page 15 at the tap zone's place");
        for (var k = 0; k < 4; k++) {
            Test.assertEqualMessage(Pages.pageAt(Pages.SECTION_PAGE + 1 + k), 15 + k, "page " + (16 + k) + " after page " + (15 + k));
        }
        Test.assertEqualMessage(Pages.pageAt(Pages.COUNT - 1), 18, "page 19 last");
        return true;
    }

    // The rows on a wall 300 m across and 400 m up (a path of 500 m) of 10 guidebook minutes, halfway, 75
    // minutes in: 250 of 500 m, 200 of 400 m, and 1:15 of 1:20 at the guidebook's pace, of 1:25 at twice it.
    (:test)
    function rowsReadTheRoute(logger as Logger) as Boolean {
        Climb.use(RouteTest.made([[300, 400]] as Array<Array<Number> >), :ferrata);
        var st = at(150.0, 75.0, 1.0);
        Test.assertEqualMessage(text(Numbers.rowIn(st, 0, false)), "250 of 500 m", "distance");
        Test.assertEqualMessage(text(Numbers.rowIn(st, 1, false)), "200 of 400 m", "ascent");
        Test.assertEqualMessage(text(Numbers.rowIn(st, 2, false)), "1:15 of 1:20 ", "time");
        Test.assertEqualMessage(Numbers.rowIn(at(150.0, 75.0, 2.0), 2, false)[1], "1:25", "the estimate at twice the guidebook");
        Test.assertEqualMessage(Numbers.rowIn(at(0.0, 595.0, 1.0), 2, false)[1], "10:05", "an estimate past ten hours");
        Test.assertEqualMessage(Numbers.hmm(-3.0), "0:00", "never below 0");
        return true;
    }

    // In feet (the watch's elevation units, owner 2026-11-27): the same wall, 820 of 1640 ft along, 656
    // of 1312 ft up; the time as in metres. The page draws the watch's own units.
    (:test)
    function rowsInFeet(logger as Logger) as Boolean {
        Climb.use(RouteTest.made([[300, 400]] as Array<Array<Number> >), :ferrata);
        var st = at(150.0, 75.0, 1.0);
        Test.assertEqualMessage(text(Numbers.rowIn(st, 0, true)), "820 of 1640 ft", "distance");
        Test.assertEqualMessage(text(Numbers.rowIn(st, 1, true)), "656 of 1312 ft", "ascent");
        Test.assertEqualMessage(text(Numbers.rowIn(st, 2, true)), "1:15 of 1:20 ", "time");
        // Converted, not relabelled: a 100 m ascent is 328 ft, as Widgets converts (x 3.28084).
        Climb.use(RouteTest.made([[100, 100]] as Array<Array<Number> >), :ferrata);
        Test.assertEqualMessage(Numbers.rowIn(at(100.0, 10.0, 1.0), 1, true)[1], "328", "100 m up in feet");
        Test.assertEqualMessage(Numbers.rowIn(at(100.0, 10.0, 1.0), 1, false)[1], "100", "100 m up in metres");
        var ft = Widgets.feet();
        Test.assertEqualMessage(text(Numbers.row(st, 1)), text(Numbers.rowIn(st, 1, ft)), "the watch's units, feet " + ft);
        return true;
    }

    // Ascent counts height gained: up 50, down 20, up 30 gains 80; halfway down the descent 50 are
    // climbed, at the top 80. The path is the three slopes, 112 + 102 + 104 m.
    (:test)
    function ascentCountsHeightGained(logger as Logger) as Boolean {
        Climb.use(RouteTest.made([[100, 50], [100, -20], [100, 30]] as Array<Array<Number> >), :ferrata);
        Test.assertEqualMessage(text(Numbers.rowIn(at(150.0, 10.0, 1.0), 1, false)), "50 of 80 m", "halfway down");
        Test.assertEqualMessage(text(Numbers.rowIn(at(300.0, 10.0, 1.0), 1, false)), "80 of 80 m", "at the top");
        Test.assertEqualMessage(text(Numbers.rowIn(at(300.0, 10.0, 1.0), 0, false)), "318 of 318 m", "the path");
        return true;
    }

    // On an approach that gains no height the ascent reads 0 of 0, not of 1 (Climb.totalU's guard).
    (:test)
    function flatApproachGainsNothing(logger as Logger) as Boolean {
        Climb.use(withApproach(200, 0), :approach);
        Test.assertEqualMessage(text(Numbers.rowIn(at(100.0, 10.0, 1.0), 1, false)), "0 of 0 m", "ascent");
        Test.assertEqualMessage(text(Numbers.rowIn(at(100.0, 10.0, 1.0), 0, false)), "100 of 200 m", "distance");
        return true;
    }

    // Driven by the tracker (TrackerTest.climbing): about 60 m up the demo's first wall in 12 minutes,
    // then an hour's pause. The stopwatch is active time (owner, 2026-11-27): pages 16 and 19 show 0:12
    // after the pause as before it, not the clock's 1:12; the distance and the ascent hold; the estimate
    // is the active time and the time left, which the slower pace makes longer.
    (:test)
    function aPauseIsLeftOutOfTheTime(logger as Logger) as Boolean {
        var t = TrackerTest.climbing(60), before = t.state();
        Numbers.activeMin = t.activeS / 60.0;
        var b = [Numbers.rowIn(before, 0, false), Numbers.rowIn(before, 1, false), Numbers.rowIn(before, 2, false)] as Array<Array<String> >;
        Test.assertEqualMessage(b[2][0], "0:12", "12 minutes");
        t.pause(TrackerTest.at(12, 1350.0));
        t.update(TrackerTest.at(72, 1350.0));
        var after = t.state();
        Numbers.activeMin = t.activeS / 60.0;
        Test.assertEqualMessage(Numbers.hmm(after.elapsed()), "1:12", "the clock counts the pause");
        Test.assertEqualMessage(Numbers.rowIn(after, 2, false)[0], "0:12", "the stopwatch does not");
        Test.assertEqualMessage(Numbers.rowIn(after, 0, false)[0], b[0][0], "the distance holds");
        Test.assertEqualMessage(Numbers.rowIn(after, 1, false)[0], b[1][0], "the ascent holds");
        Test.assertMessage(Numbers.estimate(after) > 12.0 + before.left(),
            "the estimate longer at the slower pace: " + b[2][1] + " to " + Numbers.rowIn(after, 2, false)[1]);
        Test.assertEqualMessage(Numbers.rowIn(after, 2, false)[1], Numbers.hmm(12.0 + after.left()), "active and left");
        // Pages 16 and 19 draw it.
        var d = PagesTest.draw();
        Pages.drawPage(15, d, after);
        Pages.drawPage(18, d, after);
        return true;
    }

    // Pages 16 to 19 draw at every place, on every part checked and the route that dips below its head
    // (a throw fails the test).
    (:test, :noreplay)
    function progressPagesDrawEverywhere(logger as Logger) as Boolean {
        var ps = parts(), d = PagesTest.draw();
        DescentTest.drawsEverywhere(DescentTest.dipRoute(), 15, 18);
        for (var p = 0; p < ps.size(); p++) {
            Climb.use(ps[p][0] as Route, ps[p][1] as Symbol);
            var sts = states();
            for (var s = 0; s < sts.size(); s++) {
                for (var page = 15; page <= 18; page++) { Pages.drawPage(page, d, shown(sts[s])); }
            }
        }
        return true;
    }

    // Whether (x, y) is within r of the screen's centre (FIT_R: 6 % of the width clear of the edge;
    // 0.46: 4 % clear), to half a pixel.
    function clear(d as Draw, x as Float, y as Float, r as Float) as Boolean {
        var dx = x - 0.5, dy = y - 0.5, e = r + 0.5 / d.w;
        return dx * dx + dy * dy <= e * e;
    }

    function boxClear(d as Draw, b as Array<Float>, r as Float) as Boolean {
        return clear(d, b[0], b[1], r) && clear(d, b[2], b[1], r) && clear(d, b[0], b[3], r) && clear(d, b[2], b[3], r);
    }

    // How near the box's farthest corner comes to the edge, as a share of the width (0.06: 6 % clear).
    function margin(b as Array<Float>) as Float {
        var worst = 0.0;
        for (var i = 0; i < 4; i++) {
            var dx = b[i % 2 == 0 ? 0 : 2] - 0.5, dy = b[i < 2 ? 1 : 3] - 0.5, r = dx * dx + dy * dy;
            if (r > worst) { worst = r; }
        }
        return (0.5 - Math.sqrt(worst)).toFloat();
    }

    // Page 16 as the review of #142 first measured it: one box, the widest total's width (with the wider
    // unit) at every row's height and the top symbol's: kept to show where that overstated the corner.
    function oneBoxOf(d as Draw, st as Climb.State, f as Float) as Array<Float> {
        var font = d.semi(f), widest = 0.0;
        for (var k = 0; k < 6; k++) {
            var w = d.width(font, Numbers.rowIn(st, k % 3, k >= 3)[1]);
            if (w > widest) { widest = w; }
        }
        var ofW = d.whole(f * 0.87), gap = 0.028846, pitch = d.whole(f * 1.4), top = 0.5 + Numbers.CAP * f / 2 - pitch;
        var ftW = d.width(d.semi(Numbers.F32), "ft"), up = 0.36 * f + ofW / 2, down = ofW / 2 - 0.36 * f;
        return [0.5 - ofW / 2 - gap - widest, top - (up > Numbers.CAP * f ? up : Numbers.CAP * f),
            0.5 + ofW / 2 + gap + widest + 0.009615 + ftW, top + 2 * pitch + (down > 0 ? down : 0.0)] as Array<Float>;
    }

    // How near a row's text comes to the edge, measured here: from its value done to its total and unit,
    // from its digits' top to its baseline.
    function rowClearance(d as Draw, st as Climb.State, f as Float, k as Number, ft as Boolean) as Float {
        var font = d.semi(f), row = Numbers.rowIn(st, k, ft), ofW = d.whole(f * 0.87), gap = 0.028846;
        var pitch = d.whole(f * 1.4), y = 0.5 + Numbers.CAP * f / 2 - pitch + k * pitch;
        var x1 = 0.5 + ofW / 2 + gap + d.width(font, row[1]);
        if (row[2].length() > 0) { x1 += 0.009615 + d.width(d.semi(Numbers.F32), row[2]); }
        return margin([0.5 - ofW / 2 - gap - d.width(font, row[0]), y - Numbers.CAP * f, x1, y] as Array<Float>);
    }

    // Page 16 at every place of every part, in metres and in feet: the size is the one chosen at the
    // start (each place chooses anew, the cache dropped, so it is the layout that holds, not the cache):
    // 52 with totals of four digits or fewer, in either unit (owner, 2026-11-28), and a size of the
    // table below 52 for the 12 km approach's five-digit path; every row keeps 4 % of the width clear of
    // the edge, measured here row by row in the font drawn. Logged per part: the nearest row with the
    // estimate under ten hours and past it, and what the one-box measure made of them.
    (:test)
    function pageSixteenFitsAndHoldsItsSize(logger as Logger) as Boolean {
        var d = PagesTest.draw(), ps = parts(), e = 0.5 / d.w;
        for (var p = 0; p < ps.size(); p++) {
            Climb.use(ps[p][0] as Route, ps[p][1] as Symbol);
            var sts = states(), where = "part " + p + ": ";
            Numbers.forget();
            var fs = Numbers.progressSize(d, shown(sts[0]));
            if (p < 3) {
                Test.assertEqualMessage(fs, Numbers.F52, where + "four-digit totals at 52");
            } else {
                Test.assertMessage(fs < Numbers.F52 && FontSizes.SEMI.indexOf(fs) >= 0, where + "a five-digit total steps down: " + fs);
            }
            // [the nearest, its state, its row, the one box's nearest], under ten hours and past it.
            var near = [[1.0, -1, "", 1.0], [1.0, -1, "", 1.0]] as Array<Array>;
            for (var s = 0; s < sts.size(); s++) {
                Numbers.forget();
                var st = shown(sts[s]), f = Numbers.progressSize(d, st), long = Numbers.longTime(st) ? 1 : 0;
                if (long == 0) { Test.assertEqualMessage(f, fs, where + "the same size at state " + s); }
                var font = d.semi(f), n = near[long], box = margin(oneBoxOf(d, st, f));
                if (box < (n[3] as Float)) { n[3] = box; }
                for (var u = 0; u < 2; u++) {
                    for (var k = 0; k < 3; k++) {
                        var row = Numbers.rowIn(st, k, u == 1);
                        Test.assertMessage(d.width(font, row[0]) <= d.width(font, row[1]), where + "done " + row[0] + " wider than its total " + row[1]);
                        var c = rowClearance(d, st, f, k, u == 1);
                        Test.assertMessage(c >= Numbers.ROWS_CLEAR - e, where + "state " + s + ", " + row[1] + " " + row[2] + " at " + f + ": " + c + " clear");
                        if (c < (n[0] as Float)) { n[0] = c; n[1] = s; n[2] = row[1] + " " + row[2]; }
                    }
                }
                Test.assertMessage(Numbers.progressClearance(d, st, f) >= Numbers.ROWS_CLEAR - e, where + "state " + s + ": the symbols too");
            }
            for (var l = 0; l < 2; l++) {
                var n = near[l];
                if ((n[1] as Number) < 0) { continue; }
                var at = n[1] as Number, size = l == 0 ? fs : Numbers.progressSize(d, shown(sts[at]));
                var line = where + (l == 0 ? "under ten hours" : "past ten hours") + ": size " + size.toString()
                    + ", nearest row " + (n[2] as String) + " at state " + at.toString() + ", " + (n[0] as Float).toString()
                    + " of the width clear; the one box said " + (n[3] as Float).toString();
                logger.debug(line);
            }
        }
        return true;
    }

    // Pages 17 to 19 at every place of every part, in metres and in feet: chosen afresh each time, the
    // right edge and the two lines stay where they were at the start (only the symbol moves), the value
    // done sits after its symbol, and the group stays 6 % clear of the edge, from the symbol or "of" at
    // the left to the second baseline.
    (:test)
    function pagesSeventeenToNineteenStayPut(logger as Logger) as Boolean {
        var d = PagesTest.draw(), ps = parts();
        for (var p = 0; p < ps.size(); p++) {
            Climb.use(ps[p][0] as Route, ps[p][1] as Symbol);
            var sts = states();
            for (var u = 0; u < 2; u++) {
                for (var k = 0; k < 3; k++) {
                    var ft = u == 1, where = "part " + p + ", page " + (17 + k) + (ft ? " in feet: " : ": ");
                    Numbers.forget();
                    var f = Numbers.oneFitted(d, shown(sts[0]), k)[6], first = Numbers.oneLayout(d, Numbers.rowIn(sts[0], k, ft), f);
                    var moves = 0, x = first[1];
                    for (var s = 0; s < sts.size(); s++) {
                        Numbers.forget();
                        var size = Numbers.oneFitted(d, shown(sts[s]), k)[6], row = Numbers.rowIn(sts[s], k, ft);
                        var L = Numbers.oneLayout(d, row, size);
                        if (!Numbers.longTime(sts[s]) || k < 2) {
                            Test.assertEqualMessage(size, f, where + "the size at state " + s);
                            Test.assertEqualMessage(L[0], first[0], where + "the right edge at state " + s);
                            Test.assertEqualMessage(L[2], first[2], where + "the first line at state " + s);
                            Test.assertEqualMessage(L[3], first[3], where + "the second line at state " + s);
                        }
                        if (L[1] != x) { moves++; x = L[1]; }
                        var textLeft = L[0] - L[5] - d.width(d.semi(L[6]), row[0]);
                        Test.assertMessage(textLeft >= L[1] + L[4] / 2, where + "the value over its symbol at state " + s);
                        var ofLeft = L[0] - L[5] - d.width(d.semi(L[7]), row[1]) - d.width(d.semi(Numbers.F40), "of ");
                        var x0 = L[1] - L[4] / 2 < ofLeft ? L[1] - L[4] / 2 : ofLeft;
                        var b = [x0, L[2] - Numbers.CAP * L[6], L[0], L[3]] as Array<Float>;
                        Test.assertMessage(boxClear(d, b, Numbers.FIT_R), where + "state " + s + " at " + L[6] + ": " + b + " not clear of the edge");
                    }
                    logger.debug(where + "size " + f + ", the symbol moved " + moves + " times");
                }
            }
        }
        return true;
    }

    // Memory (review of #142): every page drawn in turn on the Daubenhorn, the parked ones too, each at
    // the start, halfway and the top, the memory in use logged after each. The fonts stay loaded once
    // drawn, so the most is the peak the pages reach.
    (:test, :noreplay)
    function memoryAfterEveryPage(logger as Logger) as Boolean {
        Climb.use(PagesTest.daubenhorn(false), :ferrata);
        var d = PagesTest.draw(), total = Climb.totalD().toFloat(), peak = 0;
        var sts = [at(0.0, 0.0, 1.0), at(total / 2, 60.0, 1.0), at(total, 140.0, 1.0)] as Array<Climb.State>;
        for (var page = 0; page <= 18; page++) {
            for (var s = 0; s < sts.size(); s++) { Pages.drawPage(page, d, shown(sts[s])); }
            var used = System.getSystemStats().usedMemory;
            if (used > peak) { peak = used; }
            logger.debug("page " + (page + 1) + ": " + used + " bytes in use");
        }
        logger.debug("peak " + peak + " of " + System.getSystemStats().totalMemory + " bytes, at "
            + System.getDeviceSettings().screenWidth + " px");
        return true;
    }
}
