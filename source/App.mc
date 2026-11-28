using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

class App extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // The routes on the watch, from resources/routes/ (tools/route.py writes and checks them), and the
    // last one used, which the app opens on (Routes, #141).
    var routes as Array<RouteEntry> = [] as Array<RouteEntry>;
    var last as Number = 0;
    // The last one used, read, until the view has it: then only the feed holds it, so a route picked
    // later is the only one read.
    var route as Route?;
    var view as View?;

    // The pages count from the ferrata head: the approach is a part of its own, shown only while on it
    // (its screen first, then the pages, #121).
    function onStart(state as Dictionary?) as Void {
        Numbers.loadShowZero();
        routes = Routes.load();
        last = Routes.last(routes);
        var r = routes.size() > 0 ? Routes.open(routes[last]) : null;
        route = r;
        if (r != null) { Climb.use(r, :ferrata); }
    }

    // Lets go of the GPS.
    function onStop(state as Dictionary?) as Void {
        var v = view;
        if (v != null) { v.stop(); }
    }

    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        var v = new View(routes, last, route);
        route = null;
        view = v;
        return [v, new Delegate(v)];
    }

}
