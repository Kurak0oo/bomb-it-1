"""Run original ordinary effects and rebuilt fixtures, retaining parity differences as evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ENGINE_VERSION, ROOT, run_phase
from compare_traces import compare


def compare_effects(original, rebuilt):
    # Creation is an explicit observation, not an offset applied to later ticks.
    creation = []
    for scenario, rows in original["scenarios"].items():
        actual = rebuilt["scenarios"][scenario]
        if rows[0]["tick"] != -1 or actual[0]["tick"] != -1:
            raise ValueError("Missing literal creation observation")
        if rows[0] != actual[0]:
            creation.append({"scenario": scenario, "tick": -1, "original": rows[0], "rebuilt": actual[0]})
    left = dict(original, scenarios={k:v[1:] for k,v in original["scenarios"].items()})
    right = dict(rebuilt, scenarios={k:v[1:] for k,v in rebuilt["scenarios"].items()})
    report = compare(left, right)
    report["creation_differences"] = creation
    report["passed"] = report["passed"] and not creation
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffdec", type=Path, default=os.environ.get("FFDEC_HOME"), required=not os.environ.get("FFDEC_HOME"))
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/effects-reference")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--require-parity", action="store_true", help="Fail on observed differences as well as harness errors")
    parser.add_argument("--replay", action="store_true", help="Compare independent original drawing replay; requires Rust wasm32-wasip1 target")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["BOMB_IT_QA_DIR"] = str(output / "rebuilt/images")
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
                         str(ROOT / "Bomb It 1.swf"), str(output / "fixture.swf"), str(ROOT / "tools/reference/effects.as")], "Preserved"),
            ("original", ["node", str(ROOT / "tools/reference/capture_effects.mjs"), str(output / "fixture.swf"), str(output / "original")], "Captured original effects"),
            ("import", [godot, "--headless", "--path", str(ROOT / "godot"), "--editor", "--import", "--quit"], None),
            ("rebuilt", [godot, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy", "--script", "res://tests/effects_capture.gd"], "EFFECT_CAPTURE_OK")]
        for name, command, marker in commands:
            phase = run_phase(name, command, output, args.timeout, env, marker)
            phases.append(phase)
            for attempt in range(1, 3):
                if phase["passed"] or name != "original" or "Capture skipped a tick" not in Path(phase["log"]).read_text():
                    break
                # Reject and retain the entire failed attempt; never shift ticks.
                phase = run_phase(f"{name}-restart-{attempt}", command, output, args.timeout, env, marker)
                phases.append(phase)
            if not phase["passed"]:
                return 2
        original = output / "original/trace.json"
        data = json.loads(original.read_text())
        data["original_swf_sha256"] = hashlib.sha256((ROOT / "Bomb It 1.swf").read_bytes()).hexdigest()
        data["harness_sha256"] = hashlib.sha256((ROOT / "tools/reference/effects.as").read_bytes()).hexdigest()
        data["builder_sha256"] = hashlib.sha256((ROOT / "tools/reference/BuildReference.java").read_bytes()).hexdigest()
        data["capture_sha256"] = hashlib.sha256((ROOT / "tools/reference/capture_effects.mjs").read_bytes()).hexdigest()
        data["ffdec_sha256"] = hashlib.sha256((args.ffdec / "ffdec.jar").read_bytes()).hexdigest()
        original.write_text(json.dumps(data, indent=2), encoding="utf-8")
        report = compare_effects(data, json.loads((output / "rebuilt/trace.json").read_text()))
        (output / "trace-comparison.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        codes = [0 if report["passed"] else 1]
        for script, operands in [
            ("compare_images.py", [str(output / "original/images"), str(output / "rebuilt/images"), "--output", str(output / "image-comparison")])]:
            result = subprocess.run([sys.executable, str(ROOT / "tools" / script)] + operands, timeout=args.timeout, check=False)
            codes.append(result.returncode)
        if any(code not in [0,1] for code in codes):
            return 2
        images = json.loads((output / "image-comparison/report.json").read_text())
        if len(images["images"]) != 134 or any("error" in row for row in images["images"]):
            raise ValueError("Incomplete or incompatible reference images")
        if args.replay:
            inputs = output / "controls/inputs"
            target = output / "controls/jpeg-target"
            env["RUSTFLAGS"] = "-C target-feature=+simd128"
            commands = [
                ("source-inputs", ["java", "--class-path", classpath, str(ROOT / "tools/reference/EffectsInputs.java"), str(ROOT / "Bomb It 1.swf"), str(inputs)]),
                ("jpeg-build", ["cargo", "build", "--locked", "--manifest-path", str(ROOT / "tools/reference/jpeg_control/Cargo.toml"), "--target-dir", str(target), "--target", "wasm32-wasip1", "--release"]),
                ("jpeg-decode", ["node", str(ROOT / "tools/reference/run_jpeg_control.mjs"), str(target / "wasm32-wasip1/release/death-jpeg-control.wasm"), str(inputs)]),
                ("source-replay", ["node", str(ROOT / "tools/reference/capture_effects_sampling.mjs"), str(output / "controls/replay"), str(inputs), str(output / "original")]),
                ("source-replay-compare", [sys.executable, str(ROOT / "tools/compare_images.py"), str(output / "original/images"), str(output / "controls/replay/images"), "--output", str(output / "controls/comparison")])]
            for name, command in commands:
                phase = run_phase(name, command, output, args.timeout, env, None)
                phases.append(phase)
                if not phase["passed"]:
                    return 2
            (output / "controls/provenance.json").write_text(json.dumps({
                "source_extractor_sha256": hashlib.sha256((ROOT / "tools/reference/EffectsInputs.java").read_bytes()).hexdigest(),
                "source_replay_sha256": hashlib.sha256((ROOT / "tools/reference/capture_effects_sampling.mjs").read_bytes()).hexdigest(),
                "input_contract": "Original raw bitmap channels, original shape paths and matrices, original-runtime observations. No port images are drawing inputs."
            }, indent=2), encoding="utf-8")
        print("Reference capture complete. Differences are diagnostic; gameplay was not changed.")
        return 1 if args.require_parity and any(codes) else 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Reference harness failed: {error}", file=sys.stderr)
        return 2
    finally:
        (output / "phases.json").write_text(json.dumps(phases, indent=2), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
