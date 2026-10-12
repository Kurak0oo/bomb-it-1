"""Compare observed original bytecode and rebuild traces without shifting ticks."""
import argparse
import json
from pathlib import Path
import sys


def compare(original, rebuilt):
    if not isinstance(original, dict) or not isinstance(rebuilt, dict):
        raise ValueError("Captures must be JSON objects")
    if original.get("source") != "original-swf-bytecode" or rebuilt.get("source") != "godot-rebuild":
        raise ValueError("Expected an original-swf-bytecode reference and a godot-rebuild capture")
    for capture in (original, rebuilt):
        if not isinstance(capture.get("runtime"), str) or not capture["runtime"]:
            raise ValueError("Capture runtime is required")
    if any("profile" in capture or "configuration_sha256" in capture for capture in (original, rebuilt)):
        if original.get("profile") not in ("core-v1", "motion-v1", "interaction-v1", "order-v1", "expiry-v1", "ai_order-v1", "push-v1", "grenade-v1", "grenadescore-v1") or original.get("profile") != rebuilt.get("profile"):
            raise ValueError("Unknown or incompatible capture profile")
        from core_trace_schema import validate
        validate(original)
        validate(rebuilt)
    differences = []
    first_by_scenario = {}
    first, second = original["scenarios"], rebuilt["scenarios"]
    if not isinstance(first, dict) or not isinstance(second, dict) or not first or set(first) != set(second):
        raise ValueError("Scenario sets must be nonempty and identical")
    for scenario in first:
        first_by_scenario[scenario] = None
        expected, actual = first[scenario], second[scenario]
        if not isinstance(expected, list) or not isinstance(actual, list) or not expected or len(expected) != len(actual):
            raise ValueError(f"{scenario}: trace lengths must be nonzero and identical")
        for tick, (left, right) in enumerate(zip(expected, actual)):
            if not isinstance(left, dict) or not isinstance(right, dict):
                raise ValueError(f"{scenario}: observations must be objects")
            if type(left.get("tick")) is not int or type(right.get("tick")) is not int or left["tick"] != tick or right["tick"] != tick:
                raise ValueError(f"{scenario}: missing or out-of-order tick {tick}")
            if set(left) != set(right):
                raise ValueError(f"{scenario}: observation fields differ at tick {tick}")
            for field in sorted(left):
                if type(left[field]) != type(right[field]) or left[field] != right[field]:
                    difference = {"scenario":scenario, "tick":tick, "field":field,
                                  "original":left[field], "rebuilt":right[field]}
                    differences.append(difference)
                    if first_by_scenario[scenario] is None:
                        first_by_scenario[scenario] = difference
    return {"passed": not differences, "original_runtime": original["runtime"],
            "rebuilt_runtime": rebuilt["runtime"], "first_divergence": differences[0] if differences else None,
            "scenario_first_divergences":first_by_scenario, "differences":differences}


def load_capture(path):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    def reject_constant(value):
        raise ValueError(f"Non-finite JSON number: {value}")

    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique_object,
                      parse_constant=reject_constant)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("rebuilt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = compare(load_capture(args.original), load_capture(args.rebuilt))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Invalid capture: {error}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"{'PASS' if report['passed'] else 'DIFFERENT'}: first divergence {report['first_divergence']}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
