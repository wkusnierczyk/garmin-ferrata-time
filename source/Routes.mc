using Toybox.Application;
using Toybox.WatchUi;

import Toybox.Lang;

// A route on the watch as the route list (F0, #141) needs it: its id, its name and the resource it is
// read from (null for one the app was given already read, a test's). The route itself is read only
// when it is climbed (Routes.open), so the list does not grow with the routes on the watch.
class RouteEntry {

    var id as String;
    var name as String;
    var res as ResourceId?;

    function initialize(i as String, n as String, r as ResourceId?) {
        id = i;
        name = n;
        res = r;
    }
}

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

    function load() as Array<RouteEntry> { return entriesOf(bundled()); }

    // The routes in these resources the app can read, in their order: each read and checked
    // (Route.fromJson), one at a time, and only its id and name kept; one it cannot read is left out.
    function entriesOf(list as Array<ResourceId>) as Array<RouteEntry> {
        var out = [] as Array<RouteEntry>;
        for (var i = 0; i < list.size(); i++) {
            var r = Route.fromJson(WatchUi.loadResource(list[i]) as Dictionary);
            if (r != null) { out.add(new RouteEntry(r.id, r.name, list[i])); }
        }
        return out;
    }

    // An entry for a route already read.
    function entry(r as Route) as RouteEntry { return new RouteEntry(r.id, r.name, null); }

    // The route of an entry, read from its resource; null without one, or when it cannot be read.
    function open(e as RouteEntry) as Route? {
        var res = e.res;
        if (res == null) { return null; }
        return Route.fromJson(WatchUi.loadResource(res) as Dictionary);
    }

    // Which of the routes was used last: its index, or 0 when none was, or it is no longer on the watch.
    function last(routes as Array<RouteEntry>) as Number {
        var id = Application.Storage.getValue(LAST);
        if (!(id instanceof String)) { return 0; }
        for (var i = 0; i < routes.size(); i++) {
            if (routes[i].id.equals(id)) { return i; }
        }
        return 0;
    }

    // Written only when it changed. A storage that cannot take it (full) is no reason to stop the
    // climb: the route is then not remembered.
    function remember(id as String) as Void {
        try {
            if (id.equals(Application.Storage.getValue(LAST) as Object?)) { return; }
            Application.Storage.setValue(LAST, id);
        } catch (e) {
        }
    }
}
