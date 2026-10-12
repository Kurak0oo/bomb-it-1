import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[2]


class PackageCommands(unittest.TestCase):
    def verify(self, configuration="release", corrupt=False):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / "fixture.zip"
            files = {"BombIt.exe": b"integrity fixture, never executed", "README.txt": b"fixture"}
            metadata = {"configuration": configuration, "platform": "Windows", "architecture": "x86_64",
                        "files": {name: {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}
                                  for name, data in files.items()}}
            with zipfile.ZipFile(package, "w") as archive:
                for name, data in files.items():
                    archive.writestr(name, data + b"changed" if corrupt and name == "BombIt.exe" else data)
                archive.writestr("package.json", json.dumps(metadata))
            return subprocess.run([sys.executable, str(ROOT / "tools/smoke_windows.py"), str(package), "--verify-only"],
                                  capture_output=True, text=True, timeout=10)

    def test_archive_integrity_and_changed_executable(self):
        valid = self.verify()
        self.assertEqual(valid.returncode, 0, valid.stderr)
        self.assertIn("integrity only; no launch", valid.stdout)
        changed = self.verify(corrupt=True)
        self.assertNotEqual(changed.returncode, 0)
        self.assertIn("checksum mismatch", changed.stderr)

    def test_debug_package_cannot_be_verified_as_release(self):
        result = self.verify(configuration="debug")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release", result.stderr)

    def test_export_rejects_an_unpinned_engine(self):
        result = subprocess.run([sys.executable, str(ROOT / "tools/package_windows.py"), "--godot", sys.executable],
                                capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Expected Godot 4.7.2", result.stderr)


if __name__ == "__main__":
    unittest.main()
