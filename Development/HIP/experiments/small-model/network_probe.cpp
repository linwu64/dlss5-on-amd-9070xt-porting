#include "LmxxfProductionOptions.h"
#include <chrono>
#include <numeric>
#include <iostream>
int main(int argc,char**argv){try{
 if(argc<5)return 2;
 auto o=LmxxfProductionOptions(1920,1152,argv[2],argv[1]);o.pdl=false;o.submit_pulse=0;
 hip_reference::Network net(o);net.SetNoise({});auto&api=net.Runtime();auto input=hip_reference::ReadBytes(argv[3]);if(input.size()!=1920ull*1152*16)throw std::runtime_error("input size");void*in=nullptr,*out=nullptr;api.Check(api.hipMalloc(&in,input.size()),"input");const size_t bytes=1920ull*1152*12;api.Check(api.hipMalloc(&out,bytes),"output");api.Check(api.hipMemcpy(in,input.data(),input.size(),1),"upload");
 unsigned frames=argc>5?unsigned(std::stoul(argv[5])):12;std::vector<double>times;
 for(unsigned i=0;i<frames+3;i++){auto start=std::chrono::steady_clock::now();net.Enqueue(in,nullptr,out,0);net.Synchronize();double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();if(i>=3)times.push_back(ms);std::cout<<"frame="<<i<<" ms="<<ms<<"\n";}
 std::vector<char>result(bytes);api.Check(api.hipMemcpy(result.data(),out,bytes,2),"read");std::ofstream f(argv[4],std::ios::binary);f.write(result.data(),result.size());std::sort(times.begin(),times.end());double mean=std::accumulate(times.begin(),times.end(),0.)/times.size();if(argc>6&&std::string(argv[6])=="switch"){
  auto expected=result;for(unsigned mode:{1u,2u,3u,0u}){net.SetModelMode(mode);net.Enqueue(in,nullptr,out,0);net.Synchronize();std::vector<char>v(bytes);api.Check(api.hipMemcpy(v.data(),out,bytes,2),"switch read");std::ofstream sf(std::string(argv[4])+".mode-"+dlss5_mode::Name(mode),std::ios::binary);sf.write(v.data(),v.size());if(mode==0&&v!=expected)throw std::runtime_error("Small round-trip changed bits");std::cout<<"SWITCH mode="<<dlss5_mode::Name(mode)<<" effective="<<dlss5_mode::Name(net.EffectiveModelMode())<<" complete=1\n";}
 }
 std::cout<<"RESULT model="<<dlss5_mode::Name(net.EffectiveModelMode())<<" mean_ms="<<mean<<" median_ms="<<times[times.size()/2]<<"\n";api.hipFree(in);api.hipFree(out);return 0;
 }catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
