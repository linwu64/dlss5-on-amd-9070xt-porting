#!/usr/bin/env python3
"""Only eight TH bits may differ after proving the one style-address relocation."""
import argparse,struct,json,hashlib,subprocess,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--stock',type=Path,required=True);p.add_argument('--candidate',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
def elf(path):
 b=path.read_bytes();assert b[:6]==b'\x7fELF\x02\x01';off=struct.unpack_from('<Q',b,40)[0];esz,n=struct.unpack_from('<HH',b,58);ss=[struct.unpack_from('<IIQQQQIIQQ',b,off+i*esz) for i in range(n)];syms={}
 for s in ss:
  if s[1]!=2:continue
  st=ss[s[6]];names=b[st[4]:st[4]+st[5]]
  for pos in range(s[4],s[4]+s[5],s[9]):
   ni,info,other,idx,value,size=struct.unpack_from('<IBBHQQ',b,pos)
   if not 0<idx<len(ss) or not size:continue
   sh=ss[idx];start=sh[4]+value-sh[3];name=names[ni:names.index(b'\0',ni)].decode();syms[name]=dict(value=value,size=size,data=b[start:start+size])
 return syms
old=elf(a.stock);new=elf(a.candidate);of=old['c32_wave1_prefix_b8d'];nf=new['c32_wave1_prefix_b8d_main_nt'];assert of['size']==nf['size']==10624
os=old['dlss5_style_feature'];ns=new['dlss5_style_feature'];assert os['size']==ns['size']==4 and os['data']==ns['data']==struct.pack('<f',.0078125)
b=bytearray(nf['data']);oldstyle=struct.unpack_from('<i',of['data'],0x22c)[0];newstyle=struct.unpack_from('<i',nf['data'],0x22c)[0]
assert of['value']+0x220+oldstyle==os['value'] and nf['value']+0x220+newstyle==ns['value'];b[0x22c:0x230]=of['data'][0x22c:0x230]
main=[0x4f10c,0x4f1c4,0x4f27c,0x4f334,0x4f3ec,0x4f4a4,0x4f584,0x4f5c0];down=[0x4f92c,0x4f968]
for addr in main:
 i=addr-of['value'];o=int.from_bytes(of['data'][i:i+12],'little');n=int.from_bytes(nf['data'][i:i+12],'little');assert o^n==1<<52 and (n>>52)&7==1 and (o>>50)&3==(n>>50)&3;b[i+6]^=0x10
for addr in down:
 i=addr-of['value'];assert of['data'][i:i+12]==nf['data'][i:i+12]
assert b==of['data'],'unexpected instruction/register/wait/math difference'
tool='/home/lmxxf/work/llvm-build-23/bin/llvm-readobj'
def metadata(path,name):
 t=subprocess.check_output([tool,'--notes',str(path)],text=True)
 for chunk in t.split('  - .args:'):
  m=re.search(r'\.name:\s+(\S+)',chunk)
  if m and m.group(1)==name:
   keys=['group_segment_fixed_size','kernarg_segment_align','kernarg_segment_size','max_flat_workgroup_size','private_segment_fixed_size','sgpr_count','sgpr_spill_count','vgpr_count','vgpr_spill_count','wavefront_size','workgroup_processor_mode'];return {k:int(re.search(r'\.'+k+r':\s+(\d+)',chunk).group(1)) for k in keys}
 raise ValueError('missing metadata')
om=metadata(a.stock,'c32_wave1_prefix_b8d');nm=metadata(a.candidate,'c32_wave1_prefix_b8d_main_nt');assert om==nm
x=dict(isa_gate_pass=True,stock_sha256=hashlib.sha256(a.stock.read_bytes()).hexdigest(),candidate_sha256=hashlib.sha256(a.candidate.read_bytes()).hexdigest(),function_bytes=of['size'],exact_main_th_only_changes=8,down_exact_instruction_identity=2,all_remaining_instruction_bytes_identical_after_verified_style_relocation=True,style_relocation=dict(old_target=os['value'],new_target=ns['value'],raw_bytes=os['data'].hex(),old_literal=oldstyle,new_literal=newstyle,pc_offset=0x220,literal_offset=0x22c),resources=om,scope='FLAT gfx12 TH bits54:52 and scope51:50 per actual LLVM23 TableGen; no changed scope/waits/math/vector width; function-external padding is excluded; not GPU numerical/performance gate')
(a.out/'isa-gate.json').write_text(json.dumps(x,indent=2)+'\n');print(json.dumps(x,indent=2))
