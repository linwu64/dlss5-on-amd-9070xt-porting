#pragma once
#include <windows.h>
#include <bcrypt.h>
#include <fstream>
#include <vector>
#include <string>
// Cold-only complete-file SHA check. No Run-path hashing/API calls.
inline bool ContractCompactFileSha(const std::string& file,const char* expected){
 std::ifstream f(std::filesystem::u8path(file),std::ios::binary);if(!f)return false;
 BCRYPT_ALG_HANDLE alg{};BCRYPT_HASH_HANDLE h{};bool ok=false;
 if(BCryptOpenAlgorithmProvider(&alg,BCRYPT_SHA256_ALGORITHM,nullptr,0))return false;
 DWORD n{},got{};std::vector<unsigned char> object;unsigned char digest[32]{};
 if(!BCryptGetProperty(alg,BCRYPT_OBJECT_LENGTH,(PUCHAR)&n,sizeof(n),&got,0)){
  object.resize(n);
  if(!BCryptCreateHash(alg,&h,object.data(),n,nullptr,0,0)){
   char buf[65536];bool readok=true;while(f){f.read(buf,sizeof(buf));auto c=f.gcount();if(c&&BCryptHashData(h,(PUCHAR)buf,ULONG(c),0)){readok=false;break;}}
   if(readok&&f.eof()&&!BCryptFinishHash(h,digest,32,0)){char hex[65];for(int i=0;i<32;i++)sprintf(hex+i*2,"%02x",digest[i]);hex[64]=0;ok=std::string(hex)==expected;}
  }
 }
 if(h)BCryptDestroyHash(h);BCryptCloseAlgorithmProvider(alg,0);return ok;
}
