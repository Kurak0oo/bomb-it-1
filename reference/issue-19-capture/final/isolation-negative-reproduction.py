import json,os,subprocess
from pathlib import Path
root=Path('.artifacts/issue19-isolation-negative').resolve();root.mkdir(exist_ok=True)
exe=Path('.artifacts/issue19-final-smoke/8f7e2ffa113c/application/BombIt.exe').resolve()
env=os.environ.copy();env.update(APPDATA=str(root/'actual-user-root'),XDG_DATA_HOME=str(root/'actual-user-root'),BOMB_IT_SMOKE_USER_ROOT=str(root/'wrong-root'),BOMB_IT_SMOKE_OUTPUT=str(root),BOMB_IT_SMOKE_PHASE='play')
command=[str(exe),'--audio-driver','Dummy','--','--package-smoke']
with (root/'stdout.log').open('w',encoding='utf-8') as log:
 result=subprocess.run(command,env=env,cwd=exe.parent,stdout=log,stderr=subprocess.STDOUT,timeout=15)
text=(root/'stdout.log').read_text(encoding='utf-8')
prefs=list((root/'actual-user-root').rglob('preferences.cfg'))
report={'command':command,'exit_code':result.returncode,'guard_observed':'requires a verified isolated user-data root' in text,'preference_files_written':[str(p) for p in prefs]}
report['passed']=result.returncode!=0 and report['guard_observed'] and not prefs
(root/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
raise SystemExit(0 if report['passed'] else 1)
