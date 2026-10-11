#!/usr/bin/env python3
"""Private loader-only trial. Kernel source/ABI/math stay byte-identical."""
from pathlib import Path
import argparse,hashlib,json,shutil
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[4]);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
source=a.repo/'Development/HIP/hip_reference_network.h';s=source.read_text();start=s.index(' void* PackedVitWeight(');end=s.index(' /* Optional export probe:',start);old=s[start:end]
assert 'auto key=name+(frag?"@vit-frag":"@vit-tiled")' in old
new='''#ifndef HIP_COMPACT_VIT_EXPAND
#define HIP_COMPACT_VIT_EXPAND 0
#endif
 void* PackedVitWeight(const std::string&name,U rows,U cols,bool tiled,bool frag=false){
  if(!tiled)return PackedDeepWeight(name,size_t(rows)*cols);
  // No tail/scales exist in WeightElements(expand). All consumers of this key
  // load only the original packed matrix prefix. Contract/projection untouched.
  const bool compact=HIP_COMPACT_VIT_EXPAND&&rows==4096&&cols==1024&&frag&&opt.vit_expand_frag&&opt.vit_pack_input&&opt.vit_blocked&&opt.fp8_deep&&(opt.vit_weight_mask&1)&&!opt.vit_ffn_fused&&!opt.vit_expand_m2&&!opt.vit_expand_m4&&!opt.vit_input_tiled;
  auto key=name+(compact?"@vit-frag@compact-expand":(frag?"@vit-frag":"@vit-tiled"));auto it=weights.find(key);
  if(it==weights.end()){
   const auto legacy_key=name+(frag?"@vit-frag":"@vit-tiled");
   auto v=ReadWeights(opt.assets+"/"+name);if(v.size()!=WeightElements(name))throw std::runtime_error("ViT tiled weight shape");
   const bool known_expand=name=="block31-expand.f32"||name=="block32-expand.f32"||name=="block33-expand.f32"||name=="block34-expand.f32"||name=="block35-expand.f32"||name=="block36-expand.f32"||name=="block37-expand.f32"||name=="block38-expand.f32";
   if(compact&&(!known_expand||v.size()!=size_t(4096)*1024||name.size()<11||name.compare(name.size()-11,11,"-expand.f32")||opt.sparse_weights||weights.count(legacy_key)))throw std::runtime_error("compact expand shape/alias/ordinary-allocation contract");
   Fp8(v,{{0,size_t(rows)*cols}});if(frag)FragmentPackedMatrix(v,0,rows,cols);else TilePackedMatrix(v,0,rows,cols);
   if(compact){
    const size_t original_bytes=v.size()*4,live_bytes=size_t(rows)*cols;
    // Shrink host storage before hipMalloc; never upload or retain old GPU buffer.
    v.resize(live_bytes/4);dead.clear();
    it=weights.emplace(key,Upload(v.data(),live_bytes,true)).first;
    std::fprintf(stderr,"COMPACT_WEIGHT key=%s original_bytes=%zu live_bytes=%zu allocation_capacity=%zu legacy_key_present=%u persistent=1 ordinary_hipMalloc=1\\n",key.c_str(),original_bytes,live_bytes,it->second->capacity,unsigned(weights.count(legacy_key)));
   }else it=weights.emplace(key,UploadWeight(v,key)).first;
  }return P(it->second);
 }
'''
new='#if HIP_COMPACT_VIT_EXPAND\n'+new+'#else\n'+old+'#endif\n'
s=s[:start]+new+s[end:]
anchor='  if(opt.sparse_weights)std::fprintf(f,"hip_memory sparse_weights'
pos=s.index(anchor)
extra='  std::fprintf(f,"hip_memory_exact weights_bytes=%zu pool_bytes=%zu gather_bytes=%zu noise_bytes=%zu driver_free_bytes=%zu driver_total_bytes=%zu not_resident_peak=1\\n",wsum,psum,gsum,nsum,free,total);\n  for(const auto&kv:weights)if(kv.second)std::fprintf(f,"hip_weight_exact key=%s bytes=%zu capacity=%zu owned=%u pointer=%p\\n",kv.first.c_str(),kv.second->bytes,kv.second->capacity,unsigned(kv.second->owned),kv.second->ptr);\n'
extra=extra.replace(chr(92)*2+'n',chr(92)+'n')
s=s[:pos]+extra+s[pos:]
a.out.mkdir(parents=True,exist_ok=True);
for rel in ('src','Development/HIP'):
 target=a.out/rel;target.mkdir(parents=True,exist_ok=True)
 for f in (a.repo/rel).glob('*.h'):shutil.copyfile(f,target/f.name)
shutil.copyfile(a.repo/'Development/HIP/benchmark_vit_reuse.cpp',a.out/'Development/HIP/benchmark_vit_reuse.cpp')
(a.out/'hip_reference_network.h').write_text(s);(a.out/'loader.patch').write_text(__import__('subprocess').run(['diff','-u',str(source),str(a.out/'hip_reference_network.h')],capture_output=True,text=True).stdout)
r={'baseline_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'candidate_private_source_sha256':hashlib.sha256((a.out/'hip_reference_network.h').read_bytes()).hexdigest(),'default_macro':0,'gate':'HIP_COMPACT_VIT_EXPAND=1; only fragment expand4096x1024 no tail, original kernel unchanged','legacy_gpu_buffer_allocated':False,'kernel_changes':False,'quantization_changes':False,'scope':'CPU generated; not numerical accepted'}
shutil.copyfile(a.out/'hip_reference_network.h',a.out/'Development/HIP/hip_reference_network.h')
(a.out/'source-identity.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
