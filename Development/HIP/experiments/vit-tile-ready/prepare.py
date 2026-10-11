from pathlib import Path
import argparse,importlib.util,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('recipes',r/'Development/tools/llvm-fork/compile-modules.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
name,compiler,s,defs,files,opts=next(x for x in m.recipe(r/'hip') if x[0]=='vit-stream-fast')
# Preserve the entire production source and original exports. Add twins only.
contract='vit_stream_contract_frag_bout';qkv='vit_stream_qkv_frag_bin_w5f8'
def extract(name):
 start=s.index('WAVE void '+name) if name==contract else s.index('KERNEL __attribute__((amdgpu_flat_work_group_size(160,160))) void '+name)
 opening=s.index('{',start);level=1;i=opening+1
 while level:
  level+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[start:i]
c=extract(contract);q=extract(qkv)
c=c.replace(contract+'(',contract+'_ready(',1).replace('const uint*reuse_gate){','const uint*reuse_gate,uint*ready,unsigned long long*trace){',1)
opening=c.index('{')+1
c=c[:opening]+'''if(tokens%16)return; uint lane=__builtin_amdgcn_workitem_id_x();uint group=bid();
 if(lane==0)trace[group*2]=__builtin_amdgcn_s_sendmsg_rtnl(131);
'''+c[opening:-1]+'''
 // Single-wave producer: block barrier orders every lane's completed output stores,
 // then all lanes execute an agent release, followed by collective synchronization.
 __builtin_amdgcn_s_barrier();
 __builtin_amdgcn_fence(__ATOMIC_RELEASE,"agent");
 __builtin_amdgcn_s_barrier();
 if(lane==0){trace[group*2+1]=__builtin_amdgcn_s_sendmsg_rtnl(131);
 __hip_atomic_fetch_add(ready+group/16,1u,__ATOMIC_ACQ_REL,__HIP_MEMORY_SCOPE_AGENT);}
}'''
q=q.replace(qkv+'(',qkv+'_ready(',1).replace('const uint*reuse_gate){','const uint*reuse_gate,uint*ready,unsigned long long*trace,uint*status){',1)
needle=' const bool live=first<tokens;'
assert q.count(needle)==1
q=q.replace(needle,needle+'''
 __attribute__((shared)) uint failed[5];
 const uint qb=bid(),tracebase=tokens*2+qb*3;
 if(t==0)trace[tracebase]=__builtin_amdgcn_s_sendmsg_rtnl(131);
 uint ok=1;
 if(lane==0&&live){uint iterations=0;
  while(__hip_atomic_load(ready+first/16,__ATOMIC_ACQUIRE,__HIP_MEMORY_SCOPE_AGENT)<16u){
   if(++iterations==1000000u){ok=0;break;}__builtin_amdgcn_s_sleep(1);}
 }
 if(lane==0)failed[wv]=ok?0u:1u;
 __builtin_amdgcn_s_barrier();
 uint bad=failed[0]|failed[1]|failed[2]|failed[3]|failed[4];
 if(bad){if(t==0)status[qb]=1;return;}
 // All live waves acquired their tile before any input read; no early return crosses a barrier.
 __builtin_amdgcn_fence(__ATOMIC_ACQUIRE,"agent");
 if(t==0)trace[tracebase+1]=__builtin_amdgcn_s_sendmsg_rtnl(131);
''',1)
# Final timestamp must execute in t0 even for a non-live wave; wave0 always live on legal full tiles.
q=q[:-1]+'''\n if(t==0)trace[tracebase+2]=__builtin_amdgcn_s_sendmsg_rtnl(131);\n}'''
s+='\n#if VIT_CONTRACT_BYTE_EDGE && VIT_QKV_F8W\n'+c+'\n'+q+'\n#endif\n'
(a.output/'candidate.hip').write_text(s)
(a.output/'source.json').write_text(json.dumps({'base':'30040d4c81d486d66b588da0dcb5ac67a67b5c41','row':name,'compiler':compiler,'defines':defs,'opts':opts,'sha256':hashlib.sha256(s.encode()).hexdigest(),'counter':'fresh uint per 16 tokens, target16; all RMW acq_rel; bounded acquire load','trace':'u64 producer[tokens][start,end], consumer[96*ceil(tokens/80)][enter,ready,end]; gfx12 MSG_RTN_GET_REALTIME=131'},indent=2)+'\n')
print(json.dumps({'source':str(a.output/'candidate.hip'),'sha256':hashlib.sha256(s.encode()).hexdigest(),'bytes':len(s)}))
