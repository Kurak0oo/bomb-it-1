"""Report iOS project-export readiness; signing and device installation are external gates."""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess

from run_checks import ROOT, ENGINE_VERSION, build_metadata


def command(*arguments):
    try:
        result = subprocess.run(arguments, capture_output=True, text=True, timeout=30)
        return result.stdout.strip() if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def configuration():
    presets = configparser.ConfigParser(interpolation=None)
    presets.read(ROOT / "godot/export_presets.cfg", encoding="utf-8")
    project = configparser.ConfigParser(interpolation=None)
    project.read_string("[format]\n" + (ROOT / "godot/project.godot").read_text(encoding="utf-8"))
    matches = [name for name in presets.sections() if presets[name].get("platform") == '"iOS"']
    if len(matches) != 1:
        return {"valid": False, "errors": ["Exactly one iOS preset is required"]}
    preset = presets[matches[0]]
    options = presets[matches[0] + ".options"]
    requirements = {"architectures/arm64": "true", "application/export_project_only": "true",
                    "application/targeted_device_family": "0", "application/min_ios_version": '"15.0"',
                    "application/export_method_debug": "1", "application/app_store_team_id": '""',
                    "application/bundle_identifier": '""'}
    errors = [key for key, value in requirements.items() if options.get(key) != value]
    orientation = project.get("display", "window/handheld/orientation", fallback="")
    ticks = project.getint("physics", "common/physics_ticks_per_second", fallback=0)
    if orientation != "4":
        errors.append("sensor_landscape")
    if ticks != 35:
        errors.append("physics_ticks_per_second")
    icon = options.get("icons/icon_1024x1024", "").strip('"')
    if not icon.startswith("res://") or not (ROOT / "godot" / icon.removeprefix("res://")).is_file():
        errors.append("source_icon")
    return {"valid": not errors, "errors": errors, "preset": preset["name"].strip('"'),
            "section": matches[0], "orientation": "both_landscape" if orientation == "4" else orientation,
            "physics_ticks_per_second": ticks, "minimum_ios": options.get("application/min_ios_version", "").strip('"'),
            "icon": icon, "device_family": "iPhone"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--templates", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/ios")
    args = parser.parse_args()
    output = args.output.resolve()
    if output.is_relative_to(ROOT) and not any(output.is_relative_to(ROOT / name) for name in [".artifacts", ".scratch"]):
        parser.error("Use .artifacts, .scratch, or an external output directory")
    output.mkdir(parents=True, exist_ok=True)
    report = {**build_metadata(ROOT / "godot"), "host": platform.system(), "blockers": [],
              "export_performed": False, "signing": "unverified", "device_install": "unverified",
              "identity_validation": "format only; Apple ownership and eligibility unverified",
              "export_preset_sha256": sha256(ROOT / "godot/export_presets.cfg"),
              "preflight_sha256": sha256(Path(__file__))}
    try:
        report["configuration"] = configuration()
    except (OSError, ValueError, KeyError, configparser.Error) as error:
        report["configuration"] = {"valid": False, "errors": [str(error)]}
    if not report["configuration"]["valid"]:
        report["blockers"].append("configuration")
    engine = shutil.which(args.godot)
    report["engine"] = command(engine, "--version") if engine else ""
    if not re.match(re.escape(ENGINE_VERSION) + r"(?:\.|$)", report["engine"]):
        report["blockers"].append("engine")
    template_root = (Path.home() / "Library/Application Support/Godot/export_templates" if platform.system() == "Darwin"
                     else Path(os.environ.get("APPDATA", "")) / "Godot/export_templates")
    templates = args.templates or template_root / f"{ENGINE_VERSION}.stable"
    version = templates / "version.txt"
    report["template_version"] = version.read_text().strip() if version.is_file() else ""
    report["ios_template_sha256"] = sha256(templates / "ios.zip") if (templates / "ios.zip").is_file() else None
    if report["template_version"] != f"{ENGINE_VERSION}.stable" or not (templates / "ios.zip").is_file():
        report["blockers"].append("templates")
    report["team_id_configured"] = bool(re.fullmatch(r"[A-Z0-9]{10}", os.environ.get("BOMB_IT_IOS_TEAM_ID", "")))
    report["bundle_identifier_configured"] = bool(re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", os.environ.get("BOMB_IT_IOS_BUNDLE_ID", "")))
    if not report["team_id_configured"]:
        report["blockers"].append("team_id")
    if not report["bundle_identifier_configured"]:
        report["blockers"].append("bundle_identifier")
    if platform.system() != "Darwin":
        report["blockers"].append("macos_xcode")
    else:
        report["developer_directory"] = command("xcode-select", "-p")
        report["xcode"] = command("xcodebuild", "-version")
        report["iphoneos_sdk"] = command("xcrun", "--sdk", "iphoneos", "--show-sdk-version")
        if not report["developer_directory"].endswith(".app/Contents/Developer") or not report["xcode"] or not report["iphoneos_sdk"]:
            report["blockers"].append("macos_xcode")
    report["status"] = "blocked" if report["blockers"] else "ready_for_project_export"
    (output / "preflight.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    if report["blockers"]:
        parser.exit(2, "iOS project export blocked; see preflight.json. Device acceptance remains unverified.\n")


if __name__ == "__main__":
    main()
