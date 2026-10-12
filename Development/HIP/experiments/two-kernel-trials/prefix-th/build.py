#!/usr/bin/env python3
"""One frozen LLVM23 CPU-only compile, permitted only after Stage1 sealed."""
from pathlib import Path
import argparse,json,hashlib,struct,subprocess,time
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
if (a.out/'candidate.hsaco').exists():raise RuntimeError('existing artifact: no automatic repeat')
r=Path(__file__).resolve().parents[5]
subprocess.run(['git','merge-base','--is-ancestor','f0e40e10','HEAD'],cwd=r,check=True)
subprocess.run(['python3',str(Path(__file__).with_name('prepare_source.py')),'--out',str(a.out)],check=True)
src=a.out/'prefix-main-nt.generated.hip';cuid=hashlib.sha256(struct.pack('<Q',src.stat().st_size)+src.read_bytes()).hexdigest().upper()
ref=r/'Development/results/c32-norm-transpose-20261006';commands=[json.loads((ref/'canonical-commands.json').read_text())['A'][0]]+json.loads((ref/'object-commands.json').read_text())['A']
paths={'A.hip':src,'A-canonical.bc':a.out/'candidate.bc','A-canonical.o':a.out/'candidate.o','A-canonical.hsaco':a.out/'candidate.hsaco'}
actual=[[('-cuid='+cuid if arg.startswith('-cuid=') else str(paths[Path(arg).name]) if arg.startswith('/tmp/c32-norm-transpose-20261006/') else arg) for arg in cmd] for cmd in commands]
steps=[]
with (a.out/'compile.log').open('w') as f:
 for cmd in actual:
  print('LLVM23_CPU_STEP',len(steps),flush=True);f.write(json.dumps(cmd)+'\n');f.flush();t=time.monotonic();q=subprocess.run(cmd,stdout=f,stderr=f);steps.append(dict(command=cmd,exit_code=q.returncode,seconds=time.monotonic()-t))
  if q.returncode:break
x=dict(stage1_sealed='f0e40e10',source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),compiler_sha256=hashlib.sha256(Path(actual[0][0]).read_bytes()).hexdigest(),steps=steps,actual_exit_code=steps[-1]['exit_code'],scope='CPU offline compilation only, no device/RTC; not ISA/numerical/performance acceptance')
if x['actual_exit_code']==0:x['module_sha256']=hashlib.sha256((a.out/'candidate.hsaco').read_bytes()).hexdigest()
(a.out/'compile-receipt.json').write_text(json.dumps(x,indent=2)+'\n');print('ACTUAL_CPU_EXIT',x['actual_exit_code'],flush=True);raise SystemExit(x['actual_exit_code'])
