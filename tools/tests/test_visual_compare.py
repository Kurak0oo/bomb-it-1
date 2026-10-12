import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


class VisualComparison(unittest.TestCase):
    def test_missing_capture_and_empty_sets_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "baseline").mkdir()
            (root / "capture").mkdir()
            command = [sys.executable, str(ROOT / "tools/compare_images.py"), str(root / "baseline"),
                       str(root / "capture"), "--output", str(root / "report")]
            empty = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(empty.returncode, 1)
            Image.new("RGB", (8,8)).save(root / "baseline/screen.png")
            missing = subprocess.run(command, capture_output=True, text=True)
            self.assertEqual(missing.returncode, 1)
            self.assertIn("Missing", (root / "report/report.json").read_text())

    def test_identical_images_pass(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for folder in ["baseline", "capture"]:
                (root / folder).mkdir()
                Image.new("RGB", (8,8), "blue").save(root / folder / "screen.png")
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_images.py"), str(root / "baseline"),
                                  str(root / "capture"), "--output", str(root / "report")], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stdout + run.stderr)

    def test_changed_pixel_fails_and_produces_evidence_without_replacing_baseline(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expected, actual = root / "expected", root / "actual"
            expected.mkdir()
            actual.mkdir()
            Image.new("RGB", (8, 8), "white").save(expected / "screen.png")
            baseline = (expected / "screen.png").read_bytes()
            image = Image.new("RGB", (8, 8), "white")
            image.putpixel((3, 2), (0, 0, 0))
            image.save(actual / "screen.png")
            run = subprocess.run([sys.executable, str(ROOT / "tools/compare_images.py"),
                                  str(expected), str(actual), "--output", str(root / "diff")],
                                 capture_output=True, text=True)
            self.assertEqual(run.returncode, 1, run.stdout + run.stderr)
            report = json.loads((root / "diff/report.json").read_text())
            self.assertEqual(report["images"][0]["changed_pixels"], 1)
            self.assertTrue((root / "diff/screen-diff.png").exists())
            self.assertEqual((expected / "screen.png").read_bytes(), baseline)


if __name__ == "__main__":
    unittest.main()
