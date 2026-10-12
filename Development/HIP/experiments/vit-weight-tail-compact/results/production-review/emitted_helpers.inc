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
 Handle compact_projection_fn{};std::set<void*> compact_projection_ptrs;
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
   std::fprintf(stderr,"PROJECTION_COMPACT key=%s bytes=1052672 legacy_held=0\n",key.c_str());
  }return P(it->second);
 }

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

#ifndef HIP_COMPACT_VIT_PROJECTION
#define HIP_COMPACT_VIT_PROJECTION 1
#endif
 void InitCompactProjection(){
#if HIP_COMPACT_VIT_PROJECTION
  if(CompactVitTailDeviceEligible()&&!opt.integration.select_module&&fast_numeric&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.sparse_weights&&vit_contract_byte_edge&&vit_proj_n64_active&&opt.vit_proj_frag&&HasFn("vit_stream","vit_stream_project_n64_bb_compactw"))compact_projection_fn=Fn("vit_stream","vit_stream_project_n64_bb_compactw");
#endif
 }
