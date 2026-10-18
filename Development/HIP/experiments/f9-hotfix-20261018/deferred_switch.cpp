#define DLSS5_BENCH_BRIDGE_ISOLATE
#include <cstring>
#include "fast_history_fixture.h"
#include "hip_d3d12_bridge.h"
#include "LmxxfProductionOptions.h"
#include <thread>
#include <condition_variable>
#include <set>
int main(int argc,char**argv)try{
 Require(argc==3||argc==4,"assets modules [cold]");if(argc==4)_putenv("DLSS5_MULTI_PASS=3");Gpu g(true);constexpr unsigned W=1920,H=1152;const size_t pixels=size_t(W)*H;
 auto input=g.Buffer(pixels*16);std::vector<float>v(pixels*4,.35f);for(size_t i=3;i<v.size();i+=4)v[i]=1;g.Upload(input.Get(),v);
 auto o=LmxxfProductionOptions(W,H,argv[2],argv[1]);o.small_geometry=true;
 hip_reference::D3D12Bridge b;b.RequestNeverHistory();b.Create(g.queue.Get(),o,{});
 ComPtr<ID3D12Fence> gate;Check(g.device->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&gate)),"gate");
 std::map<unsigned,std::vector<float>>answers;std::set<unsigned>warmed;UINT64 ticket=0;
 for(unsigned mode:{0u,1u,2u,3u,0u,1u,0u}){
  auto before=b.DiagnosticNetwork().WeightUploads();auto start=std::chrono::steady_clock::now();b.SetModelMode(mode);
  Check(g.allocator->Reset(),"reset allocator");Check(g.list->Reset(g.allocator.Get(),nullptr),"reset list");b.RecordInputCopy(g.list.Get(),input.Get());Check(g.list->Close(),"producer close");
  Check(g.queue->Wait(gate.Get(),++ticket),"withhold producer gate");ID3D12CommandList*lists[]={g.list.Get()};g.queue->ExecuteCommandLists(1,lists);
  std::mutex m;std::condition_variable cv;bool done=false,released=false;const auto target=ticket;
  std::thread rescue([&]{std::unique_lock<std::mutex>l(m);if(!cv.wait_for(l,std::chrono::seconds(8),[&]{return done;})){released=true;gate->Signal(target);}});
  try{b.EnqueueAfterProducer(g.queue.Get(),0);}catch(...){gate->Signal(ticket);{std::lock_guard<std::mutex>l(m);done=true;}cv.notify_one();rescue.join();throw;}
  {std::lock_guard<std::mutex>l(m);done=true;}cv.notify_one();rescue.join();
  const bool withheld=gate->GetCompletedValue()<ticket;Check(gate->Signal(ticket),"submit producer gate");
  Require(!released&&withheld,"enqueue waited for unsubmitted producer (rescue released own fence)");
  g.Run([&](auto*c){b.RecordOutputReadable(c);});b.NotifyOutputSubmitted(g.queue.Get());
  auto result=g.Read(b.Output());for(float x:result)Require(std::isfinite(x),"nonfinite output");
  if(answers.count(mode))Require(result==answers[mode],"same-model round-trip bit diff");else answers[mode]=result;
  const auto after=b.DiagnosticNetwork().WeightUploads();if(warmed.count(mode))Require(after==before,"warm model switch uploaded again");warmed.insert(mode);
  printf("PASS deferred mode=%s producer_withheld_at_return=1 uploads=%llu delta=%llu wall_ms=%.3f\n",dlss5_mode::Name(mode),after,after-before,std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count());fflush(stdout);
 }
 g.NoErrors();puts("PASS full 0.5->1->2->3->0.5, retained weights, repeat bit-exact");return 0;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
