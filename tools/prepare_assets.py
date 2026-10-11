"""Copy the recovered Flash PNG timelines and sounds; no redrawn game artwork."""
from pathlib import Path
import json
import base64
import re
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'godot/art/original'
OUT.mkdir(parents=True, exist_ok=True)
bounds = json.loads((ROOT / 'reference/sprite-bounds.json').read_text())
ids = [11,20,23,24,33,42,45,46,55,64,67,68,77,86,89,90,195,231,236,237,248,273,279,293,304,305,306,307,308,309,310,312,315,317,319,325,371]
manifest = {}
for sid in ids:
    source = next(p for p in (ROOT / 'extracted/all/sprites').iterdir() if int(p.name.split('_')[1]) == sid)
    target = OUT / str(sid)
    target.mkdir(exist_ok=True)
    frames = sorted(source.glob('*.png'), key=lambda p: int(p.stem))
    for stale in target.glob('*.png'):
        if stale.name not in {p.name for p in frames}:
            stale.unlink()
    for file in frames:
        shutil.copy2(file, target / file.name)
    manifest[str(sid)] = {'offset': bounds[str(sid)], 'frames': len(frames)}

ns = {'x': 'http://ns.adobe.com/xfl/2008/'}
heroes = {}
for character, sid in enumerate([90,68,46,24], 1):
    doc = ET.parse(ROOT / f'xfl/Bomb It 1/LIBRARY/Symbol {sid}.xml')
    directions = []
    for body in doc.findall('.//x:DOMSymbolInstance[@name="body"]', ns):
        matrix = body.find('x:matrix/x:Matrix', ns)
        directions.append({'symbol': int(body.attrib['libraryItemName'].split()[-1]),
                           'x': float(matrix.get('tx', 0)), 'y': float(matrix.get('ty', 0)),
                           'scale_x': float(matrix.get('a', 1))})
    heroes[str(character)] = directions
manifest['heroes'] = heroes
doc = ET.parse(ROOT / 'xfl/Bomb It 1/LIBRARY/Symbol 310.xml')
grenade = []
for body in doc.findall('.//x:DOMSymbolInstance[@name="body"]', ns):
    matrix = body.find('x:matrix/x:Matrix', ns)
    grenade.append({'symbol': int(body.attrib['libraryItemName'].split()[-1]),
                    'x': float(matrix.get('tx', 0)), 'y': float(matrix.get('ty', 0)),
                    'scale_x': float(matrix.get('a', 1))})
manifest['grenade'] = grenade
# XFL graphic matrices use twips, while exported SVGs already use pixels.
for sid in [2,232,286]:
    source = ROOT / f'extracted/all/shapes/{sid}.svg'
    doc = ET.parse(source)
    svg_ns = {'s': 'http://www.w3.org/2000/svg'}
    matrix = doc.find('s:g', svg_ns).get('transform')
    values = [float(v) for v in re.search(r'matrix\((.*?)\)', matrix)[1].split(',')]
    target = OUT / str(sid)
    target.mkdir(exist_ok=True)
    extension = 'svg'
    if sid == 2:
        # Copy the original embedded shadow bitmap without resampling.
        embedded = doc.find('.//s:image', svg_ns)
        payload = embedded.get('{http://www.w3.org/1999/xlink}href').split(',')[1]
        (target / '1.png').write_bytes(base64.b64decode(payload))
        extension = 'png'
    else:
        shutil.copy2(source, target / '1.svg')
    manifest[str(sid)] = {'offset': [-values[4], -values[5]], 'frames': 1, 'extension': extension}

timelines = {}
for sid in [237,305,313,326]:
    doc = ET.parse(ROOT / f'xfl/Bomb It 1/LIBRARY/Symbol {sid}.xml')
    tracks = []
    length = 0
    for layer in reversed(doc.findall('.//x:DOMLayer', ns)):
        frames = layer.findall('x:frames/x:DOMFrame', ns)
        count = max((int(f.get('index')) + int(f.get('duration', 1)) for f in frames), default=0)
        length = max(length, count)
        track = [None] * count
        for frame in frames:
            body = frame.find('x:elements/x:DOMSymbolInstance', ns)
            if body is None:
                continue
            matrix = body.find('x:matrix/x:Matrix', ns)
            color = body.find('x:color/x:Color', ns)
            factor = 20 if body.get('symbolType') == 'graphic' else 1
            transform = [float(matrix.get(k, default)) * factor for k, default in [('a',1),('b',0),('c',0),('d',1)]]
            transform += [float(matrix.get('tx',0)), float(matrix.get('ty',0))]
            placement = {'symbol': int(body.get('libraryItemName').split()[-1]),
                         'matrix': transform, 'alpha': float(color.get('alphaMultiplier',1)) if color is not None else 1}
            start = int(frame.get('index'))
            for index in range(start, start + int(frame.get('duration',1))):
                track[index] = placement
        if any(track):
            tracks.append(track)
    timelines[str(sid)] = {'length': length, 'tracks': tracks}
manifest['timelines'] = timelines
(OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
audio = OUT / 'audio'
audio.mkdir(exist_ok=True)
for file in (ROOT / 'extracted/all/sounds').glob('*.mp3'):
    shutil.copy2(file, audio / file.name)
shutil.copy2(ROOT / 'extracted/all/frames/4.png', OUT / 'menu.png')
print(f'Prepared {sum(manifest[str(i)]["frames"] for i in ids)} original sprite frames.')
