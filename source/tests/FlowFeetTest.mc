using Toybox.Math;

import Toybox.Lang;
import Toybox.Test;

// The flow on a watch set to feet or to metres: the setting the system's (FlowMenus.feet), forced
// here, so the tests do not hang on the simulator's.
class UnitsFlow extends FlowMenus {

    var ft as Boolean;

    function initialize(f as Feed, inFeet as Boolean) {
        ft = inFeet;
        FlowMenus.initialize(f);
    }

    function feet() as Boolean { return ft; }
}

// The climb flow follows the watch's units (#144): in feet every value it shows is converted, never
// relabelled (100 m shows as 328 ft, at the pages' 3.28084), the route and the tracker staying in
// metres; an altitude entered in feet goes back to metres, and the entry steps 50 ft (owner,
// 2026-11-27). The rows and the large altitude are laid out from their widest in either unit; the
// summary's line in the unit shown, so the metric one keeps the mock's size (FlowDraw.summaryLine). On the demo route, as
// FlowTest: the head at 1290 m, the Bench at 390 m and 1310 m, the top at 640 m and 1580 m, the
// route's altitudes 1270 to 1580 m (4167 to 5184 ft), its ascent 400 m.
module FlowFeetTest {

    function flow() as FlowMenus {
        return new UnitsFlow(new FlowFeed(RouteTest.demo()), true);
    }

    function ascentAt(d as Float) as FlowMenus {
        var f = flow();
        f.feed.start(:head);
        f.feed.tracker.d = d;
        return f;
    }

    function row(r as SymRow, value as String, unit as String, what as String) as Void {
        Test.assertMessage(value.equals(r.value) && unit.equals(r.unit), what + ": " + r.value + " " + r.unit);
    }

    function near(a as Float, b as Float, e as Float) as Boolean { return FlowTest.near(a, b, e); }

    // F1: the path and the ascent in feet, the guidebook time as it is.
    (:test)
    function readyInFeet(logger as Logger) as Boolean {
        var f = flow();
        Test.assertMessage(f.feet(), "the watch in feet");
        var ft = FlowDraw.readyRows(f, true), m = FlowDraw.readyRows(f, false);
        row(ft[0], Math.round(f.path * 3.28084).toNumber().format("%d"), "ft", "the path");
        row(ft[1], "1312", "ft", "400 m of ascent");
        row(ft[2], m[2].value, "", "the guidebook time");
        row(m[1], "400", "m", "in metres");
        // Laid out from the wider unit: the same room in both.
        var d = PagesTest.draw();
        var wf = FlowDraw.rowsWidth(d, ft), wm = FlowDraw.rowsWidth(d, m);
        Test.assertMessage(near(wf, wm, 0.0001), "the same room: " + wf + ", " + wm);
        Test.assertMessage(wf <= FlowDraw.chord(0.6), "within the screen: " + wf);
        return true;
    }

    // A point's details: its altitude in feet, how far it is in feet; HERE how far along in feet.
    (:test)
    function detailInFeet(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        FlowTest.choose(f, :calibrate);
        FlowTest.choose(f, :calAt);
        var dt = f.detail as FlowDetail;
        Test.assertEqualMessage(dt.point, FlowTest.BENCH, "the Bench's details");
        var ft = FlowDraw.detailRows(f, dt, true), m = FlowDraw.detailRows(f, dt, false);
        row(ft[0], "4298", "ft", "1310 m");
        row(ft[1], "33", "ft ahead", "10 m ahead");
        row(m[0], "1310", "m", "in metres");
        var d = PagesTest.draw();
        Test.assertMessage(near(FlowDraw.rowsWidth(d, ft), FlowDraw.rowsWidth(d, m), 0.0001), "the same room");
        f.openDetail(-1, true);
        var here = f.detail as FlowDetail;
        ft = FlowDraw.detailRows(f, here, true);
        row(ft[0], Flow.inUnit(here.alt.toFloat(), true).format("%d"), "ft", "here's altitude");
        row(ft[1], "1247", "ft along", "380 m along");
        return true;
    }

    // How far a point is, as the details show it: feet under 1000 ft, else miles to one place.
    (:test)
    function aheadInFeet(logger as Logger) as Boolean {
        var a = Flow.ahead(420.0, 400.0, true);
        Test.assertMessage("66".equals(a[0]) && "ft ahead".equals(a[1]), "20 m ahead: " + a);
        a = Flow.ahead(100.0, 400.0, true);
        Test.assertMessage("984".equals(a[0]) && "ft back".equals(a[1]), "300 m back: " + a);
        a = Flow.ahead(402.0, 400.0, true);
        Test.assertMessage("here".equals(a[0]) && "".equals(a[1]), "here: " + a);
        a = Flow.ahead(705.0, 400.0, true);
        Test.assertMessage("0.2".equals(a[0]) && "mi ahead".equals(a[1]), "305 m, 1001 ft: " + a);
        a = Flow.ahead(1660.0, 400.0, true);
        Test.assertMessage("0.8".equals(a[0]) && "mi ahead".equals(a[1]), "1260 m ahead: " + a);
        // The approach's distance to the head.
        a = Flow.far(1500.0, true);
        Test.assertMessage("0.9".equals(a[0]) && "mi".equals(a[1]), "1.5 km: " + a);
        a = Flow.far(1500.0, false);
        Test.assertMessage("1.5".equals(a[0]) && "km".equals(a[1]), "in kilometres: " + a);
        return true;
    }

    // The summary: the height climbed and the drift in feet, signed; the line fits in feet too.
    (:test)
    function summaryInFeet(logger as Logger) as Boolean {
        var s = Flow.summary(374, 360, 19.4, true);
        Test.assertEqualMessage(s[0].toString(), ["1227", "0:06", "+64"].toString(), "the figures");
        Test.assertEqualMessage(s[1].toString(), ["ft", "", "ft"].toString(), "the units");
        s = Flow.summary(374, 360, -20.0, true);
        Test.assertEqualMessage(s[0][2], "-66", "a drift down");
        var m = Flow.summary(374, 360, 19.4, false);
        Test.assertEqualMessage(m[0].toString(), ["374", "0:06", "+19"].toString(), "in metres");
        var d = PagesTest.draw();
        var cases = [[841, 19020, 19.0], [1500, 36000, 100.0], [12345, 360000, -1234.0]] as Array<Array>;
        for (var i = 0; i < cases.size(); i++) {
            var c = cases[i];
            var lf = FlowDraw.summaryLine(d, Flow.summary(c[0] as Number, c[1] as Number, c[2] as Float, true));
            Test.assertMessage(lf.total <= FlowDraw.lineRoom(d, lf), lf.values + " within the screen");
            Test.assertEqualMessage(lf.units[0], "ft", "in feet");
        }
        return true;
    }

    // The altitude entry in feet: from the barometer converted, the route's range in feet, the first
    // press to the next 50 ft mark, then 50 ft; Start sets the altitude in metres.
    (:test)
    function entryInFeet(logger as Logger) as Boolean {
        var f = flow();
        FlowTest.watchReads(f, 1283.4);
        f.press(:start);
        FlowTest.choose(f, :atAltitude);
        var e = f.entry as FlowEntry;
        Test.assertMessage(e.ft && e.est == 4211 && e.value == 4211, "1283.4 m, " + e.value);
        Test.assertMessage(e.range[0] == 4167 && e.range[1] == 5184, "range " + e.range);
        var s = Flow.steps(e.value, e.range, true);
        Test.assertMessage("+39".equals(s[0]) && "–11".equals(s[1]), "to the marks: " + s);
        f.press(:up);
        Test.assertEqualMessage(e.value, 4250, "up to the mark");
        f.press(:up);
        Test.assertEqualMessage(e.value, 4300, "then 50 ft");
        f.press(:down);
        f.press(:down);
        Test.assertEqualMessage(e.value, 4200, "down 50 ft a press");
        Test.assertEqualMessage(Flow.altUp(5180, e.range, true), 5184, "not above the top");
        Test.assertEqualMessage(Flow.altDown(5184, e.range, true), 5150, "down to the mark");
        Test.assertEqualMessage(Flow.altDown(4180, e.range, true), 4167, "not below the Car park");
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.APPROACH, "on the approach");
        var want = 4200 / 3.28084 - 1283.4;
        Test.assertMessage(near(f.feed.tracker.offset as Float, want, 0.01), "offset " + f.feed.tracker.offset + ", " + want);
        return true;
    }

    // Calibrating to an altitude entered in feet: the tracker gets metres, CALIBRATED at shows the feet
    // entered.
    (:test)
    function calibrateInFeet(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        f.press(:start);
        FlowTest.choose(f, :calibrate);
        FlowTest.choose(f, :calAltitude);
        var e = f.entry as FlowEntry;
        Test.assertMessage(!e.start && e.est == 4580, "1396 m: " + e.est);
        f.press(:up);
        Test.assertEqualMessage(e.value, 4600, "to the mark");
        f.press(:start);
        var c = f.calibrated as Float;
        Test.assertMessage(near(c, 4600 / 3.28084, 0.01), "in metres: " + c);
        Test.assertEqualMessage(Flow.inUnit(c, true), 4600, "shown as entered");
        Test.assertMessage(near(f.feed.tracker.offset as Float, 4600 / 3.28084 - 1290, 0.01), "offset " + f.feed.tracker.offset);
        return true;
    }

    // The large altitude's size fits the route's widest altitude in either unit beside the steps, and
    // inside the screen: the demo's at the mock's size, a high route's 5-digit feet too.
    (:test)
    function bigAltitudeFits(logger as Logger) as Boolean {
        var d = PagesTest.draw();
        var ranges = [[1270, 1580], [2900, 3100], [4400, 4810]] as Array<[Number, Number]>;
        for (var i = 0; i < ranges.size(); i++) {
            var k = FlowDraw.bigSize(d, ranges[i]);
            Test.assertMessage(FlowDraw.bigFits(d, k, ranges[i]), ranges[i] + " at " + k);
        }
        Test.assertEqualMessage(FlowDraw.bigSize(d, ranges[0]), FlowDraw.size(true, 0.2), "the demo's at the mock's size");
        return true;
    }
}
