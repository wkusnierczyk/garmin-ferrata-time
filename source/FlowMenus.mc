using Toybox.Attention;
using Toybox.Math;

import Toybox.Lang;

// One row of a menu: what it does (its id, and the point it calibrates at or ends at, -1 for none),
// its label and the line under it, in its colour. A landmark's row starts that line with its kind's
// word, in the kind's colour.
class FlowItem {

    var id as Symbol;
    var label as String;
    var sub as String?;
    var colour as Number;
    var point as Number = -1;
    var kind as String? = null;
    var kindColour as Number = Flow.GREY;

    function initialize(i as Symbol, l as String, s as String?, c as Number) {
        id = i;
        label = l;
        sub = s;
        colour = c;
    }
}

// A menu: which one (:start, :paused, :calibrate, :landmarks, :end, :head, :summary or :confirm), its
// title in its colour, its rows, the one selected, and the menu Back returns to.
class FlowMenu {

    var id as Symbol;
    var title as String;
    var colour as Number;
    var items as Array<FlowItem>;
    var sel as Number = 0;
    var parent as FlowMenu? = null;

    function initialize(i as Symbol, t as String, c as Number, rows as Array<FlowItem>) {
        id = i;
        title = t;
        colour = c;
        items = rows;
    }

    // The row with this id, or 0.
    function indexOf(i as Symbol) as Number {
        for (var k = 0; k < items.size(); k++) { if (items[k].id == i) { return k; } }
        return 0;
    }
}

// The altitude entry: the altitude it started from (the barometer's before a start, else the
// estimate; known false when the barometer had none), the altitude shown, and where on the route that
// is, from the place d0; the menu Back returns to.
class FlowEntry {

    var start as Boolean;
    var est as Number;
    var known as Boolean;
    var value as Number;
    var d0 as Float;
    var at as Float = 0.0;
    var parent as FlowMenu;

    function initialize(s as Boolean, e as Number, k as Boolean, from as Float, p as FlowMenu) {
        start = s;
        est = e;
        known = k;
        value = e;
        d0 = from;
        parent = p;
    }
}

// The climb flow (design/real-functionality.md, section 5; the flow mock the owner picked from, #51):
// the ready screen, the menus the app draws, the altitude entry, the CALIBRATED confirmation and the
// summary, driven by the buttons and acting on the climb through the feed. Pure but for the buzz, so
// the tests drive it by press(); FlowDraw draws it, the view passes it the keys.
class FlowMenus {

    // How long SAVED or DISCARDED shows, in milliseconds.
    const TOAST_MS = 1600;

    var feed as Feed;
    var range as [Number, Number];
    // What is open: a menu, the altitude entry over its menu, the calibration's confirmation (where it
    // calibrated: "at Bench 1310 m", "at 1300 m"), a toast over the ready screen.
    var menu as FlowMenu? = null;
    var entry as FlowEntry? = null;
    var calibrated as String? = null;
    var toast as String? = null;
    var toastColour as Number = Flow.WHITE;
    var toastMs as Number = 0;
    // This climb: whether the head has been offered (once), and the landmarks the GPS prompted.
    var headOffered as Boolean = false;
    var prompted as Array<Number> = [] as Array<Number>;
    // The ready screen's figures, worked out once: the length, the ascent and the guidebook time as
    // shown, and the hardest grade.
    var figures as Array<String>;
    var hardest as Number;

    function initialize(f as Feed) {
        feed = f;
        var r = f.route;
        range = r.altRange();
        figures = [(Route.lengthOf(r.sections) / 1000.0).format("%.1f"), r.ascent().format("%d"),
            Flow.hours(r.guideMinutes())];
        var g = r.hardest();
        hardest = g < 0 ? 0 : (g > 12 ? 12 : g);
    }

    // A new climb from the settings: the ready screen, nothing open.
    function reset() as Void {
        menu = null;
        entry = null;
        calibrated = null;
        newClimb();
    }

    function newClimb() as Void {
        headOffered = false;
        prompted = [] as Array<Number>;
    }

    function phase() as Tracker.Phase { return feed.tracker.phase; }

    // Whether the flow has the screen (and Up and Down): before the start, after the end, and while
    // anything of it is open. Else the pages have it. (One test a line: a chain of them over the
    // nullable fields runs the compiler's type checker out of memory.)
    function onScreen() as Boolean {
        if (isOpen()) { return true; }
        if (calibrated != null) { return true; }
        if (toast != null) { return true; }
        var p = phase();
        return p == Tracker.IDLE || p == Tracker.ENDED;
    }

    // Whether a menu or the altitude entry is open.
    function isOpen() as Boolean {
        if (menu != null) { return true; }
        return entry != null;
    }

    // The toast's time runs out.
    function tick(ms as Number) as Void {
        if (toast == null) { return; }
        toastMs -= ms;
        if (toastMs <= 0) { toast = null; }
    }

    // A button: :start, :back, :up or :down. False when the flow does not take it: Back before the
    // start (the app closes), Up and Down during the climb (the pages change).
    function press(key as Symbol) as Boolean {
        // The confirmation stays until Start or Back; the climb goes on behind it.
        if (calibrated != null) {
            if (key == :start || key == :back) { calibrated = null; }
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
            // Up and Down do nothing yet.
            return key != :back;
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
        } else if (id == :calAt) {
            menu = null;
            feed.calibrateAt(it.point);
            quietNear();
            calibrated = "at " + pointName(it.point) + " " + pointAlt(it.point).format("%d") + " m";
        } else if (id == :endAt) {
            feed.end(it.point);
            open(summaryMenu(), null);
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

    function pressEntry(e as FlowEntry, key as Symbol) as Void {
        if (key == :up) {
            e.value = Flow.altUp(e.value, range);
            e.at = placeOf(e);
        } else if (key == :down) {
            e.value = Flow.altDown(e.value, range);
            e.at = placeOf(e);
        } else if (key == :back) {
            entry = null;
        } else if (key == :start) {
            entry = null;
            menu = null;
            if (e.start) {
                newClimb();
                feed.startAt(e.value.toFloat());
            } else {
                feed.calibrateTo(e.value.toFloat());
                quietNear();
                calibrated = "at " + e.value.format("%d") + " m";
            }
        }
    }

    function open(m as FlowMenu, parent as FlowMenu?) as Void {
        m.parent = parent;
        menu = m;
    }

    // The altitude entry, from the barometer before a start, else from the estimated place's altitude.
    function openEntry(parent as FlowMenu, start as Boolean) as Void {
        var est = 0, known = true, d0 = 0.0;
        if (start) {
            var a = feed.peek();
            known = a != null;
            est = a != null ? Math.round(a).toNumber() : feed.route.headAlt();
        } else {
            est = feed.tracker.state().altitude();
            d0 = feed.tracker.d;
        }
        var e = new FlowEntry(start, est, known, d0, parent);
        e.at = placeOf(e);
        entry = e;
    }

    // Where on the ferrata an entry's altitude is: the point at that altitude nearest the place (the
    // head, before a start). Nothing on the approach, which shows only "on the approach".
    function placeOf(e as FlowEntry) as Float {
        if (!Climb.FERRATA) { return 0.0; }
        return Climb.distanceAtNet((e.value - Climb.START_ALT).toFloat(), e.d0);
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

    function startMenu() as FlowMenu {
        var r = feed.route;
        var rows = [new FlowItem(:atHead, "Ferrata head", "at " + r.headAlt().format("%d") + " m", Flow.WHITE)];
        if (r.approachKnown()) {
            var a = r.point("approach");
            rows.add(new FlowItem(:atApproach, pointName(a), "at " + pointAlt(a).format("%d") + " m", Flow.WHITE));
        }
        var baro = feed.peek();
        rows.add(new FlowItem(:atAltitude, "At altitude",
            baro != null ? "barometer " + Math.round(baro).toNumber().format("%d") + " m" : "no barometer yet", Flow.WHITE));
        return new FlowMenu(:start, "START", Flow.WHITE, rows);
    }

    // On the approach: go on, onto the ferrata, or end. On the ferrata: go on, calibrate, or end.
    function pauseMenu() as FlowMenu {
        if (!Climb.FERRATA) {
            return new FlowMenu(:paused, "PAUSED", Flow.PAUSED, [
                new FlowItem(:continue, "Continue approach", null, Flow.WHITE),
                startAscentItem(),
                endHereItem()]);
        }
        var t = feed.tracker;
        var near = Flow.suggested(t, prompted), exits = Flow.exitsInReach(t).size();
        return new FlowMenu(:paused, "PAUSED", Flow.PAUSED, [
            new FlowItem(:continue, "Continue", null, Flow.WHITE),
            new FlowItem(:calibrate, "Calibrate", near >= 0 ? "Near " + pointName(near) : "Landmark or altitude", Flow.SYNC),
            new FlowItem(:end, "End", exits > 1 ? "Top, exits, or here" : (exits == 1 ? "Top, exit, or here" : "Top or here"),
                Widgets.RED)]);
    }

    function startAscentItem() as FlowItem {
        return new FlowItem(:startAscent, "Start ferrata", "at " + feed.route.headAlt().format("%d") + " m", Widgets.CLIMBER);
    }

    function endHereItem() as FlowItem {
        return new FlowItem(:endAt, "End here", "No altitude check", Flow.WHITE);
    }

    // End at the top, at each exit in reach, or here.
    function endMenu() as FlowMenu {
        var r = feed.route, top = r.point("top");
        var topAlt = r.points[top]["alt"] as Number?;
        var row = new FlowItem(:endAt, "End at top", topAlt != null ? topAlt.format("%d") + " m" : null, Widgets.RED);
        row.point = top;
        var rows = [row] as Array<FlowItem>;
        var exits = Flow.exitsInReach(feed.tracker);
        for (var k = 0; k < exits.size(); k++) {
            var i = exits[k], alt = r.points[i]["alt"] as Number?;
            row = new FlowItem(:endAt, "End at exit", pointName(i) + (alt != null ? ", " + alt.format("%d") + " m" : ""), Widgets.GREEN);
            row.point = i;
            rows.add(row);
        }
        rows.add(endHereItem());
        return new FlowMenu(:end, "END", Widgets.RED, rows);
    }

    // The suggested point first, when there is one, then the list and the altitude entry.
    function calibrateMenu() as FlowMenu {
        var t = feed.tracker, rows = [] as Array<FlowItem>;
        var near = Flow.suggested(t, prompted);
        if (near >= 0) { rows.add(markItem(near)); }
        var n = Flow.marks(t).size();
        if (n > 0) { rows.add(new FlowItem(:landmarks, "At landmark", n.format("%d") + " on the route", Flow.WHITE)); }
        rows.add(new FlowItem(:calAltitude, "At altitude", "estimate " + t.state().altitude().format("%d") + " m", Flow.WHITE));
        return new FlowMenu(:calibrate, "CALIBRATE", Flow.SYNC, rows);
    }

    function landmarksMenu() as FlowMenu {
        var list = Flow.marks(feed.tracker), rows = [] as Array<FlowItem>;
        for (var k = 0; k < list.size(); k++) { rows.add(markItem(list[k])); }
        return new FlowMenu(:landmarks, "LANDMARKS", Flow.SYNC, rows);
    }

    // A point as a row: its name, then its kind in colour, its altitude and how far it is.
    function markItem(i as Number) as FlowItem {
        var p = feed.route.points[i], kind = p["kind"] as String, word = Flow.kindWord(kind);
        var row = new FlowItem(:calAt, pointName(i),
            word + " at " + pointAlt(i).format("%d") + " m " + Flow.inDistance((p["at"] as Number).toFloat(), feed.tracker.d),
            Flow.WHITE);
        row.point = i;
        row.kind = word;
        row.kindColour = Flow.kindColour(kind);
        return row;
    }

    function headMenu() as FlowMenu {
        return new FlowMenu(:head, "FERRATA HEAD", Widgets.CLIMBER, [
            new FlowItem(:continue, "Continue approach", null, Flow.WHITE),
            startAscentItem()]);
    }

    // Save, Resume or Discard, so Discard is last.
    function summaryMenu() as FlowMenu {
        return new FlowMenu(:summary, "SUMMARY", Flow.WHITE, [
            new FlowItem(:save, "Save", null, Widgets.GREEN),
            new FlowItem(:resume, "Resume", null, Flow.WHITE),
            new FlowItem(:discard, "Discard", null, Widgets.RED)]);
    }

    function confirmMenu() as FlowMenu {
        return new FlowMenu(:confirm, "DISCARD THE CLIMB?", Widgets.RED, [
            new FlowItem(:no, "No", null, Flow.WHITE),
            new FlowItem(:yes, "Yes, discard", null, Widgets.RED)]);
    }

    function pointName(i as Number) as String { return feed.route.points[i]["name"] as String; }

    function pointAlt(i as Number) as Number { return feed.route.points[i]["alt"] as Number; }
}
