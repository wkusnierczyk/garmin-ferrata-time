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
// 1580 m. The watch reads 1290 m unless a test says otherwise.
module FlowTest {

    // Point indices in the demo route.
    const CAR_PARK = 0;
    const HEAD = 1;
    const BAND_EXIT = 3;
    const BENCH = 4;
    const LAST_EXIT = 5;
    const TOP = 7;

    function flow() as FlowMenus {
        return new FlowMenus(new FlowFeed(RouteTest.demo()));
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
        text(m.items[0].sub, "at 1290 m", "the head's altitude");
        Test.assertEqualMessage(m.items[1].label, "Car park", "the approach's start by name");
        text(m.items[2].sub, "barometer 1290 m", "the barometer's reading");
        return true;
    }

    (:test)
    function startMenuWithoutApproachPoint(logger as Logger) as Boolean {
        var f = new FlowMenus(new FlowFeed(RouteTest.made([[100, 100]])));
        f.press(:start);
        Test.assertMessage(rows(f.menu, [:atHead, :atAltitude]), "no approach point: " + ids(f.menu));
        return true;
    }

    (:test)
    function backBeforeStartLeaves(logger as Logger) as Boolean {
        var f = flow();
        Test.assertMessage(!f.press(:back), "Back on the ready screen leaves the app");
        f.press(:start);
        Test.assertMessage(f.press(:back) && f.menu == null, "Back in the Start menu returns to the ready screen");
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
        Test.assertMessage(e.start && e.known && e.est == 1283 && e.value == 1283, "from the barometer, " + e.value);
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
        Test.assertEqualMessage(Flow.altUp(1293, range), 1300, "up to the mark");
        Test.assertEqualMessage(Flow.altUp(1300, range), 1310, "then 10 m");
        Test.assertEqualMessage(Flow.altDown(1293, range), 1290, "down to the mark");
        Test.assertEqualMessage(Flow.altDown(1290, range), 1280, "then 10 m");
        Test.assertEqualMessage(Flow.altUp(1580, range), 1580, "not above the top");
        Test.assertEqualMessage(Flow.altDown(1270, range), 1270, "not below the Car park");
        Test.assertEqualMessage(Flow.altDown(1650, range), 1580, "a reading above comes in");
        Test.assertEqualMessage(Flow.altUp(1200, range), 1270, "a reading below comes in");
        var f = flow();
        watchReads(f, 1650.0);
        f.press(:start);
        choose(f, :atAltitude);
        Test.assertEqualMessage((f.entry as FlowEntry).value, 1650, "shown as it is");
        f.press(:up);
        Test.assertEqualMessage((f.entry as FlowEntry).value, 1580, "the first press brings it in");
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
        Test.assertMessage(rows(m, [:continue, :startAscent, :endAt]), "Continue approach, Start ferrata, End here: " + ids(m));
        Test.assertEqualMessage(m.items[0].label, "Continue approach", "Continue approach");
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
        Test.assertMessage(!f.onScreen(), "the pages, with PAUSED");
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
        text((f.menu as FlowMenu).items[2].sub, "Top or here", "End's line");
        choose(f, :end);
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.title, "END", "the End menu");
        Test.assertMessage(same(points(m), [TOP, -1]), "End at top, End here: " + points(m));
        return true;
    }

    (:test)
    function endHereAlwaysOffered(logger as Logger) as Boolean {
        var f = ascentAt(0.0);
        f.press(:start);
        choose(f, :end);
        var m = f.menu as FlowMenu;
        Test.assertMessage(same(points(m), [TOP, BAND_EXIT, LAST_EXIT, -1]), "top, both exits, here: " + points(m));
        Test.assertEqualMessage(m.items[3].label, "End here", "End here last");
        Test.assertEqualMessage(m.items[1].label, "End at exit", "an exit's row");
        text(m.items[1].sub, "Band exit", "its name; no altitude in the demo route");
        text(m.items[0].sub, "1580 m", "the top's altitude");
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
        var f = new FlowMenus(new FlowFeed(r));
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
        text((f.menu as FlowMenu).items[1].sub, "Landmark or altitude", "Calibrate's line");
        choose(f, :calibrate);
        Test.assertMessage(rows(f.menu, [:landmarks, :calAltitude]), "At landmark, At altitude: " + ids(f.menu));
        return true;
    }

    (:test)
    function nearLandmarkSuggested(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        f.press(:start);
        text((f.menu as FlowMenu).items[1].sub, "Near Bench", "Calibrate's line");
        choose(f, :calibrate);
        var m = f.menu as FlowMenu;
        Test.assertMessage(rows(m, [:calAt, :landmarks, :calAltitude]), "the Bench first: " + ids(m));
        Test.assertEqualMessage(m.items[0].point, BENCH, "the Bench");
        text(m.items[0].sub, "LANDMARK at 1310 m in 10 m", "its kind, altitude and distance");
        text(m.items[0].kind, "LANDMARK", "its kind's word in colour");
        text(m.items[1].sub, "3 on the route", "the head, the Bench and the top");
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
        text(m.items[2].sub, "HEAD at 1290 m 380 m back", "the head, behind");
        f.press(:back);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :calibrate, "Back to Calibrate");
        return true;
    }

    // Calibrating at the Bench: the place moves to it, the climb goes on, CALIBRATED shows until Start
    // or Back; the Bench is not suggested again.
    (:test)
    function calibrateAtLandmark(logger as Logger) as Boolean {
        var f = ascentAt(380.0);
        watchReads(f, 1305.0);
        f.press(:start);
        choose(f, :calibrate);
        choose(f, :calAt);
        var t = f.feed.tracker;
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "the climb goes on");
        Test.assertMessage(near(t.d, 390.0, 0.01), "at the Bench, d " + t.d);
        Test.assertMessage(near(t.offset as Float, 5.0, 0.01), "offset " + t.offset);
        text(f.calibrated, "at Bench 1310 m", "CALIBRATED at the Bench");
        Test.assertMessage(f.press(:up) && f.calibrated != null, "Up does nothing under it");
        f.press(:back);
        Test.assertMessage(f.calibrated == null && f.phase() == Tracker.ASCENT, "Back closes it, the climb running");
        f.press(:start);
        text((f.menu as FlowMenu).items[1].sub, "Landmark or altitude", "the Bench not suggested again");
        return true;
    }

    // At altitude starts at the estimate; the place moves to the point at that altitude nearest it,
    // and the offset changes without a drift.
    (:test)
    function calibrateAtAltitude(logger as Logger) as Boolean {
        var f = ascentAt(120.0);
        f.press(:start);
        choose(f, :calibrate);
        text((f.menu as FlowMenu).items[1].sub, "estimate 1396 m", "the estimate: 106 m up the traverse");
        choose(f, :calAltitude);
        var e = f.entry as FlowEntry;
        Test.assertMessage(!e.start && e.est == 1396, "from the estimate, " + e.est);
        f.press(:up);
        Test.assertEqualMessage(e.value, 1400, "to the mark");
        // 110 m up is on the traverse at 45 + 20 / 30 x 140 m.
        Test.assertMessage(near(e.at, 138.33, 0.01), "where 1400 m is: " + e.at);
        f.press(:start);
        var t = f.feed.tracker;
        text(f.calibrated, "at 1400 m", "CALIBRATED at the altitude");
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
        choose(f, :discard);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :confirm, "asks");
        choose(f, :no);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :summary, "No: back to the summary");
        choose(f, :discard);
        choose(f, :yes);
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "a new climb, ready");
        text(f.toast, "DISCARDED", "DISCARDED shows");
        f.tick(1000);
        Test.assertMessage(f.toast != null, "for a while");
        f.tick(1000);
        Test.assertMessage(f.toast == null, "then the ready screen");
        return true;
    }

    (:test)
    function saveReturnsToReady(logger as Logger) as Boolean {
        var f = flow();
        f.feed.start(:approachPoint);
        f.press(:start);
        choose(f, :endAt);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, "an approach may end");
        choose(f, :save);
        Test.assertEqualMessage(f.phase(), Tracker.IDLE, "ready");
        text(f.toast, "SAVED", "SAVED shows");
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
        Test.assertMessage(rows(m, [:continue, :startAscent]), "Continue approach, Start ferrata: " + ids(m));
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

    // The GPS near a landmark (#52): the climb pauses, the pause menu opens with Calibrate selected,
    // and Calibrate offers the landmark first; once.
    (:test)
    function landmarkPromptSelectsCalibrate(logger as Logger) as Boolean {
        var f = ascentAt(350.0);
        Test.assertMessage(f.nearLandmark(BENCH), "prompted");
        Test.assertEqualMessage(f.phase(), Tracker.PAUSED, "paused");
        var m = f.menu as FlowMenu;
        Test.assertEqualMessage(m.items[m.sel].id, :calibrate, "Calibrate selected");
        f.press(:start);
        Test.assertEqualMessage((f.menu as FlowMenu).items[0].point, BENCH, "the Bench first");
        f.press(:back);
        choose(f, :continue);
        Test.assertMessage(!f.nearLandmark(BENCH), "once");
        return true;
    }

    // A landmark the GPS prompted stays suggested within its reach, 50 m, though out of the band.
    (:test)
    function promptedLandmarkWithinGps(logger as Logger) as Boolean {
        var r = RouteTest.made([[100, 100], [100, 100]]);
        r.points.add({"kind" => "landmark", "at" => 100, "alt" => 1100, "name" => "Ledge"});
        var f = new FlowMenus(new FlowFeed(r));
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

    // Every screen of the flow draws, and the pages have the screen only during the climb with nothing
    // open (a crash check; the look is the owner's, on the watch).
    (:test)
    function everyScreenDraws(logger as Logger) as Boolean {
        var d = PagesTest.draw(), f = flow();
        Test.assertMessage(FlowDraw.draw(d, f), "the ready screen");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "the Start menu");
        choose(f, :atAltitude);
        Test.assertMessage(FlowDraw.draw(d, f), "the entry before a start");
        f.press(:back);
        choose(f, :atApproach);
        Test.assertMessage(!FlowDraw.draw(d, f), "the pages on the approach");
        f.offerHead();
        Test.assertMessage(FlowDraw.draw(d, f), "the head's offer");
        choose(f, :startAscent);
        f.feed.tracker.d = 380.0;
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "the pause menu");
        choose(f, :calibrate);
        Test.assertMessage(FlowDraw.draw(d, f), "Calibrate");
        choose(f, :landmarks);
        Test.assertMessage(FlowDraw.draw(d, f), "the landmarks");
        f.press(:back);
        choose(f, :calAltitude);
        Test.assertMessage(FlowDraw.draw(d, f), "the entry");
        f.press(:start);
        Test.assertMessage(FlowDraw.draw(d, f), "CALIBRATED");
        f.press(:start);
        Test.assertMessage(!FlowDraw.draw(d, f), "the pages");
        f.press(:start);
        choose(f, :end);
        Test.assertMessage(FlowDraw.draw(d, f), "End");
        choose(f, :endAt);
        Test.assertMessage(FlowDraw.draw(d, f), "the summary");
        choose(f, :discard);
        Test.assertMessage(FlowDraw.draw(d, f), "Discard's question");
        choose(f, :yes);
        Test.assertMessage(FlowDraw.draw(d, f), "DISCARDED over the ready screen");
        return true;
    }

    // ---------------------------------------------------------------- the view

    // The review of #88: page 9's selected section follows the climber again when the part changes.
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
        (v.feed as Feed).stop();
        return true;
    }
}
