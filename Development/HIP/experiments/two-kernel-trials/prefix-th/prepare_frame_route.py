#!/usr/bin/env python3
"""Copy current non-QPC production Frame; cold sidecar preloading only, one prefix override."""
from pathlib import Path
import argparse,hashlib,json,shutil,difflib
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True);r=Path(__file__).resolve().parents[5]
for rel in ['src','Development/HIP']:
 (a.out/rel).mkdir(parents=True,exist_ok=True)
 for f in (r/rel).glob('*.h'):shutil.copyfile(f,a.out/rel/f.name)
shutil.copyfile(r/'Development/HIP/benchmark_vit_reuse.cpp',a.out/'Development/HIP/benchmark_vit_reuse.cpp')
source=(r/'Development/HIP/hip_reference_network.h').read_text();assert 'auto_host_timing' not in source and 'score_nohi_fn' not in source and 'vtail' not in source;s=source
helper=r'''#pragma once
#include <windows.h>
#include <bcrypt.h>
#include <filesystem>
#include <fstream>
#include <vector>
#include <string>
#include <stdexcept>
inline void PrefixNtRequireSha(const std::string&path,const char*expected){
 std::ifstream f(std::filesystem::u8path(path),std::ios::binary|std::ios::ate);if(!f)throw std::runtime_error("prefix NT module missing");auto size=f.tellg();if(size<=0||size>16777216)throw std::runtime_error("prefix NT module extent");std::vector<unsigned char>data(static_cast<size_t>(size));f.seekg(0);if(!f.read((char*)data.data(),data.size()))throw std::runtime_error("prefix NT module read");
 struct State{BCRYPT_ALG_HANDLE a{};BCRYPT_HASH_HANDLE h{};std::vector<unsigned char>obj;~State(){if(h)BCryptDestroyHash(h);if(a)BCryptCloseAlgorithmProvider(a,0);}}q;
 auto ck=[](NTSTATUS s){if(s<0)throw std::runtime_error("prefix NT SHA");};ck(BCryptOpenAlgorithmProvider(&q.a,BCRYPT_SHA256_ALGORITHM,nullptr,0));DWORD bytes{},got{};ck(BCryptGetProperty(q.a,BCRYPT_OBJECT_LENGTH,(PUCHAR)&bytes,4,&got,0));q.obj.resize(bytes);ck(BCryptCreateHash(q.a,&q.h,q.obj.data(),bytes,nullptr,0,0));ck(BCryptHashData(q.h,data.data(),ULONG(data.size()),0));unsigned char hash[32];ck(BCryptFinishHash(q.h,hash,32,0));char hex[65];for(unsigned i=0;i<32;i++)sprintf(hex+2*i,"%02x",hash[i]);hex[64]=0;if(std::string(hex)!=expected)throw std::runtime_error("prefix NT module identity");
}
'''
(a.out/'Development/HIP/prefix_nt_guard.h').write_text(helper)
s=s.replace('#include "packed_weights.h"','#include "packed_weights.h"\n#include "prefix_nt_guard.h"',1)
anchor='class Network {friend class D3D12Bridge;';assert s.count(anchor)==1;s=s.replace(anchor,anchor+'''\n bool prefix_nt_requested=false;Handle prefix_nt_fn{};unsigned long long prefix_nt_calls=0,prefix_nt_stock_calls=0;
 void InitPrefixNt(){const char*v=std::getenv("NR_PREFIX_MAIN_NT");if(v&&std::strcmp(v,"0")&&std::strcmp(v,"1"))throw std::runtime_error("NR_PREFIX_MAIN_NT must be0or1");prefix_nt_requested=v&&!std::strcmp(v,"1");
 if(prefix_nt_requested&&fast_numeric&&wave_owned_active&&W==1920&&H==1152&&multi_pass==1&&!opt.graph&&!opt.experimental_temporal&&!opt.integration.select_module&&opt.skip_blocks.empty()&&opt.dup_prefix.empty()&&opt.prefix_inline&&opt.direct_prefix_input&&opt.c32_finish_fused&&opt.pre_main8&&opt.fused_ffn&&opt.half_c32&&opt.raw_chain&&opt.mapped_c32&&(api.style_feature==-1.f||api.style_feature==1.f/128.f)){
  auto props=api.Properties(int(opt.device));if(std::string(props.gcnArchName).rfind("gfx1201",0)==0&&std::strstr(props.name,"9070 XT")&&HasFn("c32_wave1","c32_wave1_prefix_b8d")&&HasFn("c32_wave1","c32_wave1_mapped_b8")){
   PrefixNtRequireSha(opt.modules+"/c32-wave1-fast.hsaco","f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52");const auto path=opt.modules+"/prefix-main-nt.hsaco";PrefixNtRequireSha(path,"761984e781c58f9587a9e6b3432f2b9c6c8713516e441ed21bc0aabdcb67f094");Handle m{};api.Check(api.LoadModule(&m,path.c_str()),"prefix NT sidecar");modules["prefix_main_nt"]=m;api.Check(api.hipModuleGetFunction(&prefix_nt_fn,m,"c32_wave1_prefix_b8d_main_nt"),"prefix NT new export");
  }
 }std::fprintf(stderr,"PREFIX_NT_COLD requested=%u ready=%u encoded_style=%.9g\\n",unsigned(prefix_nt_requested),unsigned(prefix_nt_fn!=nullptr),api.style_feature);}
''',1)
anchor='if(wave_owned_active)HasFn("c32_wave1","c32_wave1_post_b8_rgba");';assert s.count(anchor)==1;s=s.replace(anchor,'InitPrefixNt();'+anchor,1)
anchor='unsigned repeats_here=launch_repeats*';assert s.count(anchor)==1;s=s.replace(anchor,'Handle prefix_selected{};if(module=="c32_wave1"&&kernel=="c32_wave1_prefix_b8d"){if(sizeof...(A)!=13)throw std::runtime_error("prefix NT ABI count");prefix_selected=prefix_nt_fn;}'+anchor,1)
anchor='for(unsigned repeat=0;repeat<repeats_here;repeat++){unsigned gg=';assert s.count(anchor)==1;s=s.replace(anchor,'for(unsigned repeat=0;repeat<repeats_here;repeat++){if(module=="c32_wave1"&&kernel=="c32_wave1_prefix_b8d"){if(prefix_selected)++prefix_nt_calls;else ++prefix_nt_stock_calls;}unsigned gg=',1)
s=s.replace('ext_launch(paired_contract_fn?paired_contract_fn:Fn(module,kernel),','ext_launch(prefix_selected?prefix_selected:paired_contract_fn?paired_contract_fn:Fn(module,kernel),',1).replace('hipModuleLaunchKernel(paired_contract_fn?paired_contract_fn:Fn(module,kernel),','hipModuleLaunchKernel(prefix_selected?prefix_selected:paired_contract_fn?paired_contract_fn:Fn(module,kernel),',1)
s=s.replace(' ~Network(){',' ~Network(){std::fprintf(stderr,"PREFIX_NT_SUMMARY requested=%u ready=%u candidate_calls=%llu stock_calls=%llu\\n",unsigned(prefix_nt_requested),unsigned(prefix_nt_fn!=nullptr),prefix_nt_calls,prefix_nt_stock_calls);',1)
# Symmetric diagnostic memory fields; HIP_MEMORY=0 for timing.
anchor='  if(opt.sparse_weights)std::fprintf(f,"hip_memory sparse_weights';i=s.index(anchor);s=s[:i]+'  std::fprintf(f,"hip_memory_exact weights_bytes=%zu pool_bytes=%zu gather_bytes=%zu noise_bytes=%zu driver_free_bytes=%zu driver_total_bytes=%zu not_resident_peak=1\\n",wsum,psum,gsum,nsum,free,total);\n'+s[i:]
(a.out/'Development/HIP/hip_reference_network.h').write_text(s)
(a.out/'private.patch').write_text(''.join(difflib.unified_diff(source.splitlines(True),s.splitlines(True),fromfile='a/hip_reference_network.h',tofile='b/hip_reference_network.h')))
(a.out/'source-identity.json').write_text(json.dumps(dict(base='79599997 plus trial docs only; no V candidate/no QPC helper',original_header_sha256=hashlib.sha256(source.encode()).hexdigest(),private_header_sha256=hashlib.sha256(s.encode()).hexdigest(),guard_sha256=hashlib.sha256(helper.encode()).hexdigest(),candidate_module_sha256='761984e781c58f9587a9e6b3432f2b9c6c8713516e441ed21bc0aabdcb67f094',scope='single prefix_b8d handle override only; constructor cold module hash/load/getFn; existing Run launchparams/Auto/PDL/fences untouched; all other kernels use original current43'),indent=2)+'\n');print(a.out)
