using Toybox.WatchUi;

import Toybox.Lang;
import Toybox.Test;

// A first test, to prove the harness (#46): the demo route's totals are the sums of its sections (LEN, UP).
// Counted from the ferrata head since #48: the approach's 120 m and 20 m up are left out.
(:test)
function climbTotalsAreConsistent(logger as Logger) as Boolean {
    Climb.use(Route.fromJson(WatchUi.loadResource(Rez.JsonData.route) as Dictionary) as Route, :ferrata);
    Test.assertEqualMessage(Climb.totalU(), 510, "total ascent");
    Test.assertEqualMessage(Climb.totalD(), 640, "total distance");
    return true;
}
