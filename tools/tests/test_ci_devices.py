"""Tests for tools/ci-devices.py: CI's build set, one product per deviceFamily (#11)."""
import importlib.util
import json
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
_spec = importlib.util.spec_from_file_location("ci_devices", REPO / "tools" / "ci-devices.py")
ci = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ci)


def definitions(tmp_path, families):
    """A device definitions directory: each product's compiler.json with its deviceFamily."""
    root = tmp_path / "Devices"
    for product, family in families.items():
        (root / product).mkdir(parents=True)
        (root / product / "compiler.json").write_text(json.dumps({"deviceFamily": family}))
    return root


def manifest(tmp_path, ids):
    p = tmp_path / "manifest.xml"
    p.write_text("<iq:products>" + "".join(f'<iq:product id="{i}"/>' for i in ids) + "</iq:products>")
    return p


def test_the_repository_manifest_names_its_products():
    ids = ci.products(REPO / "manifest.xml")
    assert len(ids) == len(set(ids)) > 0
    assert "epix2pro47mm" in ids


def test_one_product_per_family_the_alphabetically_first(tmp_path):
    root = definitions(tmp_path, {"fr965": "round-454x454", "epix2pro51mm": "round-454x454",
                                  "enduro3": "round-280x280", "venu3s": "round-390x390"})
    ids = ci.products(manifest(tmp_path, ["fr965", "venu3s", "epix2pro51mm", "enduro3"]))
    assert ci.build_set(str(root), ids) == [("round-280x280", "enduro3"),
                                             ("round-390x390", "venu3s"),
                                             ("round-454x454", "epix2pro51mm")]


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
