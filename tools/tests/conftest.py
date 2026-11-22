# The tools are scripts, not a package: put tools/ on the path so the tests can import them.
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
