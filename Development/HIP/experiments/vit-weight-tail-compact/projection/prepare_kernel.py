#!/usr/bin/env python3
from pathlib import Path
import argparse,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
base=json.loads((Path(__file__).resolve().parents[1]/'results/cpu/kernel-source.json').read_text());defines=base['defines'];deep=(a.repo/'hip/deep_fast.hip').read_text();stream=(a.repo/'hip/vit_stream.inc').read_text()
old='template<uint TM,uint TN,bool ByteAv,bool HalfSkip,bool ByteSkip=false>';new='template<uint TM,uint TN,bool ByteAv,bool HalfSkip,bool ByteSkip=false,uint ScaleOffset=1048576>'
assert stream.count(old)==1;stream=stream.replace(old,new,1)
start=stream.index('DEV void vit_stream_project_tiles');end=stream.index('WAVE void vit_stream_project_n64_b(',start);body=stream[start:end];assert body.count('w[IN*OUT+row+j*16+rc()]')==1;stream=stream[:start]+body.replace('w[IN*OUT+row+j*16+rc()]','w[ScaleOffset+row+j*16+rc()]')+stream[end:]
entry='''\n#if VIT_CONTRACT_BYTE_EDGE && VIT_QKV_F8W
WAVE void vit_stream_project_n64_bb_compactw(const float*in,const float*w,const float*skip,float*out,uint tokens,uint inputs,uint outputs,const uint*reuse_gate){vit_stream_project_tiles<1,4,true,false,true,262144>(in,w,skip,out,tokens,reuse_gate);}
#endif
'''
source=''.join('#define '+x+'\n' for x in defines)+deep+'\n'+stream+'\n'+entry
(a.out/'projection-compact.generated.hip').write_text(source);(a.out/'new-export.inc').write_text(entry)
x=dict(defines=defines,opts='',target='gfx1201',old_export='vit_stream_project_n64_bb',new_export='vit_stream_project_n64_bb_compactw',old_scale_float_offset=1048576,new_scale_float_offset=262144,matrix_bytes=1048576,tail_bytes=4096,old_weight_bytes=4198400,new_weight_bytes=1052672,source_sha256=hashlib.sha256(source.encode()).hexdigest(),scope='projection only; default old tail preserves existing exports; same WMMA accumulation/rounding/skip math; new sidecar only new export')
(a.out/'kernel-source.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps(x,indent=2))
