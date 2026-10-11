#include "hip_api.h"
#include <cmath>
#include <cstring>
#include <fstream>
#include <iostream>
#include <vector>
using namespace hip_probe;
static float Half(unsigned h){unsigned a=h&32767u,s=(h&32768u)<<16,u;
 if(a<1024u){if(!a)u=s;else{unsigned e=113;while((a&1024u)==0){a<<=1;--e;}u=s|(e<<23)|((a&1023u)<<13);}}
 else if(a<31744u)u=s|((a+114688u)<<13);
 else u=s|0x7f800000u|((a&1023u)<<13);
 float f;std::memcpy(&f,&u,4);return f;}
int main(int argc,char**argv)try{
 setvbuf(stdout,nullptr,_IONBF,0);
 if(argc!=3)throw std::runtime_error("norm-primitive MODULE OUTRAW");
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");
 char device[256]{};a.Check(a.hipDeviceGetName(device,256,0),"name");std::cout<<"DEVICE="<<device<<"\n";
 Handle module{},fn{};a.Check(a.LoadModule(&module,argv[1]),"load");a.Check(a.hipModuleGetFunction(&fn,module,"c32_nohi_norm_primitive"),"entry");
 void*out{},*mode{};const size_t count=65536u*32u;a.Check(a.hipMalloc(&out,count*4),"alloc output");a.Check(a.hipMalloc(&mode,4),"alloc mode");
 a.Check(a.hipMemsetAsync(out,0x55,count*4,nullptr),"poison");a.Check(a.hipMemsetAsync(mode,0,4,nullptr),"mode init");void*args[]{&out,&mode};
 std::cout<<"DISPATCH_BEGIN groups=65536 threads=32 positions=32 one_dispatch=1\n";
 a.Check(a.hipModuleLaunchKernel(fn,65536,1,1,32,1,1,0,nullptr,args,nullptr),"launch");a.Check(a.hipDeviceSynchronize(),"completion");
 std::vector<float>v(count);unsigned bitsmode{};a.Check(a.hipMemcpy(v.data(),out,count*4,2),"read output");a.Check(a.hipMemcpy(&bitsmode,mode,4,2),"read mode");
 size_t finite_diff=0,subnormal_diff=0,zero_diff=0,infinity_diff=0,nan_class_diff=0;unsigned first_h=0,first_p=0;bool first=true;
 for(unsigned h=0;h<65536;h++){float expected=Half(h);for(unsigned p=0;p<32;p++){
  float x=v[h*32+p];unsigned ux,ue;std::memcpy(&ux,&x,4);std::memcpy(&ue,&expected,4);bool bad=false;
  if((h&32767u)>31744u){bad=!std::isnan(x);nan_class_diff+=bad;}
  else if((h&32767u)==31744u){bad=ux!=ue;infinity_diff+=bad;}
  else if((h&32767u)==0){bad=x!=0.f;zero_diff+=bad;} // No signed-zero-payload claim.
  else{bad=ux!=ue;finite_diff+=bad;if((h&32767u)<1024u)subnormal_diff+=bad;}
  if(bad&&first){first=false;first_h=h;first_p=p;}
 }}
 std::ofstream f(argv[2],std::ios::binary);if(!f.write(reinterpret_cast<const char*>(v.data()),v.size()*4))throw std::runtime_error("write raw");f.close();
 bool mode_ok=(bitsmode&255u)==240u&&(bitsmode&(1u<<23))==0;
 std::cout<<"NORM_PRIMITIVE mode="<<bitsmode<<" mode_ok="<<mode_ok<<" finite_diff="<<finite_diff<<" subnormal_diff="<<subnormal_diff<<" zero_diff="<<zero_diff<<" infinity_diff="<<infinity_diff<<" nan_class_diff="<<nan_class_diff<<" first_half="<<first_h<<" first_position="<<first_p<<" outputs="<<count<<" numeric_scope=F16_WMMA_input_semantics_not_full_network\n";
 a.Check(a.hipFree(out),"free");a.Check(a.hipFree(mode),"free");a.Check(a.hipModuleUnload(module),"unload");
 return !mode_ok||finite_diff||zero_diff||infinity_diff||nan_class_diff?1:0;
}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<"\n";return 2;}
