using Toybox.System;
using Toybox.WatchUi;

import Toybox.Lang;

// Up and down change page, start pauses the climb, holding Up opens Ask (and Settings), back leaves.
// On page 9 a tap on a chevron steps the previewed section.
class Delegate extends WatchUi.BehaviorDelegate {

    var view as View;

    function initialize(v as View) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onNextPage() as Boolean {
        view.nextPage(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.nextPage(-1);
        return true;
    }

    // A tap beside page 9's difficulty box, level with it, steps the section that way.
    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        if (view.page != Pages.SECTION_PAGE) { return false; }
        var xy = evt.getCoordinates(), k = 416.0 / System.getDeviceSettings().screenWidth;
        var x = xy[0] * k, y = xy[1] * k;
        var half = Pages.SECTION_BW / 2 + 10;
        if ((y - Pages.SECTION_BY).abs() > 45) { return false; }
        if (x < 208 - half) { view.stepSection(-1); return true; }
        if (x > 208 + half) { view.stepSection(1); return true; }
        return false;
    }

    // Start pauses or resumes the climb. A tap on a touchscreen also comes as select, possibly before
    // onTap sees it, so on page 9 select is left to the tap and the Start key itself pauses (onKey).
    function onSelect() as Boolean {
        if (view.page == Pages.SECTION_PAGE) { return false; }
        view.togglePause();
        return true;
    }

    function onKey(evt as WatchUi.KeyEvent) as Boolean {
        if (view.page != Pages.SECTION_PAGE || evt.getKey() != WatchUi.KEY_ENTER) { return false; }
        view.togglePause();
        return true;
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
