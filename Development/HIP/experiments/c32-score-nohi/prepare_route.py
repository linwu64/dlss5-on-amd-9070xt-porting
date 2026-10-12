#!/usr/bin/env python3
"""Private copied header, exact packed-weight SHA gate, cached cold functions."""
from pathlib import Path
import argparse,json,hashlib
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--shader',type=Path,required=True);a=p.parse_args()
here=Path(__file__).parent;r=here.resolve().parents[3];cert=json.loads((here/'results/certificate.json').read_text());shas=[x['weight_sha256'] for x in cert['layers'] if x['eligible_under_isa_contract']];assert len(shas)==7
baseline_header=(r/'Development/HIP/hip_reference_network.h').read_bytes()
if b'HIP_COMPACT_VIT_EXPAND' in baseline_header or hashlib.sha256(baseline_header).hexdigest()!='5034a59eee96538b90ec25636d5873fbe4ef768ec14d0b808bdd00b81777d085':
 raise SystemExit('A reproduction requires the original b93cc043 baseline checkout; current shared header differs or contains compact experiment B. No files generated.')
a.output.mkdir(parents=True,exist_ok=True)
shader_sha=hashlib.sha256(a.shader.read_bytes()).hexdigest()
guard=r'''#pragma once
#include <windows.h>
#include <bcrypt.h>
#include <filesystem>
#include <fstream>
#include <vector>
#include <stdexcept>
#include <string>
inline std::string C32NoHiSha(const void* data,size_t size){
 struct State{BCRYPT_ALG_HANDLE alg{};BCRYPT_HASH_HANDLE hash{};std::vector<unsigned char>obj;~State(){if(hash)BCryptDestroyHash(hash);if(alg)BCryptCloseAlgorithmProvider(alg,0);}}s;
 auto check=[](NTSTATUS hr){if(hr<0)throw std::runtime_error("NoHi SHA256 failure");};
 check(BCryptOpenAlgorithmProvider(&s.alg,BCRYPT_SHA256_ALGORITHM,nullptr,0));DWORD bytes{},got{};check(BCryptGetProperty(s.alg,BCRYPT_OBJECT_LENGTH,reinterpret_cast<PUCHAR>(&bytes),4,&got,0));s.obj.resize(bytes);
 check(BCryptCreateHash(s.alg,&s.hash,s.obj.data(),bytes,nullptr,0,0));check(BCryptHashData(s.hash,reinterpret_cast<PUCHAR>(const_cast<void*>(data)),static_cast<ULONG>(size),0));unsigned char hash[32];check(BCryptFinishHash(s.hash,hash,32,0));
 static const char hex[]="0123456789abcdef";std::string out;out.reserve(64);for(auto x:hash){out+=hex[x>>4];out+=hex[x&15];}return out;
}
inline bool C32NoHiCertified(const std::vector<float>&v){if(v.size()*4!=32900)return false;const auto sha=C32NoHiSha(v.data(),v.size()*4);const char*allowed[]={@SHAS@};for(auto x:allowed)if(sha==x)return true;return false;}
inline void C32NoHiRequireShader(const std::string&path){std::ifstream f(std::filesystem::u8path(path),std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("NoHi module missing");auto n=f.tellg();if(n<=0||n>16777216)throw std::runtime_error("NoHi module extent");std::vector<unsigned char>b(static_cast<size_t>(n));f.seekg(0);if(!f.read(reinterpret_cast<char*>(b.data()),b.size())||C32NoHiSha(b.data(),b.size())!="@SHADER@")throw std::runtime_error("NoHi module identity");}
'''.replace('@SHAS@',','.join('"'+x+'"' for x in shas)).replace('@SHADER@',shader_sha)
stock_function=guard[guard.index('inline void C32NoHiRequireShader'):].replace('C32NoHiRequireShader','C32NoHiRequireStock').replace(shader_sha,'f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52')
guard+=stock_function
(a.output/'c32_score_nohi_guard.h').write_text(guard)
s=(r/'Development/HIP/hip_reference_network.h').read_text()
def replace(old,new):
 global s
 assert s.count(old)==1,(old[:90],s.count(old));s=s.replace(old,new,1)
replace('class Network {friend class D3D12Bridge;','class Network {friend class D3D12Bridge;\n bool score_nohi_enabled=false;std::set<const void*> score_nohi_weights;unsigned long long score_nohi_calls=0,score_nohi_stock_calls=0;')
s='#include "c32_score_nohi_guard.h"\n'+s
# Register the immutable CPU-packed bytes exactly once, after uploading them.
old='   it=weights.emplace(key,UploadWeight(v,key)).first;\n  }return P(it->second);\n }\n // Split FFN weights'
new='   it=weights.emplace(key,UploadWeight(v,key)).first;\n   if(attention&&C32NoHiCertified(v))score_nohi_weights.insert(P(it->second));\n  }return P(it->second);\n }\n // Split FFN weights'
replace(old,new)
replace('fast_numeric=FastNumericFromEnvironment();','fast_numeric=FastNumericFromEnvironment();{const char*v=std::getenv("NR_C32_SCORE_NOHI");score_nohi_enabled=v&&!std::strcmp(v,"1");if(score_nohi_enabled&&!(W==1920&&H==1152&&fast_numeric&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&WaveOwnedCompatible(opt)))throw std::runtime_error("NoHi experiment profile rejected");}')
preload=r'''if(score_nohi_enabled){const std::string path=opt.modules+"/c32-score-nohi.hsaco";C32NoHiRequireShader(path);Handle m{};api.Check(api.LoadModule(&m,path.c_str()),"NoHi cold module");modules["c32_score_nohi"]=m;for(const char*k:{"c32_wave1_prefix_b8d","c32_wave1_mapped_b8","c32_wave1_chain","c32_wave1_finish_dcrop_b8d","c32_wave1_up_b8"}){const std::string f=std::string(k)+"_nohi";Handle h{};api.Check(api.hipModuleGetFunction(&h,m,f.c_str()),"NoHi cold function");functions["c32_score_nohi:"+f]=h;}}'''
replace('api.Check(api.hipStreamCreate(&stream),"stream");try{const char*names', 'api.Check(api.hipStreamCreate(&stream),"stream");try{'+preload+'const char*names')
route=r'''Handle score_nohi_fn{};
  if(score_nohi_enabled&&module=="c32_wave1"){
   auto pointer=[](auto x)->const void*{if constexpr(std::is_pointer_v<decltype(x)>)return reinterpret_cast<const void*>(x);else return nullptr;};
   std::array<const void*,sizeof...(A)> av{{pointer(args)...}};
   const bool allowed=kernel=="c32_wave1_prefix_b8d"||kernel=="c32_wave1_mapped_b8"||kernel=="c32_wave1_chain"||kernel=="c32_wave1_finish_dcrop_b8d"||kernel=="c32_wave1_up_b8";
   const unsigned wi=kernel=="c32_wave1_prefix_b8d"?3:kernel=="c32_wave1_up_b8"?4:2;
   if(allowed&&wi<av.size()&&score_nohi_weights.count(av[wi]))score_nohi_fn=functions.at("c32_score_nohi:"+kernel+"_nohi");
  }
  '''
replace(' for(auto&entry:extra){entry[1]+=".hsaco";Handle m{};', ' for(auto&entry:extra){entry[1]+=".hsaco";if(score_nohi_enabled&&entry[0]=="c32_wave1"){C32NoHiRequireStock(opt.modules+"/"+entry[1]);std::fprintf(stderr,"C32_NOHI_STOCK path=%s sha256=f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52\\n",(opt.modules+"/"+entry[1]).c_str());}Handle m{};')
replace('  void*reuse_gate_arg=adaptive_active?', '  '+route+'void*reuse_gate_arg=adaptive_active?')
old='for(unsigned repeat=0;repeat<repeats_here;repeat++){unsigned gg='
new='for(unsigned repeat=0;repeat<repeats_here;repeat++){if(module=="c32_wave1"){if(score_nohi_fn)++score_nohi_calls;else ++score_nohi_stock_calls;}unsigned gg='
replace(old,new)
# Existing Fn calls occur twice in the same single launch line (PDL and ordinary).
needle='ext_launch(Fn(module,kernel),';assert s.count(needle)==1;s=s.replace(needle,'ext_launch(score_nohi_fn?score_nohi_fn:Fn(module,kernel),')
needle='hipModuleLaunchKernel(Fn(module,kernel),';assert s.count(needle)==1;s=s.replace(needle,'hipModuleLaunchKernel(score_nohi_fn?score_nohi_fn:Fn(module,kernel),')
replace(' ~Network(){',' ~Network(){std::fprintf(stderr,"C32_NOHI_SUMMARY requested=%u certified_weights=%zu candidate_calls=%llu stock_calls=%llu profile=FAST1_1920x1152\\n",unsigned(score_nohi_enabled),score_nohi_weights.size(),score_nohi_calls,score_nohi_stock_calls);')
replace(' explicit Network(', ' unsigned long long C32NoHiCalls()const{return score_nohi_calls;}unsigned long long C32NoHiStockCalls()const{return score_nohi_stock_calls;}size_t C32NoHiWeightCount()const{return score_nohi_weights.size();}\n explicit Network(')
(a.output/'hip_reference_network.h').write_text(s)
(a.output/'route-source.json').write_text(json.dumps(dict(base='b93cc043',header_sha256=hashlib.sha256(s.encode()).hexdigest(),guard_sha256=hashlib.sha256(guard.encode()).hexdigest(),shader_sha256=shader_sha,allowed_weight_sha256=shas,cold_preload=True,run_hip_load_or_getfunction=False,scope='private experimental copy FAST1 1920x1152 only; 7 exact weight SHA and 5 permitted exports; all else original'),indent=2)+'\n')
print('PRIVATE_ROUTE_HEADER',a.output/'hip_reference_network.h')
