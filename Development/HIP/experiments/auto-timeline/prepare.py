#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,shutil,difflib
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();r=Path(__file__).resolve().parents[4];out=a.out;out.mkdir(parents=True,exist_ok=True)
original={}
for rel in ('src','Development/HIP'):
 for f in (r/rel).glob('*.h'):
  q=out/rel/f.name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(f,q)
shutil.copyfile(Path(__file__).with_name('host_timing.h'),out/'Development/HIP/host_timing.h')
def edit(rel,changes):
 f=r/rel;s=f.read_text();old=s
 for x,y in changes:
  if s.count(x)!=1:raise RuntimeError(f'{rel}: anchor count {s.count(x)} {x[:60]}')
  s=s.replace(x,y,1)
 (out/rel).write_text(s);original[rel]={'original_sha256':hashlib.sha256(old.encode()).hexdigest(),'private_sha256':hashlib.sha256(s.encode()).hexdigest()};return ''.join(difflib.unified_diff(old.splitlines(True),s.splitlines(True),fromfile='a/'+rel,tofile='b/'+rel))
patch=''
patch+=edit('src/native_game_frame.h',[
 ('#pragma once','#pragma once\n#include "../Development/HIP/host_timing.h"'),
 ('   const auto cpu_start=std::chrono::steady_clock::now();if(r.probe_on)r.probe.Reset();','   const auto cpu_start=std::chrono::steady_clock::now();if(r.probe_on)r.probe.Reset();auto_host_timing::Mark(1);'),
 ('if(r.probe_on)r.probe.Mark(c,"t1");});\n   if(!dump_prefix.empty()', 'if(r.probe_on)r.probe.Mark(c,"t1");});auto_host_timing::Mark(2);\n   if(!dump_prefix.empty()'),
 ('   r.network.Run(r.submit,seed,r.fast_history.enabled?fast_use:r.temporal?use_history:temporal_enabled);','   r.network.Run(r.submit,seed,r.fast_history.enabled?fast_use:r.temporal?use_history:temporal_enabled);auto_host_timing::Mark(5);'),
 ('   r.submit.Submit([&](ID3D12GraphicsCommandList*c){if(r.probe_on)r.probe.Mark(c,"t2");','   auto_host_timing::Mark(6);r.submit.Submit([&](ID3D12GraphicsCommandList*c){if(r.probe_on)r.probe.Mark(c,"t2");'),
 ('   });if(r.low_temporal.enabled){r.submit.Flush();','   });auto_host_timing::Mark(7);if(r.low_temporal.enabled){r.submit.Flush();')])
patch+=edit('Development/HIP/hip_d3d12_bridge.h',[
 ('#pragma once','#pragma once\n#include "host_timing.h"'),
 ('   }else network->Enqueue(input.mapped,temporal?history.mapped:nullptr,output.mapped,seed);','   }else {auto_host_timing::Mark(3);network->Enqueue(input.mapped,temporal?history.mapped:nullptr,output.mapped,seed);auto_host_timing::Mark(4);}')])
bench='Development/HIP/benchmark_vit_reuse.cpp'
patch+=edit(bench,[
 ('for(UINT i=0;i<N;i++){\n if(sequence)', 'auto_host_timing::Initialize(N);for(UINT i=0;i<N;i++){\n if(sequence)'),
 ('submit.Flush();auto begin=std::chrono::steady_clock::now();frame.ProcessSubmittedFrame(', 'submit.Flush();auto_host_timing::Reset();auto begin=std::chrono::steady_clock::now();auto_host_timing::Mark(0);frame.ProcessSubmittedFrame('),
 ('||i==0||(reset_every&&i%reset_every==0));submit.Submit([](ID3D12GraphicsCommandList*){});submit.Flush();double elapsed=', '||i==0||(reset_every&&i%reset_every==0));auto_host_timing::Mark(8);auto_host_timing::Mark(9);submit.Submit([](ID3D12GraphicsCommandList*){});submit.Flush();auto_host_timing::Mark(10);double elapsed='),
 ('walltotal+=elapsed;\n if(edges_only', 'walltotal+=elapsed;auto_host_timing::Save(i,elapsed);\n if(edges_only'),
 (' fclose(csv);save_frame(prefix,last,W,H);submit.Flush();',' auto_host_timing::Dump(prefix);fclose(csv);save_frame(prefix,last,W,H);submit.Flush();')])
(out/'private.patch').write_text(patch);(out/'source-identity.json').write_text(json.dumps({'base':'99fc33ba','scope':'host QPC only,11 marks; no GPU API or command changes; no Auto guard changes; no per-frame extra export/alloc','files':original,'helper_sha256':hashlib.sha256((out/'Development/HIP/host_timing.h').read_bytes()).hexdigest()},indent=2)+'\n');print(out)
