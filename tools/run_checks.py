"""Reproducible entry point for local and CI validation (Python standard library)."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]
SUITES = ("sim", "actors", "view", "timeline", "campaign", "special", "soak")
ENGINE_VERSION = (ROOT / "tools/godot-version.txt").read_text().strip()


def run_phase(name, command, output, timeout, env, marker=None):
    started = time.monotonic()
    log = output / f"{name}.log"
    timed_out = False
    with log.open("w", encoding="utf-8") as stream:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=stream,
                                   stderr=subprocess.STDOUT, start_new_session=os.name != "nt")
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                               capture_output=True, check=False)
            else:
                import signal
                os.killpg(process.pid, signal.SIGKILL)
            process.wait()
            code = -1
    text = log.read_text(encoding="utf-8", errors="replace")
    errors = bool(re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:|FAIL:)", text))
    passed = not timed_out and code == 0 and not errors and (marker is None or marker in text)
    result = {"name": name, "passed": passed, "exit_code": code, "timeout": timed_out,
              "seconds": round(time.monotonic() - started, 3), "log": str(log)}
    print(f"{'PASS' if passed else 'FAIL'} {name} ({result['seconds']}s): {log}", flush=True)
    if not passed:
        print(text[-6000:])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--visual", action="store_true")
    parser.add_argument("--suite", choices=SUITES + ("tooling",), action="append", help="Run selected suites after import")
    parser.add_argument("--timeout", type=float, default=120, help="Seconds allowed per phase")
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/checks")
    parser.add_argument("--compare-baselines", type=Path)
    parser.add_argument("--project", type=Path, default=ROOT / "godot", help="Project checkout to import and validate")
    args = parser.parse_args()
    if args.timeout <= 0 or (args.compare_baselines and not args.visual):
        parser.error("timeout must be positive; baseline comparison requires --visual")
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    executable = shutil.which(args.godot)
    if executable is None:
        parser.error(f"Godot not found: {args.godot}. Set GODOT or pass --godot.")
    env = os.environ.copy()
    captures = output / "captures" / uuid.uuid4().hex[:12]
    env["BOMB_IT_QA_DIR"] = str(captures)
    # Isolate Godot's user:// data from the player's saved preferences.
    env["APPDATA"] = str(output / "user-data")
    env["XDG_DATA_HOME"] = str(output / "user-data")
    results = []
    try:
        version = subprocess.run([executable, "--version"], capture_output=True, text=True,
                                 timeout=args.timeout, check=True).stdout.strip()
        if not re.match(re.escape(ENGINE_VERSION) + r"(?:\.|$)", version):
            raise ValueError(f"Expected Godot {ENGINE_VERSION}, found {version}")
        print(f"Godot {version}", flush=True)
        if not (args.project / "project.godot").is_file():
            raise ValueError(f"No project.godot in {args.project}")
        command = [executable, "--headless", "--path", str(args.project.resolve())]
        phases = [("import", command + ["--editor", "--import", "--quit"], None)]
        if not args.suite or "tooling" in args.suite:
            phases.append(("python_compile", [sys.executable, "-m", "compileall", "-q", "tools"], None))
            phases.append(("tooling", [sys.executable, "-m", "unittest", "discover", "-s", "tools/tests", "-v"], None))
            phases.append(("reference_parse", command + ["--check-only", "--script", "res://tests/reference_capture.gd"], None))
        for suite in args.suite or SUITES:
            if suite == "tooling":
                continue
            phases.append((suite, command + ["--script", f"res://tests/{suite}_check.gd"], suite.upper() + "_OK"))
        if args.visual:
            print(f"Captures: {captures}", flush=True)
            render = [executable, "--path", str(args.project.resolve()), "--resolution", "1100x800", "--audio-driver", "Dummy"]
            phases += [("death_render", render + ["--script", "res://tests/death_render_check.gd"], "DEATH_RENDER_OK"),
                       ("feedback_render", render + ["--script", "res://tests/feedback_render_check.gd"], "FEEDBACK_RENDER_OK"),
                       ("input_render", render + ["--script", "res://tests/input_render_check.gd"], "INPUT_RENDER_OK"),
                       ("menu_render", render + ["--script", "res://tests/menu_render_check.gd"], "MENU_RENDER_OK"),
                       ("ui", render + ["--script", "res://tests/ui_check.gd"], "UI_OK"),
                       ("visual_timelines", render + ["--script", "res://tests/visual_timelines.gd"], "VISUAL_TIMELINES_OK")]
        if args.compare_baselines:
            phases.append(("visual_compare", [sys.executable, str(ROOT / "tools/compare_images.py"),
                           str(args.compare_baselines.resolve()), str(captures),
                           "--output", str(output / "comparison")], None))
        for name, cmd, marker in phases:
            # Only Godot needs a private user:// directory. Changing APPDATA for
            # Python hides packages installed in its normal user site on Windows.
            phase_env = env if cmd[0] == executable else os.environ.copy()
            result = run_phase(name, cmd, output, args.timeout, phase_env, marker)
            results.append(result)
            if not result["passed"]:
                return 1
        return 0
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        results.append({"name": "setup", "passed": False, "error": str(error)})
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    finally:
        (output / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
