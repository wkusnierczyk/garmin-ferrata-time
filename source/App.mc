using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

class App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The route the app climbs, from resources/routes/ (tools/route.py writes and checks it).
    var route as Route?;

    // The pages count from the ferrata head: the approach is a part of its own, shown only while on it.
    function onStart(state as Dictionary?) as Void {
        var r = Route.fromJson(WatchUi.loadResource(Rez.JsonData.route) as Dictionary);
        route = r;
        if (r != null) { Climb.use(r, :ferrata); }
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var view = new View();
        return [view, new Delegate(view)];
    }

}
