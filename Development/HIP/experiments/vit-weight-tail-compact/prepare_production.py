#!/usr/bin/env python3
"""Emit a reviewable production patch and exact emitted helper sources; never apply it."""
from pathlib import Path
import argparse,difflib,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--projection-base',type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[4];private=r.parent/'dlss5-resource-followups-build/contract-compact/route/hip_reference_network.h';base=(r/'Development/HIP/hip_reference_network.h').read_text();private=(a.projection_base/'hip_reference_network.h') if a.projection_base else private;s=private.read_text().replace('#include "contract_compact_guard.h"\n','')
start=s.index('{const char*enable=std::getenv("NR_VIT_CONTRACT_COMPACT");');end=s.index('\n\n',start)
s=s[:start]+'InitCompactContract();'+s[end:]
if a.projection_base:
 start=s.index('{const char*enable=std::getenv("NR_VIT_PROJECTION_COMPACT");');end=s.index('\n\n',start);s=s[:start]+'InitCompactProjection();'+s[end:]
start=s.index(' // Experiment only: pointer tags');end=s.index(' void* PackedVitProjectionFrag(',start)
helpers=s[start:end]
init='''
#ifndef HIP_COMPACT_VIT_CONTRACT
#define HIP_COMPACT_VIT_CONTRACT 1
#endif
 bool CompactVitTailDeviceEligible(){hip_probe::DevicePropertiesR0600 props{};return !api.hipGetDevicePropertiesR0600(&props,int(opt.device))&&!std::strncmp(props.gcnArchName,"gfx1201",7)&&(props.gcnArchName[7]==0||props.gcnArchName[7]==':')&&std::strstr(props.name,"9070 XT");}
 void InitCompactContract(){
#if HIP_COMPACT_VIT_CONTRACT
  const bool device_ok=CompactVitTailDeviceEligible();
  if(device_ok&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&!opt.vit_split_k&&!opt.vit_ffn_fused&&HasFn("vit_stream","vit_stream_contract_frag_bout_compactw"))compact_contract_fn=Fn("vit_stream","vit_stream_contract_frag_bout_compactw");
#endif
 }
'''
if a.projection_base:
 init+='''
#ifndef HIP_COMPACT_VIT_PROJECTION
#define HIP_COMPACT_VIT_PROJECTION 1
#endif
 void InitCompactProjection(){
#if HIP_COMPACT_VIT_PROJECTION
  if(CompactVitTailDeviceEligible()&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&vit_proj_n64_active&&opt.vit_proj_frag&&HasFn("vit_stream","vit_stream_project_n64_bb_compactw"))compact_projection_fn=Fn("vit_stream","vit_stream_project_n64_bb_compactw");
#endif
 }
'''
s=s[:start]+helpers+init+s[end:]
# Exact memory line belongs only to diagnostic experiment, never production.
s='\n'.join(line for line in s.split('\n') if 'hip_memory_exact weights_bytes=' not in line)
(a.out/'hip_reference_network.h').write_text(s);(a.out/'emitted_helpers.inc').write_text(helpers+init)
old=(r/'hip/deep_fast.hip').read_text();new=old.replace('bool ByteFOut=false>\nDEV void vit_contract_blocked_body','bool ByteFOut=false,uint ScaleOffset=4194304>\nDEV void vit_contract_blocked_body',1);i=new.index('DEV void vit_contract_blocked_body');j=new.index('// Fragment-weight twin',i);new=new[:i]+new[i:j].replace('w[4194304+c]','w[ScaleOffset+c]')+new[j:]
stream=(r/'hip/vit_stream.inc').read_text();newstream=stream
if a.projection_base:
 newstream=newstream.replace('template<uint TM,uint TN,bool ByteAv,bool HalfSkip,bool ByteSkip=false>','template<uint TM,uint TN,bool ByteAv,bool HalfSkip,bool ByteSkip=false,uint ScaleOffset=1048576>',1).replace('w[IN*OUT+row+j*16+rc()]','w[ScaleOffset+row+j*16+rc()]',1)
entry=(Path(__file__).with_name('contract-compact-export.inc')).read_text()
if a.projection_base:entry+='\n'+(a.projection_base.parent/'kernel/new-export.inc').read_text()
changes=[('Development/HIP/hip_reference_network.h',base,s),('hip/deep_fast.hip',old,new),('hip/vit_stream.inc',stream,newstream+'\n'+entry)]
(a.out/'deep_fast.hip').write_text(new);(a.out/'vit_stream.inc').write_text(newstream+'\n'+entry)
defines=json.loads((Path(__file__).with_name('results')/'cpu/kernel-source.json').read_text())['defines']
combined=''.join('#define '+x+'\n' for x in defines)+new+'\n'+newstream+'\n'+entry+'\n'
(a.out/'joint-vit-stream.generated.hip').write_text(combined)
(a.out/'joint-module-source.json').write_text(json.dumps(dict(defines=defines,target='gfx1201',opts='',source_sha256=hashlib.sha256(combined.encode()).hexdigest(),scope='natural current vit-stream-fast recipe; both new compact exports; existing exports retain old default tails'),indent=2)+'\n')
patch=''.join(''.join(difflib.unified_diff(x.splitlines(True),y.splitlines(True),fromfile='a/'+name,tofile='b/'+name)) for name,x,y in changes)
(a.out/'production.patch').write_text(patch);(a.out/'identity.json').write_text(json.dumps({'status':'review only, unapplied','header_sha256':hashlib.sha256(s.encode()).hexdigest(),'patch_sha256':hashlib.sha256(patch.encode()).hexdigest()},indent=2)+'\n');print(a.out)
