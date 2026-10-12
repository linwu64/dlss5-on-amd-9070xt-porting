#!/usr/bin/env python3
"""Stage2 CPU source generation only. Never compiles, loads or executes a module."""
from pathlib import Path
import argparse,hashlib,importlib.util,json
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[5]
spec=importlib.util.spec_from_file_location('stock_recipe',r/'Development/tools/llvm-fork/compile-modules.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
row,compiler,source,defines,files,opts=next(x for x in m.recipe(r/'hip') if x[0]=='c32-wave1-fast')
base=source
old='bool PostRGBA=false,bool PostTap=false>\nDEV void cw_body'
new='bool PostRGBA=false,bool PostTap=false,bool PrefixMainNT=false>\nDEV void cw_body'
assert source.count(old)==1;source=source.replace(old,new,1)
store='__builtin_memcpy(__builtin_assume_aligned(reinterpret_cast<unsigned char*>(main)+((ty+t/8)*width+tx+t%8)*32+cg*8,8),&b,8);'
assert source.count(store)==1
nt='__builtin_nontemporal_store(b,reinterpret_cast<i2*>(__builtin_assume_aligned(reinterpret_cast<unsigned char*>(main)+((ty+t/8)*width+tx+t%8)*32+cg*8,8)));'
source=source.replace(store,'if constexpr(PrefixMainNT){'+nt+'}else{'+store+'}',1)
oldentry=next(line for line in source.splitlines() if line.startswith('CW_ENTRY void c32_wave1_prefix_b8d('))
entry=oldentry.replace('c32_wave1_prefix_b8d(', 'c32_wave1_prefix_b8d_main_nt(').replace('cw_body<false,true,false,false,true,false,false,true>','cw_body<false,true,false,false,true,false,false,true,false,false,false,false,true>')
assert entry!=oldentry and 'PrefixMainNT' not in entry
source+='\n#if CW_PREPOST_BYTE\n'+entry+'\n#endif\n'
(a.out/'stock-canonical.hip').write_text(base);(a.out/'prefix-main-nt.generated.hip').write_text(source)
manifest=dict(stage=2,status='CPU source only; forbidden compile/device until stage1 sealed by coordinator',row=row,compiler=compiler,defines=defines,opts=opts,original_sources=files,stock_module_sha256='f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52',stock_source_sha256=hashlib.sha256(base.encode()).hexdigest(),candidate_source_sha256=hashlib.sha256(source.encode()).hexdigest(),old_export='c32_wave1_prefix_b8d',new_export='c32_wave1_prefix_b8d_main_nt',main_bytes_at1152=70778880,down_bytes_at1152=17694720,expected_main_store_sites=['0x4f10c','0x4f1c4','0x4f27c','0x4f334','0x4f3ec','0x4f4a4','0x4f584','0x4f5c0'],down_store_sites_untouched=['0x4f92c','0x4f968'],source_contract='one vector8B main-store expression only; original template default false; appended new export selects true; down/values/loads/rounding/scope/fence unchanged',required_future_isa_gate='builtin metadata is not proof: only eight main store TH bits may differ, resource/other instruction/scope must match; otherwise stop',benefit_unknown=True,cache_miss_evidence=False)
(a.out/'source-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:manifest[k] for k in ['stage','status','stock_source_sha256','candidate_source_sha256','new_export']},indent=2))
