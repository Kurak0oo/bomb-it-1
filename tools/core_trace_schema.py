"""Strict contracts for controlled core and weapon-motion observations."""
import hashlib
import json
from pathlib import Path
import re

CONFIGS = {name + "-v1": Path(__file__).resolve().parents[1] / f"godot/tests/fixtures/{name}_scenarios.json" for name in ["core", "motion"]}


def validate(capture):
    path = CONFIGS[capture["profile"]]
    config = json.loads(path.read_text(encoding="utf-8"))
    for key in ("profile", "fps", "tick_origin"):
        if type(capture.get(key)) is not type(config[key]) or capture[key] != config[key]:
            raise ValueError(f"{capture['profile']}: incompatible {key}")
    if capture.get("configuration_sha256") != hashlib.sha256(path.read_text(encoding="utf-8").encode("utf-8")).hexdigest():
        raise ValueError(f"{capture['profile']}: incompatible configuration")
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
