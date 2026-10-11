"""Compare observed original bytecode and rebuild traces without shifting ticks."""
import argparse
import json
from pathlib import Path
import sys


def compare(original, rebuilt):
    if original.get("source") != "original-swf-bytecode" or rebuilt.get("source") != "godot-rebuild":
        raise ValueError("Expected an original-swf-bytecode reference and a godot-rebuild capture")
    differences = []
    first, second = original["scenarios"], rebuilt["scenarios"]
    if not first or set(first) != set(second):
        raise ValueError("Scenario sets must be nonempty and identical")
    for scenario in first:
        expected, actual = first[scenario], second[scenario]
        if not expected or len(expected) != len(actual):
            raise ValueError(f"{scenario}: trace lengths must be nonzero and identical")
        for tick, (left, right) in enumerate(zip(expected, actual)):
            if left.get("tick") != tick or right.get("tick") != tick:
                raise ValueError(f"{scenario}: missing or out-of-order tick {tick}")
            if set(left) != set(right):
                raise ValueError(f"{scenario}: observation fields differ at tick {tick}")
            for field in sorted(left):
                if type(left[field]) != type(right[field]) or left[field] != right[field]:
                    differences.append({"scenario":scenario, "tick":tick, "field":field,
                                        "original":left[field], "rebuilt":right[field]})
    return {"passed": not differences, "original_runtime": original["runtime"],
            "rebuilt_runtime": rebuilt["runtime"], "first_divergence": differences[0] if differences else None,
            "differences":differences}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original", type=Path)
    parser.add_argument("rebuilt", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        report = compare(json.loads(args.original.read_text()), json.loads(args.rebuilt.read_text()))
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"Invalid capture: {error}", file=sys.stderr)
        return 2
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"{'PASS' if report['passed'] else 'DIFFERENT'}: first divergence {report['first_divergence']}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
