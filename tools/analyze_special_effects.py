"""Retain exact special-effect difference counts and a labelled source/before/after sheet."""
import argparse
import csv
import json
from pathlib import Path

from PIL import Image, ImageDraw


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('after', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    before = {r['name']: r for r in json.loads((args.before/'image-comparison/report.json').read_text())['images']}
    after = json.loads((args.after/'image-comparison/report.json').read_text())['images']
    with (args.output/'actual-counts.csv').open('w', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['image', 'before_changed_pixels', 'after_changed_pixels'])
        for row in after:
            writer.writerow([row['name'], before.get(row['name'], {}).get('changed_pixels', ''), row['changed_pixels']])
    samples = [('rocket-2', '07'), ('mine', '14'), ('grenade-3', '08'), ('gas', '89'), ('ice', '18'), ('fire', '18'), ('ice', '38'), ('impact', '04')]
    sheet = Image.new('RGB', (750, len(samples)*205+25), 'white')
    draw = ImageDraw.Draw(sheet)
    for col, label in enumerate(['Original bytecode', 'Previous port', 'Current port']):
        draw.text((col*250+5, 5), label, fill='black')
    for row, (scenario, tick) in enumerate(samples):
        name = f'qa-{scenario}-frame-{tick}.png'
        for col, folder in enumerate([args.after/'original/images', args.before/'rebuilt/images', args.after/'rebuilt/images']):
            at = (col*250, row*205+25)
            draw.text((at[0]+5, at[1]), f'{scenario}, tick {tick}', fill='black')
            if (folder/name).exists():
                sheet.paste(Image.open(folder/name).convert('RGB').crop((130,65,380,245)), (at[0],at[1]+20))
            else:
                draw.text((at[0]+5,at[1]+50), 'No previous capture', fill='black')
    sheet.save(args.output/'contact.png')


if __name__ == '__main__':
    main()
