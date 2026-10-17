#pragma once
// Read-only diagnostic hooks, pinned to the two DLL hashes in the analysis report.
#include "MinHook.h"
#include <map>
#include <mutex>
namespace small_observe {
using Get=void*(*)(void*,const char*,uint32_t,uint32_t,uint32_t,uint64_t);
using Launch=int64_t(*)(void*,void*,uint32_t,uint32_t,uint32_t,void*,uint64_t,uint8_t);
static Get get;static Launch launch;static std::map<void*,std::string> names;static std::mutex mutex;
template<class T>T read(void*p,size_t o){T v{};SIZE_T n=0;ReadProcessMemory(GetCurrentProcess(),static_cast<char*>(p)+o,&v,sizeof(v),&n);return v;}
static void* get_hook(void*s,const char*n,uint32_t x,uint32_t y,uint32_t z,uint64_t q){auto k=get(s,n,x,y,z,q);std::lock_guard<std::mutex> g(mutex);names[k]=n?n:"?";return k;}
static int64_t launch_hook(void*s,void*k,uint32_t x,uint32_t y,uint32_t z,void*w,uint64_t size,uint8_t flag){
 std::string name;{std::lock_guard<std::mutex>g(mutex);name=names[k];}
 void*p=read<void*>(w,0);
 printf("KERNEL %s grid=%u,%u,%u param_bytes=%llu\n",name.c_str(),x,y,z,(unsigned long long)size);
 if(name.find("pre_block")!=std::string::npos||name.find("post_block")!=std::string::npos){
  printf("PARAM %s ",name.c_str());for(size_t i=0;i<size;i++)printf("%02x",read<unsigned char>(p,i));puts("");
 }
 return launch(s,k,x,y,z,w,size,flag);
}
static void install(HMODULE m,bool newer){auto b=reinterpret_cast<uintptr_t>(m);uintptr_t gr=newer?0x67450:0x44830,lr=newer?0x675c0:0x449a0;
 if(MH_Initialize()!=MH_OK||MH_CreateHook((void*)(b+gr),(void*)get_hook,(void**)&get)!=MH_OK||MH_CreateHook((void*)(b+lr),(void*)launch_hook,(void**)&launch)!=MH_OK||MH_EnableHook(MH_ALL_HOOKS)!=MH_OK)throw std::runtime_error("read-only observer hooks failed");
}
}
