// Include after windows.h, MinHook.h; call OriginalObserveInstall(plugin,logpath) BEFORE CreateFeature.
// Pinned 310.8 + 310.9.16 backend RVAs independently checked in disassembly. No seed/parameter edits.
#include <cstdint>
#include <map>
#include <string>
#include <mutex>
#include <cstdio>
#include <cstring>
#include "../../../capture_raw_buffer_cubin.inc"
namespace original_observe {
using GetKernel=void*(*)(void*,const char*,uint32_t,uint32_t,uint32_t,uint64_t);
using Launch=int64_t(*)(void*,void*,uint32_t,uint32_t,uint32_t,void*,uint64_t,uint8_t);
static GetKernel get{};static Launch launch{};static std::map<void*,std::string> names;static std::mutex guard;
template<class T>T at(const void*p,size_t o){T v{};SIZE_T n{};if(p)ReadProcessMemory(GetCurrentProcess(),static_cast<const char*>(p)+o,&v,sizeof(v),&n);return v;}
static ID3D12GraphicsCommandList* barrier_commands{};
static uintptr_t plugin_base{};static bool newer{};static uint64_t capture_va{};static void*cap_backend{},*cap_texture{},*cap_surface{};static constexpr uint32_t CW=ORACLE_WIDTH,CH=ORACLE_HEIGHT;static constexpr uint64_t PLANE=uint64_t(CW)*CH*16;
static void capture(void*self,void*restore_kernel,uint64_t object,bool surface,uint32_t sourcew,uint32_t sourceh){
 void*ctx=at<void*>(self,8);void*cmd=at<void*>(self,16);
 if(!capture_va)return;
 if(!cap_backend){
  auto cb=reinterpret_cast<void*(*)(void*)>(plugin_base+(newer?0x673d0:0x447b0));auto sc=reinterpret_cast<void(*)(void*,void*)>(plugin_base+(newer?0x67790:0x44b70));auto sm=reinterpret_cast<void(*)(void*,void*,uint32_t)>(plugin_base+(newer?0x67780:0x44b60));
  cap_backend=cb(ctx);sc(cap_backend,cmd);sm(cap_backend,_tmp_capture_raw_buffer_cubin,_tmp_capture_raw_buffer_cubin_len);
  cap_texture=get(cap_backend,"capture_texture_rgba",16,16,1,0);cap_surface=get(cap_backend,"capture_surface_rgba16f",16,16,1,0);
 }
 struct Desc{void*vt;void*blob;uint32_t bytes,pad;};auto vt=*reinterpret_cast<void***>(ctx);auto bind=reinterpret_cast<int(*)(void*,void*)>(vt[0xd8/8]);auto dispatch=reinterpret_cast<int(*)(void*,void*,void*,uint32_t,uint32_t,uint32_t)>(vt[0x140/8]);
 struct T{uint64_t object,dst;uint32_t w,h,sw,sh,x,y,sx,sy;}t{object,capture_va,CW,CH,1,1,0,0,1,1};
 struct S{uint64_t object,dst;uint32_t w,h,x,y,sx,sy;}a{object,capture_va+PLANE,CW,CH,0,0,1,1};
 Desc desc{reinterpret_cast<void*>(plugin_base+(newer?0xdf858:0xb28b8)),surface?static_cast<void*>(&a):static_cast<void*>(&t),surface?uint32_t(sizeof(a)):uint32_t(sizeof(t)),0};
 int br=bind(ctx,surface?cap_surface:cap_texture),dr=dispatch(ctx,&desc,cmd,(CW+15)/16,(CH+15)/16,1);bind(ctx,restore_kernel);
 printf("RAW_CAPTURE surface=%u bind=%d dispatch=%d object=%llx\n",unsigned(surface),br,dr,(unsigned long long)object);fflush(stdout);
}
static std::wstring path;static unsigned serial{};

static void* get_hook(void*self,const char*n,uint32_t a,uint32_t b,uint32_t c,uint64_t d){void*r=get(self,n,a,b,c,d);std::lock_guard<std::mutex>l(guard);names[r]=n?n:"?";return r;}
static int64_t launch_hook(void*self,void*k,uint32_t gx,uint32_t gy,uint32_t gz,void*wrapper,uint64_t bytes,uint8_t flag){
 void*blob=at<void*>(wrapper,0);std::string name;unsigned id;
 {std::lock_guard<std::mutex>l(guard);name=names.count(k)?names[k]:"?";id=serial++;
 if(FILE*f=_wfopen(path.c_str(),L"ab")){
  fprintf(f,"launch=%u kernel=%s kernelptr=%p grid=%u,%u,%u bytes=%llu flag=%u blob=%p ngxctx=%p commandctx=%p\n",id,name.c_str(),k,gx,gy,gz,(unsigned long long)bytes,flag,blob,at<void*>(self,8),at<void*>(self,16));
  if(blob&&bytes<=4096){
   if(name.find("pre_block")!=std::string::npos||bytes==0x108)fprintf(f,"PRE seed=%u style=%.9g texH=%u texW=%u procDims=%llx colorTex_00=%llx historyTex_08=%llx motionTex_10=%llx\n",at<uint32_t>(blob,newer?0xd0:0xc8),at<float>(blob,newer?0xb8:0xb4),at<uint32_t>(blob,newer?0xd8:0xd0),at<uint32_t>(blob,newer?0xdc:0xd4),(unsigned long long)at<uint64_t>(blob,newer?0xf8:0xf0),(unsigned long long)at<uint64_t>(blob,0),(unsigned long long)at<uint64_t>(blob,8),(unsigned long long)at<uint64_t>(blob,16));
   if(name.find("post_block")!=std::string::npos||bytes==0xb8)fprintf(f,"POST main00=%llx skip08=%llx surface10=%llx weights18=%llx height20=%u width24=%u origin28=%d,%d scale30=%.9g rgbmode34=%u color38=%llx word70=%u\n",(unsigned long long)at<uint64_t>(blob,0),(unsigned long long)at<uint64_t>(blob,8),(unsigned long long)at<uint64_t>(blob,16),(unsigned long long)at<uint64_t>(blob,24),at<uint32_t>(blob,0x20),at<uint32_t>(blob,0x24),at<int32_t>(blob,0x28),at<int32_t>(blob,0x2c),at<float>(blob,0x30),at<uint32_t>(blob,0x34),(unsigned long long)at<uint64_t>(blob,0x38),at<uint32_t>(blob,0x70));
   fprintf(f,"PARAMHEX ");for(size_t i=0;i<size_t(bytes);i++)fprintf(f,"%02x",at<unsigned char>(blob,i));fprintf(f,"\n");
  }fclose(f);
 }}
 bool pre=name.find("pre_block")!=std::string::npos;bool post=name.find("post_block")!=std::string::npos;
 if(pre)capture(self,k,at<uint64_t>(blob,0),false,at<uint32_t>(blob,newer?0xdc:0xd4),at<uint32_t>(blob,newer?0xd8:0xd0));
 auto result=launch(self,k,gx,gy,gz,wrapper,bytes,flag);
 if(post){
  D3D12_RESOURCE_BARRIER b{};b.Type=D3D12_RESOURCE_BARRIER_TYPE_UAV;
  if(barrier_commands)barrier_commands->ResourceBarrier(1,&b);
  capture(self,k,at<uint64_t>(blob,0x10),true,0,0);
  if(barrier_commands)barrier_commands->ResourceBarrier(1,&b);
 }
 return result;
}
}
static int OriginalObserveInstall(HMODULE plugin,const wchar_t*logpath,bool is_new){
 using namespace original_observe;newer=is_new;path=logpath;plugin_base=reinterpret_cast<uintptr_t>(plugin);auto s=MH_Initialize();if(s!=MH_OK&&s!=MH_ERROR_ALREADY_INITIALIZED)return 1;
 auto base=reinterpret_cast<uintptr_t>(plugin);void*a=reinterpret_cast<void*>(base+(newer?0x67450:0x44830)),*b=reinterpret_cast<void*>(base+(newer?0x675c0:0x449a0));
 if(MH_CreateHook(a,reinterpret_cast<void*>(&get_hook),reinterpret_cast<void**>(&get))!=MH_OK)return 2;
 if(MH_CreateHook(b,reinterpret_cast<void*>(&launch_hook),reinterpret_cast<void**>(&launch))!=MH_OK)return 3;
 if(MH_EnableHook(a)!=MH_OK)return 4;if(MH_EnableHook(b)!=MH_OK)return 5;return 0;
}

static void OriginalCaptureDestination(uint64_t va){original_observe::capture_va=va;}

static void OriginalCaptureCommandList(ID3D12GraphicsCommandList*l){original_observe::barrier_commands=l;}
