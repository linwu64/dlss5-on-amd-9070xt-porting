// CPU-only: no device creation, HIP runtime loading, shader or GPU dispatch.
#include "../../hip_d3d12_bridge.h"
#include <iostream>
using hip_reference::D3D12Bridge;
template<class F>void rejects(const char*name,F f){try{f();}catch(const std::runtime_error&e){if(std::string(e.what()).find("history")==std::string::npos)throw;std::cout<<"REJECT "<<name<<" "<<e.what()<<"\n";return;}throw std::runtime_error(name);}
int main(){try{
 {D3D12Bridge b;b.RequestNeverHistory();b.RequireHistory(false);rejects("temporal",[&]{b.RequireHistory(true);});rejects("direct-after-never",[&]{b.RequestDirectHistory();});rejects("aux-after-never",[&]{b.RequestPostAuxiliary(std::vector<float>(32));});rejects("record-input",[&]{b.RecordInputCopy(nullptr,nullptr,reinterpret_cast<ID3D12Resource*>(1));});rejects("recorded-execution",[&]{b.BeginRecordedExecution(nullptr,true);});rejects("enqueue",[&]{b.EnqueueAfterProducer(nullptr,0,true);});hip_reference::Options o;o.experimental_temporal=true;rejects("experimental-create",[&]{b.Create(nullptr,o,{});});}
 {D3D12Bridge b;b.RequestDirectHistory();rejects("never-after-direct",[&]{b.RequestNeverHistory();});}
 {D3D12Bridge b;b.RequestPostAuxiliary(std::vector<float>(32));rejects("never-after-aux",[&]{b.RequestNeverHistory();});}
 std::cout<<"PASS CPU_ONLY EMPTY_RESOURCE_DESTRUCTION\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
