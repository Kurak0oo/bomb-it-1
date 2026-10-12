"""Retain exact original mixed samples and evaluate the independent overlap control."""
import argparse
import gzip
import hashlib
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    raw = args.original.read_bytes()
    source = json.loads(raw)
    args.output.mkdir(parents=True, exist_ok=True)
    samples = {}
    for name in ('single', 'double'):
        values = [sample for chunk in source['scenarios'][name]['webAudio'] for sample in chunk.get('samples', [])]
        nonzero = [i for i, value in enumerate(values) if value != 0]
        if not nonzero:
            raise ValueError('Silent source overlap control: '+name)
        samples[name] = values[nonzero[0]:nonzero[-1]+1]
    error = max(abs(double-2*single) for single, double in zip(samples['single'], samples['double']))
    report = {
        'runtime':source['runtime'],'browser':source['browser'],
        'fixture_sha256':source['fixture_sha256'],
        'raw_sha256':hashlib.sha256(raw).hexdigest(),
        'overlap':{'alignment':'Only leading/trailing exact zero samples removed; no time shifting or tolerance.',
                   'single_frames':len(samples['single']),'double_frames':len(samples['double']),
                   'single_peak':max(map(abs,samples['single'])),'double_peak':max(map(abs,samples['double'])),
                   'max_double_minus_twice_single':error,
                   'passed':len(samples['single']) == len(samples['double']) and error == 0},
        'scenarios':{name:{'trace':row['trace'],'errors':row['errors'],
                           'peak':max(chunk.get('peak',0) for chunk in row['webAudio'])}
                     for name,row in source['scenarios'].items()},
    }
    (args.output/'original.json.gz').write_bytes(gzip.compress(raw, mtime=0))
    (args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report['overlap']))
    return 0 if report['overlap']['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
