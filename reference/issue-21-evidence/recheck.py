"""Regenerate integrated port observations against retained independent source captures.

Run after the public runner import, under the session's native exclusive wrapper.
Exact comparators retain diagnostic failures; no source observation is rewritten.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from run_checks import build_metadata, run_phase
from capture_effects import compare_effects


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(output/'user-data'), XDG_DATA_HOME=str(output/'user-data'))
    swf_hash = digest(ROOT/'Bomb It 1.swf')
    report = dict(build_metadata(ROOT/'godot'), original_swf_sha256=swf_hash, captures={})
    core_paths = {
        'core': 'reference/issue-13-evidence/core-nested/original-trace.json',
        'motion': 'reference/issue-13-evidence/motion-nested/original-trace.json',
        'interaction': 'reference/issue-13-evidence/original-trace.json',
        'dispatch': 'reference/issue-33-evidence/dispatch/original-trace.json',
    }
    for name in ['order','expiry','ai_order','push','grenade','grenadescore','accounting','contact','icewalk']:
        core_paths[name] = f'godot/tests/fixtures/{name}_original.json'
    for name, retained in core_paths.items():
        target = output/name
        target.mkdir(exist_ok=True)
        original = ROOT/retained
        source = json.loads(original.read_text())
        if source['original_swf_sha256'] != swf_hash:
            raise ValueError('Source SWF differs: '+name)
        driver = 'motion' if name in ('push','grenade') else 'interaction' if name in ('grenadescore','accounting','contact','icewalk','dispatch') else name
        flag = {'push':'--push-profile','grenade':'--grenade-profile','grenadescore':'--grenade-account','accounting':'--accounting-profile','contact':'--contact-profile','icewalk':'--icewalk-profile','dispatch':'--dispatch-profile'}.get(name)
        env['BOMB_IT_CORE_TRACE'] = str(target/'rebuilt.json')
        command = [args.godot,'--headless','--path',str(ROOT/'godot'),'--script',f'res://tests/{driver}_reference_capture.gd'] + (['--',flag] if flag else [])
        phase = run_phase(name, command, target, 180, env, 'CORE_REFERENCE_CAPTURE_OK')
        if not phase['passed']:
            raise RuntimeError('Rebuilt capture failed: '+name)
        compared = subprocess.run([sys.executable,str(ROOT/'tools/compare_traces.py'),str(original),str(target/'rebuilt.json'),'--output',str(target/'comparison.json')],check=False)
        if compared.returncode not in (0,1):
            raise RuntimeError('Invalid comparison: '+name)
        comparison = json.loads((target/'comparison.json').read_text())
        report['captures'][name] = {'retained':retained,'retained_sha256':digest(original),'phase':phase,'exact_passed':comparison['passed'],'differences':len(comparison['differences']),'observations':sum(map(len,source['scenarios'].values())),'source_configuration_sha256':source['configuration_sha256']}
    rendered = [
        ('death','reference/issue-02-capture/final/original','reference_capture','REFERENCE_CAPTURE_OK','death',40),
        ('feedback','reference/feedback-capture/original','feedback_capture','FEEDBACK_CAPTURE_OK','images',56),
        ('effects','reference/issue-04-capture/final/original','effects_capture','EFFECT_CAPTURE_OK','images',134),
        ('special_effects','reference/issue-05-capture/final/original','special_effects_capture','SPECIAL_EFFECT_CAPTURE_OK','images',141),
    ]
    for name, retained, script, marker, images, count in rendered:
        target = output/name
        target.mkdir(exist_ok=True)
        original = ROOT/retained
        source = json.loads((original/'trace.json').read_text())
        original_hash = source.get('original_swf_sha256')
        if name == 'special_effects':
            original_hash = json.loads((original.parent/'provenance.json').read_text())['Bomb It 1.swf']
        if original_hash != swf_hash:
            raise ValueError('Source SWF differs: '+name)
        env['BOMB_IT_QA_DIR'] = str(target/'rebuilt'/images)
        command = [args.godot,'--path',str(ROOT/'godot'),'--audio-driver','Dummy','--script',f'res://tests/{script}.gd']
        phase = run_phase(name,command,target,180,env,marker)
        if not phase['passed']:
            raise RuntimeError('Rebuilt capture failed: '+name)
        rebuilt = json.loads((target/'rebuilt/trace.json').read_text())
        if name == 'effects':
            comparison = compare_effects(source,rebuilt)
        elif name == 'special_effects':
            differences=[]
            if source['scenarios'].keys() != rebuilt['scenarios'].keys():
                raise ValueError('Scenario set differs')
            for scenario, rows in source['scenarios'].items():
                actual=rebuilt['scenarios'][scenario]
                if len(rows)!=len(actual):
                    raise ValueError('Incomplete timeline: '+scenario)
                for expected, observed in zip(rows,actual):
                    if expected['tick']!=observed['tick'] or expected['values'][0]!=observed['values'][0] or (scenario=='impact' and expected['values'][3]!=observed['values'][1]):
                        differences.append({'scenario':scenario,'original':expected,'rebuilt':observed})
            comparison={'passed':not differences,'differences':differences}
        else:
            from compare_traces import compare
            comparison=compare(source,rebuilt)
        (target/'comparison.json').write_text(json.dumps(comparison,indent=2))
        compared=subprocess.run([sys.executable,str(ROOT/'tools/compare_images.py'),str(original/images),str(target/'rebuilt'/images),'--output',str(target/'image-comparison')],check=False)
        if compared.returncode not in (0,1):
            raise RuntimeError('Invalid image comparison: '+name)
        image_report=json.loads((target/'image-comparison/report.json').read_text())
        if len(image_report['images'])!=count or any('error' in row for row in image_report['images']):
            raise ValueError('Incomplete image comparison: '+name)
        report['captures'][name]={'retained':retained,'retained_sha256':digest(original/'trace.json'),'phase':phase,'trace_passed':comparison['passed'],'observations':sum(map(len,source['scenarios'].values())),'image_count':count,'exact_images_passed':image_report['passed'],'different_images':sum(not r['passed'] for r in image_report['images'])}
    (output/'summary.json').write_text(json.dumps(report,indent=2))
    print('RECHECK_COMPLETE: exact comparison reports retained, including diagnostic differences')


if __name__ == '__main__':
    main()
