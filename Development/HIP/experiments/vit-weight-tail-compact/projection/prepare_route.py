#!/usr/bin/env python3
from pathlib import Path
import argparse,json,hashlib,shutil
p=argparse.ArgumentParser();p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True);s=(a.base/'hip_reference_network.h').read_text()
anchor=' void* PackedVitProjectionFrag('
i=s.index(anchor)
s=s[:i]+''' Handle compact_projection_fn{};std::set<void*> compact_projection_ptrs;
 void* CompactProjectionWeight(const std::string&name){
  const bool known=name.size()==22&&name.compare(0,6,"block3")==0&&name[6]>='1'&&name[6]<='8'&&name.compare(7,15,"-projection.f32")==0;
  if(!compact_projection_fn||!known||opt.sparse_weights)return PackedVitProjectionFrag(name);
  const auto legacy=name+"@vit-proj-frag";auto old=weights.find(legacy);if(old!=weights.end())return P(old->second);
  const auto key=legacy+"@compact-projection";auto it=weights.find(key);
  if(it==weights.end()){
   auto v=ReadWeights(opt.assets+"/"+name);if(v.size()!=1048576+1024||v.size()!=WeightElements(name))throw std::runtime_error("compact projection weight shape");
   Fp8(v,{{0,1048576}});FragmentPackedMatrix(v,0,1024,1024);
   std::memmove(v.data()+262144,v.data()+1048576,4096);v.resize(262144+1024);dead.clear();
   it=weights.emplace(key,Upload(v.data(),v.size()*sizeof(float),true)).first;compact_projection_ptrs.insert(P(it->second));
   std::fprintf(stderr,"PROJECTION_COMPACT key=%s bytes=1052672 legacy_held=0\\n",key.c_str());
  }return P(it->second);
 }
'''+s[i:]
old='PackedVitProjectionFrag(Block(block,"projection"))';assert s.count(old)==1;s=s.replace(old,'((vit_contract_byte_edge&&vit_proj_n64_active)?CompactProjectionWeight(Block(block,"projection")):PackedVitProjectionFrag(Block(block,"projection")))')
anchor='std::fprintf(stderr,"vit_contract_byte_edge=%u\\n",unsigned(vit_contract_byte_edge));'
cold='''
{const char*enable=std::getenv("NR_VIT_PROJECTION_COMPACT");
 if(enable&&!std::strcmp(enable,"1")&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&vit_proj_n64_active&&opt.vit_proj_frag){
  const auto stock=opt.modules+"/vit-stream-fast.hsaco",candidate=opt.modules+"/vit-projection-compact.hsaco";
  if(ContractCompactFileSha(stock,"877eaf122f827af6e00824582f5ca918b5d61499d4ad7c7cde7ab6e422516a57")&&ContractCompactFileSha(candidate,"8cd0807f1364dfc4cc9cd13bdd96bca042fd2ab3db9e05e62d64d7762be15de6")){
   Handle m{},fn{};if(!api.LoadModule(&m,candidate.c_str())){modules["projection_compact"]=m;if(!api.hipModuleGetFunction(&fn,m,"vit_stream_project_n64_bb_compactw"))compact_projection_fn=fn;}
  }
 }std::fprintf(stderr,"PROJECTION_COMPACT_COLD requested=%u ready=%u\\n",unsigned(enable&&!std::strcmp(enable,"1")),unsigned(compact_projection_fn!=nullptr));}
'''
assert s.count(anchor)==1;s=s.replace(anchor,anchor+cold)
anchor='unsigned repeats_here=launch_repeats*';assert s.count(anchor)==1
s=s.replace(anchor,'if(kernel=="vit_stream_project_n64_bb"){if(sizeof...(A)!=7)throw std::runtime_error("projection ABI count");void*wp{};std::memcpy(&wp,argv[1],sizeof(wp));if(compact_projection_ptrs.count(wp)){if(!compact_projection_fn)throw std::runtime_error("compact projection without paired function");paired_contract_fn=compact_projection_fn;}}'+anchor)
(a.output/'hip_reference_network.h').write_text(s);shutil.copyfile(a.base/'contract_compact_guard.h',a.output/'contract_compact_guard.h')
(a.output/'route-source.json').write_text(json.dumps(dict(base_contract_header_sha256=hashlib.sha256((a.base/'hip_reference_network.h').read_bytes()).hexdigest(),private_header_sha256=hashlib.sha256(s.encode()).hexdigest(),scope='contract remains independently enabled; new projection only actual bb consumer; oldcache/unknown/missing candidate retains oldpair; cold-only load/hash/function'),indent=2)+'\n');print(a.output)
