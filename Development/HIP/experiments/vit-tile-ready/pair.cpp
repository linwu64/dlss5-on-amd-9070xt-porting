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
 if(argc!=9)throw std::runtime_error("pair ORIGINAL CANDIDATE INPUT CONTRACT_W SKIP QKV_W OUTDIR TOKENS");
 unsigned n=std::stoul(argv[8]);if(n!=640)throw std::runtime_error("first gate exactly640");unsigned inputs=4096,outputs=1024;const unsigned cg=n,qg=96*((n/16+4)/5);
 auto input=Read(argv[3]),cw=Read(argv[4]),skip=Read(argv[5]),qw=Read(argv[6]);if(input.size()!=size_t(n)*4096||cw.size()!=16777216+4096||skip.size()!=size_t(n)*4096||qw.size()!=3145728+128)throw std::runtime_error("typed operand extent");
 for(auto b:input)if((b&127)==127)throw std::runtime_error("input FP8 nan");for(size_t i=0;i<skip.size();i+=4){float f;memcpy(&f,skip.data()+i,4);if(!std::isfinite(f))throw std::runtime_error("skip nonfinite");}
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");auto props=a.Properties(0);char device[256]{};a.Check(a.hipDeviceGetName(device,256,0),"device name");printf("DEVICE name=%s\n",device);
 using Ext=int(*)(Handle,unsigned,unsigned,unsigned,unsigned,unsigned,unsigned,size_t,Handle,void**,void**,Handle,Handle,unsigned);Ext ext{};a.Load(ext,"hipExtModuleLaunchKernel");
 Handle modules[2]{},stream{},f[2][2]{};a.Check(a.LoadModule(&modules[0],argv[1]),"original module");a.Check(a.LoadModule(&modules[1],argv[2]),"candidate module");a.Check(a.hipStreamCreate(&stream),"stream");
 for(unsigned m=0;m<2;m++){std::string suffix=m?"_ready":"";a.Check(a.hipModuleGetFunction(&f[m][0],modules[m],("vit_stream_contract_frag_bout"+suffix).c_str()),"contract fn");a.Check(a.hipModuleGetFunction(&f[m][1],modules[m],("vit_stream_qkv_frag_bin_w5f8"+suffix).c_str()),"qkv fn");}
 std::vector<void*>owned;auto alloc=[&](size_t bytes){void*p{};a.Check(a.hipMalloc(&p,bytes),"allocate");owned.push_back(p);return p;};auto upload=[&](auto&v){void*p=alloc(v.size());a.Check(a.hipMemcpy(p,v.data(),v.size(),1),"upload");return p;};
 void*in=upload(input),*w=upload(cw),*s=upload(skip),*qweight=upload(qw);void*contract=alloc(size_t(n)*1024),*qkv=alloc(size_t(n)*3072),*ready=alloc((n/16)*4),*trace=alloc((n*2+qg*3)*8),*status=alloc(qg*4),*gate=nullptr;
 Handle start{},end{};a.Check(a.hipEventCreate(&start),"event");a.Check(a.hipEventCreate(&end),"event");
 std::vector<unsigned char>goldC,goldQ;bool all=true;
 for(unsigned mode=0;mode<5;mode++){
  // Each reset is on this stream and completed before launch. No counter epochs or pool reuse.
  a.Check(a.hipMemsetAsync(contract,127,size_t(n)*1024,stream),"poison C");a.Check(a.hipMemsetAsync(qkv,127,size_t(n)*3072,stream),"poison Q");a.Check(a.hipMemsetAsync(ready,0,n/16*4,stream),"zero counters");a.Check(a.hipMemsetAsync(trace,0,(n*2+qg*3)*8,stream),"zero trace");a.Check(a.hipMemsetAsync(status,0,qg*4,stream),"zero status");a.Check(a.hipStreamSynchronize(stream),"init drain");
  unsigned variant=mode>=2;void*cargs[]{&in,&w,&s,&contract,&n,&inputs,&outputs,&gate,&ready,&trace};void*qargs[]{&contract,&qweight,&qkv,&n,&gate,&ready,&trace,&status};
  a.Check(a.hipEventRecord(start,stream),"outer begin");auto wallstart=std::chrono::steady_clock::now();
  a.Check(a.hipModuleLaunchKernel(f[variant][0],cg,1,1,32,1,1,0,stream,cargs,nullptr),"contract launch");
  if(mode>=3)a.Check(ext(f[variant][1],qg*160,1,1,160,1,1,0,stream,qargs,nullptr,nullptr,nullptr,1u),"anyorder qkv");
  else a.Check(a.hipModuleLaunchKernel(f[variant][1],qg,1,1,160,1,1,0,stream,qargs,nullptr),"ordered qkv");
  a.Check(a.hipEventRecord(end,stream),"outer end");a.Check(a.hipStreamSynchronize(stream),"pair completion");double wall=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-wallstart).count();float gpu{};a.Check(a.hipEventElapsedTime(&gpu,start,end),"elapsed");
  std::vector<unsigned char>c(size_t(n)*1024),q(size_t(n)*3072);std::vector<unsigned>counts(n/16),fail(qg);std::vector<unsigned long long>ticks(n*2+qg*3);
  a.Check(a.hipMemcpy(c.data(),contract,c.size(),2),"C read");a.Check(a.hipMemcpy(q.data(),qkv,q.size(),2),"Q read");a.Check(a.hipMemcpy(counts.data(),ready,counts.size()*4,2),"counter read");a.Check(a.hipMemcpy(fail.data(),status,fail.size()*4,2),"status read");a.Check(a.hipMemcpy(ticks.data(),trace,ticks.size()*8,2),"trace read");
  if(mode==0){goldC=c;goldQ=q;}size_t cdiff=0,qdiff=0,nan=0,timeouts=0,badcounts=0;for(size_t i=0;i<c.size();i++){cdiff+=c[i]!=goldC[i];nan+=(c[i]&127)==127;}for(size_t i=0;i<q.size();i++){qdiff+=q[i]!=goldQ[i];nan+=(q[i]&127)==127;}for(auto b:fail)timeouts+=b!=0;if(variant)for(auto b:counts)badcounts+=b!=16;
  std::string dir=argv[7],tag=mode==0?"original1":mode==1?"original2":mode==2?"ready-ordered":mode==3?"ready-anyorder":"ready-anyorder2";Write(dir+"/"+tag+".contract.bin",c.data(),c.size());Write(dir+"/"+tag+".qkv.bin",q.data(),q.size());
  if(variant){std::ofstream j(dir+"/"+tag+".trace.json");j<<"{\"clock_scope\":\"gpu_global_realtime\",\"clock_source\":\"gfx12 MSG_RTN_GET_REALTIME 131\",\"units\":\"ticks\",\"expected_producers\":"<<cg<<",\"expected_consumers\":"<<qg<<",\"wait_timeouts\":"<<timeouts<<",\"producers\":[";for(unsigned k=0;k<cg;k++){if(k)j<<',';j<<"{\"id\":"<<k<<",\"start\":"<<ticks[k*2]<<",\"published\":"<<ticks[k*2+1]<<'}';}j<<"],\"consumers\":[";for(unsigned k=0;k<qg;k++){if(k)j<<',';j<<"{\"id\":"<<k<<",\"enter\":"<<ticks[n*2+k*3]<<",\"work_start\":"<<ticks[n*2+k*3+1]<<",\"end\":"<<ticks[n*2+k*3+2]<<'}';}j<<"]}\n";}
  printf("PAIR mode=%s tokens=%u anyorder=%u gridC=%u gridQ=%u counter_bad=%zu timeouts=%zu contract_diff=%zu qkv_diff=%zu nonfinite=%zu gpu_ms=%.9f wall_ms=%.9f diagnostic_not_benchmark=1\n",tag.c_str(),n,mode>=3,cg,qg,badcounts,timeouts,cdiff,qdiff,nan,gpu,wall);
  if(cdiff||qdiff||nan||timeouts||badcounts){all=false;break;}
 }
 for(auto p:owned)a.Check(a.hipFree(p),"free");a.Check(a.hipEventDestroy(start),"destroy");a.Check(a.hipEventDestroy(end),"destroy");a.Check(a.hipStreamDestroy(stream),"destroy stream");for(auto m:modules)a.Check(a.hipModuleUnload(m),"unload");return all?0:1;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
