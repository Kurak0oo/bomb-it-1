import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class Commands(unittest.TestCase):
    def test_rendered_capture_rejects_unpinned_engine_before_capture(self):
        for command in ["capture_special_effects.py", "capture_death_controls.py"]:
            with self.subTest(command=command), tempfile.TemporaryDirectory(prefix="bomb it engine pin ") as directory:
                output = Path(directory) / "output"
                result = subprocess.run([
                    sys.executable, str(ROOT / "tools" / command),
                    "--godot", sys.executable, "--ffdec", str(Path(directory) / "unused-ffdec"),
                    "--output", str(output)], capture_output=True, text=True, timeout=20)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Expected Godot 4.7.2", result.stderr)
                self.assertFalse(output.exists() and any(output.iterdir()),
                                 "Unsupported engines must not start fixture/browser/import/capture phases")

    def test_symbol_reports_original_removal_script_and_dependencies(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/inspect_symbol.py"),
                                 "237", "--frames", "6", "36", "--json"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["dependencies"], [232, 236])
        self.assertEqual(report["scripts"][-1], {"frame": 36, "source": "this.removeMovieClip();"})
        invalid = subprocess.run([sys.executable, str(ROOT / "tools/inspect_symbol.py"), "999999"],
                                 capture_output=True, text=True)
        self.assertNotEqual(invalid.returncode, 0)
        self.assertIn("Cannot inspect symbol", invalid.stderr)

    def check_runner(self, behavior):
        with tempfile.TemporaryDirectory(prefix="bomb it checks ") as directory:
            root = Path(directory)
            fake = root / "fake.py"
            fake.write_text("import sys,time\n"
                            "if '--version' in sys.argv: print('4.7.2.stable.fixture')\n"
                            "elif '--import' in sys.argv: print('imported')\n"
                            f"else: {behavior}\n", encoding="utf-8")
            if os.name == "nt":
                executable = root / "engine.cmd"
                executable.write_text(f'@"{sys.executable}" "{fake}" %*\n', encoding="utf-8")
            else:
                executable = root / "engine"
                executable.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{fake}" "$@"\n')
                executable.chmod(0o755)
            result = subprocess.run([sys.executable, str(ROOT / "tools/run_checks.py"),
                                     "--godot", str(executable), "--suite", "sim", "--timeout", "2",
                                     "--output", str(root / "output")], capture_output=True, text=True, timeout=20)
            summary = json.loads((root / "output/summary.json").read_text())
            return result, summary

    def test_runner_accepts_source_copy_without_git_metadata_or_binary(self):
        with tempfile.TemporaryDirectory(prefix="bomb it source copy ") as directory:
            root = Path(directory)
            for name in ["tools/run_checks.py", "tools/performance_report.py", "tools/godot-version.txt",
                         "godot/project.godot", "godot/tests/pacing_check.gd", "godot/tests/performance_capture.gd"]:
                destination = root / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / name, destination)
            fake = root / "fake.py"
            fake.write_text("import sys\n"
                            "if '--version' in sys.argv: print('4.7.2.stable.fixture')\n"
                            "else: print('SIM_OK'); print('CORE_REFERENCE_CAPTURE_OK')\n", encoding="utf-8")
            executable = root / ("engine.cmd" if os.name == "nt" else "engine")
            executable.write_text(f'@"{sys.executable}" "{fake}" %*\n' if os.name == "nt" else
                                  f'#!/bin/sh\nexec "{sys.executable}" "{fake}" "$@"\n', encoding="utf-8")
            executable.chmod(0o755)
            for no_git in [False, True]:
                with self.subTest(no_git=no_git):
                    env = os.environ.copy()
                    if no_git:
                        env["PATH"] = str(root)
                    output = root / ("without-git" if no_git else "without-repository")
                    run = subprocess.run([sys.executable, str(root / "tools/run_checks.py"),
                                          "--godot", str(executable), "--suite", "sim", "--output", str(output)],
                                         env=env, capture_output=True, text=True, timeout=20)
                    self.assertEqual(run.returncode, 0, run.stdout + run.stderr)
                    metadata = json.loads((output / "build.json").read_text())
                    self.assertEqual(metadata["revision"], "unknown")
                    for field in ["production_source_sha256", "instrumentation_sha256"]:
                        self.assertRegex(metadata[field], r"^[0-9a-f]{64}$")

    def test_runner_imports_before_selected_suite(self):
        result, summary = self.check_runner("print('SIM_OK'); print('CORE_REFERENCE_CAPTURE_OK')")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([phase["name"] for phase in summary], ["import", "sim", "bomb_expiry", "push_motion"])

    def test_runner_rejects_engine_error_even_with_zero_exit(self):
        result, summary = self.check_runner("print('SCRIPT ERROR: fixture'); print('SIM_OK')")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(summary[-1]["passed"])

    def test_runner_kills_a_stalled_suite(self):
        result, summary = self.check_runner("print('started', flush=True); time.sleep(30)")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(summary[-1]["timeout"])


if __name__ == "__main__":
    unittest.main()
