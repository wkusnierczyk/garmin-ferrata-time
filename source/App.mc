using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

class App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The routes on the watch, from resources/routes/ (tools/route.py writes and checks them), and the
    // last one used, which the app opens on (Routes, #141).
    var routes as Array<Route> = [] as Array<Route>;
    var last as Number = 0;
    var view as View?;

    // The pages count from the ferrata head: the approach is a part of its own, shown only while on it
    // (its screen first, then the pages, #121).
    function onStart(state as Dictionary?) as Void {
        routes = Routes.load();
        last = Routes.last(routes);
        if (routes.size() > 0) { Climb.use(routes[last], :ferrata); }
    }

    // Lets go of the GPS.
    function onStop(state as Dictionary?) as Void {
        var v = view;
        if (v != null) { v.stop(); }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new View(routes, last);
        view = v;
        return [v, new Delegate(v)];
    }

}
