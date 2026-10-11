#!/usr/bin/env python3
import argparse,struct,json,hashlib,subprocess
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();o=a.output
stock=Path('/home/lmxxf/work/dlss5-dx12-artifacts/c32-family-20261010/c32-wave1-fast.hsaco')
def read(p):
 b=p.read_bytes();so=struct.unpack_from('<Q',b,40)[0];se,sn,_=struct.unpack_from('<HHH',b,58);sec=[struct.unpack_from('<IIQQQQIIQQ',b,so+i*se) for i in range(sn)];res={}
 for s in sec:
  if s[1]!=2:continue
  st=sec[s[6]];ss=b[st[4]:st[4]+st[5]]
  for i in range(0,s[5],s[9]):
   no,info,other,si,v,n=struct.unpack_from('<IBBHQQ',b,s[4]+i);name=ss[no:].split(b'\0')[0].decode()
   if si>=len(sec):continue
   st=sec[si];off=st[4]+v-st[3];res[name]=(info,b[off:off+n],off)
 return b,res
sb,s=read(stock);pb,q=read(o/'primitive.hsaco');match={}
for name,(info,data,_) in s.items():
 if info&15==2 and name.startswith('c32_'):
  match[name]=dict(stock_sha256=hashlib.sha256(data).hexdigest(),probe_module_sha256=hashlib.sha256(q[name][1]).hexdigest() if name in q else None,text_equal=name in q and q[name][1]==data)
name='c32_nohi_norm_primitive';assert name in q and name+'.kd' in q
mode=(struct.unpack_from('<I',pb,q[name+'.kd'][2]+48)[0]>>12)&255;assert mode==240,mode
cmd=['/home/lmxxf/work/llvm-build-23/bin/llvm-objdump','-d','--mcpu=gfx1201','--disassemble-symbols='+name,str(o/'primitive.hsaco')]
isa=subprocess.check_output(cmd,text=True);(o/'primitive.isa').write_text(isa)
wmma=[x.strip() for x in isa.splitlines() if 'v_wmma_' in x];assert len(wmma)==2 and all('v_wmma_f32_16x16x16_f16' in x for x in wmma),wmma
assert 's_getreg_b32' in isa
r=dict(module_sha256=hashlib.sha256(pb).hexdigest(),stock_sha256=hashlib.sha256(sb).hexdigest(),primitive_float_mode=mode,legacy_kernel_text_sha256=match,legacy_kernel_count=len(match),legacy_text_all_equal=all(x['text_equal'] for x in match.values()),legacy_text_diff_count=sum(not x['text_equal'] for x in match.values()),legacy_text_gate='observation only; canonical source extended since historical f46 and adding probe may alter layout; no legacy network dispatch in this test',wmma_instructions=wmma,isa_sha256=hashlib.sha256(isa.encode()).hexdigest(),status='CPU source/ISA/descriptor gate only; actual runtime MODE and half results pending')
(o/'isa-receipt.json').write_text(json.dumps(r,indent=2)+'\n');print('LEGACY_KERNEL_COUNT',len(match),'LEGACY_TEXT_DIFF',r['legacy_text_diff_count'],'MODE',mode,'WMMA',len(wmma),'MODULE_SHA',r['module_sha256'])
