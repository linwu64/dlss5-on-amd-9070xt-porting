#ifndef ORACLE_WIDTH
#define ORACLE_WIDTH 1920
#endif
#ifndef ORACLE_REPEATS
#define ORACLE_REPEATS 2
#endif
#ifndef ORACLE_HEIGHT
#define ORACLE_HEIGHT 1080
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <cstdio>
#include <string>
#include <vector>
#include <fstream>
#include <cmath>
#include "../issue13-original-oracle/ngx_direct_abi.h"
#ifdef ORACLE_OBSERVE
#include "observe_parameters.h"
#endif
#ifdef ORACLE_CAPTURE
#include "MinHook.h"
#include "capture_network.h"
#endif
#include "nvsdk_ngx_defs.h"
using NVSDK_NGX_Parameter=void;
static void ck(HRESULT h,const char*k){if(FAILED(h)){printf("D3D_FAIL %s %08x\n",k,unsigned(h));ExitProcess(1);}}
template<class T>T sym(HMODULE m,const char*n){auto p=GetProcAddress(m,n);if(!p){printf("EXPORT_MISSING %s\n",n);ExitProcess(2);}return reinterpret_cast<T>(p);}
void su(void*p,const char*k,unsigned n){auto v=*reinterpret_cast<void***>(p);reinterpret_cast<void(*)(void*,const char*,unsigned)>(v[4])(p,k,n);}
void sf(void*p,const char*k,float n){auto v=*reinterpret_cast<void***>(p);reinterpret_cast<void(*)(void*,const char*,float)>(v[6])(p,k,n);}
void logngx(const char*m,NVSDK_NGX_Logging_Level l,NVSDK_NGX_Feature f){printf("NGX[%d][%d] %s\n",int(l),int(f),m);}
int wmain(int argc,wchar_t**argv){setvbuf(stdout,nullptr,_IONBF,0);if(argc<6)return 2;const unsigned preset=unsigned(std::wcstoul(argv[5],nullptr,10));if(preset>2)return 2;printf("PRESET=%u reset=1 style=1 history=off\n",preset);IDXGIFactory4*f=nullptr;ck(CreateDXGIFactory1(IID_PPV_ARGS(&f)),"factory");ID3D12Device*d=nullptr;IDXGIAdapter1*a=nullptr;for(unsigned i=0;f->EnumAdapters1(i,&a)!=DXGI_ERROR_NOT_FOUND;i++){DXGI_ADAPTER_DESC1 ad{};a->GetDesc1(&ad);if(ad.VendorId==0x10de&&SUCCEEDED(D3D12CreateDevice(a,D3D_FEATURE_LEVEL_12_0,IID_PPV_ARGS(&d))))break;a->Release();a=nullptr;}if(!d)return 3;D3D12_COMMAND_QUEUE_DESC qd{};ID3D12CommandQueue*q=nullptr;ck(d->CreateCommandQueue(&qd,IID_PPV_ARGS(&q)),"queue");ID3D12CommandAllocator*al=nullptr;ID3D12GraphicsCommandList*l=nullptr;ck(d->CreateCommandAllocator(D3D12_COMMAND_LIST_TYPE_DIRECT,IID_PPV_ARGS(&al)),"alloc");ck(d->CreateCommandList(0,D3D12_COMMAND_LIST_TYPE_DIRECT,al,nullptr,IID_PPV_ARGS(&l)),"list");
 HMODULE core=LoadLibraryW(argv[1]);if(!core){printf("LOAD_FAIL %lu\n",GetLastError());return 4;}
 using Init=NVSDK_NGX_Result(*)(unsigned long long,const wchar_t*,ID3D12Device*,NVSDK_NGX_Version,const NVSDK_NGX_FeatureCommonInfo*);auto init=sym<Init>(core,"NVSDK_NGX_D3D12_Init_Ext");using Caps=NVSDK_NGX_Result(*)(NVSDK_NGX_Parameter**);auto caps=sym<Caps>(core,"NVSDK_NGX_D3D12_GetCapabilityParameters");using Create=NVSDK_NGX_Result(*)(ID3D12GraphicsCommandList*,NVSDK_NGX_Feature,NVSDK_NGX_Parameter*,NVSDK_NGX_Handle**);auto create=sym<Create>(core,"NVSDK_NGX_D3D12_CreateFeature");
 const wchar_t*paths[]={argv[2]};NVSDK_NGX_FeatureCommonInfo fc{};fc.PathListInfo.Path=paths;fc.PathListInfo.Length=1;fc.LoggingInfo.LoggingCallback=logngx;fc.LoggingInfo.MinimumLoggingLevel=NVSDK_NGX_LOGGING_LEVEL_VERBOSE;auto r=init(0x24480451ull,argv[2],d,NVSDK_NGX_Version(0x15),&fc);printf("INIT=%08x\n",unsigned(r));if(r!=1)return 5;NVSDK_NGX_Parameter*p=nullptr;r=caps(&p);printf("CAPS=%08x params=%p\n",unsigned(r),p);if(r!=1||!p)return 6;
 auto vt=*reinterpret_cast<void***>(p);sf(p,"DLSSNR.Probe",.3125f);float value=0;auto gr=reinterpret_cast<NVSDK_NGX_Result(*)(void*,const char*,float*)>(vt[14])(p,"DLSSNR.Probe",&value);printf("FLOAT_ABI=%08x value=%g\n",unsigned(gr),value);
 su(p,"DLSSNR.Enabled",1);su(p,"DLSSNR.Width",ORACLE_WIDTH);su(p,"DLSSNR.Height",ORACLE_HEIGHT);su(p,"Width",ORACLE_WIDTH);su(p,"Height",ORACLE_HEIGHT);su(p,"CreationNodeMask",1);su(p,"VisibilityNodeMask",1);su(p,"DLSSNR.Hint.Render.Preset",preset);su(p,"DLSSNR.Style",1);sf(p,"DLSSNR.Intensity",1);sf(p,"DLSSNR.LocalStructureStrength",1);sf(p,"DLSSNR.LocalToneStrength",1);sf(p,"DLSSNR.SkinStructureStrength",-1);su(p,"DLSSNR.UseAutoMask",1);su(p,"DLSSNR.UICorrection",0);

#ifdef ORACLE_OBSERVE
 auto plug=GetModuleHandleW(L"nvngx_dlssnr.dll");small_observe::install(plug,std::wstring(argv[2]).find(L"new")!=std::wstring::npos);
#endif

#ifdef ORACLE_CAPTURE
 auto capture_plugin=GetModuleHandleW(L"nvngx_dlssnr.dll");if(OriginalObserveInstall(capture_plugin,(std::wstring(argv[4])+L"/launch-observe.txt").c_str(),std::wstring(argv[2]).find(L"new")!=std::wstring::npos))throw std::runtime_error("capture hooks");
#endif
 NVSDK_NGX_Handle*h=nullptr;r=create(l,NVSDK_NGX_Feature(18),p,&h);printf("CREATE18=%08x handle=%p\n",unsigned(r),h);if(r!=1)return 7;l->Close();ID3D12CommandList*ls[]={l};q->ExecuteCommandLists(1,ls);ID3D12Fence*fe=nullptr;ck(d->CreateFence(0,D3D12_FENCE_FLAG_NONE,IID_PPV_ARGS(&fe)),"fence");HANDLE e=CreateEventW(nullptr,FALSE,FALSE,nullptr);q->Signal(fe,1);fe->SetEventOnCompletion(1,e);printf("CREATE_FENCE_WAIT=%lu\n",WaitForSingleObject(e,30000));if(argc<5)return 0;
 auto wait=[&](){static UINT64 fv=1;q->Signal(fe,++fv);fe->SetEventOnCompletion(fv,e);if(WaitForSingleObject(e,30000)!=WAIT_OBJECT_0){puts("WAIT_TIMEOUT");ExitProcess(9);}};
 auto buffer=[&](UINT64 n,D3D12_HEAP_TYPE type){D3D12_HEAP_PROPERTIES hp{};hp.Type=type;D3D12_RESOURCE_DESC rd{};rd.Dimension=D3D12_RESOURCE_DIMENSION_BUFFER;rd.Width=n;rd.Height=1;rd.DepthOrArraySize=rd.MipLevels=1;rd.SampleDesc.Count=1;rd.Layout=D3D12_TEXTURE_LAYOUT_ROW_MAJOR;ID3D12Resource*r=nullptr;ck(d->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,type==D3D12_HEAP_TYPE_UPLOAD?D3D12_RESOURCE_STATE_GENERIC_READ:D3D12_RESOURCE_STATE_COPY_DEST,nullptr,IID_PPV_ARGS(&r)),"buffer");return r;};

#ifdef ORACLE_CAPTURE
 D3D12_HEAP_PROPERTIES chp{};chp.Type=D3D12_HEAP_TYPE_DEFAULT;D3D12_RESOURCE_DESC crd{};crd.Dimension=D3D12_RESOURCE_DIMENSION_BUFFER;crd.Width=uint64_t(ORACLE_WIDTH)*ORACLE_HEIGHT*16*2;crd.Height=1;crd.DepthOrArraySize=crd.MipLevels=1;crd.SampleDesc.Count=1;crd.Layout=D3D12_TEXTURE_LAYOUT_ROW_MAJOR;crd.Flags=D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;ID3D12Resource*cap=nullptr;ck(d->CreateCommittedResource(&chp,D3D12_HEAP_FLAG_NONE,&crd,D3D12_RESOURCE_STATE_UNORDERED_ACCESS,nullptr,IID_PPV_ARGS(&cap)),"capture buffer");OriginalCaptureDestination(cap->GetGPUVirtualAddress());
#endif
 auto texture=[&](DXGI_FORMAT format,D3D12_RESOURCE_STATES state){D3D12_HEAP_PROPERTIES hp{};hp.Type=D3D12_HEAP_TYPE_DEFAULT;D3D12_RESOURCE_DESC rd{};rd.Dimension=D3D12_RESOURCE_DIMENSION_TEXTURE2D;rd.Width=ORACLE_WIDTH;rd.Height=ORACLE_HEIGHT;rd.DepthOrArraySize=rd.MipLevels=1;rd.SampleDesc.Count=1;rd.Format=format;rd.Flags=D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;ID3D12Resource*r=nullptr;ck(d->CreateCommittedResource(&hp,D3D12_HEAP_FLAG_NONE,&rd,state,nullptr,IID_PPV_ARGS(&r)),"texture");return r;};
 auto color=texture(DXGI_FORMAT_R16G16B16A16_FLOAT,D3D12_RESOURCE_STATE_COPY_DEST),output=texture(DXGI_FORMAT_R32G32B32A32_FLOAT,D3D12_RESOURCE_STATE_UNORDERED_ACCESS),depth=texture(DXGI_FORMAT_R32_FLOAT,D3D12_RESOURCE_STATE_COPY_DEST),motion=texture(DXGI_FORMAT_R16G16_FLOAT,D3D12_RESOURCE_STATE_COPY_DEST);
 auto upload=[&](ID3D12Resource*r,const void*src,size_t bytes_per_pixel){auto rd=r->GetDesc();D3D12_PLACED_SUBRESOURCE_FOOTPRINT fp{};UINT64 bytes=0;d->GetCopyableFootprints(&rd,0,1,0,&fp,nullptr,nullptr,&bytes);auto up=buffer(bytes,D3D12_HEAP_TYPE_UPLOAD);void*dst=nullptr;D3D12_RANGE z{0,0};up->Map(0,&z,&dst);for(unsigned y=0;y<ORACLE_HEIGHT;y++)memcpy(static_cast<char*>(dst)+fp.Offset+size_t(y)*fp.Footprint.RowPitch,static_cast<const char*>(src)+size_t(y)*ORACLE_WIDTH*bytes_per_pixel,ORACLE_WIDTH*bytes_per_pixel);up->Unmap(0,nullptr);al->Reset();l->Reset(al,nullptr);D3D12_TEXTURE_COPY_LOCATION a{},b{};a.pResource=r;a.Type=D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;b.pResource=up;b.Type=D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;b.PlacedFootprint=fp;l->CopyTextureRegion(&a,0,0,0,&b,nullptr);D3D12_RESOURCE_BARRIER br{};br.Transition={r,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,D3D12_RESOURCE_STATE_COPY_DEST,D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE};l->ResourceBarrier(1,&br);l->Close();ID3D12CommandList*ls[]={l};q->ExecuteCommandLists(1,ls);wait();up->Release();};
 std::vector<float>dep(ORACLE_WIDTH*ORACLE_HEIGHT,1.f);std::vector<unsigned>mv(ORACLE_WIDTH*ORACLE_HEIGHT,0);upload(depth,dep.data(),4);upload(motion,mv.data(),4);
 auto evaluate=sym<ngx_direct::Eval>(core,"NVSDK_NGX_D3D12_EvaluateFeature");CreateDirectoryW(argv[4],nullptr);
 for(const wchar_t*frame:{L"8678",L"8680"}){std::wstring path=std::wstring(argv[3])+L"/"+frame+L".rgba16f";std::ifstream inf(path.c_str(),std::ios::binary);std::vector<unsigned short>data(ORACLE_WIDTH*ORACLE_HEIGHT*4);if(!inf.read(reinterpret_cast<char*>(data.data()),data.size()*2))return 11;
 if(frame[3]=='0'){al->Reset();l->Reset(al,nullptr);D3D12_RESOURCE_BARRIER b{};b.Transition={color,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,D3D12_RESOURCE_STATE_NON_PIXEL_SHADER_RESOURCE,D3D12_RESOURCE_STATE_COPY_DEST};l->ResourceBarrier(1,&b);l->Close();ID3D12CommandList*ls[]={l};q->ExecuteCommandLists(1,ls);wait();}upload(color,data.data(),8);
 for(int repeat=1;repeat<=ORACLE_REPEATS;repeat++){al->Reset();l->Reset(al,nullptr);ngx_direct::Evaluation(p,color,output,depth,motion,ORACLE_WIDTH,ORACLE_HEIGHT);su(p,"DLSSNR.Hint.Render.Preset",preset);su(p,"DLSSNR.Style",1);su(p,"DLSSNR.UICorrection",0);
#ifdef ORACLE_CAPTURE
 OriginalCaptureCommandList(l);
#endif
 auto er=evaluate(l,reinterpret_cast<ngx_direct::Handle*>(h),p,nullptr);printf("EVAL frame=%ls repeat=%d result=%08x\n",frame,repeat,unsigned(er));if(er!=1)return 12;
 D3D12_RESOURCE_BARRIER b{};b.Transition={output,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,D3D12_RESOURCE_STATE_UNORDERED_ACCESS,D3D12_RESOURCE_STATE_COPY_SOURCE};l->ResourceBarrier(1,&b);auto rd=output->GetDesc();D3D12_PLACED_SUBRESOURCE_FOOTPRINT fp{};UINT64 bytes=0;d->GetCopyableFootprints(&rd,0,1,0,&fp,nullptr,nullptr,&bytes);auto rb=buffer(bytes,D3D12_HEAP_TYPE_READBACK);D3D12_TEXTURE_COPY_LOCATION a{},c{};a.pResource=rb;a.Type=D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;a.PlacedFootprint=fp;c.pResource=output;c.Type=D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;l->CopyTextureRegion(&a,0,0,0,&c,nullptr);std::swap(b.Transition.StateBefore,b.Transition.StateAfter);l->ResourceBarrier(1,&b);l->Close();ID3D12CommandList*ls[]={l};q->ExecuteCommandLists(1,ls);wait();void*map=nullptr;D3D12_RANGE range{0,size_t(bytes)};rb->Map(0,&range,&map);std::vector<float>rgb(ORACLE_WIDTH*ORACLE_HEIGHT*3);size_t nonfinite=0;for(size_t y=0;y<ORACLE_HEIGHT;y++){auto row=reinterpret_cast<const float*>(static_cast<char*>(map)+fp.Offset+y*fp.Footprint.RowPitch);for(size_t x=0;x<ORACLE_WIDTH;x++)for(size_t k=0;k<3;k++){float v=row[x*4+k];rgb[(y*ORACLE_WIDTH+x)*3+k]=v;nonfinite+=!std::isfinite(v);}}rb->Unmap(0,nullptr);rb->Release();std::wstring op=std::wstring(argv[4])+L"/"+frame+L"-"+std::to_wstring(repeat)+L".rgb32";std::ofstream of(op.c_str(),std::ios::binary);of.write(reinterpret_cast<const char*>(rgb.data()),rgb.size()*4);printf("OUTPUT frame=%ls repeat=%d nonfinite=%zu\n",frame,repeat,nonfinite);if(nonfinite)return 13;
#ifdef ORACLE_CAPTURE
 al->Reset();l->Reset(al,nullptr);D3D12_RESOURCE_BARRIER cb{};cb.Transition={cap,D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES,D3D12_RESOURCE_STATE_UNORDERED_ACCESS,D3D12_RESOURCE_STATE_COPY_SOURCE};l->ResourceBarrier(1,&cb);auto caprb=buffer(crd.Width,D3D12_HEAP_TYPE_READBACK);l->CopyBufferRegion(caprb,0,cap,0,crd.Width);std::swap(cb.Transition.StateBefore,cb.Transition.StateAfter);l->ResourceBarrier(1,&cb);l->Close();ID3D12CommandList*cs[]={l};q->ExecuteCommandLists(1,cs);wait();void*cm=nullptr;D3D12_RANGE rr{0,size_t(crd.Width)};caprb->Map(0,&rr,&cm);std::wstring cp=std::wstring(argv[4])+L"/"+frame+L"-"+std::to_wstring(repeat)+L"-capture.rgba32";std::ofstream cf(cp.c_str(),std::ios::binary);cf.write(static_cast<const char*>(cm),crd.Width);caprb->Unmap(0,nullptr);caprb->Release();
#endif
 }}return 0;}
