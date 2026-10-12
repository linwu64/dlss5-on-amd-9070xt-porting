#!/usr/bin/env python3
"""CPU-only immutable typed unit staging; never launches device work."""
import argparse, hashlib, json, shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
b=Path('/home/lmxxf/work/dlss5-resource-followups-build/projection-compact')
r=Path('/home/lmxxf/work/dlss5-dx12-recovery/vit/linear-inputs')
files={'unit.exe':b/'unit.exe','projection-compact.hsaco':b/'compiled/projection-compact.hsaco','canonical.hsaco':Path('/home/lmxxf/work/dlss5-dx12-recovery/vit/qkv-inputs/canonical-vit-stream-fast.hsaco'),'run-unit.ps1':Path(__file__).with_name('run-unit.ps1')}
for name,arg in [('input.bin',0),('weight.bin',1),('skip.bin',2),('gold.bin',3)]:files[name]=r/f'vit_stream_project_n64_bb-arg{arg}.bin'
rows=[]
for name,src in files.items():
 data=src.read_bytes();shutil.copyfile(src,a.output/name);rows.append(dict(file=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
assert next(x for x in rows if x['file']=='projection-compact.hsaco')['sha256']=='8cd0807f1364dfc4cc9cd13bdd96bca042fd2ab3db9e05e62d64d7762be15de6'
manifest=dict(scope='real640 projection only; unchanged FP8 prefix and F32 scales; original877e/new sidecar only export',args=['inputFP8','weight','skipFP8','outputF32',640,1024,1024,None],kernarg_bytes=56,grid=640,threads=32,files=rows)
(a.output/'unit-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(a.output/'unit-manifest.json')
