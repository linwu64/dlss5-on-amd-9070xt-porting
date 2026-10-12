#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();r=Path(__file__).resolve().parents[5];a.out.mkdir(parents=True,exist_ok=True)
deep=(r/'hip/deep_fast.hip').read_text();stream=(r/'hip/vit_stream.inc').read_text()
name='vit_stream_qkv_frag_bin_w5f8';begin=stream.index('KERNEL __attribute__((amdgpu_flat_work_group_size(160,160))) void '+name);end=stream.index('\n}\n',begin)+3;body=stream[begin:end]
old=' __builtin_amdgcn_s_barrier();\n float*raw=reinterpret_cast<float*>(lds)+wv*(16*33);'
assert body.count(old)==1
candidate=body.replace(name,name+'_vtail',1).replace(old,' if(part<2)__builtin_amdgcn_s_barrier();\n float*raw=reinterpret_cast<float*>(lds)+wv*(16*33);',1)
assert candidate.count('__builtin_amdgcn_s_barrier()')==body.count('__builtin_amdgcn_s_barrier()')
defines=['HIP_ISA_HALF 1','VIT_CONTRACT_BYTE_EDGE 1','HIP_PREPACKED_WEIGHTS 1','HIP_BRANCHLESS_F 1','HIP_VIT_STREAM_KERNELS 1','HIP_VIT_QKV_W5 1','VIT_CONTRACT_OCC_LDS 4096','VIT_QKV_F8W 1','VIT_FAST_NUM 4'];prefix=''.join('#define '+x+'\n'for x in defines)
source=prefix+deep+'\n'+stream+'\n#if VIT_CONTRACT_BYTE_EDGE && VIT_QKV_F8W\n'+candidate+'\n#endif\n'
(a.out/'candidate.hip').write_text(source);(a.out/'new-export.inc').write_text(candidate)
d={'base':'4a9d7eee parent79599997','stock_module_sha256':'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014','stock_export':name,'candidate_export':name+'_vtail','source_sha256':hashlib.sha256(source.encode()).hexdigest(),'source_inputs':{str(f.relative_to(r)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [r/'hip/deep_fast.hip',r/'hip/vit_stream.inc']},'defines':defines,'opts':'','target':'gfx1201','only_change':'WG-uniform part<2 guards final post-K barrier; all loop/norm barriers and original live exit retained','stage2_started':False}
(a.out/'source.json').write_text(json.dumps(d,indent=2)+'\n');print(json.dumps(d,indent=2))
