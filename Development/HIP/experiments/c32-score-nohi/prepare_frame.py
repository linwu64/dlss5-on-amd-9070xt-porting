#!/usr/bin/env python3
from pathlib import Path
import argparse,shutil,subprocess,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--shader',type=Path,required=True);a=p.parse_args();r=Path(__file__).resolve().parents[4]
baseline_header=(r/'Development/HIP/hip_reference_network.h').read_bytes()
if b'HIP_COMPACT_VIT_EXPAND' in baseline_header or hashlib.sha256(baseline_header).hexdigest()!='5034a59eee96538b90ec25636d5873fbe4ef768ec14d0b808bdd00b81777d085':
 raise SystemExit('A reproduction requires the original b93cc043 baseline checkout; current shared header differs or contains compact experiment B. No files generated.')
a.output.mkdir(parents=True,exist_ok=True)
for rel in ['src','Development/HIP']:
 d=a.output/rel;d.mkdir(parents=True,exist_ok=True)
 for f in (r/rel).glob('*.h'):shutil.copy2(f,d/f.name)
caller=r/'Development/HIP/benchmark_vit_reuse.cpp';shutil.copy2(caller,a.output/'Development/HIP/benchmark_vit_reuse.cpp')
subprocess.run(['python3',str(Path(__file__).parent/'prepare_route.py'),'--output',str(a.output/'Development/HIP'),'--shader',str(a.shader)],check=True)
(a.output/'source-identity.json').write_text(json.dumps(dict(base='b93cc043',original_caller=str(caller),caller_sha256=hashlib.sha256(caller.read_bytes()).hexdigest(),private_header_sha256=hashlib.sha256((a.output/'Development/HIP/hip_reference_network.h').read_bytes()).hexdigest(),scope='ordinary complete NativeGameFrame copied without compact changes, NR env controls same executable'),indent=2)+'\n')
print('PRIVATE_FRAME',a.output)
