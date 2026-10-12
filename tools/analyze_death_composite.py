"""Retain every exact composite difference and its independently isolated inputs."""
import json
from pathlib import Path
import sys
from PIL import Image

root = Path(sys.argv[1])
report = json.loads((root / "replay/composite-comparison/report.json").read_text())
records = []
for row in report["images"]:
    if row["passed"]:
        continue
    name = row["name"]
    images = {
        "original": Image.open(root / "composite-original/death" / name).convert("RGB"),
        "replay": Image.open(root / "replay/composite" / name).convert("RGB"),
        "burst": Image.open(root / "burst/original/death" / name).convert("RGB"),
        "silhouette": Image.open(root / "silhouette/original/death" / name).convert("RGB"),
    }
    for y in range(400):
        for x in range(550):
            values = {key: image.getpixel((x, y)) for key, image in images.items()}
            if values["original"] == values["replay"]:
                continue
            values.update(image=name, x=x, y=y)
            records.append(values)
summary = {
    "exact_comparison_passed": report["passed"],
    "tolerance": 0,
    "differing_pixels": len(records),
    "maximum_channel_difference": max((abs(a-b) for row in records for a,b in zip(row["original"],row["replay"])), default=0),
    "all_in_burst_silhouette_overlap": all(row["burst"] != (255,255,255) and row["silhouette"] != (255,255,255) for row in records),
    "pixels": records,
}
(root / "replay/composite-attribution.json").write_text(json.dumps(summary, indent=2))
print(f"Retained {len(records)} exact composite differences; no tolerance or capture changes.")
