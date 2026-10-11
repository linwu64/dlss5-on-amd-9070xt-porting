// CPU admission/cache test of the actual emitted loader function, not GPU/math gold.
#include <map>
#include <memory>
#include <string>
#include <vector>
#include <stdexcept>
#include <cstdio>
#include <cassert>
using U=unsigned;
struct Allocation{size_t capacity;void*ptr;};using Tensor=std::shared_ptr<Allocation>;
struct Options{std::string assets="fixture";bool sparse_weights=false,vit_expand_frag=true,vit_pack_input=true,vit_blocked=true,fp8_deep=true,vit_ffn_fused=false,vit_expand_m2=false,vit_expand_m4=false,vit_input_tiled=false;unsigned vit_weight_mask=1;};
struct MockNetwork{
 Options opt;std::map<std::string,Tensor>weights;std::vector<std::pair<size_t,size_t>>dead;size_t allocations=0,deep_fallbacks=0;bool bad_asset=false;
 size_t WeightElements(const std::string&name){return name.find("contract")!=std::string::npos?4195328:4194304;}
 std::vector<float>ReadWeights(const std::string&path){size_t n=WeightElements(path);if(bad_asset)n--;return std::vector<float>(n);}
 void Fp8(std::vector<float>&,const std::vector<std::pair<size_t,size_t>>&r){for(auto q:r)dead.push_back({q.first*4+q.second,(q.first+q.second)*4});}
 void FragmentPackedMatrix(std::vector<float>&,size_t,U,U){}void TilePackedMatrix(std::vector<float>&,size_t,U,U){}
 Tensor Upload(const void*,size_t bytes,bool persistent){assert(persistent);++allocations;return std::make_shared<Allocation>(Allocation{bytes,reinterpret_cast<void*>(allocations*4096)});}
 Tensor UploadWeight(const std::vector<float>&v,const std::string&){dead.clear();return Upload(v.data(),v.size()*4,true);}
 void*P(const Tensor&t){return t->ptr;}void*PackedDeepWeight(const std::string&,size_t){++deep_fallbacks;return reinterpret_cast<void*>(1234);}
#include "production-loader-function.inc"
};
int main(){
 MockNetwork n;for(int i=31;i<=38;i++){std::string name="block"+std::to_string(i)+"-expand.f32";void*p=n.PackedVitWeight(name,4096,1024,true,true);size_t old=n.allocations;assert(n.PackedVitWeight(name,4096,1024,true,true)==p&&n.allocations==old);}
 assert(n.weights.size()==8&&n.allocations==8&&n.dead.empty());for(auto&w:n.weights){assert(w.second->capacity==(HIP_COMPACT_VIT_EXPAND?4194304u:16777216u));assert((w.first.find("@compact-expand")!=std::string::npos)==bool(HIP_COMPACT_VIT_EXPAND));}
 MockNetwork unknown;unknown.PackedVitWeight("block39-expand.f32",4096,1024,true,true);assert(unknown.weights.begin()->second->capacity==16777216&&unknown.weights.begin()->first=="block39-expand.f32@vit-frag");
 MockNetwork tail;tail.PackedVitWeight("block31-contract.f32",1024,4096,true,true);assert(tail.weights.begin()->second->capacity==16781312);
 for(int kind=0;kind<8;kind++){
  MockNetwork x;switch(kind){case 0:x.opt.sparse_weights=true;break;case 1:x.opt.vit_expand_m2=true;break;case 2:x.opt.vit_expand_m4=true;break;case 3:x.opt.vit_input_tiled=true;break;case 4:x.opt.vit_ffn_fused=true;break;case 5:x.opt.vit_pack_input=false;break;case 6:x.opt.vit_weight_mask=0;break;case 7:x.opt.fp8_deep=false;break;}
  x.PackedVitWeight("block31-expand.f32",4096,1024,true,true);assert(x.weights.begin()->second->capacity==16777216&&x.allocations==1);
 }
 MockNetwork nonfrag;nonfrag.PackedVitWeight("block31-expand.f32",4096,1024,true,false);assert(nonfrag.weights.begin()->second->capacity==16777216);
 MockNetwork deep;assert(deep.PackedVitWeight("block31-expand.f32",4096,1024,false,true)==reinterpret_cast<void*>(1234)&&deep.deep_fallbacks==1&&deep.allocations==0);
 MockNetwork legacy;auto old=std::make_shared<Allocation>(Allocation{16777216,reinterpret_cast<void*>(8888)});legacy.weights["block31-expand.f32@vit-frag"]=old;assert(legacy.PackedVitWeight("block31-expand.f32",4096,1024,true,true)==old->ptr&&legacy.allocations==0&&legacy.weights.size()==1);
 MockNetwork bad;bad.bad_asset=true;bool threw=false;try{bad.PackedVitWeight("block31-expand.f32",4096,1024,true,true);}catch(const std::runtime_error&){threw=true;}assert(threw&&bad.allocations==0);
 printf("LOADER_SELECTION_PASS macro=%d known8_cache_no_duplicate unknown_legacy_contract_nonfrag_deep_selector_fallbacks malformed_baseline_reject mock_upload_no_GPU=1\n",HIP_COMPACT_VIT_EXPAND);
}
