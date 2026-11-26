using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

class App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The route the app climbs, from resources/routes/ (tools/route.py writes and checks it).
    var route as Route?;
    var view as View?;

    // The pages count from the ferrata head: the approach is a part of its own, shown only while on it
    // (its screen first, then the pages, #121).
    function onStart(state as Dictionary?) as Void {
        var r = Route.fromJson(WatchUi.loadResource(Rez.JsonData.route) as Dictionary);
        route = r;
        if (r != null) { Climb.use(r, :ferrata); }
    }

    // Lets go of the GPS.
    function onStop(state as Dictionary?) as Void {
        var v = view;
        if (v != null) { v.stop(); }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new View(route);
        view = v;
        return [v, new Delegate(v)];
    }

    // From the phone or the watch's Settings menu: the climb starts again on the input chosen.
    function onSettingsChanged() as Void {
        var v = view;
        if (v != null) { v.restart(); }
        WatchUi.requestUpdate();
    }

}
