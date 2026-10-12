"""Strict contracts for controlled core, motion and interaction observations."""
import hashlib
import json
from pathlib import Path
import re

CONFIGS = {name + "-v1": Path(__file__).resolve().parents[1] / f"godot/tests/fixtures/{name}_scenarios.json" for name in ["core", "motion", "interaction", "order", "expiry", "ai_order", "push", "grenade", "grenadescore", "accounting", "contact", "icewalk", "dispatch"]}


def validate(capture):
    path = CONFIGS[capture["profile"]]
    config = json.loads(path.read_text(encoding="utf-8"))
    for key in ("profile", "fps", "tick_origin"):
        if type(capture.get(key)) is not type(config[key]) or capture[key] != config[key]:
            raise ValueError(f"{capture['profile']}: incompatible {key}")
    if capture.get("configuration_sha256") != hashlib.sha256(path.read_text(encoding="utf-8").encode("utf-8")).hexdigest():
        raise ValueError(f"{capture['profile']}: incompatible configuration")
    if capture["profile"] in ("interaction-v1", "expiry-v1", "push-v1", "grenade-v1", "grenadescore-v1", "accounting-v1", "contact-v1", "icewalk-v1", "dispatch-v1") and capture.get("source") == "original-swf-bytecode":
        if capture.get("execution_scope") != "original-sprite-564-with-root-parent":
            raise ValueError(f"{capture['profile']}: requires original Sprite 564 with real root parent")
        for key in ("original_swf_sha256", "fixture_sha256", "harness_sha256", "builder_sha256", "capture_sha256", "ffdec_sha256", "prelude_sha256"):
            if not isinstance(capture.get(key), str) or not re.fullmatch(r"[0-9a-f]{64}", capture[key]):
                raise ValueError(f"{capture['profile']}: missing or malformed {key} provenance")
        bytecode = capture.get("preserved_bytecode")
        expected = "b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b"
        if not isinstance(bytecode, dict) or bytecode.get("sprite") != 564 or bytecode.get("frame") != 2 or bytecode.get("bytes") != 5624 or bytecode.get("original_sha256") != expected or bytecode.get("preserved_sha256") != expected:
            raise ValueError(f"{capture['profile']}: incompatible original polling bytecode provenance")
    scenarios = capture.get("scenarios")
    if not isinstance(scenarios, dict) or set(scenarios) != {case["name"] for case in config["scenarios"]}:
        raise ValueError(f"{capture['profile']}: missing or unknown scenarios")
    types = {"int": int, "bool": bool, "str": str}
    for case in config["scenarios"]:
        rows = scenarios[case["name"]]
        if not isinstance(rows, list) or len(rows) != len(case["commands"]):
            raise ValueError(f"{case['name']}: incomplete observation count")
        for tick, row in enumerate(rows):
            if not isinstance(row, dict) or set(row) != set(config["fields"]):
                raise ValueError(f"{case['name']}: missing or unexpected observation fields at {tick}")
            for field, kind in config["fields"].items():
                if type(row[field]) is not types[kind]:
                    raise ValueError(f"{case['name']}: invalid {field} type at {tick}")
            if row["tick"] != tick:
                raise ValueError(f"{case['name']}: missing or out-of-order tick {tick}")
            for field, pattern in config.get("serialized_fields", {"bombs": r"(?:\d+,\d+,\d+;)*", "mines": r"(?:\d+,\d+;)*"}).items():
                if not re.fullmatch(pattern, row[field]):
                    raise ValueError(f"{case['name']}: malformed {field} observation at {tick}")
