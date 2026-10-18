#include <cstring>
#include "native_hot_flags.h"
#include <filesystem>
#include <stdexcept>
static void Check(bool ok,const char*m){if(!ok)throw std::runtime_error(m);}
static void Write(const std::wstring&p,const char*s){FILE*f=_wfopen(p.c_str(),L"wb");Check(f,"create fixture");fputs(s,f);fclose(f);}
int wmain(int argc,wchar_t**argv)try{
 Check(argc==2,"fixture path");std::filesystem::create_directories(argv[1]);NativeLabRootOverride()=argv[1];
 for(const wchar_t*n:NativeConfigLayerNames)Write(NativeLabPath(n),"DLSS5_HOT_RELOAD=1\nDLSS5_MULTI_PASS=0.5\n");
 NativeHotFlags::Instance().Get();
 for(const wchar_t*n:{L"custom-config.txt",L"native-game-flags.txt"})Check(SetFileAttributesW(NativeLabPath(n).c_str(),FILE_ATTRIBUTE_READONLY),"read-only");
 dlss5_mode::Request(0);
 for(unsigned want:{1u,2u,3u,0u,1u}){
  NativeHotFlags::CycleMultiPass(dlss5_mode::Requested());Check(dlss5_mode::Requested()==want,"immediate memory mode");
  Check(NativePollRequestedModelMode()==want,"same-tick poll overwrote mode");Sleep(1100);
  Check(NativePollRequestedModelMode()==want,"one-second poll overwrote mode");
  std::string s;Check(NativeConfigReadFile(NativeLabPath(L"native-game-flags.txt"),s)&&s.find("MULTI_PASS=0.5")!=std::string::npos,"readonly fixture changed");
  printf("PASS readonly immediate+next-tick mode=%s disk=0.5\n",dlss5_mode::Name(want));
 }
 for(const wchar_t*n:{L"custom-config.txt",L"native-game-flags.txt"})SetFileAttributesW(NativeLabPath(n).c_str(),FILE_ATTRIBUTE_NORMAL);
 Sleep(1100);Write(NativeLabPath(L"native-game-flags.txt"),"DLSS5_HOT_RELOAD=1\nDLSS5_MULTI_PASS=2\n");Sleep(1100);
 Check(NativePollRequestedModelMode()==2,"external edit failed to supersede memory");puts("PASS subsequent external config edit takes effect");return 0;
}catch(const std::exception&e){fprintf(stderr,"FAIL %s\n",e.what());return 1;}
