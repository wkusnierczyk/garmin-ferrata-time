using Toybox.System;
using Toybox.WatchUi;

import Toybox.Lang;

// Up and down change page, start pauses the demo, holding Up opens Ask, back leaves. On page 9 a tap
// on a chevron steps the previewed section.
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
        if ((y - 186).abs() > 45) { return false; }
        if (x < 208 - 66 - 10) { view.stepSection(-1); return true; }
        if (x > 208 + 66 + 10) { view.stepSection(1); return true; }
        return false;
    }

    function onSelect() as Boolean {
        view.togglePause();
        return true;
    }

    function onMenu() as Boolean {
        var menu = new WatchUi.Menu2({:title => "Ask"});
        menu.addItem(new WatchUi.MenuItem("Next", "what comes", :next, null));
        menu.addItem(new WatchUi.MenuItem("So far", "summary", :soFar, null));
        menu.addItem(new WatchUi.MenuItem("Pace", "vs guidebook", :pace, null));
        menu.addItem(new WatchUi.MenuItem("Exits", "ways off", :exits, null));
        WatchUi.pushView(menu, new AskDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

// The phone app does not exist yet: choosing a question only closes the list.
class AskDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
