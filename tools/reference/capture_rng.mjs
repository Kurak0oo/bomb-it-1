import {createServer} from 'node:http';
import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve,dirname,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {chromium} from 'playwright';
const here=dirname(fileURLToPath(import.meta.url));
const [fixture,output]=process.argv.slice(2);
if(!fixture || !output) throw Error('Usage: capture_rng.mjs fixture.swf output');
await mkdir(output,{recursive:true});
const swf=await readFile(fixture);
const html=`<script src="/ruffle/ruffle.js"></script><script>
window.rows=[];window.done=false;window.failure=null;
window.boot=async scene=>{window.player=RufflePlayer.newest().createPlayer();document.body.appendChild(player);
 await player.ruffle().load({url:'/fixture.swf',parameters:{scene:String(scene)},autoplay:'on',unmuteOverlay:'hidden',preferredRenderer:'canvas',allowScriptAccess:false});
 player.ruffle().traceObserver=value=>{if(value.startsWith('RNG_'))rows.push(value);if(value.startsWith('RNG_ERROR'))failure=value;if(value==='RNG_DONE'){done=true;queueMicrotask(()=>player.ruffle().suspend());}};
 player.ruffle().resume();};</script>`;
const server=createServer(async(req,res)=>{
 try{const path=new URL(req.url,'http://localhost').pathname;
 if(path==='/'){res.setHeader('Content-Type','text/html');res.end(html);}
 else if(path==='/fixture.swf')res.end(swf);
 else if(path.startsWith('/ruffle/') && basename(path)===path.slice(8)){
 res.setHeader('Content-Type',path.endsWith('.wasm')?'application/wasm':'application/javascript');res.end(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle',basename(path))));
 }else{res.statusCode=404;res.end();}}catch(error){res.statusCode=500;res.end(String(error));}
});
await new Promise(done=>server.listen(0,'127.0.0.1',done));
const browser=await chromium.launch({headless:true});
try{
 const scenarios={};
 for(let scene=0;scene<5;scene++){
  const page=await browser.newPage();const errors=[];page.on('pageerror',error=>errors.push(String(error)));
  const epoch=new Date('2026-01-01');await page.clock.install({time:epoch});await page.clock.pauseAt(epoch);
  await page.goto(`http://127.0.0.1:${server.address().port}`);await page.evaluate(scene=>window.boot(scene),scene);
  for(let tick=0;tick<200 && !(await page.evaluate(()=>done));tick++)await page.clock.runFor(30);
  const result=await page.evaluate(()=>({done,failure,rows}));
  await writeFile(resolve(output,`scene-${scene}.log`),result.rows.join('\n'));
  if(!result.done || result.failure || errors.length)throw Error(JSON.stringify({...result,rows:result.rows.slice(-5),errors}));
  scenarios[String(scene)]=result.rows;await page.close();
 }
 const ruffle=JSON.parse(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle/package.json')));
 await writeFile(resolve(output,'raw.json'),JSON.stringify({source:'original-swf-bytecode',runtime:`Ruffle ${ruffle.version}`,browser:browser.version(),scenarios},null,2));
 console.log('RNG_ORIGINAL_CAPTURE_OK');
}finally{await browser.close();await new Promise(done=>server.close(done));}
