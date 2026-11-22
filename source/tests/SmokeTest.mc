import Toybox.Lang;
import Toybox.Test;

// A first test, to prove the harness (#46): the demo route's totals are the sums of its sections (LEN, UP).
(:test)
function climbTotalsAreConsistent(logger as Logger) as Boolean {
    Test.assertEqualMessage(Climb.totalU(), 530, "total ascent");
    Test.assertEqualMessage(Climb.totalD(), 760, "total distance");
    return true;
}
