#!/usr/bin/env python3
"""Freeze the current complete Frame host. No kernel/assets changes or GPU work."""
from pathlib import Path
import argparse,hashlib,json,shutil
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--role',choices=['baseline','candidate'],required=True);p.add_argument('--exact-memory',action='store_true');a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
files=[]
for rel in ('src','Development/HIP'):
 for f in sorted((a.repo/rel).glob('*.h')):
  dest=a.out/rel/f.name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,dest);files.append(str(f.relative_to(a.repo)))
f=a.repo/'Development/HIP/benchmark_vit_reuse.cpp';shutil.copyfile(f,a.out/'Development/HIP'/f.name);files.append(str(f.relative_to(a.repo)))
if a.exact_memory:
 header=a.out/'Development/HIP/hip_reference_network.h';text=header.read_text();anchor='  if(opt.sparse_weights)std::fprintf(f,"hip_memory sparse_weights'
 pos=text.index(anchor);text=text[:pos]+'  std::fprintf(f,"hip_memory_exact weights_bytes=%zu pool_bytes=%zu gather_bytes=%zu noise_bytes=%zu driver_free_bytes=%zu driver_total_bytes=%zu not_resident_peak=1\\n",wsum,psum,gsum,nsum,free,total);\n'+text[pos:];header.write_text(text)
record={'role':a.role,'source_repo':str(a.repo),'scope':'complete existing NativeGameFrame caller; no kernel or HDR changes','sources':{f:hashlib.sha256((a.repo/f).read_bytes()).hexdigest() for f in files}}
record['exact_memory_diagnostic']=a.exact_memory
record['copied_header_sha256']=hashlib.sha256((a.out/'Development/HIP/hip_reference_network.h').read_bytes()).hexdigest()
(a.out/'source-identity.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'role':a.role,'files':len(files),'out':str(a.out)}))
