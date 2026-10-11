#!/usr/bin/env python3
import argparse,hashlib,json,struct,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output;out.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[4]
subprocess.run(['python3',str(Path(__file__).parent/'prepare_primitive.py'),'--output',str(out)],check=True)
src=out/'primitive-canonical.hip';cuid=hashlib.sha256(struct.pack('<Q',src.stat().st_size)+src.read_bytes()).hexdigest().upper()
base=r/'Development/results/c32-norm-transpose-20261006'
commands=[json.loads((base/'canonical-commands.json').read_text())['A'][0]]+json.loads((base/'object-commands.json').read_text())['A']
map_paths={'A.hip':src,'A-canonical.bc':out/'primitive.bc','A-canonical.o':out/'primitive.o','A-canonical.hsaco':out/'primitive.hsaco'}
new=[]
for cmd in commands:
 new.append([('-cuid='+cuid if x.startswith('-cuid=') else str(map_paths[Path(x).name]) if x.startswith('/tmp/c32-norm-transpose-20261006/') else x) for x in cmd])
log=out/'build.log';results=[]
with log.open('w') as f:
 for cmd in new:
  print('CPU_STEP',len(results),flush=True);f.write(json.dumps(cmd)+'\n');f.flush();t=time.monotonic();q=subprocess.run(cmd,stdout=f,stderr=f)
  results.append(dict(command=cmd,exit=q.returncode,seconds=time.monotonic()-t))
  if q.returncode:break
receipt=dict(commands=results,actual_exit_code=results[-1]['exit'],scope='CPU canonical route compilation only')
if receipt['actual_exit_code']==0:receipt['module_sha256']=hashlib.sha256((out/'primitive.hsaco').read_bytes()).hexdigest()
(out/'build-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('CPU_BUILD_EXIT',receipt['actual_exit_code'],flush=True);raise SystemExit(receipt['actual_exit_code'])
