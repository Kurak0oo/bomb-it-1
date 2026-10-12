// Independent Canvas2D replay of the recovered image inputs and transforms.
// No screenshots or port output are used as drawing inputs.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const output = resolve(process.argv[2]);
const inputFolder = resolve(process.argv[3]);
const source = JSON.parse(await readFile(resolve(inputFolder, 'inputs.json')));
const assets = {};
const vectors = {};
const jpegAlpha = {};
const jpegRgb = {};
const rawRgba = {};
for (const [id, fills] of Object.entries(source.shapes)) {
  vectors[id] = await readFile(resolve(root, `extracted/all/shapes/${id}.svg`), 'utf8');
  for (const fill of fills) {
    const jpeg = fill.tag === 'DefineBitsJPEG3Tag';
    assets[`raw-${fill.bitmap}`] = `data:image/${jpeg?'jpeg':'png'};base64,${(await readFile(resolve(inputFolder, `raw-${fill.bitmap}.${jpeg?'jpg':'png'}`))).toString('base64')}`;
    if (jpeg) {
      jpegAlpha[`raw-${fill.bitmap}`] = [...await readFile(resolve(inputFolder, `raw-${fill.bitmap}.alpha`))];
      jpegRgb[`raw-${fill.bitmap}`] = [...await readFile(resolve(inputFolder, `raw-${fill.bitmap}.rgb`))];
    } else rawRgba[`raw-${fill.bitmap}`] = [...await readFile(resolve(inputFolder, `raw-${fill.bitmap}.rgba`))];
  }
}
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.setContent('<canvas width="550" height="400"></canvas>');
  await page.evaluate(async ({ assets, source, vectors, jpegAlpha, jpegRgb, rawRgba }) => {
    window.source = source;
    window.vectors = {};
    for (const [id, xml] of Object.entries(vectors)) window.vectors[id] = new DOMParser().parseFromString(xml, 'image/svg+xml');
    window.images = {};
    for (const [key, source] of Object.entries(assets)) {
      const image = new Image(); image.src = source; await image.decode();
      if (jpegAlpha[key]) {
        const buffer = document.createElement('canvas'); buffer.width=image.width; buffer.height=image.height;
        const c=buffer.getContext('2d'); c.drawImage(image,0,0); const pixels=c.getImageData(0,0,image.width,image.height);
        jpegAlpha[key].forEach((a,i)=>{
          for(let channel=0;channel<3;channel++) pixels.data[i*4+channel]=Math.min(a,jpegRgb[key][i*3+channel]);
          pixels.data[i*4+3]=a;
        }); c.putImageData(pixels,0,0); window.images[key]=buffer;
      } else if (rawRgba[key]) {
        const buffer=document.createElement('canvas'); buffer.width=image.width; buffer.height=image.height;
        buffer.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(rawRgba[key]),image.width),0,0);
        window.images[key]=buffer;
      } else window.images[key] = image;
    }
  }, { assets, source, vectors, jpegAlpha, jpegRgb, rawRgba });
  for (const part of ['body', 'burst', 'silhouette', 'eyes', 'shadow', 'smoke', 'eyes-black', 'smoke-black', 'burst-black', 'composite']) {
    const folder = resolve(output, part); await mkdir(folder, { recursive: true });
    for (let character = 1; character <= 4; character++) {
      await page.evaluate(() => { const previous=document.querySelector('canvas'); const next=document.createElement('canvas'); next.width=550; next.height=400; previous.replaceWith(next); });
      for (const tick of [-1, 0, 4, 5, 10, 11, 19, 20, 34, 35]) {
        const pixels = await page.evaluate(({ part, character, tick }) => {
          const canvas = document.querySelector('canvas'); const ctx = canvas.getContext('2d', {alpha:false});
          ctx.imageSmoothingEnabled = false;
          ctx.resetTransform(); ctx.globalAlpha = 1; ctx.fillStyle = part.endsWith('-black') ? 'black' : 'white'; ctx.fillRect(0, 0, 550, 400);
          const age = tick + 1;
          function shape(id, matrix = [1,0,0,1,0,0], alpha = 1) {
            ctx.save(); ctx.transform(...matrix); ctx.globalAlpha = Math.floor(255 * alpha) / 255;
            const fills = source.shapes[id];
            if (fills.length) {
              for (const fill of fills) {
                const m = fill.matrix.map((v,i) => i < 4 ? v/20 : v);
                const pattern=ctx.createPattern(images[`raw-${fill.bitmap}`],'no-repeat'); pattern.setTransform(new DOMMatrix(m));
                // Pinned Ruffle's SWF reader disables bitmap smoothing below SWF8.
                ctx.imageSmoothingEnabled=false;
                ctx.fillStyle=pattern;
                for(const path of vectors[id].querySelectorAll('path')) ctx.fill(new Path2D(path.getAttribute('d')),'evenodd');
              }
            } else {
              const doc = vectors[id];
              for (const path of doc.querySelectorAll('path')) {
                let color = path.getAttribute('fill');
                if (!color) throw new Error(`Unsupported path style in source shape ${id}: ${path.outerHTML}`);
                if (color.startsWith('url')) {
                  const node = doc.getElementById(color.slice(5,-1));
                  ctx.save();
                  ctx.globalAlpha=alpha;
                  const gm = new DOMMatrix(source.gradients[id]);
                  ctx.transform(gm.a,gm.b,gm.c,gm.d,gm.e,gm.f);
                  const gradient = ctx.createRadialGradient(0,0,0,0,0,Number(node.getAttribute('r')));
                  for (const stop of node.querySelectorAll('stop')) {
                    const opacity = Number(stop.getAttribute('stop-opacity') ?? 1);
                    gradient.addColorStop(Number(stop.getAttribute('offset')), `rgba(0,0,0,${opacity})`);
                  }
                  ctx.fillStyle=gradient;
                  const gp=new Path2D(); gp.addPath(new Path2D(path.getAttribute('d')),gm.inverse());
                  ctx.fill(gp,'evenodd'); ctx.restore(); continue;
                }
                ctx.globalAlpha=1;
                const channels=color.match(/[0-9a-f]{2}/gi).map(n=>parseInt(n,16));
                ctx.fillStyle = `rgba(${channels.join(',')},${Math.fround(Math.floor(255*alpha)/255)})`;
                ctx.fill(new Path2D(path.getAttribute('d')), 'evenodd');
              }
            }
            ctx.restore();
          }
          function timeline(id, frame) {
            for (const p of source.timelines[id][Math.min(frame, source.timelines[id].length - 1)]) shape(p.symbol,p.matrix,p.alpha);
          }
          ctx.save(); ctx.translate(240,210);
          const includes = p => part.replace('-black','') === p || part === 'composite';
          if (age < 35) {
            if (includes('shadow') && age < 5) shape(2);
            for (const p of source.timelines[237][Math.min(age,source.timelines[237].length-1)]) {
              if (includes('shadow') && p.symbol === 232) shape(232, p.matrix, p.alpha);
              if (p.symbol === 236) {
                if (includes('silhouette')) shape(character <= 2 ? 233 : 235, p.matrix, p.alpha);
                if (includes('eyes')) shape(234, p.matrix, p.alpha);
              }
            }
            if (includes('body') && age < 5) {
              const body = source.timelines[[90,68,46,24][character-1]][3].find(p=>p.symbol!==2);
              ctx.save(); ctx.transform(...body.matrix); timeline(body.symbol,age % 12); ctx.restore();
            }
            if (includes('burst') && age < 10) timeline(248,age);
            if (includes('smoke')) timeline(279,age);
          }
          ctx.restore();
          return canvas.toDataURL('image/png');
        }, { part, character, tick });
        const prefix = character === 1 ? '' : `hero${character}-`;
        const label = tick === -1 ? 'creation' : `frame-${String(tick).padStart(2, '0')}`;
        await writeFile(resolve(folder, `qa-${prefix}${label}.png`), Buffer.from(pixels.split(',')[1], 'base64'));
      }
    }
  }
  await writeFile(resolve(output, 'provenance.json'), JSON.stringify({ browser: browser.version(), inputs: 'Raw SWF bitmaps and JPEG channels, recovered SVG paths, original display-list matrices and alpha; no port assets or screenshots', renderer: 'Canvas2D paths and patterns; pinned Ruffle bitmap-decoding behavior', fps:35 }, null, 2));
} finally { await browser.close(); }
