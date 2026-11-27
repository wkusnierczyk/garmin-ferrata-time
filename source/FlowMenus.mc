using Toybox.Attention;
using Toybox.Math;

import Toybox.Lang;

// One row of a menu: what it does (its id, and the point it calibrates at or ends at, -1 for none),
// its label, one line (#121), and its colour, the selected pill's outline; a destructive row (fill)
// has its pill filled in it. The label as drawn, cut to its room, and its size, at each place it is
// drawn (a row from the selected one, -2 to 2), worked out once (FlowDraw).
class FlowItem {

    var id as Symbol;
    var label as String;
    var colour as Number;
    var point as Number = -1;
    var fill as Boolean = false;
    var shown as Array<String?> = new Array<String?>[5];
    var fonts as Array<Number> = [0, 0, 0, 0, 0] as Array<Number>;

    function initialize(i as Symbol, l as String, c as Number) {
        id = i;
        label = l;
        colour = c;
    }
}

// A menu: which one (:start, :paused, :calibrate, :landmarks, :end, :head, :summary or :confirm),
// which also says its title (FlowDraw), its rows, the one selected, and the menu Back returns to.
class FlowMenu {

    var id as Symbol;
    var items as Array<FlowItem>;
    var sel as Number = 0;
    var parent as FlowMenu? = null;
    // The summary's line of figures, laid out once when it is first drawn (FlowDraw).
    var line as SummaryLine? = null;

    function initialize(i as Symbol, rows as Array<FlowItem>) {
        id = i;
        items = rows;
    }

    // The row with this id, or 0.
    function indexOf(i as Symbol) as Number {
        for (var k = 0; k < items.size(); k++) { if (items[k].id == i) { return k; } }
        return 0;
    }
}

// The altitude entry: whether it starts the climb, the altitude it started from (the barometer's
// before a start, the head's when it has none, else the estimate), the altitude shown, and the menu
// Back returns to. It shows the altitude alone (#121); the tracker works out where on the route it is.
// The altitudes and the range they step within are in the unit shown when it opened, feet or metres
// (ft; #144).
class FlowEntry {

    var start as Boolean;
    var est as Number;
    var value as Number;
    var parent as FlowMenu;
    var ft as Boolean;
    var range as [Number, Number];

    function initialize(s as Boolean, e as Number, p as FlowMenu, inFeet as Boolean, r as [Number, Number]) {
        start = s;
        est = e;
        value = e;
        parent = p;
        ft = inFeet;
        range = r;
    }
}

// A point's details (#121), over the menu it was picked in: a landmark before calibrating there, or the
// top, an exit or here (point -1) before ending there. What it shows is worked out when it opens, the
// climb being paused: the point's altitude, and how far it is from the place (here: how far along the
// route the place is). Start calibrates or ends there, Back returns to the menu.
class FlowDetail {

    var point as Number;
    var end as Boolean;
    var alt as Number;
    var at as Float;
    var d as Float;
    // The name as drawn, cut to the screen's width once (FlowDraw).
    var shown as String? = null;

    function initialize(p as Number, e as Boolean, a as Number, pointAt as Float, place as Float) {
        point = p;
        end = e;
        alt = a;
        at = pointAt;
        d = place;
    }
}

// The climb flow (design/real-functionality.md, section 5; the flow mock the owner picked from, #51):
// the ready screen, the menus the app draws, the altitude entry, the CALIBRATED confirmation and the
// summary, driven by the buttons and acting on the climb through the feed. Pure but for the buzz, so
// the tests drive it by press(); FlowDraw draws it, the view passes it the keys.
class FlowMenus {

    // How long SAVED or DISCARDED shows, in milliseconds (#121): Back closes it sooner.
    const TOAST_MS = 3000;

    var feed as Feed;
    var range as [Number, Number];
    // What is open: a menu, the altitude entry or a point's details over its menu, the calibration's
    // confirmation (the altitude calibrated to, in metres, and the point it was at, -1 for an altitude
    // entered), a
    // toast over the ready screen. Back on the ready screen closes the app at once, to the watch's
    // activities (quit, which the view acts on; owner, 2026-11-26: no APP CLOSED).
    var menu as FlowMenu? = null;
    var entry as FlowEntry? = null;
    var detail as FlowDetail? = null;
    var calibrated as Float? = null;
    var calibratedPoint as Number = -1;
    // The point's name under CALIBRATED as drawn, cut to its room once (FlowDraw), and its size.
    var calibratedName as String? = null;
    var calibratedFont as Number = 0;
    var toast as String? = null;
    var toastColour as Number = Flow.WHITE;
    var toastMs as Number = 0;
    var quit as Boolean = false;
    // This climb: whether the head has been offered (once), and the landmarks the GPS prompted.
    var headOffered as Boolean = false;
    // On the approach, whether its own screen (F4) shows: it is the first page there, the pages after
    // it (owner, 2026-11-26). A climb starts on it.
    var approachShown as Boolean = true;
    var prompted as Array<Number> = [] as Array<Number>;
    // The ready screen's figures, worked out once (#121): the ferrata's path, its length and height
    // together as page 16 counts it, and its ascent, in metres; its guidebook time as shown.
    var path as Float = 0.0;
    var ascent as Number;
    var guide as String;
    // The large altitude's size (FlowDraw.bigSize), worked out once; -1 until then.
    var bigK as Number = -1;

    function initialize(f as Feed) {
        feed = f;
        var r = f.route;
        range = r.altRange();
        for (var i = 0; i < r.sections.size(); i++) {
            var len = r.sections[i]["len"] as Number, up = r.sections[i]["up"] as Number;
            path += Math.sqrt(len * len + up * up).toFloat();
        }
        ascent = r.ascent();
        guide = Flow.hours(r.guideMinutes());
    }

    // Whether the watch shows feet: the system's setting, never the app's (#144). A test's flow says.
    function feet() as Boolean { return Widgets.feet(); }

    // The ready screen's path, ascent and guidebook time, as shown in feet or metres.
    function figures(ft as Boolean) as Array<String> {
        return [Flow.inUnit(path, ft).format("%d"), Flow.inUnit(ascent.toFloat(), ft).format("%d"), guide];
    }

    function newClimb() as Void {
        headOffered = false;
        approachShown = true;
        prompted = [] as Array<Number>;
    }

    function phase() as Tracker.Phase { return feed.tracker.phase; }

    // Whether the flow has the screen (and Up and Down): before the start, on the approach while its
    // own screen shows (F4, #121), after the end, and while anything of it is open. Else the pages have it. (One test
    // a line: a chain of them over the nullable fields runs the compiler's type checker out of memory.)
    function onScreen() as Boolean {
        if (isOpen()) { return true; }
        if (calibrated != null) { return true; }
        if (toast != null) { return true; }
        if (onApproach() && approachShown) { return true; }
        var p = phase();
        return p == Tracker.IDLE || p == Tracker.ENDED;
    }

    // On the approach, going or paused.
    function onApproach() as Boolean { return !Climb.FERRATA && feed.climbing(); }

    // The page after page by step (1 or -1), of count. On the approach its own screen (F4) is the first
    // page (owner, 2026-11-26): past either end of the pages comes to it (the page stays as it was,
    // under it), and from it to the first or the last.
    function stepPage(page as Number, step as Number, count as Number) as Number {
        if (!onApproach()) { return (page + step + count) % count; }
        if (approachShown) {
            approachShown = false;
            return step > 0 ? 0 : count - 1;
        }
        if (page + step < 0 || page + step >= count) {
            approachShown = true;
            return page;
        }
        return page + step;
    }

    // Whether a menu, the altitude entry or a point's details is open.
    function isOpen() as Boolean {
        if (menu != null) { return true; }
        if (detail != null) { return true; }
        return entry != null;
    }

    // The toast's time runs out.
    function tick(ms as Number) as Void {
        if (toast == null) { return; }
        toastMs -= ms;
        if (toastMs <= 0) { closeToast(); }
    }

    function closeToast() as Void {
        toast = null;
    }

    // A button: :start, :back, :up or :down. False when the flow does not take it: Up and Down during
    // the climb (the pages change).
    function press(key as Symbol) as Boolean {
        // SAVED and DISCARDED stay their time; Back closes them at once (#121).
        if (toast != null) {
            if (key == :back) { closeToast(); }
            return true;
        }
        // The confirmation stays until Start or Back; the climb goes on behind it.
        if (calibrated != null) {
            if (key == :start || key == :back) { calibrated = null; }
            return true;
        }
        var dt = detail;
        if (dt != null) {
            pressDetail(dt, key);
            return true;
        }
        var e = entry;
        if (e != null) {
            pressEntry(e, key);
            return true;
        }
        var m = menu;
        if (m != null) {
            pressMenu(m, key);
            return true;
        }
        var p = phase();
        if (p == Tracker.IDLE) {
            if (key == :start) { open(startMenu(), null); }
            // Back leaves the app at once (#121). Up and Down do nothing yet.
            if (key == :back) { quit = true; }
            return true;
        }
        if (p == Tracker.ENDED) {
            open(summaryMenu(), null);
            return true;
        }
        // Start or Back during the climb pauses it and opens the menu; paused, reopens it.
        if (key == :start || key == :back) {
            if (!feed.paused()) { feed.pause(); }
            open(pauseMenu(), null);
            return true;
        }
        return false;
    }

    function pressMenu(m as FlowMenu, key as Symbol) as Void {
        var n = m.items.size();
        // An empty menu (none is opened so) takes only Back.
        if (n == 0 && key != :back) { return; }
        if (key == :up) {
            m.sel = (m.sel + n - 1) % n;
        } else if (key == :down) {
            m.sel = (m.sel + 1) % n;
        } else if (key == :start) {
            select(m, m.items[m.sel]);
        } else if (key == :back) {
            // A submenu returns to its menu; the summary stays (Save, Resume or Discard); the Start menu
            // returns to the ready screen, the head's offer leaves the approach going, the pause menu
            // leaves the climb paused.
            if (m.parent != null) {
                menu = m.parent;
            } else if (m.id != :summary) {
                menu = null;
            }
        }
    }

    function select(m as FlowMenu, it as FlowItem) as Void {
        var id = it.id;
        if (id == :calibrate) {
            open(calibrateMenu(), m);
        } else if (id == :end) {
            open(endMenu(), m);
        } else if (id == :landmarks) {
            open(landmarksMenu(), m);
        } else if (id == :atHead || id == :atApproach) {
            menu = null;
            newClimb();
            feed.start(id == :atHead ? :head : :approachPoint);
        } else if (id == :atAltitude || id == :calAltitude) {
            openEntry(m, id == :atAltitude);
        } else if (id == :continue) {
            menu = null;
            if (feed.paused()) { feed.resume(); }
        } else if (id == :startAscent) {
            menu = null;
            feed.startAscent();
        } else if (id == :calAt || id == :endAt) {
            // A point's details first (#121): Start there calibrates or ends.
            openDetail(it.point, id == :endAt);
        } else if (id == :endHere) {
            endAt(-1);
        } else if (id == :save) {
            menu = null;
            feed.save();
            newClimb();
            showToast("SAVED", Widgets.GREEN);
        } else if (id == :resume) {
            menu = null;
            feed.unend();
        } else if (id == :discard) {
            open(confirmMenu(), m);
        } else if (id == :yes) {
            menu = null;
            feed.discard();
            newClimb();
            showToast("DISCARDED", Widgets.RED);
        } else if (id == :no) {
            menu = m.parent;
        }
    }

    // A point's details: Start calibrates or ends there, Back returns to the menu it was picked in.
    function pressDetail(dt as FlowDetail, key as Symbol) as Void {
        if (key == :back) {
            detail = null;
        } else if (key == :start) {
            detail = null;
            if (dt.end) {
                endAt(dt.point);
                return;
            }
            menu = null;
            feed.calibrateAt(dt.point);
            quietNear();
            calibrated = dt.alt.toFloat();
            calibratedPoint = dt.point;
            calibratedName = null;
        }
    }

    function endAt(point as Number) as Void {
        feed.end(point);
        open(summaryMenu(), null);
    }

    // The details of a point (-1: here), from the paused climb's place.
    function openDetail(point as Number, end as Boolean) as Void {
        var t = feed.tracker;
        if (point < 0) {
            detail = new FlowDetail(point, end, t.state().altitude(), t.d, t.d);
            return;
        }
        var at = (feed.route.points[point]["at"] as Number).toFloat();
        detail = new FlowDetail(point, end, altOf(point), at, t.d);
    }

    // A point's altitude: its own, else the route's there (an exit or a top without one).
    function altOf(point as Number) as Number {
        var a = feed.route.points[point]["alt"] as Number?;
        if (a != null) { return a; }
        return Climb.START_ALT + Climb.netAtDistance((feed.route.points[point]["at"] as Number).toFloat()).toNumber();
    }

    function pressEntry(e as FlowEntry, key as Symbol) as Void {
        if (key == :up) {
            e.value = Flow.altUp(e.value, e.range, e.ft);
        } else if (key == :down) {
            e.value = Flow.altDown(e.value, e.range, e.ft);
        } else if (key == :back) {
            entry = null;
        } else if (key == :start) {
            entry = null;
            menu = null;
            // Entered in feet, set in metres (#144).
            var m = Flow.toMetres(e.value, e.ft);
            if (e.start) {
                newClimb();
                feed.startAt(m);
            } else {
                feed.calibrateTo(m);
                quietNear();
                calibrated = m;
                calibratedPoint = -1;
            }
        }
    }

    function open(m as FlowMenu, parent as FlowMenu?) as Void {
        m.parent = parent;
        menu = m;
    }

    // The altitude entry, from the barometer before a start, else from the estimated place's altitude,
    // in the unit the watch shows.
    function openEntry(parent as FlowMenu, start as Boolean) as Void {
        var est = 0.0;
        if (start) {
            var a = feed.peek();
            est = a != null ? a : feed.route.headAlt().toFloat();
        } else {
            est = feed.tracker.state().altitude().toFloat();
        }
        var ft = feet();
        entry = new FlowEntry(start, Flow.inUnit(est, ft), parent, ft, Flow.rangeIn(range, ft));
    }

    function showToast(text as String, colour as Number) as Void {
        toast = text;
        toastColour = colour;
        toastMs = TOAST_MS;
    }

    // ---------------------------------------------------------------- what the triggers call

    // The approach's GPS near the head (#113): a buzz and the offer of the head, without pausing, once
    // a climb. Not while a menu is open (the trigger asks again). True when offered.
    function offerHead() as Boolean {
        if (phase() != Tracker.APPROACH || headOffered) { return false; }
        if (isOpen()) { return false; }
        headOffered = true;
        buzz();
        open(headMenu(), null);
        return true;
    }

    // The GPS near a landmark ahead (#52): a buzz, the climb paused and the pause menu with Calibrate
    // selected, which then offers that landmark first; once a landmark. Not while a menu is open. True
    // when prompted.
    function nearLandmark(point as Number) as Boolean {
        if (phase() != Tracker.ASCENT || prompted.indexOf(point) >= 0) { return false; }
        if (isOpen()) { return false; }
        prompted.add(point);
        buzz();
        calibrated = null;
        feed.pause();
        var m = pauseMenu();
        m.sel = m.indexOf(:calibrate);
        open(m, null);
        return true;
    }

    // After a calibration, the landmarks within the GPS prompt's reach of the new place have been dealt
    // with: no prompt for them right after it (owner, #51), as if they had prompted.
    function quietNear() as Void {
        var pts = feed.route.points, d = feed.tracker.d;
        for (var i = 0; i < pts.size(); i++) {
            if (!"landmark".equals(pts[i]["kind"] as Object?) || prompted.indexOf(i) >= 0) { continue; }
            if (((pts[i]["at"] as Number) - d).abs() <= Flow.GPS) { prompted.add(i); }
        }
    }

    function buzz() as Void {
        if (Attention has :vibrate) { Attention.vibrate([new Attention.VibeProfile(50, 300)]); }
    }

    // ---------------------------------------------------------------- the menus

    // Where the climb starts (#121): HEAD (green), the approach's start by its type (TOP STATION, CAR
    // PARK) when the route knows its altitude, or ALTITUDE.
    function startMenu() as FlowMenu {
        var r = feed.route;
        var rows = [new FlowItem(:atHead, "Head", Widgets.GREEN)];
        if (r.approachKnown()) { rows.add(new FlowItem(:atApproach, r.approachType(), Flow.WHITE)); }
        rows.add(new FlowItem(:atAltitude, "Altitude", Flow.WHITE));
        return new FlowMenu(:start, rows);
    }

    // On the approach: go on, onto the ferrata, or end here. On the ferrata: go on, calibrate, or end.
    function pauseMenu() as FlowMenu {
        if (!Climb.FERRATA) {
            return new FlowMenu(:paused, [
                new FlowItem(:continue, "Continue approach", Flow.WHITE),
                startAscentItem(),
                new FlowItem(:endHere, "End here", Widgets.RED)]);
        }
        return new FlowMenu(:paused, [
            new FlowItem(:continue, "Continue", Flow.WHITE),
            new FlowItem(:calibrate, "Calibrate", Flow.SYNC),
            new FlowItem(:end, "End", Widgets.RED)]);
    }

    function startAscentItem() as FlowItem {
        return new FlowItem(:startAscent, "Start from head", Widgets.GREEN);
    }

    // End at the top, at each exit in reach, or here: the places alone, each opening its details.
    function endMenu() as FlowMenu {
        var row = new FlowItem(:endAt, "Top", Widgets.RED);
        row.point = feed.route.point("top");
        var rows = [row] as Array<FlowItem>;
        var exits = Flow.exitsInReach(feed.tracker);
        for (var k = 0; k < exits.size(); k++) {
            row = new FlowItem(:endAt, "Exit", Widgets.GREEN);
            row.point = exits[k];
            rows.add(row);
        }
        rows.add(new FlowItem(:endAt, "Here", Flow.WHITE));
        return new FlowMenu(:end, rows);
    }

    // The suggested point first, when there is one, then the list and the altitude entry.
    function calibrateMenu() as FlowMenu {
        var t = feed.tracker, rows = [] as Array<FlowItem>;
        var near = Flow.suggested(t, prompted);
        if (near >= 0) { rows.add(markItem(near)); }
        if (Flow.marks(t).size() > 0) { rows.add(new FlowItem(:landmarks, "Landmark", Flow.WHITE)); }
        rows.add(new FlowItem(:calAltitude, "Altitude", Flow.WHITE));
        return new FlowMenu(:calibrate, rows);
    }

    function landmarksMenu() as FlowMenu {
        var list = Flow.marks(feed.tracker), rows = [] as Array<FlowItem>;
        for (var k = 0; k < list.size(); k++) { rows.add(markItem(list[k])); }
        return new FlowMenu(:landmarks, rows);
    }

    // A point as a row: its name alone, outlined in its type's colour.
    function markItem(i as Number) as FlowItem {
        var row = new FlowItem(:calAt, pointName(i), Flow.colour(feed.route.points[i]));
        row.point = i;
        return row;
    }

    function headMenu() as FlowMenu {
        return new FlowMenu(:head, [new FlowItem(:continue, "Continue approach", Flow.WHITE), startAscentItem()]);
    }

    // Save, Resume or Discard, so Discard is last.
    function summaryMenu() as FlowMenu {
        return new FlowMenu(:summary, [
            new FlowItem(:save, "Save", Widgets.GREEN),
            new FlowItem(:resume, "Resume", Flow.WHITE),
            new FlowItem(:discard, "Discard", Widgets.RED)]);
    }

    // DISCARD is the one destructive row: its pill filled red.
    function confirmMenu() as FlowMenu {
        var yes = new FlowItem(:yes, "Discard", Widgets.RED);
        yes.fill = true;
        return new FlowMenu(:confirm, [new FlowItem(:no, "No", Flow.WHITE), yes]);
    }

    function pointName(i as Number) as String { return feed.route.points[i]["name"] as String; }

}
