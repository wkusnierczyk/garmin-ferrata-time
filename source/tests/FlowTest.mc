import Toybox.Lang;
import Toybox.Test;

// An input whose readings the test sets: the watch's altitude and the time of day, in seconds.
class SetInput extends Input {

    var alt as Float? = 1290.0;
    var t as Number = 30000;

    function initialize() {
        Input.initialize();
    }

    function read(now as Number) as Reading {
        return new Reading(alt, null, null, t);
    }

    function peek() as Float? {
        return alt;
    }
}

// A feed on the sensors' path playing a recording: 1000 m, then 1100 m ten minutes later.
class ReplayFeed extends Feed {

    function initialize(r as Route) {
        Feed.initialize(r);
    }

    function wantsDemo() as Boolean { return false; }

    function newInput(isDemo as Boolean) as Input {
        return new ReplayInput([[30000, 1000, null, null], [30600, 1100, null, null]] as Array<Array>, ReplayInput.SPEED);
    }
}

// A feed on the sensors' path with the test's input.
class FlowFeed extends Feed {

    var set as SetInput;

    function initialize(r as Route) {
        set = new SetInput();
        Feed.initialize(r);
    }

    function wantsDemo() as Boolean { return false; }

    function newInput(isDemo as Boolean) as Input { return set; }
}

// The climb flow (#51): the menus each phase offers, what each row does to the climb, Back, the
// summary, and the triggers the GPS prompts (#52, #113) will call. On the demo route: the approach
// from the Car park (1270 m), the head at 1290 m, the Band exit at 210 m along and the Last exit at
// 475 m (neither with an altitude), the Bench landmark at 390 m and 1310 m, the top at 640 m and
// 1580 m. The watch reads 1290 m unless a test says otherwise, and shows metres whatever the
// simulator's setting (UnitsFlow; FlowFeetTest has feet).
module FlowTest {

    // Point indices in the demo route.
    const CAR_PARK = 0;
    const HEAD = 1;
    const BAND_EXIT = 3;
    const BENCH = 4;
    const LAST_EXIT = 5;
    const TOP = 7;

    function flow() as FlowMenus {
        return new UnitsFlow(new FlowFeed(RouteTest.demo()), false);
    }

    // On the ferrata from the head, the estimate put at d.
    function ascentAt(d as Float) as FlowMenus {
        var f = flow();
        f.feed.start(:head);
        f.feed.tracker.d = d;
        return f;
    }

    // Whether the menu's rows are these, in this order (a symbol prints as a number, so the rows are
    // compared, not printed).
    function rows(m as FlowMenu?, want as Array<Symbol>) as Boolean {
        if (m == null || m.items.size() != want.size()) { return false; }
        for (var i = 0; i < want.size(); i++) { if (m.items[i].id != want[i]) { return false; } }
        return true;
    }

    // The rows' labels, for the messages.
    function ids(m as FlowMenu?) as String {
        if (m == null) { return "none"; }
        var s = "";
        for (var i = 0; i < m.items.size(); i++) { s += (i > 0 ? ", " : "") + m.items[i].label; }
        return s;
    }

    function points(m as FlowMenu) as Array<Number> {
        var out = [] as Array<Number>;
        for (var i = 0; i < m.items.size(); i++) { out.add(m.items[i].point); }
        return out;
    }

    function same(a as Array<Number>, b as Array<Number>) as Boolean {
        if (a.size() != b.size()) { return false; }
        for (var i = 0; i < a.size(); i++) { if (a[i] != b[i]) { return false; } }
        return true;
    }

    // The watch's altitude from now on.
    function watchReads(f as FlowMenus, alt as Float) as Void {
        var input = (f.feed as FlowFeed).set;
        input.alt = alt;
    }

    // A text the flow shows, which may be null.
    function text(a as String?, want as String, what as String) as Void {
        Test.assertMessage(want.equals(a), what + ": " + a);
    }

    function near(a as Float, b as Float, e as Float) as Boolean {
        var x = a - b;
        return x <= e && x >= -e;
    }

    // Selects the open menu's row i.
    function pick(f as FlowMenus, i as Number) as Void {
        var m = f.menu as FlowMenu;
        m.sel = i;
    }

    // Opens the row with this id in the open menu.
    function choose(f as FlowMenus, id as Symbol) as Void {
        var m = f.menu as FlowMenu;
        m.sel = m.indexOf(id);
        Test.assertEqualMessage(m.items[m.sel].id, id, "a row " + id + " in " + ids(m));
        f.press(:start);
    }

    // ---------------------------------------------------------------- before the start

    (:test)
    function readyThenStartMenu(logger as Logger) as Boolean {
        var f = flow();
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "ready");
        Test.assertMessage(f.onScreen(), "the ready screen");
        Test.assertMessage(f.press(:up) && f.press(:down) && f.menu == null, "Up and Down do nothing yet");
        f.press(:start);
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.id, :start, "the Start menu");
        Test.assertMessage(rows(m, [:atHead, :atApproach, :atAltitude]), "head, the approach's start, at altitude: " + ids(m));
        // #121: HEAD (green), the approach's start by its type, ALTITUDE; one line each.
        Test.assertEqualMessage(m.items[0].label, "Head", "the head");
        Test.assertEqualMessage(m.items[0].colour, Widgets.GREEN, "the head's green");
        Test.assertEqualMessage(m.items[1].label, "Car park", "the approach's start by its type");
        Test.assertEqualMessage(m.items[2].label, "Altitude", "an altitude");
        return true;
    }

    (:test)
    function startMenuWithoutApproachPoint(logger as Logger) as Boolean {
        var f = new UnitsFlow(new FlowFeed(RouteTest.made([[100, 100]])), false);
        f.press(:start);
        Test.assertMessage(rows(f.menu, [:atHead, :atAltitude]), "no approach point: " + ids(f.menu));
        return true;
    }

    // Back on the ready screen closes the app at once, with nothing shown (owner, 2026-11-26, #121).
    (:test)
    function backBeforeStartClosesApp(logger as Logger) as Boolean {
        var f = flow();
        f.press(:start);
        Test.assertMessage(f.press(:back) && f.menu == null && !f.quit, "Back in the Start menu returns to the ready screen");
        Test.assertMessage(f.press(:back), "Back on the ready screen taken");
        Test.assertMessage(f.toast == null && f.quit, "the app closes at once, no toast");
        return true;
    }

    (:test)
    function startAtHeadStartsAscent(logger as Logger) as Boolean {
        var f = flow();
        f.press(:start);
        choose(f, :atHead);
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "on the ferrata");
        Test.assertMessage(f.menu == null && !f.onScreen(), "the pages have the screen");
        Test.assertMessage(Climb.FERRATA, "the ferrata in use");
        return true;
    }

    (:test)
    function startAtApproachPoint(logger as Logger) as Boolean {
        var f = flow();
        f.press(:start);
        choose(f, :atApproach);
        Test.assertEqualMessage(f.phase(), Tracker.APPROACH, "on the approach");
        Test.assertMessage(near(f.feed.tracker.offset as Float, -20.0, 0.01), "calibrated to 1270 m");
        return true;
    }

    // At altitude opens the entry at the barometer's reading; Start at once starts on the approach
    // with no change; Back returns to the Start menu.
    (:test)
    function startAtAltitudeUnchanged(logger as Logger) as Boolean {
        var f = flow();
        watchReads(f, 1283.4);
        f.press(:start);
        choose(f, :atAltitude);
        var e = f.entry as FlowEntry;
        Test.assertMessage(e.start && e.est == 1283 && e.value == 1283, "from the barometer, " + e.value);
        f.press(:back);
        Test.assertMessage(f.entry == null && (f.menu as FlowMenu).id == :start, "Back to the Start menu");
        choose(f, :atAltitude);
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.APPROACH, "on the approach");
        Test.assertMessage(f.entry == null && f.menu == null, "nothing open");
        Test.assertMessage(near(f.feed.tracker.offset as Float, -0.4, 0.01), "no change: " + f.feed.tracker.offset);
        return true;
    }

    // The first press goes to the next 10 m mark, later ones 10 m; within the route's range, the
    // approach included (1270 to 1580 m); a reading outside it comes in at the first press.
    (:test)
    function altitudeEntrySteps(logger as Logger) as Boolean {
        var range = RouteTest.demo().altRange();
        Test.assertMessage(range[0] == 1270 && range[1] == 1580, "range " + range);
        Test.assertEqualMessage(Flow.altUp(1293, range, false), 1300, "up to the mark");
        Test.assertEqualMessage(Flow.altUp(1300, range, false), 1310, "then 10 m");
        Test.assertEqualMessage(Flow.altDown(1293, range, false), 1290, "down to the mark");
        Test.assertEqualMessage(Flow.altDown(1290, range, false), 1280, "then 10 m");
        Test.assertEqualMessage(Flow.altUp(1580, range, false), 1580, "not above the top");
        Test.assertEqualMessage(Flow.altDown(1270, range, false), 1270, "not below the Car park");
        Test.assertEqualMessage(Flow.altDown(1650, range, false), 1580, "a reading above comes in");
        Test.assertEqualMessage(Flow.altUp(1200, range, false), 1270, "a reading below comes in");
        var f = flow();
        watchReads(f, 1650.0);
        f.press(:start);
        choose(f, :atAltitude);
        Test.assertEqualMessage((f.entry as FlowEntry).value, 1650, "shown as it is");
        f.press(:up);
        Test.assertEqualMessage((f.entry as FlowEntry).value, 1580, "the first press brings it in");
        return true;
    }

    // On the approach its screen (F4) is the first page, the pages after it (owner, 2026-11-26): Up and
    // Down on it go on to the pages, and past either end of them back to it.
    (:test)
    function approachPages(logger as Logger) as Boolean {
        var f = flow();
        f.feed.start(:approachPoint);
        Test.assertMessage(f.onScreen() && f.approachShown, "the approach's screen first");
        Test.assertEqualMessage(f.press(:down), false, "Down on it is the pages'");
        Test.assertEqualMessage(f.stepPage(5, 1, 33), 0, "Down: the first page");
        Test.assertMessage(!f.onScreen(), "the pages have the screen");
        Test.assertEqualMessage(f.stepPage(0, 1, 33), 1, "the pages step on");
        Test.assertEqualMessage(f.stepPage(1, -1, 33), 0, "and back");
        Test.assertEqualMessage(f.stepPage(0, -1, 33), 0, "Up from the first page: the approach's screen");
        Test.assertMessage(f.onScreen() && f.approachShown, "the approach's screen again");
        Test.assertEqualMessage(f.stepPage(0, -1, 33), 32, "Up from it: the last page");
        Test.assertEqualMessage(f.stepPage(32, 1, 33), 32, "Down from the last: the approach's screen");
        Test.assertMessage(f.approachShown, "the approach's screen");
        // Paused on a page, the pause menu opens over it; closed, the page is back.
        f.stepPage(32, 1, 33);
        f.press(:start);
        Test.assertMessage(f.onScreen() && f.menu != null, "the pause menu over the page");
        f.press(:back);
        Test.assertMessage(!f.onScreen() && f.feed.paused(), "the page, paused");
        // On the ferrata the pages wrap, and a new climb starts on the approach's screen again.
        f.press(:start);
        choose(f, :startAscent);
        Test.assertEqualMessage(f.stepPage(32, 1, 33), 0, "the ferrata's pages wrap");
        var g = flow();
        g.feed.start(:approachPoint);
        Test.assertMessage(g.onScreen() && g.approachShown, "a new climb: the approach's screen");
        return true;
    }

    // ---------------------------------------------------------------- the pause menus

    (:test)
    function approachPauseMenu(logger as Logger) as Boolean {
        var f = flow();
        f.feed.start(:approachPoint);
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "Start pauses");
        var m = f.menu as FlowMenu;
        Test.assertMessage(rows(m, [:continue, :startAscent, :endHere]), "Continue approach, Start from head, End here: " + ids(m));
        Test.assertEqualMessage(m.items[0].label, "Continue approach", "Continue approach");
        Test.assertEqualMessage(m.items[1].label, "Start from head", "Start from head, green");
        Test.assertEqualMessage(m.items[1].colour, Widgets.GREEN, "green");
        Test.assertEqualMessage(m.items[2].colour, Widgets.RED, "End here red");
        choose(f, :startAscent);
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "on the ferrata");
        Test.assertMessage(Climb.FERRATA && f.menu == null, "the ferrata, nothing open");
        return true;
    }

    (:test)
    function ascentPauseMenu(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        f.press(:start);
        Test.assertMessage(rows(f.menu, [:continue, :calibrate, :end]), "Continue, Calibrate, End: " + ids(f.menu));
        return true;
    }

    // Back never leaves a climb: it pauses and opens the menu; Back there closes it, still paused, and
    // Start or Back opens it again; only Continue resumes.
    (:test)
    function backDuringClimbPauses(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        Test.assertMessage(!f.press(:up), "Up changes page during the climb");
        Test.assertMessage(f.press(:back), "Back taken");
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "paused");
        Test.assertEqualMessage((f.menu as FlowMenu).id, :paused, "the pause menu");
        f.press(:back);
        Test.assertMessage(f.menu == null && f.phase() == Tracker.PAUSED, "menu closed, still paused");
        Test.assertMessage(!f.onScreen(), "the pages, under the pause symbol");
        Test.assertMessage(FlowDraw.banded(f), "the pause symbol over them");
        f.press(:back);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :paused, "Back opens it again");
        f.press(:back);
        f.press(:start);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :paused, "so does Start");
        choose(f, :continue);
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "Continue resumes");
        return true;
    }

    // Review Focus 5: with no exit ahead or in the band, no End at exit row.
    (:test)
    function noExitInReachHidesEndAtExit(logger as Logger) as Boolean {
        // On the Bridge, past both exits: the Overhang behind is steep, so the band ends on it.
        var f = ascentAt(500.0);
        Test.assertEqualMessage(Flow.exitsInReach(f.feed.tracker).size(), 0, "no exit in reach");
        f.press(:start);
        choose(f, :end);
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.id, :end, "the End menu");
        Test.assertMessage(same(points(m), [TOP, -1]), "TOP, HERE: " + points(m));
        return true;
    }

    (:test)
    function endHereAlwaysOffered(logger as Logger) as Boolean {
        var f = ascentAt(0.0);
        f.press(:start);
        choose(f, :end);
        var m = f.menu as FlowMenu;
        Test.assertMessage(same(points(m), [TOP, BAND_EXIT, LAST_EXIT, -1]), "top, both exits, here: " + points(m));
        // #121: the places alone, TOP red, EXIT green, HERE white.
        Test.assertEqualMessage(m.items[0].label, "Top", "the top");
        Test.assertEqualMessage(m.items[0].colour, Widgets.RED, "red");
        Test.assertEqualMessage(m.items[1].label, "Exit", "an exit's row");
        Test.assertEqualMessage(m.items[1].colour, Widgets.GREEN, "green");
        Test.assertEqualMessage(m.items[3].label, "Here", "Here last");
        Test.assertEqualMessage(m.items[3].colour, Flow.WHITE, "white");
        return true;
    }

    // An estimate that ran a little past an exit still lists it: the Band exit is at the Dihedral's
    // foot, 10 m back, within the band.
    (:test)
    function exitJustBehindWithinBandListed(logger as Logger) as Boolean {
        var f = ascentAt(220.0);
        Test.assertMessage(same(Flow.exitsInReach(f.feed.tracker), [BAND_EXIT, LAST_EXIT]), "the Band exit listed");
        return true;
    }

    (:test)
    function exitFarBehindNotListed(logger as Logger) as Boolean {
        // 25 m past the Last exit, up the Overhang: 85 m higher, well out of the band.
        var f = ascentAt(500.0);
        Test.assertEqualMessage(Flow.exitsInReach(f.feed.tracker).indexOf(LAST_EXIT), -1, "the Last exit behind");
        return true;
    }

    // On a flat route the band is all of it: an exit behind and one ahead, the nearer first.
    (:test)
    function exitsNearestFirst(logger as Logger) as Boolean {
        var r = RouteTest.made([[100, 0], [200, 0], [100, 0]]);
        r.points.add({"kind" => "exit", "at" => 100, "name" => "Early"});
        r.points.add({"kind" => "exit", "at" => 300, "name" => "Late"});
        var f = new UnitsFlow(new FlowFeed(r), false);
        f.feed.start(:head);
        f.feed.tracker.d = 260.0;
        Test.assertMessage(same(Flow.exitsInReach(f.feed.tracker), [3, 2]), "Late, then Early: " + Flow.exitsInReach(f.feed.tracker));
        return true;
    }

    // ---------------------------------------------------------------- Calibrate

    // Review Focus 5: no landmark in the band or prompted by the GPS, no suggestion.
    (:test)
    function noLandmarkHidesSuggestion(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        f.press(:start);
        choose(f, :calibrate);
        Test.assertMessage(rows(f.menu, [:landmarks, :calAltitude]), "LANDMARK, ALTITUDE: " + ids(f.menu));
        Test.assertEqualMessage((f.menu as FlowMenu).items[0].label, "Landmark", "LANDMARK");
        Test.assertEqualMessage((f.menu as FlowMenu).items[1].label, "Altitude", "ALTITUDE");
        return true;
    }

    (:test)
    function nearLandmarkSuggested(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        choose(f, :calibrate);
        var m = f.menu as FlowMenu;
        Test.assertMessage(rows(m, [:calAt, :landmarks, :calAltitude]), "the Bench first: " + ids(m));
        Test.assertEqualMessage(m.items[0].point, BENCH, "the Bench");
        Test.assertEqualMessage(m.items[0].label, "Bench", "its name alone");
        Test.assertEqualMessage(m.items[0].colour, Widgets.REST, "outlined in a rest's blue");
        return true;
    }

    // At landmark lists the points with an altitude, nearest first, each however far: the head and the
    // top too; the exits without an altitude cannot calibrate.
    (:test)
    function landmarksNearestFirst(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :landmarks);
        var m = f.menu as FlowMenu;
        Test.assertMessage(same(points(m), [BENCH, TOP, HEAD]), "Bench, top, head: " + points(m));
        Test.assertEqualMessage(m.items[2].colour, Widgets.GREEN, "the head's green");
        Test.assertEqualMessage(m.items[1].colour, Widgets.RED, "the top's red");
        f.press(:back);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :calibrate, "Back to Calibrate");
        return true;
    }

    // Calibrating at the Bench: its details first; Start there moves the place to it, the climb goes
    // on, CALIBRATED shows until Start or Back; the Bench is not suggested again.
    (:test)
    function calibrateAtLandmark(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        watchReads(f, 1305.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAt);
        Test.assertMessage(f.detail != null && f.phase() == Tracker.PAUSED, "its details, still paused");
        f.press(:start);
        var t = f.feed.tracker;
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "the climb goes on");
        Test.assertMessage(near(t.d, 390.0, 0.01), "at the Bench, d " + t.d);
        Test.assertMessage(near(t.offset as Float, 5.0, 0.01), "offset " + t.offset);
        Test.assertMessage(near(f.calibrated as Float, 1310.0, 0.001), "CALIBRATED at the Bench's 1310 m");
        Test.assertEqualMessage(f.calibratedPoint, BENCH, "the Bench named");
        Test.assertMessage(f.detail == null && f.menu == null, "nothing open under it");
        Test.assertMessage(f.press(:up) && f.calibrated != null, "Up does nothing under it");
        f.press(:back);
        Test.assertMessage(f.calibrated == null && f.phase() == Tracker.ASCENT, "Back closes it, the climb running");
        f.press(:start);
        choose(f, :calibrate);
        Test.assertMessage(rows(f.menu, [:landmarks, :calAltitude]), "the Bench not suggested again: " + ids(f.menu));
        return true;
    }

    // At altitude starts at the estimate; the place moves to the point at that altitude nearest it,
    // and the offset changes without a drift.
    (:test)
    function calibrateAtAltitude(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAltitude);
        var e = f.entry as FlowEntry;
        Test.assertMessage(!e.start && e.est == 1396, "from the estimate, 106 m up the traverse: " + e.est);
        f.press(:up);
        Test.assertEqualMessage(e.value, 1400, "to the mark");
        f.press(:start);
        var t = f.feed.tracker;
        Test.assertMessage(near(f.calibrated as Float, 1400.0, 0.001), "CALIBRATED at the altitude");
        Test.assertEqualMessage(f.calibratedPoint, -1, "no point named");
        // 110 m up is on the traverse at 45 + 20 / 30 x 140 m.
        Test.assertMessage(near(t.d, 138.33, 0.01), "the place moved, d " + t.d);
        Test.assertMessage(near(t.offset as Float, 110.0, 0.01), "offset " + t.offset);
        Test.assertEqualMessage(t.drifts.size(), 0, "no drift from a guess");
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "the climb goes on");
        return true;
    }

    // ---------------------------------------------------------------- the summary

    (:test)
    function endShowsSummaryResumeRestores(logger as Logger) as Boolean {
        // The watch reads the head's 1290 m as it pauses, so the place holds at 600 m; 1560 m at the end.
        var f = ascentAt(600.0);
        f.press(:start);
        watchReads(f, 1560.0);
        choose(f, :end);
        choose(f, :endAt);
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, "ended");
        var m = f.menu as FlowMenu;
        Test.assertMessage(rows(m, [:save, :resume, :discard]), "Save, Resume, Discard: " + ids(m));
        var t = f.feed.tracker;
        Test.assertMessage(near(t.d, 640.0, 0.01), "at the top");
        Test.assertMessage(near(t.drift(), 20.0, 0.01), "the top's check: " + t.drift());
        f.press(:back);
        Test.assertMessage(f.menu == m, "Back stays on the summary");
        choose(f, :resume);
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "paused again");
        Test.assertMessage(near(t.d, 600.0, 0.01) && t.drifts.size() == 0, "as before the end");
        Test.assertMessage(f.menu == null, "the pages, paused");
        return true;
    }

    (:test)
    function discardAsksFirst(logger as Logger) as Boolean {
        var f = ascentAt(100.0);
        f.press(:start);
        choose(f, :end);
        choose(f, :endAt);
        f.press(:start);
        choose(f, :discard);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :confirm, "asks");
        Test.assertMessage(rows(f.menu, [:no, :yes]), "NO, DISCARD: " + ids(f.menu));
        Test.assertMessage((f.menu as FlowMenu).items[1].fill && !(f.menu as FlowMenu).items[0].fill, "DISCARD's pill filled");
        choose(f, :no);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :summary, "No: back to the summary");
        choose(f, :discard);
        choose(f, :yes);
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "a new climb, ready");
        text(f.toast, "DISCARDED", "DISCARDED shows");
        f.tick(2999);
        Test.assertMessage(f.toast != null, "for 3 s");
        f.tick(1);
        Test.assertMessage(f.toast == null && !f.quit, "then the ready screen");
        return true;
    }

    (:test)
    function saveReturnsToReady(logger as Logger) as Boolean {
        var f = flow();
        f.feed.start(:approachPoint);
        f.press(:start);
        choose(f, :endHere);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, "an approach may end, at once");
        choose(f, :save);
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "ready");
        text(f.toast, "SAVED", "SAVED shows");
        f.tick(2000);
        f.press(:start);
        Test.assertMessage(f.toast != null && f.menu == null, "Start does nothing under it");
        f.press(:back);
        Test.assertMessage(f.toast == null && !f.quit, "Back closes it at once");
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "on the ready screen");
        return true;
    }

    // ---------------------------------------------------------------- a point's details (#121)

    // Picking a landmark, from the list or Calibrate's suggestion, opens its details: its altitude and
    // how far it is. Back returns to the list, Start calibrates there.
    (:test)
    function landmarkOpensDetails(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :landmarks);
        var list = f.menu as FlowMenu;
        list.sel = 2;
        f.press(:start);
        var dt = f.detail as FlowDetail;
        Test.assertMessage(dt.point == HEAD && !dt.end, "the head's details");
        Test.assertEqualMessage(dt.alt, 1290, "its altitude");
        Test.assertMessage(near(dt.at - dt.d, -380.0, 0.01), "380 m back");
        Test.assertMessage(f.onScreen() && f.isOpen(), "the flow has the screen");
        Test.assertMessage(f.press(:up) && f.press(:down) && f.detail == dt, "Up and Down do nothing");
        f.press(:back);
        Test.assertMessage(f.detail == null && f.menu == list && f.calibrated == null, "Back to the list, nothing calibrated");
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "still paused");
        f.press(:start);
        f.press(:start);
        Test.assertMessage(near(f.calibrated as Float, 1290.0, 0.001), "Start calibrates at the head");
        Test.assertMessage(near(f.feed.tracker.d, 0.0, 0.01), "the place at the head");
        return true;
    }

    // END at's TOP, EXIT and HERE each open their details; Back returns to END at, Start ends there.
    (:test)
    function endPlacesOpenDetails(logger as Logger) as Boolean {
        var f = ascentAt(220.0);
        f.press(:start);
        choose(f, :end);
        var end = f.menu as FlowMenu;
        var want = [TOP, BAND_EXIT, LAST_EXIT, -1] as Array<Number>;
        for (var i = 0; i < want.size(); i++) {
            end.sel = i;
            f.press(:start);
            var dt = f.detail as FlowDetail;
            Test.assertMessage(dt.point == want[i] && dt.end, "the details of " + want[i]);
            f.press(:back);
            Test.assertMessage(f.detail == null && f.menu == end, "Back to END at");
            Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "not ended");
        }
        end.sel = 0;
        f.press(:start);
        Test.assertEqualMessage((f.detail as FlowDetail).alt, 1580, "the top's altitude");
        var how = Flow.ahead((f.detail as FlowDetail).at, (f.detail as FlowDetail).d, false);
        Test.assertMessage("420".equals(how[0]) && "m ahead".equals(how[1]), "420 m ahead: " + how);
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, "Start ends there");
        Test.assertEqualMessage((f.menu as FlowMenu).id, :summary, "the summary");
        Test.assertMessage(near(f.feed.tracker.d, 640.0, 0.01), "at the top");
        return true;
    }

    // An exit without an altitude shows the route's there; here shows the estimate and the place.
    (:test)
    function endDetailsAltitudes(logger as Logger) as Boolean {
        var f = ascentAt(220.0);
        f.press(:start);
        choose(f, :end);
        pick(f, 1);
        f.press(:start);
        // The Band exit at 210 m: the head's 1290 m, 90 + 0 + 30 - 110 m on.
        Test.assertEqualMessage((f.detail as FlowDetail).alt, 1300, "the Band exit's, from the route");
        f.press(:back);
        pick(f, 3);
        f.press(:start);
        var dt = f.detail as FlowDetail;
        Test.assertEqualMessage(dt.alt, f.feed.tracker.state().altitude(), "here: the estimate");
        Test.assertMessage(near(dt.d, 220.0, 0.01), "220 m along");
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, "ended here");
        return true;
    }

    // A point's details are titled by what it is (#121): a landmark by its type, REST blue, BRIDGE and
    // SIGN grey; the head and exits green, the top red. CALIBRATED's name takes the same colour.
    (:test)
    function pointWordsAndColours(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        Test.assertEqualMessage(Flow.word(r.points[BENCH]), "REST", "the Bench is a rest");
        Test.assertEqualMessage(Flow.colour(r.points[BENCH]), Widgets.REST, "blue");
        var kinds = ["bridge", "sign"] as Array<String>;
        for (var i = 0; i < kinds.size(); i++) {
            var p = {"kind" => "landmark", "type" => kinds[i]} as Dictionary;
            Test.assertEqualMessage(Flow.word(p), kinds[i].toUpper(), "its type");
            Test.assertEqualMessage(Flow.colour(p), Flow.GREY, "grey");
        }
        Test.assertEqualMessage(Flow.word(r.points[HEAD]), "HEAD", "the head");
        Test.assertEqualMessage(Flow.colour(r.points[HEAD]), Widgets.GREEN, "green");
        Test.assertEqualMessage(Flow.word(r.points[BAND_EXIT]), "EXIT", "an exit");
        Test.assertEqualMessage(Flow.colour(r.points[BAND_EXIT]), Widgets.GREEN, "green");
        Test.assertEqualMessage(Flow.word(r.points[TOP]), "TOP", "the top");
        Test.assertEqualMessage(Flow.colour(r.points[TOP]), Widgets.RED, "red");
        return true;
    }

    // Each step beside Up and Down shows the change it makes, with its own sign: the demo's watch reads
    // 1258 m, under the route's 1270 m, so both bring it up by 12 m (the review of #124).
    (:test)
    function altitudeStepsSigned(logger as Logger) as Boolean {
        var range = RouteTest.demo().altRange();
        var cases = [[1258, "+12", "+12"], [1293, "+7", "–3"], [1300, "+10", "–10"], [1270, "+10", "–0"],
            [1580, "+0", "–10"], [1650, "–70", "–70"]] as Array<Array>;
        for (var i = 0; i < cases.size(); i++) {
            var v = cases[i][0] as Number, s = Flow.steps(v, range, false);
            Test.assertMessage((cases[i][1] as String).equals(s[0]) && (cases[i][2] as String).equals(s[1]),
                v + ": " + s);
        }
        return true;
    }

    // A new climb from the settings leaves no toast, and no quit (the review of #124).
    (:test)
    function resetClearsToasts(logger as Logger) as Boolean {
        var f = flow();
        f.showToast("SAVED", Flow.WHITE);
        f.reset();
        Test.assertMessage(f.toast == null && !f.quit, "nothing left");
        f.tick(5000);
        Test.assertMessage(!f.quit, "the app stays");
        f.quit = true;
        f.reset();
        Test.assertMessage(!f.quit, "nor a quit");
        return true;
    }

    // A narrowed two-part title keeps its grey "at" no larger than the bold part (the review of #124).
    (:test)
    function titleSemiNotAboveBold(logger as Logger) as Boolean {
        for (var b = 0; b < FontSizes.BOLD.size(); b++) {
            var s = FlowDraw.semiAtMost(FontSizes.BOLD[b]);
            Test.assertMessage(FontSizes.SEMI[s] <= FontSizes.BOLD[b] + 0.0001, "not above " + FontSizes.BOLD[b]);
            Test.assertMessage(s == FontSizes.SEMI.size() - 1 || FontSizes.SEMI[s + 1] > FontSizes.BOLD[b] + 0.0001,
                "the largest so: " + FontSizes.SEMI[s]);
        }
        return true;
    }

    // The summary's line of three figures fits the round screen whatever the climb (Codex on #124): a
    // typical climb's at the mock's size (owner), a long one's smaller, its symbols and gaps with it.
    // Cases: the height climbed, the active seconds, the drift, in metres (FlowFeetTest has feet).
    (:test)
    function summaryLineFits(logger as Logger) as Boolean {
        var d = PagesTest.draw();
        var cases = [[374, 360, 0.0], [1500, 36000, 100.0], [12345, 36000, 0.0],
            [12345, 360000, -1234.0], [841, 19020, 19.0]] as Array<Array>;
        var lines = [] as Array<SummaryLine>;
        for (var i = 0; i < cases.size(); i++) {
            var c = cases[i], h = c[0] as Number, s = c[1] as Number, dr = c[2] as Float;
            var line = FlowDraw.summaryLine(d, Flow.summary(h, s, dr, false));
            var room = FlowDraw.lineRoom(d, line);
            Test.assertMessage(line.total <= room, line.values + ": " + line.total + " in " + room);
            lines.add(line);
        }
        var mock = Fonts.nearest(0.085, FontSizes.SEMI);
        Test.assertEqualMessage(lines[0].vk, mock, "a short climb at the mock's size");
        Test.assertEqualMessage(lines[4].vk, mock, "the mock's own example too");
        Test.assertMessage(lines[1].vk < mock, "1500 m, 10:00, +100 m smaller");
        Test.assertMessage(lines[2].vk < mock, "12345 m smaller");
        return true;
    }

    (:test)
    function aheadOrBack(logger as Logger) as Boolean {
        var a = Flow.ahead(420.0, 400.0, false);
        Test.assertMessage("20".equals(a[0]) && "m ahead".equals(a[1]), "20 m ahead: " + a);
        a = Flow.ahead(100.0, 400.0, false);
        Test.assertMessage("300".equals(a[0]) && "m back".equals(a[1]), "300 m back: " + a);
        a = Flow.ahead(402.0, 400.0, false);
        Test.assertMessage("here".equals(a[0]) && "".equals(a[1]), "here: " + a);
        a = Flow.ahead(1660.0, 400.0, false);
        Test.assertMessage("1.3".equals(a[0]) && "km ahead".equals(a[1]), "1.3 km ahead: " + a);
        return true;
    }

    // ---------------------------------------------------------------- the triggers

    // The GPS near the head (#113): offered without pausing, once; Back closes the offer.
    (:test)
    function headOfferDoesNotPause(logger as Logger) as Boolean {
        var f = flow();
        Test.assertMessage(!f.offerHead(), "not before the start");
        f.feed.start(:approachPoint);
        Test.assertMessage(f.offerHead(), "offered");
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.id, :head, "the head's offer");
        Test.assertMessage(rows(m, [:continue, :startAscent]), "Continue approach, Start from head: " + ids(m));
        Test.assertEqualMessage(f.phase(), Tracker.APPROACH, "not paused");
        f.press(:back);
        Test.assertMessage(f.menu == null && f.phase() == Tracker.APPROACH, "closed, the approach going on");
        Test.assertMessage(!f.offerHead(), "once");
        return true;
    }

    (:test)
    function headOfferStartsFerrata(logger as Logger) as Boolean {
        var f = flow();
        f.feed.start(:approachPoint);
        f.offerHead();
        choose(f, :startAscent);
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "on the ferrata");
        Test.assertMessage(f.feed.tracker.calibratedAt.indexOf(HEAD) >= 0, "calibrated at the head");
        return true;
    }

    // On steep ground, 40 m below a landmark: out of the band, so offered only because the GPS
    // prompted it.
    function belowLedge() as FlowMenus {
        var r = RouteTest.made([[100, 100], [100, 100]]);
        r.points.add({"kind" => "landmark", "at" => 100, "alt" => 1100, "name" => "Ledge"});
        var f = new UnitsFlow(new FlowFeed(r), false);
        f.feed.start(:head);
        f.feed.tracker.d = 60.0;
        return f;
    }

    const LEDGE = 2;

    // The GPS near a landmark (#52): the climb pauses, the pause menu opens with Calibrate selected,
    // and Calibrate offers the landmark first; once.
    (:test)
    function landmarkPromptSelectsCalibrate(logger as Logger) as Boolean {
        var f = belowLedge();
        Test.assertEqualMessage(Flow.suggested(f.feed.tracker, [] as Array<Number>), -1, "not suggested unprompted");
        Test.assertMessage(f.nearLandmark(LEDGE), "prompted");
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "paused");
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.id, :paused, "the pause menu");
        Test.assertEqualMessage(m.items[m.sel].id, :calibrate, "Calibrate selected");
        f.press(:start);
        Test.assertEqualMessage((f.menu as FlowMenu).items[0].point, LEDGE, "the Ledge first");
        f.press(:back);
        choose(f, :continue);
        Test.assertMessage(!f.nearLandmark(LEDGE), "once");
        return true;
    }

    // Owner, #51: no landmark prompt within 50 m right after a calibration, at it or near it.
    (:test)
    function noPromptRightAfterCalibration(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAt);
        f.press(:start);
        f.press(:back);
        Test.assertMessage(!f.nearLandmark(BENCH), "not at the landmark calibrated at");
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "the climb goes on");
        f = belowLedge();
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAltitude);
        f.press(:up);
        f.press(:start);
        f.press(:back);
        Test.assertMessage(!f.nearLandmark(LEDGE), "not 30 m from an altitude calibration");
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "the climb goes on");
        return true;
    }

    // The review of #114: with no point to calibrate at (no altitudes), no At landmark row, and an empty
    // menu takes the buttons without failing.
    (:test)
    function noMarksNoLandmarkRow(logger as Logger) as Boolean {
        var r = Route.fromJson({"format" => 1, "id" => "t", "name" => "T", "short" => "T",
            "sections" => [{"len" => 100, "up" => 100, "grade" => 1, "min" => 10, "name" => "S", "side" => 0.0}],
            "points" => [{"kind" => "head", "at" => 0, "name" => "Head"},
                {"kind" => "landmark", "at" => 50, "type" => "rest", "name" => "Bench"},
                {"kind" => "top", "at" => 100, "name" => "Top"}]}) as Route;
        var f = new UnitsFlow(new FlowFeed(r), false);
        f.feed.start(:head);
        f.press(:start);
        choose(f, :calibrate);
        Test.assertMessage(rows(f.menu, [:calAltitude]), "At altitude only: " + ids(f.menu));
        var empty = new FlowMenu(:landmarks, [] as Array<FlowItem>);
        f.open(empty, null);
        f.press(:up);
        f.press(:down);
        f.press(:start);
        Test.assertMessage(f.menu == empty, "nothing chosen");
        return true;
    }

    // The review of #114: a landmark on the approach is not one the ferrata can calibrate at.
    (:test)
    function approachPointsNotMarks(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        r.points.add({"kind" => "landmark", "at" => -50, "alt" => 1280, "name" => "Spring"});
        var f = new UnitsFlow(new FlowFeed(r), false);
        f.feed.start(:head);
        Test.assertMessage(same(Flow.marks(f.feed.tracker), [HEAD, BENCH, TOP]), "the ferrata's: " + Flow.marks(f.feed.tracker));
        return true;
    }

    // The review of #114: the Start menu and the altitude entry read the barometer without starting
    // the replay's clock; the recording plays from its start when the climb starts.
    (:test)
    function startMenuLeavesReplayClock(logger as Logger) as Boolean {
        var f = new UnitsFlow(new ReplayFeed(RouteTest.demo()), false);
        var input = f.feed.input as ReplayInput;
        f.press(:start);
        choose(f, :atAltitude);
        Test.assertEqualMessage((f.entry as FlowEntry).est, 1000, "the entry from the recording's first altitude");
        Test.assertMessage(input.startMs == null, "the replay not started");
        f.press(:start);
        Test.assertMessage(input.startMs != null, "started with the climb");
        return true;
    }

    // Each climb plays a replay from its start: Save or Discard rewinds it, so the next climb does not
    // go on from where the last one ended (Codex on PR #114).
    (:test)
    function nextClimbRewindsReplay(logger as Logger) as Boolean {
        var feed = new ReplayFeed(RouteTest.demo());
        var input = feed.input as ReplayInput;
        for (var k = 0; k < 2; k++) {
            feed.start(:head);
            input.startMs = (input.startMs as Number) - 20000;
            feed.tick();
            Test.assertMessage(input.at == 1, "the recording played to its end");
            feed.pause();
            feed.end(-1);
            if (k == 0) { feed.save(); } else { feed.discard(); }
            Test.assertMessage(input.startMs == null && input.at == 0, "rewound for the next climb");
        }
        return true;
    }

    // A landmark the GPS prompted stays suggested within its reach, 50 m, though out of the band.
    (:test)
    function promptedLandmarkWithinGps(logger as Logger) as Boolean {
        var r = RouteTest.made([[100, 100], [100, 100]]);
        r.points.add({"kind" => "landmark", "at" => 100, "alt" => 1100, "name" => "Ledge"});
        var f = new UnitsFlow(new FlowFeed(r), false);
        f.feed.start(:head);
        var t = f.feed.tracker;
        t.d = 60.0;
        Test.assertEqualMessage(Flow.suggested(t, [] as Array<Number>), -1, "40 m below it, out of the band");
        Test.assertEqualMessage(Flow.suggested(t, [2]), 2, "prompted, within 50 m");
        t.d = 40.0;
        Test.assertEqualMessage(Flow.suggested(t, [2]), -1, "60 m away, out of reach");
        return true;
    }

    // ---------------------------------------------------------------- the screens

    // Every screen of the flow draws, F1 to F26, and the pages have the screen only on the ferrata with
    // nothing open (a crash check; the look is the owner's, on the watch).
    (:test)
    function everyScreenDraws(logger as Logger) as Boolean {
        var d = PagesTest.draw(), f = flow();
        Test.assertMessage(FlowDraw.draw(d, f), "F1, the ready screen");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F2, the Start menu");
        choose(f, :atAltitude);
        f.press(:down);
        Test.assertMessage(FlowDraw.draw(d, f), "F3, the entry before a start");
        f.press(:back);
        choose(f, :atApproach);
        Test.assertMessage(FlowDraw.draw(d, f) && f.onScreen(), "F4, the approach");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f) && !FlowDraw.banded(f), "F5, the approach paused, the symbol its title");
        f.press(:back);
        Test.assertMessage(FlowDraw.draw(d, f) && FlowDraw.banded(f), "F20, the approach under the pause symbol");
        f.press(:start);
        choose(f, :continue);
        f.offerHead();
        Test.assertMessage(FlowDraw.draw(d, f), "F6, the head's offer");
        choose(f, :startAscent);
        Test.assertMessage(!FlowDraw.draw(d, f) && !f.onScreen(), "the pages on the ferrata");
        f.feed.tracker.d = 380.0;
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F7, the pause menu");
        f.press(:back);
        Test.assertMessage(!FlowDraw.draw(d, f) && FlowDraw.banded(f), "F21, the pages under the pause symbol (View)");
        f.press(:start);
        choose(f, :calibrate);
        Test.assertMessage(FlowDraw.draw(d, f), "F8, Calibrate with the Bench near");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F18, the Bench's details");
        f.press(:back);
        choose(f, :landmarks);
        Test.assertMessage(FlowDraw.draw(d, f), "F9, the landmarks");
        f.press(:back);
        choose(f, :calAltitude);
        f.press(:up);
        Test.assertMessage(FlowDraw.draw(d, f), "F10, the entry");
        f.press(:back);
        choose(f, :calAt);
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F11, CALIBRATED at the Bench");
        f.press(:start);
        Test.assertMessage(f.nearLandmark(TOP), "a passing point prompts");
        Test.assertMessage(FlowDraw.draw(d, f), "F12, the pause menu from a passing landmark");
        f.press(:back);
        f.feed.tracker.d = 220.0;
        f.press(:start);
        choose(f, :end);
        Test.assertMessage(FlowDraw.draw(d, f), "F13, End with exits in reach");
        choose(f, :endAt);
        Test.assertMessage(FlowDraw.draw(d, f), "F24, the top's details");
        f.press(:back);
        pick(f, 1);
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F25, an exit's details");
        f.press(:back);
        pick(f, 3);
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F26, here's details");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "F14, the summary");
        choose(f, :discard);
        pick(f, 1);
        Test.assertMessage(FlowDraw.draw(d, f), "F15, Discard's question, DISCARD selected");
        choose(f, :yes);
        Test.assertMessage(FlowDraw.draw(d, f), "F17, DISCARDED over the ready screen");
        f.press(:back);
        f.feed.start(:head);
        f.feed.tracker.d = 600.0;
        f.press(:start);
        choose(f, :calibrate);
        Test.assertMessage(FlowDraw.draw(d, f), "F22, Calibrate with no landmark near");
        f.press(:back);
        choose(f, :end);
        Test.assertMessage(FlowDraw.draw(d, f), "F23, End with no exit in reach");
        choose(f, :endAt);
        f.press(:start);
        choose(f, :save);
        Test.assertMessage(FlowDraw.draw(d, f), "F16, SAVED");
        return true;
    }

    // A long name on a point's details is cut with an ellipsis to the round screen's width, once.
    (:test)
    function longNameCut(logger as Logger) as Boolean {
        var d = PagesTest.draw(), f = ascentAt(380.0);
        var name = "The very long name of a ledge with a bench and a view";
        var bench = f.feed.route.points[BENCH];
        bench["name"] = name;
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAt);
        FlowDraw.draw(d, f);
        var shown = (f.detail as FlowDetail).shown as String;
        Test.assertMessage(shown.length() < name.length() && shown.find("…") == shown.length() - 1, "cut: " + shown);
        Test.assertMessage(d.width(d.bold(0.0577), shown) <= FlowDraw.chord(0.28) * 0.8, "within the screen");
        var dt = f.detail as FlowDetail;
        dt.shown = "KEPT";
        FlowDraw.draw(d, f);
        text(dt.shown, "KEPT", "cut once, then reused");
        // The same name as a menu row: cut once per place it is drawn in, the pill and beside it.
        f.press(:back);
        var m = f.menu as FlowMenu;
        FlowDraw.draw(d, f);
        var cut = m.items[0].shown[2] as String;
        Test.assertMessage(cut.find("…") == cut.length() - 1, "the pill's label cut: " + cut);
        Test.assertMessage(d.width(FlowDraw.font(d, true, m.items[0].fonts[2]), cut) <= 0.72, "within the pill");
        var below = m.items[1].shown[3] as String;
        Test.assertMessage(d.width(FlowDraw.font(d, true, m.items[1].fonts[3]), below) <= FlowDraw.chord(0.73) * 0.8, "the row below within the screen");
        var pill = m.items[0].shown;
        pill[2] = "KEPT";
        FlowDraw.draw(d, f);
        text(m.items[0].shown[2], "KEPT", "the label cut once");
        // CALIBRATED's name too.
        f.press(:start);
        f.press(:start);
        FlowDraw.draw(d, f);
        var named = f.calibratedName as String;
        Test.assertMessage(named.find("…") == named.length() - 1, "CALIBRATED's name cut: " + named);
        return true;
    }

    // The menu's dots keep within 60 degrees of three o'clock however long the list, clear of the title
    // (the review of #114).
    (:test)
    function menuDotsKeepClearOfTitle(logger as Logger) as Boolean {
        Test.assertMessage(near(FlowDraw.dotStep(3), 6.0, 0.001), "6 degrees on a short list");
        var sizes = [21, 22, 40, 200] as Array<Number>;
        for (var i = 0; i < sizes.size(); i++) {
            var n = sizes[i];
            Test.assertMessage(FlowDraw.dotStep(n) * (n - 1) <= 120.001, n + " rows: " + FlowDraw.dotStep(n) * (n - 1));
        }
        return true;
    }

    // ---------------------------------------------------------------- the view

    // The review of #88: page 15's selected section follows the climber again when the part changes.
    (:test)
    function selectionResetsWithPart(logger as Logger) as Boolean {
        var r = RouteTest.demo();
        var v = new View(r);
        Climb.use(r, :ferrata);
        v.followPart();
        v.sel = 5;
        Climb.use(r, :approach);
        v.followPart();
        Test.assertEqualMessage(v.sel, -1, "reset on the approach");
        v.sel = 0;
        v.followPart();
        Test.assertEqualMessage(v.sel, 0, "kept within the part");
        Climb.use(r, :ferrata);
        v.followPart();
        Test.assertEqualMessage(v.sel, -1, "reset on the ferrata");
        // A new climb on the same part (the review of #114).
        v.sel = 3;
        (v.feed as Feed).save();
        Climb.use(r, :ferrata);
        v.followPart();
        Test.assertEqualMessage(v.sel, -1, "reset for a new climb");
        (v.feed as Feed).stop();
        return true;
    }

    // On the approach its own screen has the display: Up and Down leave the page as it was (the review
    // of #124).
    (:test)
    function approachKeepsPage(logger as Logger) as Boolean {
        var v = new View(RouteTest.demo()), del = new Delegate(v);
        var fl = v.flow as FlowMenus;
        fl.feed.start(:approachPoint);
        Test.assertMessage(v.flowOnScreen(), "the approach's screen");
        del.onNextPage();
        del.onPreviousPage();
        del.onNextPage();
        Test.assertEqualMessage(v.page, 0, "the page kept");
        (v.feed as Feed).stop();
        return true;
    }
}
