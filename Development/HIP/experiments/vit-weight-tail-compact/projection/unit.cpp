#include "hip_api.h"
#include <cmath>
#include <algorithm>
#include <cstring>
using namespace hip_probe;
static std::vector<unsigned char>Read(const char*p){std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("open input");std::vector<unsigned char>v(size_t(f.tellg()));f.seekg(0);if(!f.read((char*)v.data(),v.size()))throw std::runtime_error("read input");return v;}
static void Write(const std::string&p,const std::vector<unsigned char>&v){std::ofstream f(p,std::ios::binary);if(!f.write((char*)v.data(),v.size()))throw std::runtime_error("write output");}
int main(int argc,char**argv)try{
 setvbuf(stdout,nullptr,_IONBF,0);if(argc!=8)throw std::runtime_error("unit STOCK_MODULE SIDECAR INPUT_FP8 PACKED_FW SKIP_FP8 GOLD_F32 OUTDIR");
 auto input=Read(argv[3]),fw=Read(argv[4]),skip=Read(argv[5]),gold=Read(argv[6]);unsigned tokens=640,inputs=1024,outputs=1024;size_t output_bytes=size_t(tokens)*outputs*4;constexpr size_t live=1048576;
 if(input.size()!=655360||fw.size()!=4198400||skip.size()!=655360||gold.size()!=output_bytes)throw std::runtime_error("actual typed extent");
 for(auto b:skip)if((b&127)==127)throw std::runtime_error("skip FP8 NaN");for(auto b:input)if((b&127)==127)throw std::runtime_error("input FP8 NaN");for(size_t i=0;i<live;i++)if((fw[i]&127)==127)throw std::runtime_error("weight FP8 NaN");
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");char dev[256]{};a.Check(a.hipDeviceGetName(dev,256,0),"device");printf("DEVICE %s\n",dev);if(!strstr(dev,"9070 XT"))throw std::runtime_error("expected RX9070 XT device0");
 Handle m{},side{},fn{},newfn{},stream{};a.Check(a.LoadModule(&m,argv[1]),"module");a.Check(a.hipModuleGetFunction(&fn,m,"vit_stream_project_n64_bb"),"function");a.Check(a.LoadModule(&side,argv[2]),"sidecar");a.Check(a.hipModuleGetFunction(&newfn,side,"vit_stream_project_n64_bb_compactw"),"new function");a.Check(a.hipStreamCreate(&stream),"stream");
 void*in{},*out{},*weight{},*sk{},*gate=nullptr;a.Check(a.hipMalloc(&in,input.size()),"input allocate");a.Check(a.hipMalloc(&out,output_bytes+256),"output allocate");a.Check(a.hipMemcpy(in,input.data(),input.size(),1),"input upload");a.Check(a.hipMalloc(&sk,skip.size()),"skip allocate");a.Check(a.hipMemcpy(sk,skip.data(),skip.size(),1),"skip upload");std::vector<unsigned char>compact(fw.begin(),fw.begin()+live);compact.insert(compact.end(),fw.begin()+4194304,fw.end());std::vector<unsigned char>first;
 for(unsigned variant=0;variant<2;variant++){
  const size_t bytes=variant?compact.size():fw.size();size_t free_before{},total{},free_after{};a.Check(a.hipMemGetInfo(&free_before,&total),"memory before");a.Check(a.hipMalloc(&weight,bytes),"ordinary weight allocate");a.Check(a.hipMemcpy(weight,variant?compact.data():fw.data(),bytes,1),"weight upload");a.Check(a.hipMemGetInfo(&free_after,&total),"memory after");
  std::vector<unsigned char>back(live);a.Check(a.hipMemcpy(back.data(),weight,live,2),"actual matrix readback");if(memcmp(back.data(),fw.data(),live))throw std::runtime_error("GPU matrix byte copy mismatch");
  printf("WEIGHT variant=%s held_weight_allocations=1 requested_bytes=%zu driver_free_before=%zu driver_free_after=%zu driver_total=%zu driver_delta_not_peak_or_residency=1\n",variant?"compact":"original",bytes,free_before,free_after,total);
  for(unsigned repeat=0;repeat<2;repeat++){
   a.Check(a.hipMemsetAsync(out,127,output_bytes,stream),"output poison");a.Check(a.hipMemsetAsync((char*)out+output_bytes,90,256,stream),"tail guard");void*args[]{&in,&weight,&sk,&out,&tokens,&inputs,&outputs,&gate};a.Check(a.hipModuleLaunchKernel(variant?newfn:fn,640,1,1,32,1,1,0,stream,args,nullptr),"projection same math new tail offset");a.Check(a.hipStreamSynchronize(stream),"completion");
   std::vector<unsigned char>v(output_bytes),tail(256);a.Check(a.hipMemcpy(v.data(),out,v.size(),2),"output read");a.Check(a.hipMemcpy(tail.data(),(char*)out+output_bytes,256,2),"guard read");size_t diff=0,own=0,nan=0,guard=0;for(size_t i=0;i<v.size();i++){diff+=v[i]!=gold[i];if(!first.empty())own+=v[i]!=first[i];}for(size_t i=0;i<v.size();i+=4){float f;memcpy(&f,v.data()+i,4);nan+=!std::isfinite(f);}for(auto b:tail)guard+=b!=90;if(first.empty())first=v;
   printf("GOLD variant=%s repeat=%u capture_diff=%zu original_repeat_diff=%zu nonfinite=%zu tail_guard_diff=%zu logical_bytes=%zu grid=640 threads=32 launchflags=0 paired_kernel_by_variant=1\n",variant?"compact":"original",repeat,diff,own,nan,guard,v.size());Write(std::string(argv[7])+"/"+(variant?"compact-":"original-")+std::to_string(repeat)+".bin",v);if(diff||own||nan||guard)throw std::runtime_error("strict byte gate");
  }
  a.Check(a.hipFree(weight),"weight free before next variant");weight=nullptr;
 }
 a.Check(a.hipFree(sk),"free skip");a.Check(a.hipFree(in),"free input");a.Check(a.hipFree(out),"free output");a.Check(a.hipStreamDestroy(stream),"destroy stream");a.Check(a.hipModuleUnload(m),"unload");a.Check(a.hipModuleUnload(side),"unload sidecar");puts("COMPACT_PROJECTION_UNIT_PASS no_timing=1 unchanged_math=1 no_VMM=1");return 0;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
