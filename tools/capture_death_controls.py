"""Isolate original death drawing definitions without replacing their timelines."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ENGINE_VERSION, ROOT, run_phase
from compare_images import compare


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffdec", type=Path, required=True)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--parts", nargs="+", default=["body", "burst", "silhouette", "eyes", "shadow", "smoke", "eyes-black", "smoke-black", "burst-black"])
    parser.add_argument("--replay", action="store_true", help="Independently replay original drawing inputs (requires Rust wasm32-wasip1 target)")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot executable not found")
    try:
        version = subprocess.run([godot, "--version"], capture_output=True, text=True,
                                 timeout=args.timeout, check=True).stdout.strip()
        if not version.startswith(ENGINE_VERSION + "."):
            parser.error(f"Expected Godot {ENGINE_VERSION}, found {version}")
    except (OSError, subprocess.SubprocessError) as error:
        parser.error(f"Cannot verify Godot version: {error}")
    args.godot = godot
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    classpath = os.pathsep.join([str(args.ffdec / "ffdec.jar"), str(args.ffdec / "lib/*")])
    phases = []

    def phase(name, command, marker=None):
        result = run_phase(name, command, output, args.timeout, env, marker)
        phases.append(result)
        # A busy host can miss Ruffle's initial pause barrier. Reject that entire
        # capture and start a fresh browser; retain every failed attempt log.
        for attempt in range(1, 3):
            log = Path(result["log"]).read_text()
            clock_failure = "Capture skipped a tick" in log or "Did not isolate the original creation frame" in log
            if result["passed"] or marker != "Captured original" or not clock_failure:
                break
            result = run_phase(f"{name}-restart-{attempt}", command, output, args.timeout, env, marker)
            phases.append(result)
        if not result["passed"]:
            raise ValueError("Failed control phase " + name)

    try:
        fixture = output / "fixture.swf"
        phase("fixture", ["java", "--class-path", classpath, str(ROOT / "tools/reference/BuildReference.java"),
                          str(ROOT / "Bomb It 1.swf"), str(fixture), str(ROOT / "tools/reference/scenario.as")], "Preserved")
        phase("import", [args.godot, "--headless", "--path", str(ROOT / "godot"), "--editor", "--import", "--quit"])
        for part in args.parts:
            env["BOMB_IT_REFERENCE_BACKGROUND"] = "#000000" if part.endswith("-black") else "#ffffff"
            swf = output / f"{part}.swf"
            phase(part + "-isolate", ["java", "--class-path", classpath, str(ROOT / "tools/reference/IsolateDeath.java"),
                                      str(fixture), str(swf), part], "Kept original")
            phase(part + "-original", ["node", str(ROOT / "tools/reference/capture.mjs"), str(swf), str(output / part / "original")], "Captured original")
            env["BOMB_IT_DEATH_COMPONENT"] = part
            env["BOMB_IT_QA_DIR"] = str(output / part / "rebuilt/death")
            phase(part + "-rebuilt", [args.godot, "--path", str(ROOT / "godot"), "--audio-driver", "Dummy",
                                     "--script", "res://tests/reference_capture.gd"], "REFERENCE_CAPTURE_OK")
            report = compare(output / part / "original/death", output / part / "rebuilt/death", output / part / "comparison")
            if len(report["images"]) != 40 or any("error" in row for row in report["images"]):
                raise ValueError("Malformed component images")
        if args.replay:
            inputs = output / "inputs"
            phase("source-inputs", ["java", "--class-path", classpath, str(ROOT / "tools/reference/DeathInputs.java"), str(ROOT / "Bomb It 1.swf"), str(inputs)], "Extracted original")
            env["RUSTFLAGS"] = "-C target-feature=+simd128"
            target = output / "jpeg-target"
            phase("jpeg-build", ["cargo", "build", "--locked", "--manifest-path", str(ROOT / "tools/reference/jpeg_control/Cargo.toml"), "--target-dir", str(target), "--target", "wasm32-wasip1", "--release"])
            phase("jpeg-decode", ["node", str(ROOT / "tools/reference/run_jpeg_control.mjs"), str(target / "wasm32-wasip1/release/death-jpeg-control.wasm"), str(inputs)])
            phase("source-replay", ["node", str(ROOT / "tools/reference/capture_death_sampling.mjs"), str(output / "replay"), str(inputs)])
            for part in args.parts:
                report = compare(output / part / "original/death", output / "replay" / part, output / "replay" / (part + "-comparison"))
                if not report["passed"]:
                    raise ValueError("Original source-input replay diverged: " + part)
            env["BOMB_IT_REFERENCE_BACKGROUND"] = "#ffffff"
            phase("composite-original", ["node", str(ROOT / "tools/reference/capture.mjs"), str(fixture), str(output / "composite-original")], "Captured original")
            compare(output / "composite-original/death", output / "replay/composite", output / "replay/composite-comparison")
            phase("composite-attribution", [sys.executable, str(ROOT / "tools/analyze_death_composite.py"), str(output)])
        (output / "provenance.json").write_text(json.dumps({
            "original_swf_sha256": hashlib.sha256((ROOT / "Bomb It 1.swf").read_bytes()).hexdigest(),
            "isolation_builder_sha256": hashlib.sha256((ROOT / "tools/reference/IsolateDeath.java").read_bytes()).hexdigest(),
            "control": "Only unrelated drawing definitions are empty; original bytecode, clip timelines, transforms and alpha are retained."
        }, indent=2))
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(error, file=sys.stderr)
        return 2
    finally:
        (output / "phases.json").write_text(json.dumps(phases, indent=2))


if __name__ == "__main__":
    sys.exit(main())
