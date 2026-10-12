#!/usr/bin/env python3
"""Sidecar contract export only; legacy module is never replaced or called here."""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[4]);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r=a.repo;deep=(r/'hip/deep_fast.hip').read_text();stream=(r/'hip/vit_stream.inc').read_text()
old='template<bool Partial,bool Tiled=false,bool ByteStream=false,bool HalfOut=false,bool Frag=false,bool ByteFOut=false>\nDEV void vit_contract_blocked_body'
new='template<bool Partial,bool Tiled=false,bool ByteStream=false,bool HalfOut=false,bool Frag=false,bool ByteFOut=false,uint ScaleOffset=4194304>\nDEV void vit_contract_blocked_body'
assert deep.count(old)==1;deep=deep.replace(old,new,1)
start=deep.index('DEV void vit_contract_blocked_body');end=deep.index('// Fragment-weight twin',start);body=deep[start:end];assert body.count('w[4194304+c]')==1;deep=deep[:start]+body.replace('w[4194304+c]','w[ScaleOffset+c]')+deep[end:]
entry='''\n// New ABI-name, identical argument layout/math; only scalar tail address differs.
#if VIT_CONTRACT_BYTE_EDGE && VIT_QKV_F8W
WAVE void vit_stream_contract_frag_bout_compactw(const float*in,const float*w,const float*skip,float*out,uint tokens,uint inputs,uint outputs,const uint*reuse_gate){if(reuse_gate&&reuse_gate[0])return;if(inputs==4096&&outputs==1024)vit_contract_blocked_body<false,false,false,false,true,true,1048576>(in,w,skip,out,tokens);}
#endif
'''
# Same actual current vit-stream-fast recipe, no unsafe fast-math compiler option.
defines=['HIP_ISA_HALF 1','VIT_CONTRACT_BYTE_EDGE 1','HIP_PREPACKED_WEIGHTS 1','HIP_BRANCHLESS_F 1','HIP_VIT_STREAM_KERNELS 1','HIP_VIT_QKV_W5 1','VIT_CONTRACT_OCC_LDS 4096','VIT_QKV_F8W 1','VIT_FAST_NUM 4']
base=''.join('#define '+x+'\n'for x in defines)
(a.out/'stock.generated.hip').write_text(base+(r/'hip/deep_fast.hip').read_text()+'\n'+stream+'\n')
(a.out/'contract-compact.generated.hip').write_text(base+deep+'\n'+stream+'\n'+entry)
(a.out/'new-export.inc').write_text(entry)
manifest={'baseline':'a5786fbb stage1+B; stage2 reverted','stock_runtime_module_sha256':'877eaf122f827af6e00824582f5ca918b5d61499d4ad7c7cde7ab6e422516a57','old_export':'vit_stream_contract_frag_bout','new_export':'vit_stream_contract_frag_bout_compactw','same_argument_abi':True,'old_scale_float_index':4194304,'new_scale_float_index':1048576,'matrix_bytes':4194304,'tail_bytes':4096,'new_weight_bytes':4198400,'old_weight_bytes':16781312,'defines':defines,'opts':'','sources':{n:hashlib.sha256((a.out/n).read_bytes()).hexdigest()for n in ['stock.generated.hip','contract-compact.generated.hip','new-export.inc']},'legacy_default_template_offset_unchanged':True,'new_module_sidecar_only':True,'legacy_exports_of_sidecar_never_used':True,'numeric_gold_pass':False}
(a.out/'kernel-source.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
