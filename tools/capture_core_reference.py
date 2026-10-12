"""Observe original polling bytecode and accepted GameState with shared fixed inputs."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ENGINE_VERSION, ROOT, run_phase


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffdec", type=Path, default=os.environ.get("FFDEC_HOME"), required=not os.environ.get("FFDEC_HOME"))
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/core-reference")
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--require-parity", action="store_true", help="Fail on observed differences as well as harness errors")
    parser.add_argument("--profile", choices=["core-v1", "motion-v1", "interaction-v1", "order-v1"], default="core-v1")
    parser.add_argument("--nested", action="store_true", help="Execute preserved callbacks inside original Sprite 564 with a real root parent")
    args = parser.parse_args()
    stem = args.profile.removesuffix("-v1")
    nested = args.nested or stem in ("interaction", "order")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / "rebuilt").mkdir(exist_ok=True)
    env = os.environ.copy()
    env["BOMB_IT_CORE_TRACE"] = str(output / "rebuilt/trace.json")
    phases = []
    try:
        godot = shutil.which(args.godot)
        if godot is None:
            raise ValueError("Godot not found")
        version = subprocess.run([godot, "--version"], capture_output=True, text=True,
                                 timeout=args.timeout, check=True).stdout.strip()
        if not version.startswith(ENGINE_VERSION + "."):
            raise ValueError(f"Expected Godot {ENGINE_VERSION}, found {version}")
        config = json.loads((ROOT / f"godot/tests/fixtures/{stem}_scenarios.json").read_text(encoding="utf-8"))
        # Execute the whole unchanged frame-2 tag on an empty controlled stage.
        # Its original callbacks survive; the fixture installs actors afterward.
        prelude = output / "prelude.as"
        prelude.write_text("var configuration = " + re.sub(r'"([A-Za-z_][A-Za-z_0-9]*)":', r'\1:', json.dumps(config, ensure_ascii=False)) + ";\n" +
            ('scenario=_parent.scenario;\n' if nested else '') +
            'game=this; w=0; h=0; brickStyle=[]; bgMusic_sound=new Sound(this);\n'
            'createEmptyMovieClip("bgArea",1); createEmptyMovieClip("brickArea",2);\n', encoding="utf-8")
        classpath = os.pathsep.join([str(args.ffdec / "ffdec.jar"), str(args.ffdec / "lib/*")])
        commands = [
            ("fixture", ["java", "--class-path", classpath, str(ROOT / "tools/reference/BuildReference.java"),
                         str(ROOT / "Bomb It 1.swf"), str(output / "fixture.swf"), str(ROOT / f"tools/reference/{stem}_scenario.as"), str(prelude)] + (["--nested"] if nested else []), "Preserved complete original frame 2"),
            ("original", ["node", str(ROOT / "tools/reference/capture_core.mjs"), str(output / "fixture.swf"), str(output / "original"), str(ROOT / f"godot/tests/fixtures/{stem}_scenarios.json")], "Captured original"),
            ("import", [godot, "--headless", "--path", str(ROOT / "godot"), "--editor", "--import", "--quit"], None),
            ("rebuilt", [godot, "--headless", "--path", str(ROOT / "godot"), "--script", f"res://tests/{stem}_reference_capture.gd"], "CORE_REFERENCE_CAPTURE_OK")]
        for name, command, marker in commands:
            phase = run_phase(name, command, output, args.timeout, env, marker)
            phases.append(phase)
            if not phase["passed"]:
                return 2
        original = output / "original/trace.json"
        data = json.loads(original.read_text(encoding="utf-8"))
        for label, path in {
            "original_swf": ROOT / "Bomb It 1.swf", "harness": ROOT / f"tools/reference/{stem}_scenario.as",
            "builder": ROOT / "tools/reference/BuildReference.java", "capture": ROOT / "tools/reference/capture_core.mjs",
            "ffdec": args.ffdec / "ffdec.jar", "prelude": prelude,
        }.items():
            data[label + "_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        data["execution_scope"] = "original-sprite-564-with-root-parent" if nested else "controlled-root"
        data["preserved_bytecode"] = json.loads((output / "fixture.swf.bytecode.json").read_text(encoding="utf-8"))
        original.write_text(json.dumps(data, indent=2), encoding="utf-8")
        result = subprocess.run([sys.executable, str(ROOT / "tools/compare_traces.py"), str(original),
                                 str(output / "rebuilt/trace.json"), "--output", str(output / "trace-comparison.json")],
                                timeout=args.timeout, check=False)
        if result.returncode not in (0, 1):
            return 2
        print("Core reference capture complete. Differences are diagnostic; gameplay was not changed.")
        return 1 if args.require_parity and result.returncode else 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Core reference harness failed: {error}", file=sys.stderr)
        return 2
    finally:
        (output / "phases.json").write_text(json.dumps(phases, indent=2), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
