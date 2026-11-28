using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

// The routes on the watch (#141): those bundled with the app, in the order the route list (F0) shows
// them, and the last one used, remembered across launches in the app's storage by its id. Ferrata
// bundles the real routes, the Daubenhorn and the Sulzfluh (#55); Ferrata Demo the demo route alone, on
// which its made-up climb was designed (#140), so it opens on the ready screen (F1), as with any one
// route. The routes the companion app sends (#80) join them later.
module Routes {

    // The storage key of the last route used: its id.
    const LAST = "route";

    (:nodemo)
    function bundled() as Array<ResourceId> {
        return [Rez.JsonData.daubenhorn, Rez.JsonData.sulzfluh] as Array<ResourceId>;
    }

    (:demo)
    function bundled() as Array<ResourceId> {
        return [Rez.JsonData.route] as Array<ResourceId>;
    }

    // The bundled routes the app can read, in their order; one it cannot (Route.fromJson) is left out.
    function load() as Array<Route> {
        var ids = bundled(), out = [] as Array<Route>;
        for (var i = 0; i < ids.size(); i++) {
            var r = Route.fromJson(WatchUi.loadResource(ids[i]) as Dictionary);
            if (r != null) { out.add(r); }
        }
        return out;
    }

    // Which of the routes was used last: its index, or 0 when none was, or it is no longer on the watch.
    function last(routes as Array<Route>) as Number {
        var id = Application.Storage.getValue(LAST);
        if (!(id instanceof String)) { return 0; }
        for (var i = 0; i < routes.size(); i++) {
            if (routes[i].id.equals(id)) { return i; }
        }
        return 0;
    }

    function remember(r as Route) as Void {
        Application.Storage.setValue(LAST, r.id);
    }
}
