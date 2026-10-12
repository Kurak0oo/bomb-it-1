// Capture unmodified original root screens by following their real buttons.
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { chromium } from 'playwright';

const here = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
if (args.length !== 2) throw new Error('Usage: node capture_hud.mjs <original.swf> <output-directory>');
const swf = await readFile(resolve(args[0]));
const output = resolve(args[1]);
await mkdir(output, { recursive: true });
const html = `<!doctype html><style>html,body{margin:0;background:rgb(27,18,36)}ruffle-player{width:550px;height:400px;display:block;margin:auto}</style>
<script src="/ruffle/ruffle.js"></script><script>
window.boot = async () => {
 window.player = window.RufflePlayer.newest().createPlayer();
 document.body.appendChild(window.player);
 await window.player.ruffle().load({url:'/original.swf',allowScriptAccess:false,
  autoplay:'on',unmuteOverlay:'hidden',quality:'high',preferredRenderer:'canvas',
  warnOnUnsupportedContent:false});
 window.player.ruffle().volume = 0;
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
 await page.evaluate(() => window.boot());
 await page.clock.runFor(2000);
 async function capture(name) {
  await page.clock.runFor(48);
  await page.screenshot({path:resolve(output,`qa-${name}.png`)});
 }
 async function click(x,y) { await page.mouse.click(x,y); await page.clock.runFor(48); await page.mouse.move(1,1); }
 await click(477,100);
 await click(470,155);
 await click(477,189);
 await page.keyboard.press('Space');
 await capture('hud-original');
 const ruffle = JSON.parse(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle/package.json')));
 const lock = JSON.parse(await readFile(resolve(here,'package-lock.json')));
 await writeFile(resolve(output,'runtime.json'),JSON.stringify({
  source:'unmodified-original-swf',source_sha256:createHash('sha256').update(swf).digest('hex'),
  runtime:`Ruffle ${ruffle.version}`,browser:browser.version(),fps:35,
  capture_sha256:createHash('sha256').update(await readFile(fileURLToPath(import.meta.url))).digest('hex'),
  ruffle_integrity:lock.packages['node_modules/@ruffle-rs/ruffle'].integrity,
  renderer:'canvas',clock:'Playwright virtual clock; round after original keyboard confirmation',
  caveat:'Original bytecode in Ruffle, not Adobe Flash Player certification. No port images used as source.'
 },null,2));
 console.log(`Captured original HUD: ${output}`);
} finally {
 await writeFile(resolve(output,'browser.log'),messages.join('\n'));
 if (browser) await browser.close();
 await new Promise(done=>server.close(done));
}
