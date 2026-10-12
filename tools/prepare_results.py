"""Export original result art and the sampled source outcome-banner transforms."""
import argparse,json,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--ffdec',required=True,type=Path);a=p.parse_args()
import os
classpath=os.pathsep.join([str(a.ffdec/'ffdec.jar'),str(a.ffdec/'lib/*')])
subprocess.run(['java','--class-path',classpath,str(root/'tools/ExportResultsArt.java'),str(root/'Bomb It 1.swf'),str(root/'godot/art/original/results')],check=True)
n={'x':'http://ns.adobe.com/xfl/2008/'}
track=[None]*70
for f in ET.parse(root/'xfl/Bomb It 1/LIBRARY/Symbol 563.xml').findall('.//x:DOMFrame',n):
 body=f.find('x:elements/x:DOMSymbolInstance',n)
 if body is None:continue
 m=body.find('x:matrix/x:Matrix',n)
 value=[float(m.get(k,d)) for k,d in [('a',1),('b',0),('c',0),('d',1),('tx',0),('ty',0)]]
 for i in range(int(f.get('index')),int(f.get('index'))+int(f.get('duration','1'))):track[i]=value
path=root/'godot/art/original/results/manifest.json';manifest=json.loads(path.read_text());manifest['banner']=track
import hashlib
manifest['source_sha256']=hashlib.sha256((root/'Bomb It 1.swf').read_bytes()).hexdigest()
path.write_text(json.dumps(manifest,indent=2)+'\n')
