#!/usr/bin/env python3
"""Compile actual emitted production helper methods against CPU storage/API stubs."""
from pathlib import Path
import argparse,subprocess
p=argparse.ArgumentParser();p.add_argument('--production',type=Path,required=True);a=p.parse_args();helpers=(a.production/'emitted_helpers.inc').read_text()
preamble=r'''
#include <vector>
#include <map>
#include <set>
#include <string>
#include <cstring>
#include <cstdio>
#include <stdexcept>
#include <memory>
#include <fstream>
#include <functional>
#include <cassert>
namespace hip_probe{struct DevicePropertiesR0600{char name[256],gcnArchName[256];};}
using U=unsigned;using Handle=void*;using Tensor=std::shared_ptr<std::vector<float>>;
struct S{
 struct{bool sparse_weights{},graph{},experimental_temporal{},vit_split_k{},vit_ffn_fused{},vit_proj_frag=true;unsigned device{};struct{std::function<void()>select_module;}integration;std::string assets;}opt;
 struct{std::string arch="gfx1201";int hipGetDevicePropertiesR0600(hip_probe::DevicePropertiesR0600*p,int){strcpy(p->name,"AMD Radeon RX 9070 XT");strcpy(p->gcnArchName,arch.c_str());return 0;}}api;
 bool fast_numeric=true,vit_contract_byte_edge=true,vit_proj_n64_active=true,hasfn=true;U W=1920,H=1152,multi_pass=1;int uploads=0,oldcalls=0;std::vector<int>dead;std::vector<float>fixture;std::map<std::string,Tensor>weights;
 S(){fixture.resize(4194304+1024);auto*b=(unsigned char*)fixture.data();for(size_t i=0;i<4194304;i++)b[i]=unsigned(i*17);for(size_t i=4194304;i<fixture.size();i++)fixture[i]=float(i-4194304)+.25f;}
 void*P(const Tensor&t){return t->data();}
 bool HasFn(const char*,const char*){return hasfn;}Handle Fn(const char*,const char*){return (void*)1234;}
 size_t WeightElements(const std::string&n){return n.find("projection")!=std::string::npos?1048576+1024:4194304+1024;}
 std::vector<float>ReadWeights(const std::string&n){if(n.find("projection")!=std::string::npos){auto v=fixture;v.resize(1048576+1024);memcpy(v.data()+1048576,fixture.data()+4194304,4096);return v;}return fixture;}
 void Fp8(std::vector<float>&,std::initializer_list<std::pair<size_t,size_t>>){}void FragmentPackedMatrix(std::vector<float>&,int,int,int){}
 Tensor Upload(const void*p,size_t bytes,bool){++uploads;auto t=std::make_shared<std::vector<float>>(bytes/4);memcpy(t->data(),p,bytes);return t;}
 void*PackedVitProjectionFrag(const std::string&){++oldcalls;return (void*)8888;}
 void*PackedVitWeight(const std::string&,U,U,bool,bool){++oldcalls;return (void*)9999;}
'''
tests=r'''
};int main(){
 const std::string n="block31-contract.f32";
 {S s;s.hasfn=false;s.InitCompactContract();assert(!s.compact_contract_fn);assert(s.CompactContractWeight(n,1024,4096,true,true)==(void*)9999&&s.uploads==0);}
 {S s;s.opt.integration.select_module=[]{};s.InitCompactContract();assert(!s.compact_contract_fn);}
 {S s;s.opt.sparse_weights=true;s.InitCompactContract();assert(!s.compact_contract_fn);}
 {S s;s.vit_contract_byte_edge=false;s.InitCompactContract();assert(!s.compact_contract_fn);}
 {S s;s.H=960;s.InitCompactContract();assert(!s.compact_contract_fn);}
 {S s;s.InitCompactContract();auto old=std::make_shared<std::vector<float>>(4);s.weights[n+"@vit-frag"]=old;assert(s.CompactContractWeight(n,1024,4096,true,true)==old->data());assert(s.uploads==0&&s.compact_contract_ptrs.empty()&&s.weights.size()==1);}
 {S s;s.InitCompactContract();assert(s.CompactContractWeight("unknown",1024,4096,true,true)==(void*)9999&&s.uploads==0);assert(s.CompactContractWeight(n,1024,4096,true,false)==(void*)9999);}
 {S s;s.InitCompactContract();auto*p=s.CompactContractWeight(n,1024,4096,true,true);assert(s.uploads==1&&s.weights.size()==1&&s.compact_contract_ptrs.count(p));auto&t=*s.weights.at(n+"@vit-frag@compact-contract");assert(t.size()*4==4198400);assert(!memcmp(t.data(),s.fixture.data(),4194304));assert(!memcmp(t.data()+1048576,s.fixture.data()+4194304,4096));assert(s.CompactContractWeight(n,1024,4096,true,true)==p&&s.uploads==1);}
 {S s;s.api.arch="gfx1200";s.InitCompactContract();assert(!s.compact_contract_fn);}
 puts("ACTUAL_EMITTED_HELPERS_CPU_PASS mock_prepacked_storage_no_GPU_no_quantization_claim");
}
'''
if 'InitCompactProjection' in helpers:
 extra=r'''
 {S s;s.hasfn=false;s.InitCompactProjection();assert(!s.compact_projection_fn);assert(s.CompactProjectionWeight("block31-projection.f32")== (void*)8888&&s.uploads==0);}
 {S s;s.vit_proj_n64_active=false;s.InitCompactProjection();assert(!s.compact_projection_fn);}
 {S s;s.opt.integration.select_module=[]{};s.InitCompactProjection();assert(!s.compact_projection_fn);}
 {S s;s.api.arch="gfx1200";s.InitCompactProjection();assert(!s.compact_projection_fn);}
 {S s;s.InitCompactProjection();auto old=std::make_shared<std::vector<float>>(4);s.weights["block31-projection.f32@vit-proj-frag"]=old;assert(s.CompactProjectionWeight("block31-projection.f32")==old->data());assert(s.uploads==0&&s.compact_projection_ptrs.empty());}
 {S s;s.InitCompactProjection();assert(s.CompactProjectionWeight("unknown")== (void*)8888);auto*p=s.CompactProjectionWeight("block31-projection.f32");assert(s.uploads==1&&s.weights.size()==1&&s.compact_projection_ptrs.count(p));auto&t=*s.weights.at("block31-projection.f32@vit-proj-frag@compact-projection");assert(t.size()*4==1052672);assert(!memcmp(t.data(),s.fixture.data(),1048576));assert(!memcmp(t.data()+262144,s.fixture.data()+4194304,4096));}
'''
 tests=tests.replace(' puts("ACTUAL_EMITTED_HELPERS_CPU_PASS',extra+' puts("ACTUAL_EMITTED_HELPERS_CPU_PASS')
(a.production/'selection.cpp').write_text(preamble+helpers+tests)
subprocess.run(['g++','-std=c++17','-O2',str(a.production/'selection.cpp'),'-o',str(a.production/'selection')],check=True);subprocess.run([str(a.production/'selection')],check=True)
# Default-off is the same emitted methods; only profile initialization changes.
offtests=tests[:tests.index('};int main()')]+r'''};int main(){S s;s.InitCompactContract();assert(!s.compact_contract_fn);assert(s.CompactContractWeight("block31-contract.f32",1024,4096,true,true)==(void*)9999&&s.uploads==0);puts("ACTUAL_EMITTED_HELPERS_MACRO_OFF_PASS");}'''
if 'InitCompactProjection' in helpers:offtests=offtests.replace('puts("ACTUAL_EMITTED_HELPERS_MACRO_OFF_PASS")','s.InitCompactProjection();assert(!s.compact_projection_fn);assert(s.CompactProjectionWeight("block31-projection.f32")== (void*)8888&&s.uploads==0);puts("ACTUAL_EMITTED_HELPERS_MACRO_OFF_PASS")')
(a.production/'selection-off.cpp').write_text(preamble+helpers+offtests)
subprocess.run(['g++','-std=c++17','-O2','-DHIP_COMPACT_VIT_CONTRACT=0','-DHIP_COMPACT_VIT_PROJECTION=0',str(a.production/'selection-off.cpp'),'-o',str(a.production/'selection-off')],check=True);subprocess.run([str(a.production/'selection-off')],check=True)
