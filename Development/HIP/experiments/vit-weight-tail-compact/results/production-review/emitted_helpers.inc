 // Experiment only: pointer tags and cold cached function are a single layout contract.
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
   std::fprintf(stderr,"CONTRACT_COMPACT key=%s bytes=4198400 legacy_held=0\n",key.c_str());
  }return P(it->second);
 }

#ifndef HIP_COMPACT_VIT_CONTRACT
#define HIP_COMPACT_VIT_CONTRACT 1
#endif
 void InitCompactContract(){
#if HIP_COMPACT_VIT_CONTRACT
  char device[256]{};const bool device_ok=!api.hipDeviceGetName(device,256,int(opt.device))&&std::strstr(device,"9070 XT");
  if(device_ok&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&!opt.vit_split_k&&!opt.vit_ffn_fused&&HasFn("vit_stream","vit_stream_contract_frag_bout_compactw"))compact_contract_fn=Fn("vit_stream","vit_stream_contract_frag_bout_compactw");
#endif
 }
