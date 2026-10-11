"""Run original SWF bytecode and rebuilt fixtures, retaining parity differences as evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ENGINE_VERSION, ROOT, run_phase


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffdec", type=Path, default=os.environ.get("FFDEC_HOME"), required=not os.environ.get("FFDEC_HOME"))
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/reference")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--require-parity", action="store_true", help="Fail on observed differences as well as harness errors")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["BOMB_IT_QA_DIR"] = str(output / "rebuilt/death")
    phases = []
    try:
        godot = shutil.which(args.godot)
        if godot is None:
            raise ValueError("Godot not found")
        version = subprocess.run([godot, "--version"], capture_output=True, text=True,
                                 timeout=args.timeout, check=True).stdout.strip()
        if not version.startswith(ENGINE_VERSION + "."):
            raise ValueError(f"Expected Godot {ENGINE_VERSION}, found {version}")
        classpath = os.pathsep.join([str(args.ffdec / "ffdec.jar"), str(args.ffdec / "lib/*")])
        commands = [
            ("fixture", ["java", "--class-path", classpath, str(ROOT / "tools/reference/BuildReference.java"),
                         str(ROOT / "Bomb It 1.swf"), str(output / "fixture.swf"), str(ROOT / "tools/reference/scenario.as")], "Preserved"),
            ("original", ["node", str(ROOT / "tools/reference/capture.mjs"), str(output / "fixture.swf"), str(output / "original")], "Captured original"),
            ("import", [godot, "--headless", "--path", str(ROOT / "godot"), "--editor", "--import", "--quit"], None),
            ("rebuilt", [godot, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy", "--script", "res://tests/reference_capture.gd"], "REFERENCE_CAPTURE_OK")]
        for name, command, marker in commands:
            phase = run_phase(name, command, output, args.timeout, env, marker)
            phases.append(phase)
            if not phase["passed"]:
                return 2
        original = output / "original/trace.json"
        data = json.loads(original.read_text())
        data["original_swf_sha256"] = hashlib.sha256((ROOT / "Bomb It 1.swf").read_bytes()).hexdigest()
        data["harness_sha256"] = hashlib.sha256((ROOT / "tools/reference/scenario.as").read_bytes()).hexdigest()
        data["builder_sha256"] = hashlib.sha256((ROOT / "tools/reference/BuildReference.java").read_bytes()).hexdigest()
        data["capture_sha256"] = hashlib.sha256((ROOT / "tools/reference/capture.mjs").read_bytes()).hexdigest()
        data["ffdec_sha256"] = hashlib.sha256((args.ffdec / "ffdec.jar").read_bytes()).hexdigest()
        original.write_text(json.dumps(data, indent=2), encoding="utf-8")
        codes = []
        for script, operands in [
            ("compare_traces.py", [str(original), str(output / "rebuilt/trace.json"), "--output", str(output / "trace-comparison.json")]),
            ("compare_images.py", [str(output / "original/death"), str(output / "rebuilt/death"), "--output", str(output / "death-comparison")])]:
            result = subprocess.run([sys.executable, str(ROOT / "tools" / script)] + operands, timeout=args.timeout, check=False)
            codes.append(result.returncode)
        if any(code not in [0,1] for code in codes):
            return 2
        images = json.loads((output / "death-comparison/report.json").read_text())
        if len(images["images"]) != 36 or any("error" in row for row in images["images"]):
            raise ValueError("Incomplete or incompatible reference images")
        print("Reference capture complete. Differences are diagnostic; gameplay was not changed.")
        return 1 if args.require_parity and any(codes) else 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Reference harness failed: {error}", file=sys.stderr)
        return 2
    finally:
        (output / "phases.json").write_text(json.dumps(phases, indent=2), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
