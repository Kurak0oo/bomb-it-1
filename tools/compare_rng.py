"""Compare strict original RNG component replays; report full-session policy differences separately."""
import argparse
import hashlib
import json
import itertools
import math
from pathlib import Path
import sys

PHASES=("initial","retry","stage2","stage3","stage4")
FIELDS=("scene","floor","center","brick_styles","rotation","special_index","stage","shields","cells")
SNAPSHOTS={phase+"/"+kind for phase in PHASES for kind in ("population",) if phase=="retry"} | {phase+"/"+kind for phase in PHASES if phase!="retry" for kind in ("topology","population")}
SOURCE_PHASES=["initial"]+[f"drop-{index}" for index in range(9)]+list(PHASES[1:])+["shuffle-boundary","shuffle-random"]


def require(condition,message):
    if not condition: raise ValueError(message)


def integer(value):
    return type(value) in (int,float) and math.isfinite(value) and int(value)==value


def validate_calls(calls,phases):
    require(isinstance(calls,list) and bool(calls),"Missing random call stream")
    for index,row in enumerate(calls):
        require(all(integer(row.get(key)) for key in ("order","bound","result")),"Invalid random record")
        require(row["order"]==index and row["bound"]>0 and 0<=row["result"]<row["bound"],"Invalid random order/bound/result")
    require([phase for phase,_ in itertools.groupby(row["phase"] for row in calls)]==list(phases),"Incomplete or reordered random phases")


def validate(original,rebuilt):
    require(original["schema"]==rebuilt["schema"]=="rng-v1","Unknown RNG schema")
    adapter=original["bytecode_adapter"]
    require(adapter["sprite"]==564 and adapter["sites"]==27,"Missing original opcode adapter audit")
    require([row["original_sha256"] for row in adapter["frames"]]==[
        "d33fd976a76c1d51d7e31d2ed3c4da5012f5f87191cf605c745c362de152aa22",
        "b68c1872f3a1a9967dee94c3bae9d50ca9c52aab0caa357ea5d78de993e62a9b"],"Original frame bytecode identity changed")
    require(len(original["provenance"])>=6 and all(len(value)==64 and all(c in "0123456789abcdef" for c in value) for value in original["provenance"].values()),"Missing source provenance")
    expected_names=set(map(str,range(5)))
    require(set(original["scenarios"])==set(rebuilt["scenarios"])==expected_names,"All five themes required")
    validate_calls(rebuilt["full_session"],PHASES)
    for name,source in original["scenarios"].items():
        actual=rebuilt["scenarios"][name]
        validate_calls(source["calls"],SOURCE_PHASES)
        replay=actual["replay"]
        require([entry["phase"] for entry in replay]==list(PHASES),"Missing replay completion report")
        for entry in replay:
            require(entry["passed"] is True and entry["error"]=="","Failed strict replay cannot compare successfully")
            calls=[row for row in source["calls"] if row["phase"]==entry["phase"]]
            start=0 if entry["phase"]=="retry" else next(index for index,row in enumerate(calls) if row["site"]=="f1:22882")
            require(entry["calls"]==len(calls)-start,"Extra or unconsumed source generation calls")
        for capture in (source,actual):
            require(set(capture["snapshots"])==SNAPSHOTS,"Missing or extra board observation")
            require([row["case"] for row in capture["drops"]]==list(range(9)),"Missing or extra controlled drop")
            require([row["case"] for row in capture["shuffles"]]==["boundary"]+list(map(str,range(100))),"Missing shuffle control")
            for key,snapshot in capture["snapshots"].items():
                cells=snapshot["cells"]
                require([(row[0],row[1]) for row in cells]==[(x,y) for y in range(13) for x in range(15)],"Incomplete or reordered board cells")
                require(all(len(row)==4 and all(integer(value) for value in row) and 0<=row[2]<=2 and 0<=row[3]<=58 for row in cells),"Invalid board cell")
                require(len(snapshot["shields"])==(0 if key.endswith("topology") else 4),"Missing initial shield observations")


def compare(original,rebuilt):
    if original["schema"]!="rng-v1" or original["source"]!="original-swf-bytecode" or rebuilt["source"]!="godot-replay":
        raise ValueError("Expected original executable capture and Godot replay")
    validate(original,rebuilt)
    report={"components_equal":True,"full_session_equal":True,"snapshots_compared":0,"drops_compared":0,
            "shuffle_controls_compared":0,"differences":[],"session_policy":[],
            "policy":"Components consume recorded original results. Full session is separately observed normal seeded play; Flash PRNG/equal-seed equivalence is not claimed. Source music calls remain in the full stream. Retry discarded setup and fresh per-round seeds remain unchanged."}
    for name,expected in original["scenarios"].items():
        actual=rebuilt["scenarios"][name]
        for key,snapshot in expected["snapshots"].items():
            observed=actual["snapshots"][key]
            for field in FIELDS:
                if snapshot[field]!=observed[field]:
                    report["differences"].append({"theme":name,"snapshot":key,"field":field})
            report["snapshots_compared"]+=1
        for field in ["drops","shuffles"]:
            if expected[field]!=actual[field]:
                report["differences"].append({"theme":name,"field":field})
        report["drops_compared"]+=len(expected["drops"])
        report["shuffle_controls_compared"]+=len(expected["shuffles"])
        for phase in PHASES:
            source=[row for row in expected["calls"] if row["phase"]==phase]
            port=[row for row in rebuilt["full_session"] if row["phase"]==phase]
            bounds=next((index for index,(a,b) in enumerate(zip(source,port)) if a["bound"]!=b["bound"]),None)
            if bounds is None and len(source)!=len(port): bounds=min(len(source),len(port))
            same=[(row["bound"],row["result"]) for row in source]==[(row["bound"],row["result"]) for row in port]
            report["full_session_equal"] &= same
            report["session_policy"].append({"theme":name,"phase":phase,"source_calls":len(source),"rebuilt_calls":len(port),
                "first_bound_divergence":bounds,"original":source[bounds] if bounds is not None and bounds<len(source) else None,
                "rebuilt":port[bounds] if bounds is not None and bounds<len(port) else None,"calls_and_results_equal":same})
    report["components_equal"]=not report["differences"]
    return report


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original",type=Path);parser.add_argument("rebuilt",type=Path)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--require-full-stream",action="store_true")
    args=parser.parse_args()
    try:
        source_bytes=args.original.read_bytes()
        rebuilt=json.loads(args.rebuilt.read_text(encoding="utf-8"))
        require(rebuilt["original_capture_sha256"]==hashlib.sha256(source_bytes).hexdigest(),"Replay was produced from a different original recording")
        report=compare(json.loads(source_bytes),rebuilt)
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(report,indent=2),encoding="utf-8")
        print("RNG_COMPONENTS_OK" if report["components_equal"] else "RNG_COMPONENTS_DIFFER")
        print("Full session streams equal: "+str(report["full_session_equal"]))
        return 0 if report["components_equal"] and (not args.require_full_stream or report["full_session_equal"]) else 1
    except (OSError,ValueError,KeyError,TypeError,IndexError,StopIteration) as error:
        print("FAIL: "+str(error),file=sys.stderr);return 2


if __name__=="__main__":
    sys.exit(main())
