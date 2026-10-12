"""Capture original special-effect timelines and the actual port without parity tolerances."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from run_checks import ENGINE_VERSION, ROOT, run_phase


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ffdec', type=Path, required=True)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--require-parity', action='store_true')
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    godot = shutil.which(args.godot)
    if not godot:
        parser.error('Godot executable not found')
    try:
        version = subprocess.run([godot, '--version'], capture_output=True, text=True,
                                 timeout=180, check=True).stdout.strip()
        if not version.startswith(ENGINE_VERSION + '.'):
            parser.error(f'Expected Godot {ENGINE_VERSION}, found {version}')
    except (OSError, subprocess.SubprocessError) as error:
        parser.error(f'Cannot verify Godot version: {error}')
    profile = ROOT / 'godot/tests/fixtures/special_effect_scenarios.json'
    env = os.environ.copy()
    env['BOMB_IT_QA_DIR'] = str(output / 'rebuilt/images')
    classpath = os.pathsep.join([str(args.ffdec/'ffdec.jar'), str(args.ffdec/'lib/*')])
    phases = []
    for name, command, marker in [
        ('fixture', ['java', '--class-path', classpath, str(ROOT/'tools/reference/BuildReference.java'), str(ROOT/'Bomb It 1.swf'), str(output/'fixture.swf'), str(ROOT/'tools/reference/special_effects.as')], 'Preserved'),
        ('original', ['node', str(ROOT/'tools/reference/capture_effects.mjs'), str(output/'fixture.swf'), str(output/'original'), str(profile)], 'Captured original effects'),
        ('import', [godot, '--headless', '--path', str(ROOT/'godot'), '--editor', '--import', '--quit'], None),
        ('rebuilt', [godot, '--path', str(ROOT/'godot'), '--audio-driver', 'Dummy', '--script', 'res://tests/special_effects_capture.gd'], 'SPECIAL_EFFECT_CAPTURE_OK'),
    ]:
        result = run_phase(name, command, output, 180, env, marker)
        phases.append(result)
        for retry in range(2):
            if result['passed'] or name != 'original' or 'Capture skipped a tick' not in Path(result['log']).read_text():
                break
            result = run_phase(f'original-restart-{retry+1}', command, output, 180, env, marker)
            phases.append(result)
        (output/'phases.json').write_text(json.dumps(phases, indent=2))
        if not result['passed']:
            return 2
    inputs = ['Bomb It 1.swf', 'tools/reference/special_effects.as', 'tools/reference/BuildReference.java', 'tools/reference/capture_effects.mjs', str(profile.relative_to(ROOT))]
    (output/'provenance.json').write_text(json.dumps({p: hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in inputs}, indent=2))
    source = json.loads((output/'original/trace.json').read_text())['scenarios']
    rebuilt = json.loads((output/'rebuilt/trace.json').read_text())['scenarios']
    differences = []
    count = 0
    for scenario, rows in source.items():
        actual = rebuilt[scenario]
        if len(rows) != len(actual):
            raise ValueError('Incomplete timeline capture: '+scenario)
        for expected, observed in zip(rows, actual):
            count += 1
            if expected['tick'] != observed['tick'] or expected['values'][0] != observed['values'][0]:
                differences.append({'scenario': scenario, 'original': expected, 'rebuilt': observed})
            if scenario == 'impact' and expected['values'][3] != observed['values'][1]:
                differences.append({'scenario': scenario, 'field': 'independent_smoke_count', 'original': expected, 'rebuilt': observed})
    (output/'visibility-comparison.json').write_text(json.dumps({'observations': count, 'differences': differences, 'passed': not differences}, indent=2))
    result = subprocess.run([sys.executable, str(ROOT/'tools/compare_images.py'), str(output/'original/images'), str(output/'rebuilt/images'), '--output', str(output/'image-comparison')])
    if result.returncode not in (0, 1):
        return 2
    report = json.loads((output/'image-comparison/report.json').read_text())
    expected_images = sum(len(s['captures']) for s in json.loads(profile.read_text())['scenarios'].values())
    if len(report['images']) != expected_images or any('error' in row for row in report['images']):
        raise ValueError('Incomplete or incompatible rendered samples')
    print(f'Special-effect capture complete: {count} visibility observations, {len(differences)} differences. Exact image report retained.')
    return 1 if args.require_parity and (differences or result.returncode) else 0


if __name__ == '__main__':
    sys.exit(main())
