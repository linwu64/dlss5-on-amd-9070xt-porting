#!/usr/bin/env python3
"""Freeze the current complete Frame host. No kernel/assets changes or GPU work."""
from pathlib import Path
import argparse,hashlib,json,shutil
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--role',choices=['baseline','candidate'],required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
files=[]
for rel in ('src','Development/HIP'):
 for f in sorted((a.repo/rel).glob('*.h')):
  dest=a.out/rel/f.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dest);files.append(str(f.relative_to(a.repo)))
f=a.repo/'Development/HIP/benchmark_vit_reuse.cpp';shutil.copyfile(f,a.out/'Development/HIP'/f.name);files.append(str(f.relative_to(a.repo)))
record={'role':a.role,'source_repo':str(a.repo),'scope':'complete existing NativeGameFrame caller; no kernel or HDR changes','sources':{f:hashlib.sha256((a.repo/f).read_bytes()).hexdigest() for f in files}}
(a.out/'source-identity.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'role':a.role,'files':len(files),'out':str(a.out)}))
