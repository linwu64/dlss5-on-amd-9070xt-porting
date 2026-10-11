#ifndef HIP_COMPACT_VIT_EXPAND
#define HIP_COMPACT_VIT_EXPAND 1 // Reviewed narrow packed-expand storage only.
#endif
#if HIP_COMPACT_VIT_EXPAND
 void* PackedVitWeight(const std::string&name,U rows,U cols,bool tiled,bool frag=false){
  if(!tiled)return PackedDeepWeight(name,size_t(rows)*cols);
  const bool expand_name=name.size()==18&&name.compare(0,6,"block3")==0&&name[6]>='1'&&name[6]<='8'&&name.compare(7,11,"-expand.f32")==0;
  // Unknown names/layouts/selector paths keep the original full allocation.
  const bool compact=expand_name&&rows==4096&&cols==1024&&frag&&!opt.sparse_weights&&opt.vit_expand_frag&&opt.vit_pack_input&&opt.vit_blocked&&opt.fp8_deep&&(opt.vit_weight_mask&1)&&!opt.vit_ffn_fused&&!opt.vit_expand_m2&&!opt.vit_expand_m4&&!opt.vit_input_tiled;
  auto key=name+(compact?"@vit-frag@compact-expand":(frag?"@vit-frag":"@vit-tiled"));auto it=weights.find(key);
  if(it==weights.end()){
   if(compact){auto legacy=weights.find(name+"@vit-frag");if(legacy!=weights.end())return P(legacy->second);}
   auto v=ReadWeights(opt.assets+"/"+name);if(v.size()!=WeightElements(name))throw std::runtime_error("ViT tiled weight shape");
   Fp8(v,{{0,size_t(rows)*cols}});if(frag)FragmentPackedMatrix(v,0,rows,cols);else TilePackedMatrix(v,0,rows,cols);
   if(compact){
    // Only logical upload size shrinks; temporary CPU vector capacity may stay large.
    // FW byte load range is [0,4194304), independent of token count. No scale tail.
    v.resize(size_t(rows)*cols/4);dead.clear();
    it=weights.emplace(key,Upload(v.data(),size_t(rows)*cols,true)).first;
   }else it=weights.emplace(key,UploadWeight(v,key)).first;
  }return P(it->second);
 }
#else
 void* PackedVitWeight(const std::string&name,U rows,U cols,bool tiled,bool frag=false){
  if(!tiled)return PackedDeepWeight(name,size_t(rows)*cols);
  auto key=name+(frag?"@vit-frag":"@vit-tiled");auto it=weights.find(key);
  if(it==weights.end()){auto v=ReadWeights(opt.assets+"/"+name);if(v.size()!=WeightElements(name))throw std::runtime_error("ViT tiled weight shape");Fp8(v,{{0,size_t(rows)*cols}});if(frag)FragmentPackedMatrix(v,0,rows,cols);else TilePackedMatrix(v,0,rows,cols);it=weights.emplace(key,UploadWeight(v,key)).first;}return P(it->second);
 }
#endif
