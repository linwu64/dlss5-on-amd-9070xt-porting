// One authorized semantic gate, not a network candidate or a performance probe.
// Match stock Norm: A=all-one F16 fragment, B=squares fragment, two K16 calls.
using uint=unsigned int;
using ushort=unsigned short;
using h8=_Float16 __attribute__((ext_vector_type(8)));
using f8=float __attribute__((ext_vector_type(8)));
extern "C" __attribute__((global)) __attribute__((amdgpu_flat_work_group_size(32,32)))
void c32_nohi_norm_primitive(float* output,uint* mode){
 const uint lane=__builtin_amdgcn_workitem_id_x(),g=lane>>4;
 const uint hb=__builtin_amdgcn_workgroup_id_x();
 if(hb>=65536u)return;
 if(hb==0&&lane==0)mode[0]=__builtin_amdgcn_s_getreg(1u|(31u<<11));
 const _Float16 h=__builtin_bit_cast(_Float16,static_cast<ushort>(hb));
 #pragma unroll 1
 for(uint position=0;position<32;position++){
  f8 sum{};
  #pragma unroll 2
  for(uint ci=0;ci<2;ci++){
   h8 squares{},ones{};
   #pragma unroll
   for(uint e=0;e<8;e++){
    squares[e]=(ci*16+g*8+e==position)?h:(_Float16)0.f;
    ones[e]=(_Float16)1.f;
   }
   sum=__builtin_amdgcn_wmma_f32_16x16x16_f16_w32_gfx12(ones,squares,sum);
  }
  // For B(feature,token) the selected feature is present for every token;
  // every accumulator element equals h (zero signs follow FMA with +0 seed).
  if(lane==0)output[hb*32+position]=sum[0];
 }
}
