using Toybox.Math;

import Toybox.Lang;
import Toybox.Test;

// Pages 16 to 19 (#67, design/page-16.md): progress as done and total, from the tracker's state, laid
// out from the widest values so nothing moves, on the screen at every size the app builds for.
module NumbersTest {

    // The routes the pages are checked on: the demo, and the Daubenhorn (four-digit path, three-digit
    // ascent, the widest the bundled routes get).
    function routes() as Array<Route> {
        return [RouteTest.demo(), PagesTest.daubenhorn(false)] as Array<Route>;
    }

    // Places along the part: the head, every section's end and middle, and the top.
    function places() as Array<Float> {
        var out = [] as Array<Float>;
        for (var i = 0; i <= Climb.count(); i++) {
            var b = Climb.dAt(i).toFloat();
            out.add(b);
            if (i < Climb.count()) { out.add((b + Climb.dAt(i + 1)) / 2); }
        }
        return out;
    }

    function at(d as Float, elapsed as Float) as Climb.State {
        return Climb.State.placed(d, Climb.heightAtDistance(d), elapsed, 1.0, 480.0, 25);
    }

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

    // The rows' values are the state's: the path along the route (length and height combined) done of
    // its total, the height gained of the route's, and the time passed of the estimate (passed and left
    // at the climber's pace), each to the metre or minute.
    (:test)
    function rowsMatchTheState(logger as Logger) as Boolean {
        Climb.use(RouteTest.demo(), :ferrata);
        var st = at(200.0, 75.0), path = Widgets.pathAtDistance(200.0), total = Widgets.pathAt(Climb.count());
        Test.assertMessage(path > 200.0 && path < total, "the path at 200 m along: " + path);
        var r = Numbers.row(st, 0);
        Test.assertEqualMessage(r[0], Math.round(path).toNumber().format("%d"), "distance done");
        Test.assertEqualMessage(r[1], Math.round(total).toNumber().format("%d"), "distance total");
        Test.assertEqualMessage(r[2], "m", "distance unit");
        r = Numbers.row(st, 1);
        Test.assertEqualMessage(r[0], st.climbed().format("%d"), "ascent done");
        Test.assertEqualMessage(r[1], Climb.totalU().format("%d"), "ascent total");
        r = Numbers.row(st, 2);
        Test.assertEqualMessage(r[0], "1:15", "75 minutes passed");
        Test.assertEqualMessage(r[1], Numbers.hmm(75.0 + st.left()), "the estimate");
        Test.assertEqualMessage(r[2], "", "no unit after a time");
        // At the top, done is the total.
        var top = at(Climb.totalD().toFloat(), 200.0);
        for (var k = 0; k < 2; k++) {
            var t = Numbers.row(top, k);
            Test.assertEqualMessage(t[0], t[1], "row " + k + " at the top");
        }
        Test.assertEqualMessage(Numbers.hmm(59.6), "1:00", "rounded to the minute");
        Test.assertEqualMessage(Numbers.hmm(-3.0), "0:00", "never below 0");
        return true;
    }

    // Driven by the tracker: the demo climb, its state each tick, the rows its climbed height and time.
    (:test)
    function rowsFollowTheTracker(logger as Logger) as Boolean {
        var f = new TestFeed(RouteTest.demo(), true, false);
        f.start(:head);
        for (var k = 0; k < 40; k++) { f.tick(); }
        var st = f.tracker.state();
        Test.assertMessage(st.d > 0 && st.elapsed() > 0, "the climber moved: " + st.d + " m, " + st.elapsed() + " min");
        Test.assertEqualMessage(Numbers.row(st, 0)[0], Math.round(Widgets.pathAtDistance(st.d)).toNumber().format("%d"), "distance");
        Test.assertEqualMessage(Numbers.row(st, 1)[0], st.climbed().format("%d"), "ascent");
        Test.assertEqualMessage(Numbers.row(st, 2)[0], Numbers.hmm(st.elapsed()), "time");
        Test.assertEqualMessage(Numbers.row(st, 2)[1], Numbers.hmm(st.elapsed() + st.left()), "estimate");
        return true;
    }

    // Pages 16 to 19 draw at every place, on the demo, the Daubenhorn and the route that dips below its
    // head (a throw fails the test).
    (:test, :noreplay)
    function progressPagesDrawEverywhere(logger as Logger) as Boolean {
        var rs = routes();
        rs.add(DescentTest.dipRoute());
        for (var r = 0; r < rs.size(); r++) { DescentTest.drawsEverywhere(rs[r], 15, 18); }
        return true;
    }

    // Whether (x, y) is within radius r of the screen's centre.
    function within(x as Float, y as Float, r as Float) as Boolean {
        var dx = x - 0.5, dy = y - 0.5;
        return dx * dx + dy * dy <= r * r + 0.0001;
    }

    // Page 16: its size is 64 or 52 and stays one size through the climb; at 64 its rows keep 6 % of
    // the width clear of the edge, and at either they are on the screen, measured in the fonts drawn.
    (:test)
    function pageSixteenFitsAndHoldsItsSize(logger as Logger) as Boolean {
        var d = PagesTest.draw(), rs = routes();
        for (var r = 0; r < rs.size(); r++) {
            Climb.use(rs[r], :ferrata);
            var ps = places(), fs = Numbers.progressSize(d, at(0.0, 0.0));
            Test.assertMessage(fs == Numbers.F64 || fs == Numbers.F52, "route " + r + ": size " + fs);
            var font = d.semi(fs), widest = 0.0;
            for (var p = 0; p < ps.size(); p++) {
                var st = at(ps[p], 30.0);
                Test.assertEqualMessage(Numbers.progressSize(d, st), fs, "route " + r + " at " + ps[p] + ": the same size");
                for (var k = 0; k < 3; k++) {
                    var row = Numbers.row(st, k), wd = d.width(font, row[0]), wt = d.width(font, row[1]);
                    if (wd > widest) { widest = wd; }
                    if (wt > widest) { widest = wt; }
                }
            }
            var half = widest + 0.028846 + d.whole(fs * 0.87) / 2 + 0.009615 + d.width(d.semi(Numbers.F32), "m");
            var pitch = d.whole(fs * 1.4), top = 0.5 + Numbers.CAP * fs / 2 - pitch - Numbers.CAP * fs;
            var bottom = 0.5 + Numbers.CAP * fs / 2 + pitch;
            var edge = fs == Numbers.F64 ? Numbers.FIT_R + 2.0 / d.w : 0.5;
            logger.debug("route " + r + ": size " + fs + ", rows " + (2 * half) + " wide, from " + top + " to " + bottom);
            Test.assertMessage(within(0.5 - half, top, edge) && within(0.5 + half, top, edge)
                && within(0.5 - half, bottom, edge) && within(0.5 + half, bottom, edge), "route " + r + ": off the screen");
        }
        return true;
    }

    // Pages 17 to 19: the right edge never moves as the value done grows (only the symbol does), and the
    // group is on the screen, measured in the fonts drawn.
    (:test)
    function pagesSeventeenToNineteenStayPut(logger as Logger) as Boolean {
        var d = PagesTest.draw(), rs = routes(), f1 = d.semi(Numbers.F104);
        for (var r = 0; r < rs.size(); r++) {
            Climb.use(rs[r], :ferrata);
            var ps = places();
            for (var k = 0; k < 3; k++) {
                var where = "route " + r + ", page " + (17 + k) + ": ", first = Numbers.oneLayout(d, Numbers.row(at(0.0, 0.0), k));
                var symbols = [] as Array<Float>;
                for (var p = 0; p < ps.size(); p++) {
                    var row = Numbers.row(at(ps[p], ps[p] / 4), k), L = Numbers.oneLayout(d, row);
                    Test.assertEqualMessage(L[0], first[0], where + "the right edge at " + ps[p]);
                    Test.assertEqualMessage(L[2], first[2], where + "the first line at " + ps[p]);
                    Test.assertEqualMessage(L[3], first[3], where + "the second line at " + ps[p]);
                    if (symbols.indexOf(L[1]) < 0) { symbols.add(L[1]); }
                    // The group: from the symbol's left to the right edge, the digits' top to the baseline below.
                    var x0 = L[1] - L[4] / 2, x1 = L[0], y0 = L[2] - Numbers.CAP * Numbers.F104, y1 = L[3];
                    var lx = x1 - L[5] - d.width(d.semi(Numbers.F84), row[1]) - d.width(d.semi(Numbers.F40), "of ");
                    if (lx < x0) { x0 = lx; }
                    Test.assertMessage(within(x0, y0, 0.5) && within(x1, y0, 0.5) && within(x0, y1, 0.5) && within(x1, y1, 0.5),
                        where + "off the screen at " + ps[p] + ": " + x0 + " to " + x1 + ", " + y0 + " to " + y1);
                    Test.assertMessage(x1 - L[5] - d.width(f1, row[0]) >= L[1] + L[4] / 2, where + "the value over its symbol");
                }
                logger.debug(where + "the symbol at " + symbols.size() + " places");
            }
        }
        return true;
    }
}
