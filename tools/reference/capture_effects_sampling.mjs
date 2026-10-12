// Independent Canvas2D replay of the recovered image inputs and transforms.
// No screenshots or port output are used as drawing inputs.
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const output = resolve(process.argv[2]);
const inputFolder = resolve(process.argv[3]);
const reference = JSON.parse(await readFile(resolve(process.argv[4], 'trace.json')));
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
  const imagesFolder=resolve(output,'images'); await mkdir(imagesFolder,{recursive:true});
  for (const [scenario, observations] of Object.entries(reference.scenarios)) {
    for (const row of observations) {
      const label=`qa-${scenario}-frame-${String(row.tick).padStart(2,'0')}.png`;
      // Replay exactly the retained observation set, without input port pixels.
      try { await readFile(resolve(process.argv[4],'images',label)); } catch { continue; }
      const pixels=await page.evaluate(({scenario,row})=>{
        const ctx=document.querySelector('canvas').getContext('2d');
        ctx.resetTransform(); ctx.globalAlpha=1; ctx.fillStyle='white'; ctx.fillRect(0,0,550,400);
        const rgba=(hex,a)=>`rgba(${hex.match(/[0-9a-f]{2}/gi).map(n=>parseInt(n,16)).join(',')},${a})`;
        function shape(id,alpha) {
          const doc=vectors[id];
          for(const path of doc.querySelectorAll('path')) {
            ctx.save();
            const bitmap=path.getAttributeNS('https://www.free-decompiler.com/flash','fill-bitmapId');
            let color=path.getAttribute('fill');
            if(bitmap) {
              const fill=source.shapes[id].find(f=>f.bitmap===Number(bitmap));
              const m=fill.matrix.map((v,i)=>i<4?v/20:v);
              const pattern=ctx.createPattern(images[`raw-${fill.bitmap}`],'no-repeat');
              pattern.setTransform(new DOMMatrix(m)); ctx.fillStyle=pattern;
              ctx.imageSmoothingEnabled=false; ctx.globalAlpha=alpha;
              ctx.fill(new Path2D(path.getAttribute('d')),'evenodd');
            } else if(color?.startsWith('url')) {
              const node=doc.getElementById(color.slice(5,-1));
              const rounded=node.getAttribute('gradientTransform').match(/[-+]?\d*\.?\d+(?:E[-+]?\d+)?/gi).map(Number);
              const candidates=Object.entries(source.gradients).filter(([key])=>key.startsWith(id+'_')).map(([,m])=>m);
              candidates.sort((a,b)=>a.reduce((n,v,i)=>n+Math.abs(v-rounded[i]),0)-b.reduce((n,v,i)=>n+Math.abs(v-rounded[i]),0));
              if(!candidates.length || candidates[0].some((v,i)=>Math.abs(v-rounded[i])>0.000051)) throw Error('Unresolved source gradient '+id);
              const gm=new DOMMatrix(candidates[0].map((v,i)=>i<4?Math.round(v*65536)/65536:v));
              const radial=node.tagName==='radialGradient';
              const transformed=radial?Math.abs(gm.a-gm.d)>0.0001||Math.abs(gm.b+gm.c)>0.0001:Math.abs(gm.a*gm.c+gm.b*gm.d)>0.0001;
              let g;
              if(transformed) {
                ctx.transform(gm.a,gm.b,gm.c,gm.d,gm.e,gm.f);
                g=radial?ctx.createRadialGradient(0,0,0,0,0,819.2):ctx.createLinearGradient(-819.2,0,819.2,0);
              } else {
                // Pinned Ruffle's simple-gradient path quantizes endpoints to twips.
                const end=[Math.floor(gm.a*16384)/20+gm.e,Math.floor(gm.b*16384)/20+gm.f];
                const start=[Math.floor(-gm.a*16384)/20+gm.e,Math.floor(-gm.b*16384)/20+gm.f];
                g=radial?ctx.createRadialGradient(gm.e,gm.f,0,gm.e,gm.f,Math.hypot(end[0]-gm.e,end[1]-gm.f)):ctx.createLinearGradient(...start,...end);
              }
              for(const stop of node.querySelectorAll('stop')) g.addColorStop(Math.fround(Number(stop.getAttribute('offset'))),rgba(stop.getAttribute('stop-color'),Math.fround(Number(stop.getAttribute('stop-opacity')??1))));
              ctx.fillStyle=g; ctx.globalAlpha=alpha;
              const p=new Path2D(); p.addPath(new Path2D(path.getAttribute('d')),transformed?gm.inverse():new DOMMatrix()); ctx.fill(p,'evenodd');
            } else {
              if(!color) throw Error('Unsupported source path '+id);
              ctx.globalAlpha=1;
              ctx.fillStyle=rgba(color,Math.fround(Math.floor(255*alpha*Number(path.getAttribute('fill-opacity')??1))/255));
              ctx.fill(new Path2D(path.getAttribute('d')),'evenodd');
            }
            ctx.restore();
          }
        }
        function timeline(id,frame,alpha=1,variant=1) {
          for(const p of source.timelines[id][frame]) {
            ctx.save(); ctx.transform(...p.matrix);
            if(source.timelines[p.symbol]) timeline(p.symbol,p.symbol===293?variant-1:0,alpha*p.alpha,variant);
            else shape(p.symbol,alpha*p.alpha);
            ctx.restore();
          }
        }
        if(scenario==='pickups') {
          if(row.tick<105) for(let i=0;i<6;i++) {
            ctx.save();ctx.translate(60+i*60,210);
            const frame=row.tick>=85?80+row.tick-85:(row.tick+1)%79;
            timeline(326,frame,1,i+1); ctx.restore();
          }
        } else if(scenario==='brick') {
          if(row.values[0]) {ctx.save();ctx.translate(240,180);timeline(248,row.values[0]-1);ctx.restore();}
        } else {
          if(row.values[0]) {ctx.save();ctx.translate(240,180);timeline(371,row.values[0]-1);ctx.restore();}
          if(row.values[2]) {
            const variant=scenario==='bomb'?1:Number(scenario.slice(5));
            const draw=(dx,dy,angle,frame)=>{ctx.save();ctx.translate(255+dx*30,195+dy*30);ctx.rotate(angle);timeline(273,frame,row.values[1]/256);ctx.restore();};
            draw(0,0,0,variant-1);
            const radius=(row.values[2]-1)/4;
            for(let step=1;step<=radius;step++) for(let direction=0;direction<4;direction++) {
              const [dx,dy]=[[-1,0],[0,-1],[1,0],[0,1]][direction];
              draw(dx*step,dy*step,(direction+2)*Math.PI/2,variant-1+(step===3?8:4));
            }
          }
        }
        return document.querySelector('canvas').toDataURL('image/png');
      },{scenario,row});
      await writeFile(resolve(imagesFolder,label),Buffer.from(pixels.split(',')[1],'base64'));
    }
  }
  await writeFile(resolve(output,'provenance.json'),JSON.stringify({browser:browser.version(),inputs:'Original SWF drawing inputs, source SVG paths, original observation trace; no port images or assets',renderer:'Canvas2D original geometry and pinned Ruffle bitmap decode behavior'},null,2));
} finally { await browser.close(); }
