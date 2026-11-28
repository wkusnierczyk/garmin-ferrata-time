using Toybox.WatchUi;

import Toybox.Lang;
import Toybox.Test;

// Page 20 (#68, design/page-20.md): the time spent in each grade, "{time} in {grade}", hardest first,
// from the tracker's state; laid out once per part from the widest values, so nothing moves, 6 % of
// the width clear of the edge at every size the app builds for; its menu shows or hides the grades
// still at 0:00.
module GradesTest {

    // A route of sections [grade, guidebook minutes], each 100 m long and 50 m up.
    function graded(steps as Array<Array<Number> >) as Route {
        var sections = [] as Array<Dictionary>, len = 0;
        for (var i = 0; i < steps.size(); i++) {
            sections.add({"len" => 100, "up" => 50, "grade" => steps[i][0], "min" => steps[i][1],
                "name" => "S" + i, "side" => 0.0});
            len += 100;
        }
        return Route.fromJson({"format" => 1, "id" => "g", "name" => "Graded", "short" => "Graded",
            "sections" => sections, "points" => [
                {"kind" => "head", "at" => 0, "alt" => 1000, "name" => "Head"},
                {"kind" => "top", "at" => len, "name" => "Top"}]}) as Route;
    }

    function daubenhorn() as Route {
        return Route.fromJson(WatchUi.loadResource(Rez.JsonData.daubenhorn) as Dictionary) as Route;
    }

    function sulzfluh() as Route {
        return Route.fromJson(WatchUi.loadResource(Rez.JsonData.sulzfluh) as Dictionary) as Route;
    }

    // The parts checked, [route, part]: the demo's ferrata and approach (a walk alone), and the
    // Daubenhorn's and the Sulzfluh's ferratas (seven and five grades) and approaches.
    function parts() as Array<Array> {
        return [[RouteTest.demo(), :ferrata], [RouteTest.demo(), :approach], [daubenhorn(), :ferrata],
            [daubenhorn(), :approach], [sulzfluh(), :ferrata], [sulzfluh(), :approach]] as Array<Array>;
    }

    function at(d as Float, pace as Float) as Climb.State {
        return Climb.State.placed(d, Climb.heightAtDistance(d), Climb.minuteAtDistance(d) * pace, pace, 480.0, 25);
    }

    // States along the part in use: every section's start, middle and end, at the guidebook's pace, and
    // the top once more at a pace that puts more than ten hours in one grade (h:mm a digit wider).
    function states() as Array<Climb.State> {
        var out = [] as Array<Climb.State>;
        for (var i = 0; i < Climb.count(); i++) {
            var b = Climb.dAt(i).toFloat(), e = Climb.dAt(i + 1).toFloat();
            out.add(at(b, 1.0));
            out.add(at((b + e) / 2, 1.0));
            out.add(at(e - 0.5, 1.0));
        }
        out.add(at(Climb.totalD().toFloat(), 1.0));
        out.add(at(Climb.totalD().toFloat(), 40.0));
        return out;
    }

    // The rows as text: "{time} in {grade}" each, top to bottom.
    function rows(st as Climb.State) as String {
        var shown = Numbers.shownGrades(st), t = Numbers.spent(st), s = "";
        for (var k = 0; k < shown.size(); k++) {
            s += (k > 0 ? ", " : "") + Numbers.hmm(t[shown[k]]) + " in " + Widgets.BOX_NAME[shown[k]];
        }
        return s;
    }

    // Page 20 follows page 19, the cycle's last.
    (:test)
    function timePageFollowsPageNineteen(logger as Logger) as Boolean {
        Test.assertEqualMessage(Pages.pageAt(Pages.GRADES_PAGE), 19, "page 20 at its place");
        Test.assertEqualMessage(Pages.pageAt(Pages.GRADES_PAGE - 1), 18, "page 19 before it");
        Test.assertEqualMessage(Pages.GRADES_PAGE, Pages.COUNT - 1, "page 20 last");
        return true;
    }

    // One row per grade the part has, hardest first; a walk is W, the last; a rest is no row (the
    // mock, owner 2026-11-22). The Daubenhorn has seven grades, its approach a walk alone.
    (:test)
    function oneRowPerGradeHardestFirst(logger as Logger) as Boolean {
        Numbers.showZero = true;
        Climb.use(graded([[3, 10], [-1, 5], [0, 4], [5, 20], [3, 10], [12, 6]] as Array<Array<Number> >), :ferrata);
        Test.assertEqualMessage(rows(at(0.0, 1.0)), "0:00 in F/G, 0:00 in C, 0:00 in B, 0:00 in W", "the grades, hardest first");
        Climb.use(daubenhorn(), :ferrata);
        Test.assertEqualMessage(Numbers.partGrades().toString(), [8, 7, 6, 5, 4, 3, 1].toString(), "the Daubenhorn's");
        Climb.use(daubenhorn(), :approach);
        Test.assertEqualMessage(rows(at(0.0, 1.0)), "0:00 in W", "its approach: a walk");
        return true;
    }

    // The time in a grade: the guidebook's minutes of its sections done and of the current one up to
    // the place, at the climber's pace; a rest counts in none. Halfway along the C section (20 minutes)
    // after B (10) and a rest (5): 10 in C and 10 in B at the guidebook's pace, 15 each at 1.5.
    (:test)
    function timeSpentPerGrade(logger as Logger) as Boolean {
        Numbers.showZero = true;
        Climb.use(graded([[3, 10], [-1, 5], [5, 20], [3, 10]] as Array<Array<Number> >), :ferrata);
        Test.assertEqualMessage(rows(at(250.0, 1.0)), "0:10 in C, 0:10 in B", "halfway along C");
        Test.assertEqualMessage(rows(at(250.0, 1.5)), "0:15 in C, 0:15 in B", "at 1.5 the guidebook's time");
        Test.assertEqualMessage(rows(at(400.0, 1.0)), "0:20 in C, 0:20 in B", "at the top");
        Test.assertEqualMessage(rows(at(400.0, 40.0)), "13:20 in C, 13:20 in B", "past ten hours");
        return true;
    }

    // With the menu's Hide, only the grades with time and the current one: the page grows as the climb
    // goes on, the rows centred again.
    (:test)
    function hideLeavesOutTheGradesAtZero(logger as Logger) as Boolean {
        Climb.use(graded([[3, 10], [-1, 5], [5, 20], [3, 10]] as Array<Array<Number> >), :ferrata);
        Numbers.showZero = false;
        Test.assertEqualMessage(rows(at(0.0, 1.0)), "0:00 in B", "at the head: the current grade alone");
        Test.assertEqualMessage(rows(at(150.0, 1.0)), "0:10 in B", "on the rest: none current");
        Test.assertEqualMessage(rows(at(250.0, 1.0)), "0:10 in C, 0:10 in B", "in C");
        Numbers.showZero = true;
        Test.assertEqualMessage(rows(at(0.0, 1.0)), "0:00 in C, 0:00 in B", "with Show, every grade");
        return true;
    }

    // Each row's box at layout L, top to bottom, for n rows: from the widest the time can get to the
    // widest grade name, from the digits' top to the baseline.
    function rowBoxes(d as Draw, L as Array<Float>, n as Number) as Array<Array<Float> > {
        var fs = L[0], cols = Numbers.gradeColumns(d, fs, L[1], L[3] > 0.5), inW = d.width(d.semi(Numbers.F32), "in");
        var pitch = d.whole(fs * Numbers.GRADES_PITCH), y0 = 0.5 - (n - 1) * pitch / 2 + Numbers.CAP * fs / 2, out = [] as Array<Array<Float> >;
        for (var k = 0; k < n; k++) {
            var y = y0 + k * pitch;
            out.add([L[2] - inW / 2 - Numbers.IN_GAP - cols[0], y - Numbers.CAP * fs, L[2] + inW / 2 + Numbers.IN_GAP + cols[1], y] as Array<Float>);
        }
        return out;
    }

    // At every place of every part, the layout chosen afresh is the one chosen at the start (size, the
    // grades' size and the "in" column), but for more than ten hours in a grade, and every row, all of
    // them shown, keeps 6 % of the width clear of the edge. Logged: the size per part.
    (:test)
    function pageTwentyFitsAndHoldsStill(logger as Logger) as Boolean {
        var d = PagesTest.draw(), ps = parts();
        for (var p = 0; p < ps.size(); p++) {
            Climb.use(ps[p][0] as Route, ps[p][1] as Symbol);
            var sts = states(), where = "part " + p + ": ", n = Numbers.partGrades().size();
            Numbers.forget();
            var first = Numbers.gradesLayout(d, sts[0]);
            for (var s = 0; s < sts.size(); s++) {
                Numbers.forget();
                var L = Numbers.gradesLayout(d, sts[s]);
                if (L[3] < 0.5) {
                    for (var i = 0; i < 3; i++) { Test.assertEqualMessage(L[i], first[i], where + "layout " + i + " at state " + s); }
                }
                var boxes = rowBoxes(d, L, n);
                for (var k = 0; k < n; k++) {
                    Test.assertMessage(NumbersTest.boxClear(d, boxes[k], Numbers.FIT_R), where + "row " + k + " at state " + s + ": " + boxes[k]);
                }
            }
            logger.debug(where + n + " rows at " + first[0] + ", grades at " + first[1] + ", \"in\" at " + first[2]);
        }
        return true;
    }

    // Page 20 draws at every place, every row shown and the zeros hidden, on every part checked and the
    // route that dips below its head (a throw fails the test).
    (:test, :noreplay)
    function pageTwentyDrawsEverywhere(logger as Logger) as Boolean {
        var d = PagesTest.draw(), ps = parts();
        for (var z = 0; z < 2; z++) {
            Numbers.showZero = z == 0;
            DescentTest.drawsEverywhere(DescentTest.dipRoute(), 19, 19);
            for (var p = 0; p < ps.size(); p++) {
                Climb.use(ps[p][0] as Route, ps[p][1] as Symbol);
                var sts = states();
                for (var s = 0; s < sts.size(); s++) { Pages.drawPage(19, d, sts[s]); }
            }
        }
        Numbers.showZero = true;
        return true;
    }

    // The page's menu (hold Up on page 20): ROWS at 0:00, Show or Hide, on the one in use; Start on the
    // other changes it and closes the menu, Back closes it as it was. Not on another page, nor while the
    // flow has the screen.
    (:test)
    function pageMenuShowsOrHidesTheZeros(logger as Logger) as Boolean {
        Numbers.showZero = true;
        var f = FlowTest.flow();
        Test.assertMessage(!f.openPageMenu(Pages.GRADES_PAGE), "not before the start: the flow has the screen");
        f.feed.start(:head);
        Test.assertMessage(!f.openPageMenu(Pages.GRADES_PAGE - 1), "not on page 19");
        Test.assertMessage(f.openPageMenu(Pages.GRADES_PAGE), "on page 20");
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.id, :zeroRows, "the page's menu");
        Test.assertMessage(FlowTest.rows(m, [:showZero, :hideZero] as Array<Symbol>), "Show, Hide");
        Test.assertEqualMessage(m.sel, 0, "on Show, in use");
        Test.assertMessage(!f.feed.paused(), "the climb goes on");
        f.press(:down);
        f.press(:start);
        Test.assertMessage(!Numbers.showZero, "Hide");
        Test.assertMessage(f.menu == null, "closed");
        Test.assertMessage(f.openPageMenu(Pages.GRADES_PAGE), "again");
        Test.assertEqualMessage((f.menu as FlowMenu).sel, 1, "on Hide, in use");
        f.press(:up);
        f.press(:back);
        Test.assertMessage(!Numbers.showZero && f.menu == null, "Back changes nothing");
        f.openPageMenu(Pages.GRADES_PAGE);
        f.press(:up);
        f.press(:start);
        Test.assertMessage(Numbers.showZero, "Show again");
        return true;
    }
}
