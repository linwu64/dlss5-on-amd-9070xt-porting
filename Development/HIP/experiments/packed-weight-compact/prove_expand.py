#!/usr/bin/env python3
"""Actual ledger/packed-bytes and exhaustive unchanged fragment address proof."""
import argparse,hashlib,json
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--ledger',type=Path,required=True);p.add_argument('--weight',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
resources={};calls={};current=None
for line in a.ledger.read_text().splitlines():
 t=line.split()
 if not t:continue
 if t[0]=='R':resources[int(t[1])]={'bytes':int(t[2]),'role':t[3],'file':t[4]}
 elif t[0]=='D':current=int(t[1]);calls[current]={'module':t[2],'function':t[3],'arguments':[]}
 elif t[0]=='A':
  calls.setdefault(int(t[1]),{'arguments':[]})['arguments'].append({'arg':int(t[2]),'pointer':int(t[3])==1,'resource':int(t[5]),'offset':int(t[6]),'logical_bytes':int(t[7]),'capacity':int(t[8])})
selected=[]
for ordinal,c in calls.items():
 if c.get('function')!='vit_expand_blocked_fp8_frag_bytein':continue
 w=next(x for x in c['arguments']if x['arg']==1);assert w['pointer']and w['offset']==0 and w['logical_bytes']==16777216 and w['capacity']==16777216
 consumers=[{'ordinal':o,'function':v.get('function'),'arg':q['arg'],'offset':q['offset']} for o,v in calls.items()for q in v['arguments']if q['pointer']and q['resource']==w['resource']]
 assert all(x['function']==c['function']and x['arg']==1 and x['offset']==0 for x in consumers),'shared consumer outside proved interface'
 selected.append({'ordinal':ordinal,'resource':w['resource'],'old_bytes':16777216,'new_bytes':4194304,'consumers':consumers})
assert len(selected)==8 and len({x['resource']for x in selected})==8
# Exact byte addresses loaded by vit_weight_fragment_native for every row/K16/gr/e.
row=np.arange(4096,dtype=np.uint32)[:,None,None,None];k=np.arange(0,1024,16,dtype=np.uint32)[None,:,None,None];gr=np.arange(2,dtype=np.uint32)[None,None,:,None];e=np.arange(8,dtype=np.uint32)[None,None,None,:]
idx=(((row//16)*32+k//32)*512+(((k%32)//16*2+gr)*16+row%16)*8+e).reshape(-1)
assert idx.size==4194304 and int(idx.min())==0 and int(idx.max())==4194303
assert np.all(np.bincount(idx,minlength=4194304)==1),'fragment bytes must bijectively cover matrix prefix'
b=a.weight.read_bytes();assert len(b)==16777216
compact=b[:4194304];f=a.out/'expand-compact.bin';f.write_bytes(compact)
# Same actual bytes at every original consumer address; reverse live projection is exact.
old=np.frombuffer(b,dtype=np.uint8);new=np.frombuffer(compact,dtype=np.uint8);diff=int(np.count_nonzero(old[idx]!=new[idx]));assert diff==0
r={'ledger_sha256':hashlib.sha256(a.ledger.read_bytes()).hexdigest(),'actual_capture_scope':'full graph50843 production profile1152/640 tokens; frozen historical input, not current livegame','weight_original_sha256':hashlib.sha256(b).hexdigest(),'weight_compact_sha256':hashlib.sha256(compact).hexdigest(),'original_bytes':len(b),'compact_bytes':len(compact),'logical_capacity_recovered_per_weight':len(b)-len(compact),'actual_eight_distinct_weight_resources':selected,'family_capacity_recovered_bytes':sum(x['old_bytes']-x['new_bytes']for x in selected),'address_min':int(idx.min()),'address_max':int(idx.max()),'all_fragment_bytes_once':True,'all_consumed_bytes_inverse_diff':diff,'dead_tail_not_a_tensor_or_scale':True,'new_gpu_allocation_count_expected':8,'old_gpu_allocation_count_expected':0,'numeric_hardware_gold_pass':False,'resident_vram_measured':False,'scope':'CPU byte/address/actual-resource-alias proof only; no quantization or kernel changes'}
(a.out/'proof.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items()if k!='actual_eight_distinct_weight_resources'},indent=2))
