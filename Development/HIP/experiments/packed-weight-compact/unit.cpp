#include "hip_api.h"
#include <algorithm>
#include <cstring>
using namespace hip_probe;
static std::vector<unsigned char>Read(const char*p){std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("open input");std::vector<unsigned char>v(size_t(f.tellg()));f.seekg(0);if(!f.read((char*)v.data(),v.size()))throw std::runtime_error("read input");return v;}
static void Write(const std::string&p,const std::vector<unsigned char>&v){std::ofstream f(p,std::ios::binary);if(!f.write((char*)v.data(),v.size()))throw std::runtime_error("write output");}
int main(int argc,char**argv)try{
 setvbuf(stdout,nullptr,_IONBF,0);if(argc!=6)throw std::runtime_error("unit MODULE INPUT_FP8 PACKED_FW_16M GOLD_FP8 OUTDIR");
 auto input=Read(argv[2]),fw=Read(argv[3]),gold=Read(argv[4]);unsigned tokens=640,inputs=1024,outputs=4096;size_t output_bytes=size_t(tokens)*outputs;constexpr size_t live=4194304;
 if(input.size()!=655360||fw.size()!=16777216||gold.size()!=output_bytes)throw std::runtime_error("actual typed extent");
 for(auto b:input)if((b&127)==127)throw std::runtime_error("input FP8 NaN");for(size_t i=0;i<live;i++)if((fw[i]&127)==127)throw std::runtime_error("weight FP8 NaN");
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");char dev[256]{};a.Check(a.hipDeviceGetName(dev,256,0),"device");printf("DEVICE %s\n",dev);
 Handle m{},fn{},stream{};a.Check(a.LoadModule(&m,argv[1]),"module");a.Check(a.hipModuleGetFunction(&fn,m,"vit_expand_blocked_fp8_frag_bytein"),"function");a.Check(a.hipStreamCreate(&stream),"stream");
 void*in{},*out{},*weight{},*gate=nullptr;a.Check(a.hipMalloc(&in,input.size()),"input allocate");a.Check(a.hipMalloc(&out,output_bytes+256),"output allocate");a.Check(a.hipMemcpy(in,input.data(),input.size(),1),"input upload");std::vector<unsigned char>first;
 for(unsigned variant=0;variant<2;variant++){
  const size_t bytes=variant?live:fw.size();size_t free_before{},total{},free_after{};a.Check(a.hipMemGetInfo(&free_before,&total),"memory before");a.Check(a.hipMalloc(&weight,bytes),"ordinary weight allocate");a.Check(a.hipMemcpy(weight,fw.data(),bytes,1),"weight upload");a.Check(a.hipMemGetInfo(&free_after,&total),"memory after");
  std::vector<unsigned char>back(live);a.Check(a.hipMemcpy(back.data(),weight,live,2),"actual matrix readback");if(memcmp(back.data(),fw.data(),live))throw std::runtime_error("GPU matrix byte copy mismatch");
  printf("WEIGHT variant=%s held_weight_allocations=1 requested_bytes=%zu driver_free_before=%zu driver_free_after=%zu driver_total=%zu driver_delta_not_peak_or_residency=1\n",variant?"compact":"original",bytes,free_before,free_after,total);
  for(unsigned repeat=0;repeat<2;repeat++){
   a.Check(a.hipMemsetAsync(out,127,output_bytes,stream),"output poison");a.Check(a.hipMemsetAsync((char*)out+output_bytes,90,256,stream),"tail guard");void*args[]{&in,&weight,&out,&tokens,&inputs,&outputs,&gate};a.Check(a.hipModuleLaunchKernel(fn,2560,1,1,32,1,1,0,stream,args,nullptr),"unchanged expand");a.Check(a.hipStreamSynchronize(stream),"completion");
   std::vector<unsigned char>v(output_bytes),tail(256);a.Check(a.hipMemcpy(v.data(),out,v.size(),2),"output read");a.Check(a.hipMemcpy(tail.data(),(char*)out+output_bytes,256,2),"guard read");size_t diff=0,own=0,nan=0,guard=0;for(size_t i=0;i<v.size();i++){diff+=v[i]!=gold[i];nan+=(v[i]&127)==127;if(!first.empty())own+=v[i]!=first[i];}for(auto b:tail)guard+=b!=90;if(first.empty())first=v;
   printf("GOLD variant=%s repeat=%u capture_diff=%zu original_repeat_diff=%zu nonfinite=%zu tail_guard_diff=%zu logical_bytes=%zu grid=2560 threads=32 launchflags=0 original_kernel=1\n",variant?"compact":"original",repeat,diff,own,nan,guard,v.size());Write(std::string(argv[5])+"/"+(variant?"compact-":"original-")+std::to_string(repeat)+".bin",v);if(diff||own||nan||guard)throw std::runtime_error("strict byte gate");
  }
  a.Check(a.hipFree(weight),"weight free before next variant");weight=nullptr;
 }
 a.Check(a.hipFree(in),"free input");a.Check(a.hipFree(out),"free output");a.Check(a.hipStreamDestroy(stream),"destroy stream");a.Check(a.hipModuleUnload(m),"unload");puts("COMPACT_EXPAND_UNIT_PASS no_timing=1 no_new_kernel=1 no_VMM=1");return 0;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
