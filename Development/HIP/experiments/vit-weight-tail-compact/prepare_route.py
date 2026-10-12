#!/usr/bin/env python3
"""Private paired storage/export route; production headers are never modified."""
import argparse,hashlib,json,shutil
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[4];src=root/'Development/HIP/hip_reference_network.h';s=src.read_text(); original=hashlib.sha256(src.read_bytes()).hexdigest()
s=s.replace('#include "packed_weights.h"','#include "packed_weights.h"\n#include "contract_compact_guard.h"',1)
anchor=' void* PackedVitProjectionFrag('
pos=s.index(anchor)
s=s[:pos]+''' // Experiment only: pointer tags and cold cached function are a single layout contract.
 Handle compact_contract_fn{};std::set<void*> compact_contract_ptrs;
 void* CompactContractWeight(const std::string&name,U rows,U cols,bool tiled,bool frag){
  const bool known=name.size()==20&&name.compare(0,6,"block3")==0&&name[6]>='1'&&name[6]<='8'&&name.compare(7,13,"-contract.f32")==0;
  if(!compact_contract_fn||!known||rows!=1024||cols!=4096||!tiled||!frag||opt.sparse_weights)return PackedVitWeight(name,rows,cols,tiled,frag);
  const auto legacy=name+"@vit-frag";auto old=weights.find(legacy);if(old!=weights.end())return P(old->second);
  const auto key=legacy+"@compact-contract";auto it=weights.find(key);
  if(it==weights.end()){
   auto v=ReadWeights(opt.assets+"/"+name);if(v.size()!=4194304+1024||v.size()!=WeightElements(name))throw std::runtime_error("compact contract weight shape");
   Fp8(v,{{0,4194304}});FragmentPackedMatrix(v,0,1024,4096);
   std::memmove(v.data()+1048576,v.data()+4194304,4096);v.resize(1048576+1024);dead.clear();
   it=weights.emplace(key,Upload(v.data(),v.size()*sizeof(float),true)).first;
   compact_contract_ptrs.insert(P(it->second));
   std::fprintf(stderr,"CONTRACT_COMPACT key=%s bytes=4198400 legacy_held=0\\n",key.c_str());
  }return P(it->second);
 }
''' +s[pos:]
# Only the actual byte-edge contract call can request compact storage. Other consumers remain legacy.
old='P(hidden),PackedVitWeight(Block(block,"contract"),1024,4096,true,true),P(input),P(contract),n,U(4096),U(1024)'
new='P(hidden),(vit_contract_byte_edge?CompactContractWeight(Block(block,"contract"),1024,4096,true,true):PackedVitWeight(Block(block,"contract"),1024,4096,true,true)),P(input),P(contract),n,U(4096),U(1024)'
assert s.count(old)==1;s=s.replace(old,new)
anchor='std::fprintf(stderr,"vit_contract_byte_edge=%u\\n",unsigned(vit_contract_byte_edge));'
cold='''
{const char*enable=std::getenv("NR_VIT_CONTRACT_COMPACT");
 if(enable&&!std::strcmp(enable,"1")&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&!opt.vit_split_k&&!opt.vit_ffn_fused){
  const auto stock=opt.modules+"/vit-stream-fast.hsaco",candidate=opt.modules+"/vit-contract-compact.hsaco";
  if(ContractCompactFileSha(stock,"877eaf122f827af6e00824582f5ca918b5d61499d4ad7c7cde7ab6e422516a57")&&ContractCompactFileSha(candidate,"14facdb57be7b3864b913a99ebe42604c9add4ed4f8bf032b2b04235897ec83f")){
   Handle m{},fn{};if(!api.LoadModule(&m,candidate.c_str())){modules["contract_compact"]=m;if(!api.hipModuleGetFunction(&fn,m,"vit_stream_contract_frag_bout_compactw"))compact_contract_fn=fn;}
  }
 }std::fprintf(stderr,"CONTRACT_COMPACT_COLD requested=%u ready=%u\\n",unsigned(enable&&!std::strcmp(enable,"1")),unsigned(compact_contract_fn!=nullptr));}
'''
assert s.count(anchor)==1;s=s.replace(anchor,anchor+cold)
anchor='unsigned repeats_here=launch_repeats*'
assert s.count(anchor)==1
s=s.replace(anchor,'Handle paired_contract_fn{};if(kernel=="vit_stream_contract_frag_bout"){if(sizeof...(A)!=7)throw std::runtime_error("contract ABI count");void*wp{};std::memcpy(&wp,argv[1],sizeof(wp));if(compact_contract_ptrs.count(wp)){if(!compact_contract_fn)throw std::runtime_error("compact weight without paired function");paired_contract_fn=compact_contract_fn;}}'+anchor)
s=s.replace('ext_launch(Fn(module,kernel),','ext_launch(paired_contract_fn?paired_contract_fn:Fn(module,kernel),').replace('hipModuleLaunchKernel(Fn(module,kernel),','hipModuleLaunchKernel(paired_contract_fn?paired_contract_fn:Fn(module,kernel),')
anchor='  if(opt.sparse_weights)std::fprintf(f,"hip_memory sparse_weights'
pos=s.index(anchor);s=s[:pos]+'  std::fprintf(f,"hip_memory_exact weights_bytes=%zu pool_bytes=%zu gather_bytes=%zu noise_bytes=%zu driver_free_bytes=%zu driver_total_bytes=%zu not_resident_peak=1\\n",wsum,psum,gsum,nsum,free,total);\n'+s[pos:]
out=a.output;out.mkdir(parents=True,exist_ok=True);(out/'hip_reference_network.h').write_text(s);shutil.copyfile(Path(__file__).with_name('contract_compact_guard.h'),out/'contract_compact_guard.h')
(out/'route-source.json').write_text(json.dumps(dict(base_sha256=original,private_sha256=hashlib.sha256(s.encode()).hexdigest(),scope='only contract byte edge; cold SHA/export guard; legacy pointer stays legacy function',candidate_sha256='14facdb57be7b3864b913a99ebe42604c9add4ed4f8bf032b2b04235897ec83f'),indent=2)+'\n')
print(out)
