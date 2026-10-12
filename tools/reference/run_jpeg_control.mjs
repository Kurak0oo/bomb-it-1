import { readFile, readdir } from 'node:fs/promises';
import { resolve } from 'node:path';
import { WASI } from 'node:wasi';
const folder=resolve(process.argv[3]);
const names=(await readdir(folder)).filter(n=>n.endsWith('.jpg'));
const wasi=new WASI({version:'preview1',args:['death-jpeg-control',...names],preopens:{'.':folder}});
const module=await WebAssembly.compile(await readFile(resolve(process.argv[2])));
const instance=await WebAssembly.instantiate(module,wasi.getImportObject());
wasi.start(instance);
