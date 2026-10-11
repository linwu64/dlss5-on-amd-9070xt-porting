#include "hip_api.h"
#include <algorithm>
#include <cmath>
#include <cstring>
#include <chrono>
using namespace hip_probe;
static std::vector<unsigned char> Read(const std::string&p){std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("open "+p);size_t n=f.tellg();std::vector<unsigned char>x(n);f.seekg(0);if(!f.read((char*)x.data(),n))throw std::runtime_error("read "+p);return x;}
static void Write(const std::string&p,const void*x,size_t n){std::ofstream f(p,std::ios::binary);if(!f.write((char*)x,n))throw std::runtime_error("write "+p);}
int main(int argc,char**argv)try{
 setvbuf(stdout,nullptr,_IONBF,0);
 if(argc!=9)throw std::runtime_error("timing ORIGINAL CANDIDATE INPUT CONTRACT_W SKIP QKV_W OUTDIR TOKENS");
 unsigned n=std::stoul(argv[8]);if(n!=640)throw std::runtime_error("first gate exactly640");unsigned inputs=4096,outputs=1024;const unsigned cg=n,qg=96*((n/16+4)/5);
 auto input=Read(argv[3]),cw=Read(argv[4]),skip=Read(argv[5]),qw=Read(argv[6]);if(input.size()!=size_t(n)*4096||cw.size()!=16777216+4096||skip.size()!=size_t(n)*4096||qw.size()!=3145728+128)throw std::runtime_error("typed operand extent");
 for(auto b:input)if((b&127)==127)throw std::runtime_error("input FP8 nan");for(size_t i=0;i<skip.size();i+=4){float f;memcpy(&f,skip.data()+i,4);if(!std::isfinite(f))throw std::runtime_error("skip nonfinite");}
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");auto props=a.Properties(0);char device[256]{};a.Check(a.hipDeviceGetName(device,256,0),"device name");printf("DEVICE name=%s\n",device);
 using Ext=int(*)(Handle,unsigned,unsigned,unsigned,unsigned,unsigned,unsigned,size_t,Handle,void**,void**,Handle,Handle,unsigned);Ext ext{};a.Load(ext,"hipExtModuleLaunchKernel");
 Handle modules[2]{},stream{},f[2][2]{};a.Check(a.LoadModule(&modules[0],argv[1]),"original module");a.Check(a.LoadModule(&modules[1],argv[2]),"candidate module");a.Check(a.hipStreamCreate(&stream),"stream");
 for(unsigned m=0;m<2;m++){std::string suffix=m?"_ready":"";a.Check(a.hipModuleGetFunction(&f[m][0],modules[m],("vit_stream_contract_frag_bout"+suffix).c_str()),"contract fn");a.Check(a.hipModuleGetFunction(&f[m][1],modules[m],("vit_stream_qkv_frag_bin_w5f8"+suffix).c_str()),"qkv fn");}
 std::vector<void*>owned;auto alloc=[&](size_t bytes){void*p{};a.Check(a.hipMalloc(&p,bytes),"allocate");owned.push_back(p);return p;};auto upload=[&](auto&v){void*p=alloc(v.size());a.Check(a.hipMemcpy(p,v.data(),v.size(),1),"upload");return p;};
 void*in=upload(input),*w=upload(cw),*s=upload(skip),*qweight=upload(qw);void*contract=alloc(size_t(n)*1024),*qkv=alloc(size_t(n)*3072),*ready=alloc((n/16)*4),*trace=nullptr,*status=alloc(qg*4),*gate=nullptr;
 Handle start{},end{};a.Check(a.hipEventCreate(&start),"event");a.Check(a.hipEventCreate(&end),"event");

 auto goldC=Read("expected-c.bin"),goldQ=Read("expected-q.bin");if(goldC.size()!=size_t(n)*1024||goldQ.size()!=size_t(n)*3072)throw std::runtime_error("reference logical span");
 std::ofstream csv(std::string(argv[7])+"/samples.csv");csv<<"slot,variant,frame,warm,gpu_ms,wall_ms\n";
 for(unsigned slot=0;slot<4;slot++){
  bool candidate=slot==1||slot==2;unsigned variant=candidate;
  // Output poison/readback is correctness-only, outside timing; counters/status reset is a necessary protocol cost inside.
  a.Check(a.hipMemsetAsync(contract,127,size_t(n)*1024,stream),"C poison");a.Check(a.hipMemsetAsync(qkv,127,size_t(n)*3072,stream),"Q poison");a.Check(a.hipMemsetAsync(ready,0,n/16*4,stream),"control counters initialization");a.Check(a.hipMemsetAsync(status,0,qg*4,stream),"control status initialization");a.Check(a.hipStreamSynchronize(stream),"initial poison complete");
  for(unsigned frame=0;frame<30;frame++){
   void*cargs[]{&in,&w,&s,&contract,&n,&inputs,&outputs,&gate,&ready,&trace};void*qargs[]{&contract,&qweight,&qkv,&n,&gate,&ready,&trace,&status};
   auto wallstart=std::chrono::steady_clock::now();a.Check(a.hipEventRecord(start,stream),"outer begin");
   if(candidate){a.Check(a.hipMemsetAsync(ready,0,n/16*4,stream),"fresh flags");a.Check(a.hipMemsetAsync(status,0,qg*4,stream),"fresh status");}
   a.Check(a.hipModuleLaunchKernel(f[variant][0],cg,1,1,32,1,1,0,stream,cargs,nullptr),"contract");
   if(candidate)a.Check(ext(f[variant][1],qg*160,1,1,160,1,1,0,stream,qargs,nullptr,nullptr,nullptr,1u),"anyorder QKV");
   else a.Check(a.hipModuleLaunchKernel(f[variant][1],qg,1,1,160,1,1,0,stream,qargs,nullptr),"ordered QKV");
   a.Check(a.hipEventRecord(end,stream),"outer end");a.Check(a.hipStreamSynchronize(stream),"pair fence");double wall=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-wallstart).count();float gpu{};a.Check(a.hipEventElapsedTime(&gpu,start,end),"gpu elapsed");
   if(!std::isfinite(gpu)||gpu<=0||!std::isfinite(wall)||wall<=0)throw std::runtime_error("invalid timing");
   csv<<slot<<','<<(candidate?"anyorder":"original")<<','<<frame<<','<<(frame<10)<<','<<std::fixed<<gpu<<','<<wall<<'\n';csv.flush();
   // Both variants perform the same two small D2H copies outside timing. Only candidate counters/status are protocol evidence.
   {std::vector<unsigned>counts(n/16),fail(qg);a.Check(a.hipMemcpy(counts.data(),ready,counts.size()*4,2),"counts");a.Check(a.hipMemcpy(fail.data(),status,fail.size()*4,2),"status");if(candidate)for(auto x:counts)if(x!=16)throw std::runtime_error("counter missing");if(candidate)for(auto x:fail)if(x)throw std::runtime_error("bounded wait failed");}
   if(frame==0||frame==29){std::vector<unsigned char>c(goldC.size()),q(goldQ.size());a.Check(a.hipMemcpy(c.data(),contract,c.size(),2),"C read");a.Check(a.hipMemcpy(q.data(),qkv,q.size(),2),"Q read");size_t cd=0,qd=0,nan=0;for(size_t i=0;i<c.size();i++){cd+=c[i]!=goldC[i];nan+=(c[i]&127)==127;}for(size_t i=0;i<q.size();i++){qd+=q[i]!=goldQ[i];nan+=(q[i]&127)==127;}printf("EDGE slot=%u frame=%u Cdiff=%zu Qdiff=%zu nonfinite=%zu\n",slot,frame,cd,qd,nan);if(cd||qd||nan)throw std::runtime_error("edge gold failed");}
  }
  printf("SLOT_COMPLETE slot=%u variant=%s warm=10 measured=20 trace=0 reset_in_gpu_window=%u\n",slot,candidate?"anyorder":"original",candidate);
 }
 for(auto p:owned)a.Check(a.hipFree(p),"free");a.Check(a.hipEventDestroy(start),"destroy");a.Check(a.hipEventDestroy(end),"destroy");a.Check(a.hipStreamDestroy(stream),"destroy stream");for(auto m:modules)a.Check(a.hipModuleUnload(m),"unload");return 0;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
