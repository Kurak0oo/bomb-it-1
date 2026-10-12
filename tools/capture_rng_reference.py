"""Capture original generation random boundaries and replay the port, retaining policy differences."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ROOT, ENGINE_VERSION, run_phase

NAMES = dict(zip(["火箭","地雷","手榴弹","汽弹","冰箭","火焰箭","生命加1","抢手","炸弹糖","盾牌","威力药","飞鞋"],
                 ["rocket","mine","grenade","gas","ice","fire","life","glove","bomb","shield","power","shoe"]))


def parse_original(raw):
    result = {"schema":"rng-v1", "source":raw["source"], "runtime":raw["runtime"], "browser":raw["browser"], "scenarios":{}}
    for name, rows in raw["scenarios"].items():
        data = {"calls":[], "snapshots":{}, "drops":[], "shuffles":[]}
        for line in rows:
            fields = line.split("|")
            if fields[0] == "RNG_CALL":
                phase, order, site, bound, value = fields[1:]
                data["calls"].append({"phase":phase,"order":int(order),"site":site,"bound":int(bound),"result":int(value)})
            elif fields[0] == "RNG_META":
                phase, kind = fields[1:3]
                snapshot = {"scene":int(fields[3]),"floor":int(fields[4]),"center":int(fields[5]),
                            "brick_styles":list(map(int,fields[6].split(","))),
                            "rotation":[NAMES[value] for value in fields[7].split(",")],
                            "special_index":int(fields[8]),"music":fields[9].split(","),"music_index":int(fields[10]),
                            "stage":int(fields[11]),"shields":[] if kind=="topology" else list(map(int,fields[12].split(","))),"cells":[]}
                data["snapshots"][phase+"/"+kind] = snapshot
            elif fields[0] == "RNG_CELL":
                phase, kind = fields[1:3]
                data["snapshots"][phase+"/"+kind]["cells"].append(list(map(int,fields[3:])))
            elif fields[0] == "RNG_DROP":
                data["drops"].append({"case":int(fields[1]),"cell":list(map(int,fields[2:4])),"item":NAMES.get(fields[4],fields[4])})
            elif fields[0] == "RNG_SHUFFLE":
                data["shuffles"].append({"case":fields[1],"before":list(map(int,fields[2].split(","))),"after":list(map(int,fields[3].split(",")))})
        if rows[-1] != "RNG_DONE" or len(data["drops"]) != 9 or len(data["snapshots"]) != 9:
            raise ValueError("Incomplete original generation observations")
        if len(data["shuffles"]) != 101 or data["shuffles"][0]["case"] != "boundary":
            raise ValueError("Missing source shuffle controls")
        for index, call in enumerate(data["calls"]):
            if call["order"] != index or call["bound"] <= 0 or not 0 <= call["result"] < call["bound"]:
                raise ValueError("Invalid original random stream")
        for snapshot in data["snapshots"].values():
            if [(row[0],row[1]) for row in snapshot["cells"]] != [(x,y) for y in range(13) for x in range(15)]:
                raise ValueError("Incomplete board observation")
        result["scenarios"][name] = data
    if set(result["scenarios"]) != set(map(str,range(5))):
        raise ValueError("Missing theme")
    return result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffdec",type=Path,required=True)
    parser.add_argument("--godot",default=os.environ.get("GODOT","godot"))
    parser.add_argument("--output",type=Path,default=ROOT/".artifacts/rng-reference")
    args=parser.parse_args()
    output=args.output.resolve(); output.mkdir(parents=True,exist_ok=True)
    env=os.environ.copy()
    env["APPDATA"]=str(output/"user-data");env["XDG_DATA_HOME"]=str(output/"user-data")
    env["BOMB_IT_RNG_REFERENCE"]=str(output/"original.json")
    env["BOMB_IT_RNG_REBUILT"]=str(output/"rebuilt.json")
    phases=[]
    try:
        engine=shutil.which(args.godot)
        if not engine: raise ValueError("Godot not found")
        version=subprocess.run([engine,"--version"],capture_output=True,text=True,check=True,timeout=15).stdout.strip()
        if not version.startswith(ENGINE_VERSION+"."): raise ValueError("Expected pinned Godot "+ENGINE_VERSION)
        classpath=os.pathsep.join([str(args.ffdec/"ffdec.jar"),str(args.ffdec/"lib/*")])
        commands=[("fixture",["java","--class-path",classpath,str(ROOT/"tools/reference/BuildRngReference.java"),str(ROOT/"Bomb It 1.swf"),str(output/"fixture.swf"),str(ROOT/"tools/reference/rng_scenario.as")],"RNG_REFERENCE_BUILT"),
                  ("original",["node",str(ROOT/"tools/reference/capture_rng.mjs"),str(output/"fixture.swf"),str(output/"original")],"RNG_ORIGINAL_CAPTURE_OK")]
        for name,command,marker in commands:
            phases.append(run_phase(name,command,output,120,env,marker))
            if not phases[-1]["passed"]: return 2
        data=parse_original(json.loads((output/"original/raw.json").read_text(encoding="utf-8")))
        data["bytecode_adapter"]=json.loads((output/"fixture.swf.random.json").read_text())
        data["provenance"]={str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else path.name:hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in [ROOT/"Bomb It 1.swf",ROOT/"tools/reference/BuildRngReference.java",ROOT/"tools/reference/rng_scenario.as",ROOT/"tools/reference/capture_rng.mjs",output/"fixture.swf",args.ffdec/"ffdec.jar"]}
        (output/"original.json").write_text(json.dumps(data,separators=(",",":")),encoding="utf-8")
        for name,command,marker in [("import",[engine,"--headless","--path",str(ROOT/"godot"),"--editor","--import","--quit"],None),
                                    ("rebuilt",[engine,"--headless","--path",str(ROOT/"godot"),"--script","res://tests/rng_reference_capture.gd"],"RNG_REFERENCE_CAPTURE_OK")]:
            phases.append(run_phase(name,command,output,120,env,marker))
            if not phases[-1]["passed"]: return 2
        return subprocess.run([sys.executable,str(ROOT/"tools/compare_rng.py"),str(output/"original.json"),str(output/"rebuilt.json"),"--output",str(output/"comparison.json")],check=False,timeout=30).returncode
    except (OSError,ValueError,subprocess.SubprocessError) as error:
        print(f"FAIL: {error}",file=sys.stderr);return 2
    finally:
        (output/"phases.json").write_text(json.dumps(phases,indent=2),encoding="utf-8")


if __name__=="__main__":
    sys.exit(main())
