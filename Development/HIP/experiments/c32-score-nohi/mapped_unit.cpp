#include "hip_api.h"
#include "c32_score_nohi_guard.h"
#include <cstring>
#include <iostream>
using namespace hip_probe;
static std::vector<unsigned char>Read(const std::string&p){std::ifstream f(p,std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("open "+p);size_t n=f.tellg();std::vector<unsigned char>b(n);f.seekg(0);if(!f.read(reinterpret_cast<char*>(b.data()),n))throw std::runtime_error("read "+p);return b;}
int main(int argc,char**argv)try{
 setvbuf(stdout,nullptr,_IONBF,0);if(argc!=8)throw std::runtime_error("mapped-unit STOCK CLONE INPUT FW AW GOLD OUTDIR");
 auto in=Read(argv[3]),fw=Read(argv[4]),aw=Read(argv[5]),gold=Read(argv[6]);const size_t n=17694720,guard=256;
 if(in.size()!=n||gold.size()!=n||fw.size()!=41088||aw.size()!=32900)throw std::runtime_error("operand logical span");
 std::vector<float>w(aw.size()/4);std::memcpy(w.data(),aw.data(),aw.size());if(!C32NoHiCertified(w))throw std::runtime_error("weight not certified");C32NoHiRequireShader(argv[2]);
 Api a(7);a.Check(a.hipInit(0),"init");a.Check(a.hipSetDevice(0),"device");Handle modules[2]{},f[2]{};a.Check(a.LoadModule(&modules[0],argv[1]),"stock");a.Check(a.LoadModule(&modules[1],argv[2]),"clone");a.Check(a.hipModuleGetFunction(&f[0],modules[0],"c32_wave1_mapped_b8"),"stock Fn");a.Check(a.hipModuleGetFunction(&f[1],modules[1],"c32_wave1_mapped_b8_nohi"),"clone Fn");
 std::vector<void*>owned;auto upload=[&](const auto&b){void*p{};a.Check(a.hipMalloc(&p,b.size()),"alloc");owned.push_back(p);a.Check(a.hipMemcpy(p,b.data(),b.size(),1),"upload");return p;};void*input=upload(in),*ffn=upload(fw),*attention=upload(aw),*out{};a.Check(a.hipMalloc(&out,n+guard),"output");owned.push_back(out);
 unsigned windows=8640,mode=0,raw=1,width=960,height=576,sx=0,sy=0;void*reuse=nullptr;void*args[]{&input,&ffn,&attention,&out,&windows,&mode,&raw,&width,&height,&sx,&sy,&reuse};
 for(unsigned test=0;test<4;test++){
  bool clone=test>=2;a.Check(a.hipMemsetAsync(out,0xa5,n+guard,nullptr),"poison");a.Check(a.hipModuleLaunchKernel(f[clone],8640,1,1,32,1,1,0,nullptr,args,nullptr),"launch mapped");a.Check(a.hipDeviceSynchronize(),"completion");std::vector<unsigned char>b(n+guard);a.Check(a.hipMemcpy(b.data(),out,b.size(),2),"read");
  size_t diff=0,nan=0,tail=0;for(size_t i=0;i<n;i++){diff+=b[i]!=gold[i];nan+=(b[i]&127)==127;}for(size_t i=n;i<b.size();i++)tail+=b[i]!=0xa5;
  std::cout<<"MAPPED_UNIT test="<<test<<" clone="<<clone<<" windows=8640 logical_bytes="<<n<<" byte_diff="<<diff<<" fp8_nan="<<nan<<" tail_guard_diff="<<tail<<"\n";
  std::string tag=std::string(argv[7])+"/"+(clone?"clone":"stock")+std::to_string(test%2)+".fp8";std::ofstream file(tag,std::ios::binary);if(!file.write(reinterpret_cast<char*>(b.data()),n))throw std::runtime_error("write");
  if(diff||nan||tail)throw std::runtime_error("unit gold failed");
 }
 for(auto p:owned)a.Check(a.hipFree(p),"free");for(auto m:modules)a.Check(a.hipModuleUnload(m),"unload");return 0;
}catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<"\n";return 2;}
