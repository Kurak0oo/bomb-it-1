import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { chromium } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
if (args.length !== 2) throw new Error('Usage: node capture.mjs <fixture.swf> <output-directory>');
const swf = await readFile(resolve(args[0]));
const output = resolve(args[1]);
await mkdir(output, { recursive: true });
const html = `<!doctype html><style>html,body{margin:0;background:#fff}ruffle-player{width:550px;height:400px;display:block}</style>
<script src="/ruffle/ruffle.js"></script><script>
window.samples=[];
window.referenceSample = message => {
  if (!message.startsWith('REFERENCE_SAMPLE|')) return;
  const p = message.split('|');
  window.samples.push({tick:Number(p[1]),deathFrame:Number(p[2]),heroVisible:p[3]==='true',
    silhouetteVisible:p[4]==='true',centerEnergy:Number(p[5]),armEnergy:Number(p[6]),
    brickBlocking:p[7]==='true',blastVisible:p[8]==='true'});
  queueMicrotask(() => window.player.ruffle().suspend());
};
window.boot = async scenario => {
  window.player = window.RufflePlayer.newest().createPlayer();
  document.body.appendChild(window.player);
  await window.player.ruffle().load({url:'/fixture.swf',parameters:{scenario},
    allowScriptAccess:false,autoplay:'on',unmuteOverlay:'hidden',
    backgroundColor:'#ffffff',quality:'high',preferredRenderer:'canvas',
    warnOnUnsupportedContent:false});
  window.player.ruffle().traceObserver = window.referenceSample;
  window.player.ruffle().resume();
};
</script>`;
const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://localhost');
    if (url.pathname === '/') {
      response.setHeader('Content-Type', 'text/html'); response.end(html);
    } else if (url.pathname === '/fixture.swf') {
      response.setHeader('Content-Type', 'application/x-shockwave-flash'); response.end(swf);
    } else if (url.pathname.startsWith('/ruffle/') && basename(url.pathname) === url.pathname.slice(8)) {
      const name = basename(url.pathname);
      response.setHeader('Content-Type', name.endsWith('.wasm') ? 'application/wasm' : 'application/javascript');
      response.end(await readFile(resolve(here, 'node_modules/@ruffle-rs/ruffle', name)));
    } else { response.statusCode = 404; response.end(); }
  } catch { response.statusCode = 404; response.end(); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
let browser;
try {
  browser = await chromium.launch({ headless: true });
  const address = `http://127.0.0.1:${server.address().port}`;
  const all = {};
  for (const scenario of ['death', 'death2', 'death3', 'death4', 'explosion', 'brick']) {
    const page = await browser.newPage({ viewport: { width: 550, height: 400 }, deviceScaleFactor: 1 });
    const messages = [];
    page.on('console', message => messages.push(message.text()));
    page.on('pageerror', error => messages.push(String(error)));
    try {
      // Advance browser time explicitly: a busy host must not let Ruffle run
      // several Flash frames in one RAF callback before the pause microtask.
      const epoch = new Date('2026-01-01T00:00:00Z');
      await page.clock.install({ time: epoch });
      await page.clock.pauseAt(epoch);
      await page.goto(address);
      await page.evaluate(scenario => window.boot(scenario), scenario);
      const rows = [];
      for (let tick = 0; tick < 40; tick++) {
        for (let step = 0; step < 20; step++) {
          if (await page.evaluate(n => window.samples.length > n, tick)) break;
          await page.clock.runFor(16);
        }
        // The microtask pauses the runtime before another frame. No wall-clock sleeps.
        const observed = await page.evaluate(() => window.samples);
        if (observed.length !== tick + 1 || observed[tick].tick !== tick)
          throw new Error(`Capture skipped a tick: expected ${tick}, received ${JSON.stringify(observed)}`);
        rows.push(observed[tick]);
        if (scenario.startsWith('death') && [0,4,5,10,11,19,20,34,35].includes(tick)) {
          const folder = resolve(output, 'death');
          await mkdir(folder, { recursive: true });
          // Ruffle displays its own play overlay when suspended. Export only the
          // game's canvas, so runtime controls cannot contaminate reference art.
          const pixels = await page.locator('ruffle-player').locator('canvas').evaluate(canvas => canvas.toDataURL('image/png'));
          const prefix = scenario === 'death' ? '' : `hero${scenario.slice(5)}-`;
          await writeFile(resolve(folder, `qa-${prefix}frame-${String(tick).padStart(2,'0')}.png`), Buffer.from(pixels.split(',')[1], 'base64'));
        }
        if (tick < 39) await page.evaluate(() => window.player.ruffle().resume());
      }
      all[scenario] = rows;
    } finally {
      await writeFile(resolve(output, `${scenario}.log`), messages.join('\n'));
      await page.close();
    }
  }
  const ruffle = JSON.parse(await readFile(resolve(here, 'node_modules/@ruffle-rs/ruffle/package.json')));
  const lock = JSON.parse(await readFile(resolve(here, 'package-lock.json')));
  await writeFile(resolve(output, 'trace.json'), JSON.stringify({
    source: 'original-swf-bytecode', runtime: `Ruffle ${ruffle.version}`, browser: browser.version(),
    fixture_sha256: createHash('sha256').update(swf).digest('hex'),
    ruffle_integrity: lock.packages['node_modules/@ruffle-rs/ruffle'].integrity,
    fps:35, tick_origin:'first onEnterFrame observation after fixture creation',
    caveat:'Ruffle executes the original bytecode; this is not Adobe Flash Player certification.',
    scenarios: all
  }, null, 2));
  console.log(`Captured original SWF bytecode: ${output}`);
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}

