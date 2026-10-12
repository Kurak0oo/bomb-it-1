"""Build an unsigned, editor-free Windows x64 release ZIP with provenance."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

from run_checks import ROOT, ENGINE_VERSION, build_metadata


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def run(command, log):
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT, timeout=240)
    text = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", text):
        raise ValueError(f"Build phase failed; see {log}\n{text[-3000:]}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--templates", type=Path, default=Path(os.environ.get("APPDATA", "")) / "Godot/export_templates" / f"{ENGINE_VERSION}.stable")
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/windows-package")
    args = parser.parse_args()
    try:
        executable = shutil.which(args.godot)
        if executable is None:
            raise ValueError("Godot was not found; pass --godot")
        engine = subprocess.run([executable, "--version"], check=True, capture_output=True, text=True, timeout=15).stdout.strip()
        if not re.match(re.escape(ENGINE_VERSION) + r"(?:\.|$)", engine):
            raise ValueError(f"Expected Godot {ENGINE_VERSION}, found {engine}")
        templates = args.templates.resolve()
        if (templates / "version.txt").read_text().strip() != f"{ENGINE_VERSION}.stable":
            raise ValueError("Export templates do not match the pinned engine")
        release = templates / "windows_release_x86_64.exe"
        debug = templates / "windows_debug_x86_64.exe"
        if not release.is_file() or not debug.is_file():
            raise ValueError("Both official Windows x64 templates are required")
        output = args.output.resolve()
        if output.is_relative_to(ROOT) and not any(output.is_relative_to(ROOT / name) for name in [".artifacts", ".scratch"]):
            raise ValueError("Use .artifacts, .scratch, or a directory outside this checkout for generated packages")
        output.mkdir(parents=True, exist_ok=True)
        metadata = build_metadata(ROOT / "godot")
        tree_digest = hashlib.sha256()
        for path in sorted((ROOT / "godot").rglob("*")):
            relative = path.relative_to(ROOT / "godot")
            if path.is_file() and not any(part in [".godot", ".codegraph", "tests"] for part in relative.parts):
                tree_digest.update(relative.as_posix().encode())
                tree_digest.update(path.read_bytes())
        metadata["project_source_sha256"] = tree_digest.hexdigest()
        metadata["source_tree_dirty"] = None
        if metadata["revision"] != "unknown":
            status = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=ROOT,
                                    capture_output=True, text=True, timeout=5)
            if status.returncode == 0:
                metadata["source_tree_dirty"] = bool(status.stdout.strip())
        metadata.update({"engine": engine, "engine_sha256": sha256(Path(executable)),
                         "template_version": f"{ENGINE_VERSION}.stable", "template_sha256": sha256(release),
                         "platform": "Windows", "architecture": "x86_64", "configuration": "release",
                         "export_preset_sha256": sha256(ROOT / "godot/export_presets.cfg"),
                         "packager_sha256": sha256(Path(__file__)),
                         "smoke_driver_sha256": sha256(ROOT / "tools/smoke_windows.py"),
                         "signed": False, "embedded_pck": True})
        with tempfile.TemporaryDirectory(prefix="export-", dir=output) as temporary:
            stage = Path(temporary)
            project = stage / "project"
            shutil.copytree(ROOT / "godot", project, ignore=shutil.ignore_patterns(".godot", ".codegraph", "tests"))
            preset = project / "export_presets.cfg"
            text = preset.read_text(encoding="utf-8")
            for mode, template in [("debug", debug), ("release", release)]:
                text = text.replace(f'custom_template/{mode}=""', f'custom_template/{mode}={json.dumps(template.as_posix())}')
            preset.write_text(text, encoding="utf-8")
            run([executable, "--headless", "--path", str(project), "--editor", "--import", "--quit"], output / "import.log")
            bundle = stage / "bundle"
            bundle.mkdir()
            game = bundle / "BombIt.exe"
            run([executable, "--headless", "--path", str(project), "--export-release", "Windows Desktop", str(game)], output / "export.log")
            with game.open("rb") as stream:
                if stream.read(2) != b"MZ":
                    raise ValueError("Export did not create a Windows executable")
                stream.seek(0x3C)
                stream.seek(struct.unpack("<I", stream.read(4))[0])
                if stream.read(6) != b"PE\0\0\x64\x86":
                    raise ValueError("Export is not a Windows x86_64 executable")
            (bundle / "README.txt").write_text(
                "Bomb It 1 - Windows preservation build\n\n"
                "Extract this folder and launch BombIt.exe. No Godot editor or installer is needed.\n"
                "Windows x64; OpenGL 3.3-capable graphics. This build is unsigned.\n"
                "Use the original menus to choose players, difficulty and characters.\n"
                "1P: arrows or WASD, Space to fire. 2P: P1 WASD/Space, P2 arrows/Enter.\n"
                "Esc pauses, M toggles sound. Preferences are stored under\n"
                "%APPDATA%/Godot/app_userdata/Bomb It 1/preferences.cfg.\n"
                "This portable application still uses per-user preferences, not its package folder.\n"
                f"Revision: {metadata['revision']}\n"
                "See package.json for source, engine, template and executable fingerprints.\n",
                encoding="utf-8")
            metadata["files"] = {p.name: {"sha256": sha256(p), "bytes": p.stat().st_size}
                                 for p in sorted(bundle.iterdir()) if p.is_file()}
            (bundle / "package.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
            archive = output / f"bomb-it-windows-x64-{metadata['revision'][:12]}.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
                for path in sorted(bundle.iterdir()):
                    info = zipfile.ZipInfo(path.name, date_time=(1980, 1, 1, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    info.external_attr = 0o644 << 16
                    package.writestr(info, path.read_bytes(), compresslevel=9)
            report = {**metadata, "artifact": archive.name, "artifact_sha256": sha256(archive), "artifact_bytes": archive.stat().st_size}
            (output / "build.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"WINDOWS_PACKAGE_OK {archive}")
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f"FAIL: {error}\n")


if __name__ == "__main__":
    main()
