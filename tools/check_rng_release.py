"""Run the public RNG boundary checks in the actual Windows release template (no editor/debug assertions)."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from run_checks import ROOT, ENGINE_VERSION, run_phase


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--templates",type=Path,required=True)
    parser.add_argument("--output",type=Path,default=ROOT/".artifacts/rng-release")
    args=parser.parse_args()
    output=args.output.resolve()
    if os.name!="nt": parser.error("This probe uses the Windows release template")
    version=subprocess.run([args.godot,"--version"],capture_output=True,text=True,check=True,timeout=15).stdout.strip()
    if not version.startswith(ENGINE_VERSION+"."): parser.error("Pinned engine required")
    if output.is_relative_to(ROOT) and not output.is_relative_to(ROOT/".artifacts"): parser.error("Use .artifacts or external output")
    if (args.templates/"version.txt").read_text().strip()!=f"{ENGINE_VERSION}.stable": parser.error("Template version mismatch")
    output.mkdir(parents=True,exist_ok=True)
    env=dict(os.environ,APPDATA=str(output/"user-data"),XDG_DATA_HOME=str(output/"user-data"))
    phases=[]
    with tempfile.TemporaryDirectory(prefix="probe-",dir=output) as temporary:
        project=Path(temporary).resolve()
        if not project.is_relative_to(output): raise ValueError("Probe must stay inside output")
        shutil.copytree(ROOT/"godot/scripts/simulation",project/"simulation")
        checks=(ROOT/"godot/tests/rng_check.gd").read_text(encoding="utf-8")
        checks=checks.replace("extends SceneTree","extends Node").replace("func _init() -> void:",
            'func _ready() -> void:\n\tcheck(not OS.has_feature("editor") and not OS.is_debug_build(),"actual release runtime")').replace("\tquit(","\tget_tree().quit(")
        (project/"probe.gd").write_text(checks,encoding="utf-8")
        (project/"main.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://probe.gd" id="1"]\n[node name="Probe" type="Node"]\nscript=ExtResource("1")\n')
        (project/"project.godot").write_text('config_version=5\n[application]\nconfig/name="BombItRngReleaseProbe"\nrun/main_scene="res://main.tscn"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        preset=(ROOT/"godot/export_presets.cfg").read_text().split("[preset.1]")[0]
        for mode in ["debug","release"]:
            template=(args.templates/f"windows_{mode}_x86_64.exe").resolve()
            if not template.is_file(): parser.error("Windows template missing")
            preset=preset.replace(f'custom_template/{mode}=""',f'custom_template/{mode}={json.dumps(template.as_posix())}')
        (project/"export_presets.cfg").write_text(preset)
        executable=output/"RngReleaseProbe.exe"
        for name,command,marker in [("import",[args.godot,"--headless","--path",str(project),"--editor","--import","--quit"],None),
                ("export",[args.godot,"--headless","--path",str(project),"--export-release","Windows Desktop",str(executable)],None),
                ("release",[str(executable),"--headless","--audio-driver","Dummy"],"RNG_OK")]:
            phases.append(run_phase(name,command,output,120,env,marker))
            if not phases[-1]["passed"]: break
        report={"engine":version,"phases":phases,"passed":len(phases)==3 and all(phase["passed"] for phase in phases),
                "source_sha256":hashlib.sha256((ROOT/"godot/scripts/simulation/original_rng.gd").read_bytes()).hexdigest(),
                "checks_sha256":hashlib.sha256((ROOT/"godot/tests/rng_check.gd").read_bytes()).hexdigest(),
                "template_sha256":hashlib.sha256((args.templates/"windows_release_x86_64.exe").read_bytes()).hexdigest(),
                "executable_sha256":hashlib.sha256(executable.read_bytes()).hexdigest() if executable.is_file() else None,
                "scope":"standalone actual release-runtime RNG checks; not a playable game package or device pass"}
        (output/"report.json").write_text(json.dumps(report,indent=2))
    return 0 if report["passed"] else 1


if __name__=="__main__":
    raise SystemExit(main())
