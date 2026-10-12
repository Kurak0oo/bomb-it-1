"""Verify and smoke-test the actual portable release with isolated preferences."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / ".artifacts/windows-smoke")
    parser.add_argument("--verify-only", action="store_true", help="Check archive integrity without launching code")
    parser.add_argument("--timeout", type=float, default=45)
    args = parser.parse_args()
    try:
        with zipfile.ZipFile(args.package) as archive:
            if len(archive.namelist()) != 3 or set(archive.namelist()) != {"BombIt.exe", "README.txt", "package.json"}:
                raise ValueError("Unexpected portable package files")
            metadata = json.loads(archive.read("package.json"))
            if (metadata.get("configuration"), metadata.get("platform"), metadata.get("architecture")) != ("release", "Windows", "x86_64"):
                raise ValueError("Expected a Windows x86_64 release package")
            if set(metadata["files"]) != {"BombIt.exe", "README.txt"}:
                raise ValueError("Incomplete package file manifest")
            for name, expected in metadata["files"].items():
                data = archive.read(name)
                if len(data) != expected["bytes"] or hashlib.sha256(data).hexdigest() != expected["sha256"]:
                    raise ValueError(f"Package checksum mismatch: {name}")
            if args.verify_only:
                print("WINDOWS_PACKAGE_VERIFIED (integrity only; no launch)")
                return
            if os.name != "nt":
                raise ValueError("Executable smoke requires Windows; --verify-only is portable")
            output = args.output.resolve() / uuid.uuid4().hex[:12]
            bundle = output / "application"
            bundle.mkdir(parents=True)
            archive.extractall(bundle)  # Exact allowlist above prevents path traversal.
        env = os.environ.copy()
        user_root = output / "user-data"
        env["APPDATA"] = str(user_root)
        env["XDG_DATA_HOME"] = str(user_root)
        env["BOMB_IT_SMOKE_USER_ROOT"] = str(user_root)
        env["BOMB_IT_SMOKE_OUTPUT"] = str(output)
        reports = []
        for phase in ["play", "reload"]:
            log = output / f"{phase}.log"
            command = [str(bundle / "BombIt.exe"), "--audio-driver", "Dummy", "--log-file", str(log)]
            env["BOMB_IT_SMOKE_PHASE"] = phase
            command += ["--", "--package-smoke"]
            with (output / f"{phase}-stdout.log").open("w", encoding="utf-8") as stream:
                result = subprocess.run(command, cwd=bundle, env=env, stdout=stream,
                                        stderr=subprocess.STDOUT, timeout=args.timeout)
            text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else ""
            text += (output / f"{phase}-stdout.log").read_text(encoding="utf-8", errors="replace")
            if result.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:|FAIL:)", text):
                raise ValueError(f"Exported {phase} launch failed; see {output}")
            report = json.loads((output / f"{phase}.json").read_text(encoding="utf-8"))
            if not report["passed"] or report["editor"] or report["debug_build"]:
                raise ValueError(f"Exported {phase} smoke failed: {report}")
            reports.append(report)
        artifact_sha = hashlib.sha256(args.package.read_bytes()).hexdigest()
        summary = {"passed": True, "package_sha256": artifact_sha, "package": metadata,
                   "normal_title_route_then_opt_in_smoke": True, "reports": reports,
                   "boundary": "Same release executable, real rendered input and automatic 35 Hz updates; isolated preferences, two smoke processes"}
        (output / "smoke.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"WINDOWS_SMOKE_OK {output}")
    except (OSError, ValueError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        parser.exit(1, f"FAIL: {error}\n")


if __name__ == "__main__":
    main()
