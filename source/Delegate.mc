using Toybox.System;
using Toybox.WatchUi;

import Toybox.Lang;

// The buttons go to the climb flow (#51) first: Start and Back open its menus (and before the start
// Back leaves), and Up and Down move in them while one is open, else change page. Holding Up opens Ask
// (and Settings). On page 9 a tap on a chevron steps the previewed section; other taps do nothing.
// A button's behaviour (onSelect, onBack, onNextPage ...) comes first, and onKey only when it returns
// false (BehaviorDelegate's documented order, #117).
class Delegate extends WatchUi.BehaviorDelegate {

    var view as View;
    // When the Start button last went down (System.getTimer()), null once taken or after another key:
    // Start comes as the select behaviour, which a tap on the screen also sends, so onSelect presses
    // Start only for a press this recent (#117). A Start held, or whose release a system screen took,
    // never comes as select; the bound keeps that press from making a later tap act as Start.
    var startDownMs as Number? = null;
    const START_MS = 1500;

    function initialize(v as View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    // Up and Down as behaviours (a swipe; the buttons come to onKey first).
    function onNextPage() as Boolean {
        if (view.flowOnScreen()) { return view.press(:down); }
        view.nextPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        if (view.flowOnScreen()) { return view.press(:up); }
        view.nextPage(-1);
        return true;
    }

    // A tap beside page 9's difficulty box, level with it, steps the section that way. The zone's edges
    // are shares of the screen's width, in whole pixels as the page draws them (a share is a decimal a
    // hair off its pixel).
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (view.page != Pages.SECTION_PAGE || view.flowOnScreen()) { return false; }
        var xy = evt.getCoordinates(), w = System.getDeviceSettings().screenWidth;
        var x = xy[0], y = xy[1];
        var mid = Math.round(0.5 * w), half = Math.round((Pages.SECTION_BW / 2 + 0.024038) * w);
        if ((y - Math.round(Pages.SECTION_BY * w)).abs() > Math.round(0.108173 * w)) { return false; }
        if (x < mid - half) { view.stepSection(-1); return true; }
        if (x > mid + half) { view.stepSection(1); return true; }
        return false;
    }

    // The buttons. Up and Down go to the flow only while it has the screen; else they come back as
    // onNextPage and onPreviousPage and change page. Back the flow does not take (before the start)
    // comes back as onBack, which leaves the app.
    function onKeyPressed(evt as WatchUi.KeyEvent) as Boolean {
        startDownMs = evt.getKey() == WatchUi.KEY_ENTER ? System.getTimer() : null;
        return false;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        var k = evt.getKey();
        // On a watch whose Start has no select behaviour, it comes here. Always taken, so Start is
        // pressed once whatever press() returns.
        if (k == WatchUi.KEY_ENTER) { startDownMs = null; view.press(:start); return true; }
        if (k == WatchUi.KEY_ESC) { return view.press(:back); }
        if ((k == WatchUi.KEY_UP || k == WatchUi.KEY_DOWN) && view.flowOnScreen()) {
            return view.press(k == WatchUi.KEY_UP ? :up : :down);
        }
        return false;
    }

    // The Start button comes here first (#117), and so does a tap on the touchscreen, possibly before
    // onTap sees it. Only the button presses Start, so a touch never pauses the climb or picks a row;
    // Start is taken here, so onKey does not see it again. A tap is taken too (it does nothing) except
    // on page 9 off the flow, where onTap steps the section.
    function onSelect() as Boolean {
        var t = startDownMs;
        startDownMs = null;
        if (t != null && System.getTimer() - t < START_MS) {
            view.press(:start);
            return true;
        }
        return view.page != Pages.SECTION_PAGE || view.flowOnScreen();
    }

    // Back as a behaviour (a swipe, or the Back button the flow did not take): the same as the button.
    function onBack() as Boolean {
        return view.press(:back);
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Ask"});
        menu.addItem(new WatchUi.MenuItem("Next", "what comes", :next, null));
        menu.addItem(new WatchUi.MenuItem("So far", "summary", :soFar, null));
        menu.addItem(new WatchUi.MenuItem("Pace", "vs guidebook", :pace, null));
        menu.addItem(new WatchUi.MenuItem("Exits", "ways off", :exits, null));
        menu.addItem(new WatchUi.MenuItem("Settings", null, :settings, null));
        WatchUi.pushView(menu, new AskDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

// The phone app does not exist yet: choosing a question only closes the list. Settings opens the
// watch's settings in its place (until the climb's menus come, #51).
class AskDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :settings) {
            WatchUi.switchToView(new SettingsMenu(), new SettingsMenuDelegate(), WatchUi.SLIDE_LEFT);
            return;
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
