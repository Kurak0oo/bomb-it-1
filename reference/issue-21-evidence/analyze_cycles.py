"""Derive measured phase windows from retained frame intervals; no rerendering."""
import argparse
import bisect
import json
from pathlib import Path
import statistics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('raw', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = json.loads(args.raw.read_text())
    frames = raw['frames']
    times = [raw['metadata']['first_measured_submission_us']]
    for frame in frames[1:]:
        times.append(times[-1] + frame['submission_interval_ms']*1000)
    last = raw['metadata']['last_measured_submission_us']
    if abs(times[-1]-last)>1:
        raise ValueError('Submission intervals do not reproduce measured endpoint')
    phases = []
    for serial, scenario in enumerate(raw['scenarios']):
        start = scenario['start_us']
        end = raw['scenarios'][serial+1]['start_us'] if serial+1<len(raw['scenarios']) else last+1
        rows = frames[bisect.bisect_left(times,start):bisect.bisect_left(times,end)]
        if not rows:
            continue
        settled = frames[bisect.bisect_left(times,max(start,end-2_000_000)):bisect.bisect_left(times,end)]
        inputs = [s for s in raw['inputs'] if start<=s['dispatch_us']<end]
        intervals = [r['submission_interval_ms'] for r in rows]
        phases.append(dict(scenario, serial=serial, cycle=serial//6+1, measured_frames=len(rows),
            partial_measurement=start<times[0] or end>last,
            memory_first_bytes=rows[0]['static_memory_bytes'], memory_last_bytes=rows[-1]['static_memory_bytes'],
            memory_peak_bytes=max(r['static_memory_bytes'] for r in rows),
            settled_last_two_seconds_median_bytes=statistics.median(r['static_memory_bytes'] for r in settled),
            submission_max_ms=max(intervals), submission_mean_ms=statistics.mean(intervals),
            input_count=len(inputs), unobserved_feedback=sum(s['feedback_submission_us'] is None for s in inputs)))
    report={'target_hz':raw['target_hz'],
        'measured_endpoint_seconds':(last-times[0])/1_000_000,
        'reconstruction':'first measured submission plus subsequent intervals; verified against final timestamp within one microsecond',
        'memory_scope':'Godot static allocation, including caches and observer records; not process working set or GPU memory',
        'phases':phases}
    args.output.write_text(json.dumps(report,indent=2))


if __name__ == '__main__':
    main()
