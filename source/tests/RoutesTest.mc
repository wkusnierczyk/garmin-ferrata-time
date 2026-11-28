using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;
import Toybox.Test;

// A flow with the route list (#141) whose last route used the test keeps, not the app's storage.
class PickerFlow extends UnitsFlow {

    var remembered as String? = null;

    function initialize(f as Feed) {
        UnitsFlow.initialize(f, false);
    }

    function remember(id as String) as Void { remembered = id; }
}

// The route list (#141, variant A of the flow mock): with more than one route the app opens on F0,
// ROUTES, a row per route with its name, the last route used selected; Start opens F1 for the selected
// route, Back on F1 returns to F0, Back on F0 closes the app. With one route F0 is skipped. The last
// route used is remembered across launches. Then the real routes the app bundles, the Daubenhorn and
// the Sulzfluh, through the tracker, the flow and the pages: the approach, the head, the exits and the
// top (most other tests climb the demo route).
module RoutesTest {

    // The Daubenhorn and the Sulzfluh, in F0's order: as the list has them, and read.
    function entries() as Array<RouteEntry> {
        return Routes.entriesOf([Rez.JsonData.daubenhorn, Rez.JsonData.sulzfluh] as Array<ResourceId>);
    }

    function real() as Array<Route> {
        var list = entries();
        return [Routes.open(list[0]) as Route, Routes.open(list[1]) as Route] as Array<Route>;
    }

    // The app as it opens with these routes, the last used at last, read.
    function opened(list as Array<RouteEntry>, last as Number) as PickerFlow {
        var f = new PickerFlow(new FlowFeed(Routes.open(list[last]) as Route));
        f.offer(list, last);
        return f;
    }

    function labels(m as FlowMenu?) as String { return FlowTest.ids(m); }

    // ---------------------------------------------------------------- the list

    // Ferrata bundles the real routes, the Daubenhorn first (#55), each by its resource: the entries
    // keep its id and name, and open the route itself.
    (:test, :nodemo)
    function ferrataBundlesTheRealRoutes(logger as Logger) as Boolean {
        var list = Routes.load();
        Test.assertEqualMessage(list.size(), 2, "two routes");
        Test.assertMessage(list[0].id.equals("daubenhorn") && list[0].name.equals("Daubenhorn"), "the Daubenhorn first");
        Test.assertMessage(list[1].id.equals("sulzfluh") && list[1].name.equals("Sulzfluh"), "the Sulzfluh second");
        for (var i = 0; i < 2; i++) {
            var r = Routes.open(list[i]);
            Test.assertMessage(r != null && (r as Route).id.equals(list[i].id), list[i].name + " opens");
        }
        return true;
    }

    // Ferrata Demo plays its made-up climb on the demo route alone, so it opens on F1.
    (:test, :demo)
    function demoBundlesTheDemoRoute(logger as Logger) as Boolean {
        var list = Routes.load();
        Test.assertEqualMessage(list.size(), 1, "one route");
        Test.assertEqualMessage(list[0].id, "demo", "the demo route");
        return true;
    }

    // A route the app cannot read is left off the list; one given read has nothing to open.
    (:test)
    function unreadableRouteLeftOut(logger as Logger) as Boolean {
        Test.assertEqualMessage(Routes.entriesOf([] as Array<ResourceId>).size(), 0, "none");
        Test.assertMessage(Routes.open(Routes.entry(real()[0])) == null, "an entry without a resource opens nothing");
        return true;
    }

    // F0: ROUTES, the routes' names alone, in their order, the last route used selected; the feed on
    // the selected route, so F1 shows it.
    (:test)
    function opensOnTheListLastSelected(logger as Logger) as Boolean {
        var list = entries();
        for (var last = 0; last < 2; last++) {
            var f = opened(list, last);
            var m = f.menu;
            Test.assertMessage(m != null && (m as FlowMenu).id == :routes, "F0 first");
            Test.assertEqualMessage(labels(m), "Daubenhorn, Sulzfluh", "the names, in order");
            Test.assertEqualMessage((m as FlowMenu).sel, last, "the last route used selected");
            Test.assertMessage((m as FlowMenu).items[0].colour == Flow.WHITE && (m as FlowMenu).items[1].colour == Flow.WHITE, "white outlines");
            Test.assertMessage(f.onScreen() && f.phase() == Tracker.IDLE, "the flow has the screen, no climb");
            Test.assertMessage(FlowDraw.draw(PagesTest.draw(), f), "F0 draws");
            // Start at once: F1 for the route selected, the one already climbed, nothing read again.
            var feedRoute = f.feed.route;
            f.press(:start);
            Test.assertMessage(f.menu == null && f.feed.route == feedRoute, "F1 on the same route");
            Test.assertEqualMessage(f.feed.route.name, list[last].name, "the route of the row selected");
        }
        return true;
    }

    // One route on the watch: no list, the app opens on F1, and Back there closes it.
    (:test)
    function oneRouteSkipsTheList(logger as Logger) as Boolean {
        var one = [entries()[1]] as Array<RouteEntry>;
        var f = opened(one, 0);
        Test.assertMessage(f.menu == null, "no F0: " + labels(f.menu));
        Test.assertMessage(f.onScreen() && f.phase() == Tracker.IDLE, "F1");
        Test.assertMessage(f.press(:back) && f.quit, "Back on F1 closes the app");
        return true;
    }

    // Up and Down move in F0; Start opens F1 for the selected route, which is remembered, and its
    // figures are the ready screen's.
    (:test)
    function startOpensTheSelectedRoute(logger as Logger) as Boolean {
        var list = entries(), f = opened(list, 0);
        f.press(:down);
        Test.assertEqualMessage((f.menu as FlowMenu).sel, 1, "Down to the Sulzfluh");
        f.press(:start);
        Test.assertMessage(f.menu == null && f.phase() == Tracker.IDLE && f.onScreen(), "F1");
        Test.assertMessage(!f.quit, "the app stays");
        Test.assertMessage(f.feed.route.id.equals("sulzfluh") && f.feed.tracker.route == f.feed.route, "the feed on the Sulzfluh");
        Test.assertMessage("sulzfluh".equals(f.remembered), "the Sulzfluh remembered");
        // The mock's F1 for the Sulzfluh: 795 m, 451 m, 2:30.
        Test.assertEqualMessage(f.figures(false).toString(), ["795", "451", "2:30"].toString(), "the Sulzfluh's figures");
        Test.assertMessage(FlowDraw.draw(PagesTest.draw(), f), "F1 draws");
        // Back to F0 and down to the Daubenhorn: its figures, 1991 m, 841 m, 5:30.
        f.press(:back);
        f.press(:up);
        f.press(:start);
        Test.assertMessage(f.feed.route.id.equals("daubenhorn") && "daubenhorn".equals(f.remembered), "the Daubenhorn, remembered");
        Test.assertEqualMessage(f.figures(false).toString(), ["1991", "841", "5:30"].toString(), "the Daubenhorn's figures");
        Test.assertEqualMessage(f.range.toString(), f.feed.route.altRange().toString(), "its range of altitudes");
        return true;
    }

    // Back on F1 returns to F0, the route on F1 selected; Back on F0 closes the app. Back in the Start
    // menu returns to F1, not to F0.
    (:test)
    function backFromReadyToListToOut(logger as Logger) as Boolean {
        var list = entries(), f = opened(list, 1);
        f.press(:start);
        f.press(:start);
        Test.assertEqualMessage((f.menu as FlowMenu).id, :start, "the Start menu");
        f.press(:back);
        Test.assertMessage(f.menu == null && f.phase() == Tracker.IDLE && !f.quit, "Back in the Start menu: F1");
        Test.assertMessage(f.press(:back) && !f.quit, "Back on F1 taken, the app stays");
        var m = f.menu;
        Test.assertMessage(m != null && (m as FlowMenu).id == :routes, "Back on F1: F0");
        Test.assertEqualMessage((m as FlowMenu).sel, 1, "the route on F1 selected");
        Test.assertMessage(f.press(:back) && f.quit, "Back on F0 closes the app");
        return true;
    }

    // After a climb (SAVED or DISCARDED, then F1), Back returns to F0 too.
    (:test)
    function listAfterAClimb(logger as Logger) as Boolean {
        var list = entries(), f = opened(list, 0);
        f.press(:start);
        f.press(:start);
        FlowTest.choose(f, :atHead);
        f.press(:start);
        FlowTest.choose(f, :end);
        FlowTest.choose(f, :endAt);
        f.press(:start);
        FlowTest.choose(f, :save);
        f.press(:back);
        Test.assertMessage(f.toast == null && f.phase() == Tracker.IDLE && f.menu == null, "F1 after SAVED");
        f.press(:back);
        Test.assertMessage(f.menu != null && (f.menu as FlowMenu).id == :routes && !f.quit, "Back: F0");
        return true;
    }

    // A climb on the Daubenhorn, saved, then the Sulzfluh picked: nothing of the Daubenhorn's climb is
    // left (its tracker, its sections, its range of altitudes, the head offered, the landmark prompted,
    // the large altitude's size, the page), and the Sulzfluh's climb opens on the first page, its dots
    // showing. Through the view, as the buttons drive it.
    (:test)
    function nothingOfTheLastRouteLeft(logger as Logger) as Boolean {
        var list = entries(), a = Routes.open(list[0]) as Route;
        var v = new View(list, 0, a), fl = v.flow as FlowMenus;
        v.press(:start);
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:atApproach));
        v.press(:start);
        Test.assertEqualMessage(fl.phase(), Tracker.APPROACH, "the Daubenhorn's approach");
        Test.assertMessage(fl.offerHead(), "its head offered");
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:startAscent));
        v.press(:start);
        Test.assertMessage(fl.nearLandmark(a.point("landmark")), "its bench prompted");
        Test.assertMessage(fl.headOffered && fl.prompted.size() == 1, "offered and prompted");
        fl.bigK = 3;
        v.page = 6;
        v.dotsMs = 0;
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:end));
        v.press(:start);
        v.press(:start);
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:save));
        v.press(:start);
        v.press(:back);
        v.press(:back);
        Test.assertEqualMessage((fl.menu as FlowMenu).id, :routes, "F0 after SAVED");
        v.press(:down);
        v.press(:start);
        var f = v.feed as Feed, b = f.route;
        Test.assertEqualMessage(b.id, "sulzfluh", "the Sulzfluh picked");
        Test.assertMessage(f.tracker.route == b && f.tracker.phase == Tracker.IDLE, "a new climb on it");
        Test.assertEqualMessage(Climb.count(), 16, "its sections");
        Test.assertEqualMessage(Climb.START_ALT, 2366, "its head");
        Test.assertEqualMessage(fl.range.toString(), b.altRange().toString(), "its range");
        Test.assertMessage(!fl.headOffered && fl.prompted.size() == 0, "no offer, no prompt");
        Test.assertEqualMessage(fl.bigK, -1, "the large altitude sized again");
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:atHead));
        v.press(:start);
        Test.assertEqualMessage(fl.phase(), Tracker.ASCENT, "the Sulzfluh from its head");
        Test.assertEqualMessage(v.page, 0, "the first page");
        Test.assertEqualMessage(v.dotsMs, v.DOTS_MS, "its dots showing");
        f.stop();
        return true;
    }

    // Each new climb opens on the first page, its dots showing, wherever the last one ended; Resume
    // after an end is the same climb and keeps its page.
    (:test)
    function newClimbOnTheFirstPage(logger as Logger) as Boolean {
        var r = RouteTest.demo(), v = new View([Routes.entry(r)] as Array<RouteEntry>, 0, r), fl = v.flow as FlowMenus;
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:atHead));
        v.press(:start);
        v.page = 4;
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:end));
        v.press(:start);
        v.press(:start);
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:resume));
        v.press(:start);
        Test.assertEqualMessage(v.page, 4, "Resume keeps the page");
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:end));
        v.press(:start);
        v.press(:start);
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:discard));
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:yes));
        v.press(:start);
        v.press(:back);
        v.dotsMs = 0;
        v.press(:start);
        FlowTest.pick(fl, (fl.menu as FlowMenu).indexOf(:atApproach));
        v.press(:start);
        Test.assertEqualMessage(fl.phase(), Tracker.APPROACH, "the next climb, on the approach");
        Test.assertEqualMessage(v.page, 0, "the first page, under the approach's screen");
        Test.assertEqualMessage(v.dotsMs, v.DOTS_MS, "its dots showing");
        (v.feed as Feed).stop();
        return true;
    }

    // The last route used across launches: stored by its id, written only when it changed, and the
    // first route when none is stored or the one stored is no longer on the watch. The app's storage is
    // left as it was, whatever the test finds.
    (:test)
    function lastRouteRemembered(logger as Logger) as Boolean {
        var list = entries(), was = Application.Storage.getValue(Routes.LAST);
        try {
            Routes.remember("sulzfluh");
            Test.assertMessage("sulzfluh".equals(Application.Storage.getValue(Routes.LAST) as Object?), "stored by its id");
            Test.assertEqualMessage(Routes.last(list), 1, "the Sulzfluh");
            Routes.remember("daubenhorn");
            Test.assertEqualMessage(Routes.last(list), 0, "the Daubenhorn");
            Application.Storage.setValue(Routes.LAST, "furenwand");
            Test.assertEqualMessage(Routes.last(list), 0, "a route no longer on the watch: the first");
            Application.Storage.setValue(Routes.LAST, 3);
            Test.assertEqualMessage(Routes.last(list), 0, "not an id: the first");
            Application.Storage.deleteValue(Routes.LAST);
            Test.assertEqualMessage(Routes.last(list), 0, "none: the first");
        } finally {
            if (was != null) { Application.Storage.setValue(Routes.LAST, was); } else { Application.Storage.deleteValue(Routes.LAST); }
        }
        return true;
    }

    // The app opened as the watch opens it: the view on the last route used, F0 over it.
    (:test)
    function viewOpensOnTheList(logger as Logger) as Boolean {
        var list = entries(), v = new View(list, 1, Routes.open(list[1]));
        var fl = v.flow as FlowMenus;
        Test.assertMessage(fl.menu != null && (fl.menu as FlowMenu).id == :routes, "F0");
        Test.assertEqualMessage((fl.menu as FlowMenu).sel, 1, "the Sulzfluh selected");
        Test.assertEqualMessage((v.feed as Feed).route.id, "sulzfluh", "on the Sulzfluh");
        (v.feed as Feed).stop();
        var one = new View([list[0]] as Array<RouteEntry>, 0, Routes.open(list[0]));
        Test.assertMessage((one.flow as FlowMenus).menu == null, "one route: F1");
        (one.feed as Feed).stop();
        var none = new View([] as Array<RouteEntry>, 0, null);
        Test.assertMessage(none.feed == null && none.flow == null, "no route: nothing to climb");
        return true;
    }

    // ---------------------------------------------------------------- the real routes

    // A picked route is the one the tracker climbs: the Sulzfluh from its head, at 2366 m, its 16
    // sections, the Car park its approach's start.
    (:test)
    function pickedRouteIsClimbed(logger as Logger) as Boolean {
        var list = entries(), f = opened(list, 0);
        f.press(:down);
        f.press(:start);
        f.press(:start);
        Test.assertEqualMessage(((f.menu as FlowMenu).items[1]).label, "Car park", "the Sulzfluh's approach start");
        FlowTest.choose(f, :atHead);
        Test.assertEqualMessage(f.phase(), Tracker.ASCENT, "on the ferrata");
        Test.assertEqualMessage(f.feed.tracker.route.id, "sulzfluh", "the tracker's route");
        Test.assertEqualMessage(Climb.START_ALT, 2366, "the Sulzfluh's head");
        Test.assertEqualMessage(Climb.count(), 16, "its sections");
        Test.assertEqualMessage(Climb.totalD(), 595, "its length");
        return true;
    }

    // A real route from its approach's start to its top through the flow, the watch reading the route's
    // altitudes: started at the approach's start, the place moves along the approach (the Daubenhorn's
    // goes down, the Sulzfluh's up) and the distance to the head falls; the head's offer onto the
    // ferrata; each landmark suggested where it is and calibrated at; End offers the exits in reach
    // (the Daubenhorn's Obere Freiheit; the Sulzfluh has none) and the top, where the climb ends with
    // the route's height gained. Every flow screen on the way draws.
    function climbs(r as Route, exits as Array<Number>) as Void {
        var d = PagesTest.draw(), f = new UnitsFlow(new FlowFeed(r), false), name = r.name + ": ";
        var start = r.points[r.point("approach")]["alt"] as Number, head = r.headAlt();
        var input = (f.feed as FlowFeed).set;
        input.alt = start.toFloat();
        f.press(:start);
        FlowTest.choose(f, :atApproach);
        Test.assertEqualMessage(f.phase(), Tracker.APPROACH, name + "on the approach");
        Test.assertEqualMessage(Climb.START_ALT, start, name + "the approach's start");
        Test.assertMessage(FlowDraw.draw(d, f), name + "F4");
        var left = f.feed.tracker.toHead()[0];
        Test.assertMessage(FlowTest.near(left, Route.lengthOf(r.approach).toFloat(), 0.5), name + "the whole approach to go: " + left);
        // Half the approach's guidebook time on, the watch half way to the head's altitude.
        var half = Climb.totalM() / 2;
        input.t += half * 60;
        input.alt = (start + head) / 2.0;
        f.feed.tick();
        var t = f.feed.tracker;
        Test.assertMessage(t.d > 0 && t.d < Climb.totalD(), name + "along the approach: " + t.d);
        Test.assertMessage(t.toHead()[0] < left, name + "nearer the head: " + t.toHead()[0]);
        Test.assertMessage(FlowDraw.draw(d, f), name + "F4 on the way");
        // At the head: its offer, onto the ferrata calibrated there.
        input.t += half * 60;
        input.alt = head.toFloat();
        f.feed.tick();
        Test.assertMessage(f.offerHead(), name + "the head offered");
        Test.assertMessage(FlowDraw.draw(d, f), name + "F6");
        FlowTest.choose(f, :startAscent);
        Test.assertMessage(f.phase() == Tracker.ASCENT && Climb.FERRATA, name + "on the ferrata");
        Test.assertEqualMessage(Climb.START_ALT, head, name + "from the head");
        Test.assertMessage(FlowTest.near(f.feed.tracker.altitude() as Float, head.toFloat(), 0.5), name + "at the head's altitude");
        // Each landmark with an altitude, in turn: suggested where it is, its details, calibrated at.
        var pts = r.points;
        for (var i = 0; i < pts.size(); i++) {
            if (!"landmark".equals(pts[i]["kind"] as Object?) || pts[i]["alt"] == null || (pts[i]["at"] as Number) < 0) { continue; }
            var at = pts[i]["at"] as Number, nm = pts[i]["name"] as String;
            f.feed.tracker.d = at.toFloat();
            input.alt = (pts[i]["alt"] as Number).toFloat();
            f.press(:start);
            FlowTest.choose(f, :calibrate);
            var m = f.menu as FlowMenu;
            Test.assertMessage(m.items[0].id == :calAt && m.items[0].point == i, name + nm + " suggested: " + labels(m));
            Test.assertMessage(FlowDraw.draw(d, f), name + "F8 at " + nm);
            f.press(:start);
            Test.assertMessage(FlowDraw.draw(d, f), name + "F18 at " + nm);
            f.press(:start);
            Test.assertMessage(FlowDraw.draw(d, f), name + "F11 at " + nm);
            f.press(:start);
            Test.assertMessage(FlowTest.near(f.feed.tracker.d, at.toFloat(), 0.5), name + "the place at " + nm);
            Test.assertMessage(FlowTest.near(f.feed.tracker.altitude() as Float, (pts[i]["alt"] as Number).toFloat(), 0.5),
                name + "the altitude at " + nm);
        }
        // The exits, the watch reading each one's altitude: each offered by End where it is.
        for (var k = 0; k < exits.size(); k++) {
            f.feed.tracker.d = (pts[exits[k]]["at"] as Number).toFloat();
            input.alt = (pts[exits[k]]["alt"] as Number).toFloat();
            f.press(:start);
            FlowTest.choose(f, :end);
            var m = f.menu as FlowMenu;
            Test.assertMessage(FlowTest.same(FlowTest.points(m), [r.point("top"), exits[k], -1]), name + "End at " + labels(m));
            FlowTest.pick(f, 1);
            f.press(:start);
            Test.assertMessage(FlowDraw.draw(d, f), name + "F25 at " + (pts[exits[k]]["name"] as String));
            Test.assertEqualMessage((f.detail as FlowDetail).alt, pts[exits[k]]["alt"] as Number, name + "the exit's altitude");
            // Back to End, Back to the pause menu, and on.
            f.press(:back);
            f.press(:back);
            FlowTest.choose(f, :continue);
        }
        // Near the top: no exit in reach; End at the top, the route's height gained.
        f.feed.tracker.d = Climb.totalD() - 20.0;
        f.press(:start);
        FlowTest.choose(f, :end);
        Test.assertMessage(FlowTest.same(FlowTest.points(f.menu as FlowMenu), [r.point("top"), -1]), name + "End near the top: " + labels(f.menu));
        input.alt = (pts[r.point("top")]["alt"] as Number).toFloat();
        FlowTest.choose(f, :endAt);
        Test.assertEqualMessage((f.detail as FlowDetail).alt, pts[r.point("top")]["alt"] as Number, name + "the top's altitude");
        Test.assertMessage(FlowDraw.draw(d, f), name + "F24");
        f.press(:start);
        Test.assertEqualMessage(f.phase(), Tracker.ENDED, name + "ended");
        Test.assertMessage(FlowTest.near(f.feed.tracker.d, Climb.totalD().toFloat(), 0.5), name + "at the top");
        Test.assertEqualMessage(f.feed.tracker.state().climbed(), r.ascent(), name + "the route's height gained");
        Test.assertMessage(FlowDraw.draw(d, f), name + "F14");
    }

    (:test)
    function daubenhornClimbs(logger as Logger) as Boolean {
        var r = real()[0];
        climbs(r, [r.point("exit")]);
        return true;
    }

    (:test)
    function sulzfluhClimbs(logger as Logger) as Boolean {
        climbs(real()[1], [] as Array<Number>);
        return true;
    }

    // Every page draws on a real route, at its start, half way and at its end, on the approach and on
    // the ferrata (a crash check; the look is the owner's, on the watch).
    function pagesDraw(r as Route, part as Symbol) as Void {
        var d = PagesTest.draw();
        Climb.use(r, part);
        var places = [0.0, Climb.totalD() / 2.0, Climb.totalD().toFloat()] as Array<Float>;
        for (var k = 0; k < places.size(); k++) {
            for (var p = 0; p < Pages.COUNT; p++) { Pages.draw(p, d, PagesTest.at(places[k])); }
        }
    }

    (:test)
    function daubenhornPagesDraw(logger as Logger) as Boolean {
        var r = real()[0];
        pagesDraw(r, :approach);
        pagesDraw(r, :ferrata);
        return true;
    }

    (:test)
    function sulzfluhPagesDraw(logger as Logger) as Boolean {
        var r = real()[1];
        pagesDraw(r, :approach);
        pagesDraw(r, :ferrata);
        return true;
    }
}
