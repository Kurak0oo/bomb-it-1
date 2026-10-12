"""Summarize engine submissions and injected input; never infer physical presentation."""
import argparse
import json
import math
from pathlib import Path


def distribution(values):
    values = sorted(values)
    if not values:
        return {"samples": 0, "p50_ms": None, "p95_ms": None, "p99_ms": None, "max_ms": None}
    return {"samples": len(values), **{
        f"p{percent}_ms": values[math.ceil(len(values) * percent / 100) - 1]
        for percent in [50, 95, 99]}, "max_ms": values[-1]}


def summarize(raw):
    frames = raw["frames"]
    intervals = [frame["submission_interval_ms"] for frame in frames]
    target = 1000 / raw["target_hz"]
    summary = distribution(intervals)
    summary["over_target_percent"] = 100 * sum(n > target for n in intervals) / len(intervals) if intervals else None
    summary["target_interval_ms"] = target
    inputs = raw["inputs"]
    delivered, feedback = [], []
    for sample in inputs:
        if sample.get("feedback_submission_us") is not None and (
                sample.get("delivered_us") is None or sample["feedback_submission_us"] < sample["delivered_us"]):
            raise ValueError("Input clock endpoints are out of order")
        for key, values in [("delivered_us", delivered), ("feedback_submission_us", feedback)]:
            if sample.get(key) is not None:
                elapsed = sample[key] - sample["dispatch_us"]
                if elapsed < 0:
                    raise ValueError("Input clock endpoints are out of order")
                values.append(elapsed / 1000)
    scenarios = raw.get("scenarios", [])
    observed = {}
    for scenario in scenarios:
        for event, count in scenario.get("events", {}).items():
            observed[event] = observed.get(event, 0) + count
    coverage = {event: observed.get(event, 0) > 0
                for event in ["place", "explode", "rocket", "grenade", "mine", "gas", "fire", "ice"]}
    coverage["six_pickup_trail"] = any(s["scenario"] == "pickups" and s.get("events", {}).get("pickup", 0) >= 6 for s in scenarios)
    coverage["outcome_scores"] = any("result:scores" in s.get("screens", []) for s in scenarios)
    memory = [frame["static_memory_bytes"] for frame in frames]
    return {
        "schema": 1, "metadata": raw["metadata"], "target_hz": raw["target_hz"],
        "measurement_boundary": "Engine frame_post_draw submission callbacks and injected viewport/keyboard events; not scanout or photons",
        "submission_intervals": summary,
        "process_deltas": distribution([f["process_delta_ms"] for f in frames]),
        "physics_cpu_per_submission_interval": distribution([f["physics_cpu_ms"] for f in frames]),
        "input_dispatch_to_simulation": distribution(delivered),
        "input_dispatch_to_feedback_submission": distribution(feedback),
        "input_samples": inputs,
        "unobserved_feedback_inputs": sum(s.get("feedback_submission_us") is None for s in inputs),
        "source_action_waits_are_included": True,
        "static_memory": {"first_bytes": memory[0] if memory else None,
                          "last_bytes": memory[-1] if memory else None,
                          "peak_bytes": max(memory) if memory else None,
                          "change_percent": 100 * (memory[-1] / memory[0] - 1) if memory and memory[0] else None},
        "scenarios": scenarios, "activity_coverage": coverage,
        "full_scenario_sequence_observed": all(coverage.values()),
        "presented_frame_intervals": None, "physical_input_to_photon": None,
        "device_performance_signoff": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        report = summarize(json.loads(args.raw.read_text(encoding="utf-8")))
        args.output.write_text(json.dumps(report, indent=2), encoding="utf-8")
    except (OSError, ValueError, KeyError, ZeroDivisionError) as error:
        parser.exit(1, f"FAIL: {error}\n")
    print("PERFORMANCE_REPORT_OK")


if __name__ == "__main__":
    main()
