// Capture unmodified original root screens by following their real buttons.
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { chromium } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
if (args.length !== 2) throw new Error('Usage: node capture_outcomes.mjs <original.swf> <output-directory>');
const swf = await readFile(resolve(args[0]));
const output = resolve(args[1]);
await mkdir(output, { recursive: true });
const html = `<!doctype html><style>html,body{margin:0;background:rgb(27,18,36)}ruffle-player{width:550px;height:400px;display:block;margin:auto}</style>
<script src="/ruffle/ruffle.js"></script><script>
window.boot = async players => {
 window.samples = [];
 window.player = window.RufflePlayer.newest().createPlayer();
 document.body.appendChild(window.player);
 await window.player.ruffle().load({url:'/original.swf',parameters:{players},allowScriptAccess:false,
  autoplay:'on',unmuteOverlay:'hidden',quality:'high',preferredRenderer:'canvas',
  warnOnUnsupportedContent:false});
 window.player.ruffle().volume = 0;
 window.player.ruffle().traceObserver = message => {if(message.startsWith("OUTCOME_SAMPLE|")) window.samples.push(message.split("|"));};
};</script>`;
const server = createServer(async (request, response) => {
 try {
  const path = new URL(request.url, 'http://localhost').pathname;
  if (path === '/') { response.setHeader('Content-Type','text/html'); response.end(html); }
  else if (path === '/original.swf') { response.setHeader('Content-Type','application/x-shockwave-flash'); response.end(swf); }
  else if (path.startsWith('/ruffle/') && basename(path) === path.slice(8)) {
   response.setHeader('Content-Type',path.endsWith('.wasm')?'application/wasm':'application/javascript');
   response.end(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle',basename(path))));
  } else { response.statusCode=404; response.end(); }
 } catch { response.statusCode=404; response.end(); }
});
await new Promise(done => server.listen(0,'127.0.0.1',done));
let browser;
const messages = [];
try {
 browser = await chromium.launch({headless:true});
 const address = `http://127.0.0.1:${server.address().port}`;
 const page = await browser.newPage({viewport:{width:550,height:400},deviceScaleFactor:1});
 await page.route('**/*', route => route.request().url().startsWith(address) ? route.continue() : route.abort());
 page.on('console', message => messages.push(message.text()));
 page.on('pageerror', error => messages.push(String(error)));
 const epoch = new Date('2026-01-01T00:00:00Z');
 await page.clock.install({time:epoch});
 await page.clock.pauseAt(epoch);
 await page.goto(address);
 const traces = {};
 for(const players of [1,2]) {
  if(players===2) await page.reload();
  await page.evaluate(players => window.boot(players), String(players));
  let bannerCaptured=false;
  for(let i=0;i<400;i++) {
   await page.clock.runFor(16);
   const rows=await page.evaluate(()=>window.samples);
   const last=rows.at(-1);
   if(!last)continue;
   if(!bannerCaptured && Number(last[1])>=2000) {
    await page.screenshot({path:resolve(output,`qa-outcome-${players}p.png`)});
    bannerCaptured=true;
   }
   if(Number(last[1])>=5700)break;
  }
  const rows=await page.evaluate(()=>window.samples);
  const first=rows.find(row=>Number(row[3])>1);
  if(!first || Number(first[1])<5500 || Number(first[1])>5540)throw new Error(`Unexpected original timer deadline ${JSON.stringify(first)}`);
  if(rows.some(row=>Number(row[4])!==3110 || Number(row[6])!==4110))throw new Error('Original score changed during display');
  if(rows.filter(row=>Number(row[3])>1).some(row=>Number(row[5])!==3110))throw new Error('Original score sheet did not show final value immediately');
  traces[players]=rows;
  await page.screenshot({path:resolve(output,`qa-score-${players}p.png`)});
 }
 await writeFile(resolve(output,'trace.json'),JSON.stringify(traces,null,2));
 const ruffle = JSON.parse(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle/package.json')));
 const lock = JSON.parse(await readFile(resolve(here,'package-lock.json')));
 await writeFile(resolve(output,'runtime.json'),JSON.stringify({
  source:'original-gameover-bytecode-with-controlled-fixture',fixture_sha256:createHash('sha256').update(swf).digest('hex'),
  original_sha256:createHash('sha256').update(await readFile(resolve(here,'../../Bomb It 1.swf'))).digest('hex'),
  builder_sha256:createHash('sha256').update(await readFile(resolve(here,'BuildOutcomeReference.java'))).digest('hex'),
  root_setup_sha256:createHash('sha256').update(await readFile(resolve(here,'outcome_root.as'))).digest('hex'),
  game_setup_sha256:createHash('sha256').update(await readFile(resolve(here,'outcome_game.as'))).digest('hex'),
  runtime:`Ruffle ${ruffle.version}`,browser:browser.version(),fps:35,
  capture_sha256:createHash('sha256').update(await readFile(fileURLToPath(import.meta.url))).digest('hex'),
  ruffle_integrity:lock.packages['node_modules/@ruffle-rs/ruffle'].integrity,
  renderer:'canvas',clock:'Playwright virtual clock; source 5500ms gameover interval and Sprite603 field binding',
  caveat:'Original bytecode in Ruffle, not Adobe Flash Player certification. No port images used as source.'
 },null,2));
 console.log(`Captured original outcomes: ${output}`);
} finally {
 await writeFile(resolve(output,'browser.log'),messages.join('\n'));
 if (browser) await browser.close();
 await new Promise(done=>server.close(done));
}
