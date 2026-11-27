"""Tests for tools/check-manifests.py: the two apps' manifests agree but for the id and name (#140)."""
import importlib.util
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("check_manifests", REPO / "tools" / "check-manifests.py")
check = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(check)

APP = (REPO / "manifest.xml").read_text()
DEMO = (REPO / "manifest-demo.xml").read_text()


def write(tmp_path, text):
    p = tmp_path / "manifest-demo.xml"
    p.write_text(text)
    return p


def test_the_repository_manifests_agree():
    assert check.differences(REPO / "manifest.xml", REPO / "manifest-demo.xml") == []


@pytest.mark.parametrize("change, expect", [
    (lambda t: t.replace('<iq:product id="venu3"/>', ""), "products only in the app: ['venu3']"),
    (lambda t: t.replace('<iq:uses-permission id="Sensor"/>', ""), "permissions"),
    (lambda t: t.replace('version="0.1.0"', 'version="0.1.1"'), "version"),
    (lambda t: t.replace("63bb9612-97e7-4341-bce5-d32228087caa", "d05650dc-a1c7-46a5-9055-4e98ac0e00d1"), "the same id"),
    (lambda t: t.replace("@Strings.DemoAppName", "@Strings.AppName"), "the same name"),
])
def test_each_difference_is_found(tmp_path, change, expect):
    changed = change(DEMO)
    assert changed != DEMO
    found = check.differences(REPO / "manifest.xml", write(tmp_path, changed))
    assert any(expect in f for f in found), found


def test_main_exits_1_on_a_difference(tmp_path, capsys):
    demo = write(tmp_path, DEMO.replace('<iq:product id="venu3"/>', ""))
    assert check.main(["check-manifests.py", str(REPO / "manifest.xml"), str(demo)]) == 1
    assert "venu3" in capsys.readouterr().err
