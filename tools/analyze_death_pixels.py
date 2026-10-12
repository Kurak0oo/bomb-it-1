"""Map actual full-image differences to independently observed component differences."""
import argparse
import json
from pathlib import Path
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("before", type=Path)
parser.add_argument("after", type=Path)
parser.add_argument("controls", type=Path)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
before = {r["name"]: r for r in json.loads((args.before / "death-comparison/report.json").read_text())["images"]}
after = json.loads((args.after / "death-comparison/report.json").read_text())
parts = ["body", "burst", "silhouette", "eyes", "shadow", "smoke", "eyes-black", "smoke-black", "burst-black"]

def pixels(path):
    return list(Image.open(path).convert("RGB").getdata())

rows = []
for sample in after["images"]:
    name = sample["name"]
    original = pixels(args.after / "original/death" / name)
    rebuilt = pixels(args.after / "rebuilt/death" / name)
    changed = {i for i,(a,b) in enumerate(zip(original,rebuilt)) if a != b}
    covered = set()
    components = {}
    overlap_inputs = {}
    for part in parts:
        source = pixels(args.controls / part / "original/death" / name)
        port = pixels(args.controls / part / "rebuilt/death" / name)
        if part in ["eyes-black", "eyes", "silhouette", "shadow"]:
            overlap_inputs[part] = (source, port)
        difference = {i for i,(a,b) in enumerate(zip(source,port)) if a != b}
        relevant = changed & difference
        if relevant:
            components[part] = {"component_changed_pixels":len(difference), "full_difference_pixels_at_same_coordinates":len(relevant)}
        covered |= relevant
    rows.append({
        "name":name,
        "before_changed_pixels":before.get(name,{}).get("changed_pixels"),
        "after_changed_pixels":len(changed),
        "component_evidence":components,
        "covered_pixels":len(covered),
        "remaining_composite_pixels":[{"x":i%550,"y":i//550,"original":original[i],"rebuilt":rebuilt[i],
            "eyes_over_black": [p[i] for p in overlap_inputs["eyes-black"]],
            "eyes_over_white": [p[i] for p in overlap_inputs["eyes"]],
            "shadow_over_white": [p[i] for p in overlap_inputs["shadow"]],
            "silhouette_over_white": [p[i] for p in overlap_inputs["silhouette"]]} for i in sorted(changed-covered)],
    })
args.output.write_text(json.dumps({"tolerance":0,"images":rows},indent=2))
print("Retained actual before/after counts and component attribution:",args.output)
print("Remaining composite pixels:",sum(len(r["remaining_composite_pixels"]) for r in rows))
