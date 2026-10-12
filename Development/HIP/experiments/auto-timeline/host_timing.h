#pragma once
#include <windows.h>
#include <array>
#include <vector>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>
namespace auto_host_timing {
inline bool enabled=false;
inline long long frequency=0;
inline unsigned failures=0;
inline std::array<long long,11> ticks{};
struct Row {std::array<long long,11> marks{};double wall_ms{};};
inline std::vector<Row> rows;
inline void Initialize(unsigned n){const char*v=std::getenv("NR_AUTO_HOST_TIMING");if(v&&std::strcmp(v,"0")&&std::strcmp(v,"1"))throw std::runtime_error("host timing switch");enabled=v&&!std::strcmp(v,"1");LARGE_INTEGER f{};if(!QueryPerformanceFrequency(&f)||f.QuadPart<=0)throw std::runtime_error("QPC frequency");frequency=f.QuadPart;rows.resize(n);}
inline void Reset(){if(enabled)ticks.fill(0);}
inline void Mark(unsigned i){if(enabled){LARGE_INTEGER t{};if(!QueryPerformanceCounter(&t))++failures;else ticks[i]=t.QuadPart;}}
inline void Save(unsigned i,double elapsed){if(enabled)rows[i].marks=ticks;rows[i].wall_ms=elapsed;}
inline void Dump(const std::wstring&prefix){FILE*f=_wfopen((prefix+L".host.csv").c_str(),L"wb");if(!f)throw std::runtime_error("host timing csv open");fprintf(f,"frame,on,qpc_frequency,frame_wall_ms,t0_frame_begin,t1_input_begin,t2_input_end,t3_hip_begin,t4_hip_end,t5_network_end,t6_output_begin,t7_output_end,t8_process_return,t9_completion_begin,t10_completion_end\n");for(size_t i=0;i<rows.size();i++){fprintf(f,"%zu,%u,%lld,%.9f",i,unsigned(enabled),frequency,rows[i].wall_ms);for(auto t:rows[i].marks)fprintf(f,",%lld",t);fputc('\n',f);}if(fclose(f))throw std::runtime_error("host timing csv write");printf("HOST_TIMING on=%u frames=%zu qpc_frequency=%lld qpc_failures=%u gpu_commands_added=0 added_waits=0 export_after_frames=1\n",unsigned(enabled),rows.size(),frequency,failures);if(failures)throw std::runtime_error("host timing QPC failure");}
}
