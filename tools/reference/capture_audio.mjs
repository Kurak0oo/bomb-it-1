import {createServer} from 'node:http';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve,dirname,basename} from 'node:path';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import {chromium} from 'playwright';

const here=dirname(fileURLToPath(import.meta.url));
const [fixture,outputArg,requested]=process.argv.slice(2);
if(!fixture || !outputArg) throw Error('Usage: capture_audio.mjs fixture.swf output');
const swf=await readFile(resolve(fixture)), output=resolve(outputArg);
await mkdir(output,{recursive:true});
const html=`<!doctype html><script src="/ruffle/ruffle.js"></script><script>
window.trace=[];window.webAudio=[];window.done=false;
const start=AudioBufferSourceNode.prototype.start,stop=AudioBufferSourceNode.prototype.stop;
let serial=0;
AudioBufferSourceNode.prototype.start=function(...args){this.observedId=++serial;const samples=this.buffer?Array.from(this.buffer.getChannelData(0)):[];webAudio.push({op:'start',id:this.observedId,time:this.context.currentTime,duration:this.buffer?.duration,peak:Math.max(0,...samples.map(Math.abs)),samples});return start.apply(this,args);};
AudioBufferSourceNode.prototype.stop=function(...args){webAudio.push({op:'stop',id:this.observedId,time:this.context.currentTime});return stop.apply(this,args);};
window.boot=async scenario=>{
 const player=window.RufflePlayer.newest().createPlayer();document.body.appendChild(player);
 await player.ruffle().load({url:'/fixture.swf',parameters:{scenario},autoplay:'on',unmuteOverlay:'hidden',allowScriptAccess:false,preferredRenderer:'canvas'});
 player.ruffle().traceObserver=message=>{trace.push(message);if(message==='AUDIO_DONE')done=true;};
 player.ruffle().resume();
};</script>`;
const server=createServer(async(req,res)=>{
 try{
  const path=new URL(req.url,'http://localhost').pathname;
  if(path==='/'){res.setHeader('Content-Type','text/html');res.end(html);}
  else if(path==='/fixture.swf')res.end(swf);
  else if(path.startsWith('/ruffle/') && basename(path)===path.slice(8)){
   res.setHeader('Content-Type',path.endsWith('.wasm')?'application/wasm':'application/javascript');
   res.end(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle',basename(path))));
  }else{res.statusCode=404;res.end();}
 }catch{res.statusCode=404;res.end();}
});
await new Promise(r=>server.listen(0,'127.0.0.1',r));
let browser;
try{
 browser=await chromium.launch({headless:true,args:['--autoplay-policy=no-user-gesture-required']});
 const scenarios={};
 for(const name of requested?requested.split(','):['single','double','overlap','bombs','push','pickup','muted','rocket-wall','rocket-brick','mine','grenade','gas','ice','fire-brick','fire']){
  const page=await browser.newPage();const errors=[];
  page.on('pageerror',e=>errors.push(String(e)));
  await page.goto('http://127.0.0.1:'+server.address().port);
  await page.evaluate(name=>boot(name),name);
  await page.waitForFunction(()=>done,{},{timeout:10000});
  scenarios[name]=await page.evaluate(()=>({trace,webAudio}));scenarios[name].errors=errors;
  await page.close();
 }
 const ruffle=JSON.parse(await readFile(resolve(here,'node_modules/@ruffle-rs/ruffle/package.json')));
 await writeFile(resolve(output,'original.json'),JSON.stringify({runtime:'Ruffle '+ruffle.version,browser:browser.version(),fixture_sha256:createHash('sha256').update(swf).digest('hex'),scenarios},null,2));
 console.log('AUDIO_SOURCE_OK');
}finally{if(browser)await browser.close();await new Promise(r=>server.close(r));}
