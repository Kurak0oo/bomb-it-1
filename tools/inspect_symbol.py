"""Inspect a recovered Flash symbol without dumping its drawing geometry."""
import argparse
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {"x": "http://ns.adobe.com/xfl/2008/"}


def inspect(symbol, root):
    path = root / "xfl/Bomb It 1/LIBRARY" / f"Symbol {symbol}.xml"
    doc = ET.parse(path)
    result = {"symbol": symbol, "linkage": doc.getroot().get("linkageIdentifier"),
              "labels": [], "scripts": [], "layers": [], "dependencies": []}
    dependencies = set()
    for layer in doc.findall(".//x:DOMLayer", NS):
        placements = []
        for frame in layer.findall("x:frames/x:DOMFrame", NS):
            number = int(frame.get("index")) + 1
            if frame.get("name"):
                result["labels"].append({"frame": number, "name": frame.get("name")})
            script = frame.find("x:Actionscript/x:script", NS)
            if script is not None:
                result["scripts"].append({"frame": number, "source": script.text.strip()})
            for instance in frame.findall("x:elements/x:DOMSymbolInstance", NS):
                child = int(instance.get("libraryItemName").split()[-1])
                dependencies.add(child)
                matrix = instance.find("x:matrix/x:Matrix", NS)
                color = instance.find("x:color/x:Color", NS)
                placements.append({"frame": number, "duration": int(frame.get("duration", 1)),
                                   "symbol": child, "name": instance.get("name"),
                                   "kind": instance.get("symbolType", "movie clip"),
                                   "matrix": {} if matrix is None else matrix.attrib,
                                   "color": {} if color is None else color.attrib})
        if placements:
            result["layers"].append({"name": layer.get("name"), "placements": placements})
    result["dependencies"] = sorted(dependencies)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("symbol", type=int)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--frames", type=int, nargs="+", help="Only these 1-based frames, including held placements")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        result = inspect(args.symbol, args.root)
    except (OSError, ET.ParseError, ValueError) as error:
        print(f"Cannot inspect symbol {args.symbol}: {error}", file=sys.stderr)
        return 1
    if args.frames:
        for layer in result["layers"]:
            layer["placements"] = [p for p in layer["placements"] if any(
                p["frame"] <= f < p["frame"] + p["duration"] for f in args.frames)]
        for field in ["labels", "scripts"]:
            result[field] = [p for p in result[field] if p["frame"] in args.frames]
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(f"Symbol {args.symbol} ({result['linkage'] or 'no linkage'})")
        print("Dependencies: " + ", ".join(map(str, result["dependencies"])))
        for entry in result["labels"]:
            print(f"Frame {entry['frame']}: label {entry['name']}")
        for entry in result["scripts"]:
            print(f"Frame {entry['frame']}:\n{entry['source']}")
        for layer in result["layers"]:
            print(layer["name"])
            for entry in layer["placements"]:
                print(f"  {entry['frame']}+{entry['duration']}: symbol {entry['symbol']} "
                      f"{entry['name'] or ''} [{entry['kind']}] {entry['matrix']} {entry['color']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
