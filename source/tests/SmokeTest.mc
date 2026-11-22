import Toybox.Lang;
import Toybox.Test;

// A first test, to prove the harness (#46): the demo route's totals agree with its sections.
(:test)
function climbTotalsAreConsistent(logger as Logger) as Boolean {
    Test.assertEqualMessage(Climb.totalU(), 530, "total ascent");
    Test.assertEqualMessage(Climb.dAt(Climb.count()), Climb.totalD(), "distance at the top");
    return true;
}
