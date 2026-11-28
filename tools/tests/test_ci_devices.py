"""Tests for tools/ci-devices.py: CI's build set, one product per deviceFamily (#11)."""
import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("ci_devices", REPO / "tools" / "ci-devices.py")
ci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ci)


def definitions(tmp_path, families, root=None):
    """A device definitions directory: each product's compiler.json with its deviceFamily and, given
    as (family, [versions]), its partNumbers' connectIQVersions."""
    root = root or tmp_path / "Devices"
    for product, family in families.items():
        family, versions = family if isinstance(family, tuple) else (family, ["6.0.0"])
        (root / product).mkdir(parents=True)
        (root / product / "compiler.json").write_text(json.dumps(
            {"deviceFamily": family, "partNumbers": [{"connectIQVersion": v} for v in versions]}))
    return root


def manifest(tmp_path, ids):
    p = tmp_path / "manifest.xml"
    p.write_text("<iq:products>" + "".join(f'<iq:product id="{i}"/>' for i in ids) + "</iq:products>")
    return p


def test_the_repository_manifest_names_its_products():
    ids = ci.products(REPO / "manifest.xml")
    assert len(ids) == len(set(ids)) > 0
    assert "epix2pro47mm" in ids


def test_one_product_per_family_the_alphabetically_first_on_one_version(tmp_path):
    root = definitions(tmp_path, {"fr965": "round-454x454", "epix2pro51mm": "round-454x454",
                                  "enduro3": "round-280x280", "venu3s": "round-390x390"})
    ids = ci.products(manifest(tmp_path, ["fr965", "venu3s", "epix2pro51mm", "enduro3"]))
    assert ci.build_set(str(root), ids) == [("round-280x280", "enduro3"),
                                             ("round-390x390", "venu3s"),
                                             ("round-454x454", "epix2pro51mm")]


def test_the_lowest_connect_iq_version_represents_its_family(tmp_path):
    # venu2s's lowest part number is 5.0.0; fr165 is alphabetically first but 5.1.0 throughout.
    root = definitions(tmp_path, {"fr165": ("round-360x360", ["5.1.0"]),
                                  "venu2s": ("round-360x360", ["5.2.0", "5.0.0"]),
                                  "fr265s": ("round-360x360", ["5.0.1"]),
                                  "venu3": ("round-454x454", ["5.0.10"]),
                                  "fr965": ("round-454x454", ["5.0.9"])})
    assert ci.build_set(str(root), ["fr165", "venu2s", "fr265s", "venu3", "fr965"]) == [
        ("round-360x360", "venu2s"), ("round-454x454", "fr965")]


def test_a_tie_on_the_lowest_version_goes_to_the_alphabetically_first(tmp_path):
    root = definitions(tmp_path, {"venu2plus": ("round-416x416", ["5.0.0"]),
                                  "d2airx10": ("round-416x416", ["5.0.0", "5.2.0"]),
                                  "approachs7243mm": ("round-416x416", ["5.1.0"])})
    assert ci.build_set(str(root), ["venu2plus", "d2airx10", "approachs7243mm"]) == [
        ("round-416x416", "d2airx10")]


def test_a_commented_out_product_is_not_a_product(tmp_path):
    p = tmp_path / "manifest.xml"
    p.write_text('<iq:products><iq:product id="fr965"/>\n<!-- <iq:product id="vivoactive5"/> -->\n'
                 '<!--\n<iq:product id="fr70"/>\n--><iq:product id="venu3"/></iq:products>')
    assert ci.products(p) == ["fr965", "venu3"]


def test_a_product_with_no_definition_fails_and_is_named(tmp_path):
    root = definitions(tmp_path, {"fr965": "round-454x454"})
    with pytest.raises(SystemExit) as e:
        ci.build_set(str(root), ["fr965", "fenix8pro47mm", "venu4"])
    assert "fenix8pro47mm, venu4" in str(e.value)


def test_ciq_devices_names_the_directory(tmp_path, monkeypatch):
    root = definitions(tmp_path, {"fr965": "round-454x454"})
    monkeypatch.setenv("CIQ_DEVICES", str(root))
    assert ci.devices_dir() == str(root)


def test_ciq_devices_naming_no_directory_fails(tmp_path, monkeypatch):
    monkeypatch.setenv("CIQ_DEVICES", str(tmp_path / "absent"))
    with pytest.raises(SystemExit):
        ci.devices_dir()


def test_without_ciq_devices_linux_definitions_are_found_under_home(tmp_path, monkeypatch):
    linux = tmp_path / ".Garmin" / "ConnectIQ" / "Devices"
    definitions(tmp_path, {"fr965": "round-454x454"}, root=linux)
    monkeypatch.delenv("CIQ_DEVICES", raising=False)
    monkeypatch.setenv("HOME", str(tmp_path))
    assert ci.devices_dir() == str(linux)


def test_without_ciq_devices_macos_definitions_come_before_linux(tmp_path, monkeypatch):
    macos = tmp_path / "Library" / "Application Support" / "Garmin" / "ConnectIQ" / "Devices"
    linux = tmp_path / ".Garmin" / "ConnectIQ" / "Devices"
    definitions(tmp_path, {"fr965": "round-454x454"}, root=macos)
    definitions(tmp_path, {"fr965": "round-454x454"}, root=linux)
    monkeypatch.delenv("CIQ_DEVICES", raising=False)
    monkeypatch.setenv("HOME", str(tmp_path))
    assert ci.devices_dir() == str(macos)


def run(tmp_path, *args):
    env = dict(os.environ, CIQ_DEVICES=str(tmp_path / "Devices"))
    return subprocess.run([sys.executable, str(REPO / "tools" / "ci-devices.py"), *args],
                          capture_output=True, text=True, env=env)


def test_the_script_prints_family_and_product_per_line(tmp_path):
    definitions(tmp_path, {"fr965": "round-454x454", "enduro3": "round-280x280"})
    result = run(tmp_path, str(manifest(tmp_path, ["fr965", "enduro3"])))
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["round-280x280 enduro3", "round-454x454 fr965"]


def test_the_script_takes_at_most_one_argument(tmp_path):
    definitions(tmp_path, {"fr965": "round-454x454"})
    m = str(manifest(tmp_path, ["fr965"]))
    result = run(tmp_path, m, m)
    assert result.returncode != 0
    assert result.stdout == ""
