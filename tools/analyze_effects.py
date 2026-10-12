"""Retain actual per-image deltas and audit ordinary-effect source asset inputs."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET

from run_checks import ROOT


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    reports = {}
    for name, folder in [("before",args.before),("after",args.after)]:
        reports[name] = {r["name"]:r for r in json.loads((folder / "image-comparison/report.json").read_text())["images"]}
    control = {r["name"]:r for r in json.loads((args.after / "controls/comparison/report.json").read_text())["images"]}
    if set(reports["before"]) != set(reports["after"]) or set(control) != set(reports["after"]):
        raise ValueError("Incomplete comparison inputs")
    with (args.output / "actual-counts.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.writer(stream)
        writer.writerow(["image","actual_before_changed_pixels","actual_after_changed_pixels","source_replay_changed_pixels"])
        for name, row in reports["after"].items():
            writer.writerow([name,reports["before"][name]["changed_pixels"],row["changed_pixels"],control[name]["changed_pixels"]])
    art = ROOT / "godot/art/original"
    manifest = json.loads((art / "manifest.json").read_text())
    bounds = json.loads((ROOT / "reference/sprite-bounds.json").read_text())
    audit = {"png_inputs":[],"removal_paths":[]}
    for sid in [248,273,293,371]:
        source = next(p for p in (ROOT / "extracted/all/sprites").iterdir() if int(p.name.split('_')[1]) == sid)
        if manifest[str(sid)]["offset"] != bounds[str(sid)]:
            raise ValueError(f"Changed registration for {sid}")
        for file in sorted((art / str(sid)).glob('*.png')):
            entry = {"symbol":sid,"frame":file.stem,"offset":bounds[str(sid)],"source_sha256":sha(source / file.name),"port_sha256":sha(file)}
            if entry["source_sha256"] != entry["port_sha256"]:
                raise ValueError("Port bitmap differs from recovered original asset")
            audit["png_inputs"].append(entry)
    for variant,sid in enumerate(range(280,286),1):
        source = ROOT / f"extracted/all/shapes/{sid}.svg"
        paths = [p.get('d') for p in ET.parse(source).iter() if p.tag.endswith('path')]
        for file in sorted((art / "pickup_removal" / str(variant)).glob('*.svg')):
            derived = [p.get('d') for p in ET.parse(file).iter() if p.tag.endswith('path')]
            if paths != derived:
                raise ValueError("Recovered removal path geometry changed")
            audit["removal_paths"].append({"variant":variant,"frame":int(file.stem),"source_sha256":sha(source),"derived_sha256":sha(file),"original_paths":len(paths),"alpha":manifest["pickup_removal"][str(variant)]["alphas"][int(file.stem)-1]})
    (args.output / "asset-audit.json").write_text(json.dumps(audit,indent=2),encoding="utf-8")
    print("Audited unchanged original geometry and all actual before/after counts")


if __name__ == "__main__":
    main()
