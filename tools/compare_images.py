"""Compare separate baseline/capture directories; never update baselines implicitly."""
import argparse
import json
from pathlib import Path
import sys

from PIL import Image, ImageChops


def compare(expected, actual, output, tolerance=0, max_changed_fraction=0.0):
    if output == expected or expected in output.parents or output in expected.parents:
        raise ValueError("Comparison output must be separate from the baseline directory")
    output.mkdir(parents=True, exist_ok=True)
    names = sorted({p.name for p in expected.glob("*.png")} | {p.name for p in actual.glob("*.png")})
    rows = []
    for name in names:
        row = {"name": name, "passed": False}
        rows.append(row)
        if not (expected / name).exists() or not (actual / name).exists():
            row["error"] = "Missing baseline or capture"
            continue
        with Image.open(expected / name) as baseline, Image.open(actual / name) as capture:
            if baseline.size != capture.size:
                row["error"] = f"Size mismatch: {baseline.size} != {capture.size}"
                continue
            difference = ImageChops.difference(baseline.convert("RGBA"), capture.convert("RGBA"))
            channels = difference.split()
            maximum = channels[0]
            for channel in channels[1:]:
                maximum = ImageChops.lighter(maximum, channel)
            mask = maximum.point(lambda value: 255 if value > tolerance else 0)
            changed = mask.histogram()[255]
            fraction = changed / (baseline.width * baseline.height)
            row.update(changed_pixels=changed, changed_fraction=fraction,
                       passed=fraction <= max_changed_fraction)
            if changed:
                evidence = Image.new("RGB", (baseline.width * 3, baseline.height))
                evidence.paste(baseline.convert("RGB"), (0, 0))
                evidence.paste(capture.convert("RGB"), (baseline.width, 0))
                evidence.paste(mask.convert("RGB"), (baseline.width * 2, 0))
                evidence.save(output / f"{Path(name).stem}-diff.png")
    report = {"passed": bool(rows) and all(row["passed"] for row in rows),
              "tolerance": tolerance, "max_changed_fraction": max_changed_fraction, "images": rows}
    (output / "report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("capture", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--tolerance", type=int, default=0, help="Allowed per-channel difference (0–255)")
    parser.add_argument("--max-changed-fraction", type=float, default=0.0)
    args = parser.parse_args()
    if not 0 <= args.tolerance <= 255 or not 0 <= args.max_changed_fraction <= 1:
        parser.error("Tolerance must be 0–255 and changed fraction 0–1")
    try:
        report = compare(args.baseline.resolve(), args.capture.resolve(), args.output.resolve(),
                         args.tolerance, args.max_changed_fraction)
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 2
    print(f"{'PASS' if report['passed'] else 'FAIL'}: {len(report['images'])} images; {args.output / 'report.json'}")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
