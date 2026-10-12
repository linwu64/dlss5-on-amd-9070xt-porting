#!/usr/bin/env python3
"""Read-only certificate over frozen weights and actual stock ELF; no sample maxima."""
from pathlib import Path
import hashlib,json,math,re,struct
ROOT=Path(__file__).resolve().parent
ART=Path('/home/lmxxf/work/dlss5-dx12-artifacts/full-graph-50843')
STOCK=Path('/home/lmxxf/work/dlss5-dx12-artifacts/c32-family-20261010/c32-wave1-fast.hsaco')
SHA='f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52'
def sha(b):return hashlib.sha256(b).hexdigest()
def descriptors(b):
 shoff=struct.unpack_from('<Q',b,40)[0];ents,num,st=struct.unpack_from('<HHH',b,58)
 sec=[struct.unpack_from('<IIQQQQIIQQ',b,shoff+i*ents) for i in range(num)];out={}
 for s in sec:
  if s[1]!=2:continue
  q=sec[s[6]];strings=b[q[4]:q[4]+q[5]]
  for i in range(0,s[5],s[9]):
   no,info,other,si,v,size=struct.unpack_from('<IBBHQQ',b,s[4]+i);name=strings[no:].split(b'\0')[0].decode()
   if name.startswith('c32_wave1_') and name.endswith('.kd'):
    q=sec[si];off=q[4]+v-q[3];r1=struct.unpack_from('<I',b,off+48)[0];mode=(r1>>12)&255
    assert mode==0xf0,(name,mode) # RNE, preserve F32 and F16 denormals.
    out[name]=dict(float_mode=mode,round32=mode&3,round16=(mode>>2)&3,denorm32=(mode>>4)&3,denorm16=(mode>>6)&3)
 return out
b=STOCK.read_bytes();assert sha(b)==SHA;modes=descriptors(b)
manifest=json.loads((ART/'result-files.json').read_text());expected={x['Path'].replace('\\','/').split('/')[-1]:(x['Hash'].lower()) for x in manifest}
ledger=(ART/'actual-graph.tsv').read_text();ds={};resources={};args={}
for line in ledger.splitlines():
 t=line.split()
 if t[0]=='D':ds[int(t[1])]=t
 if t[0]=='R':resources[int(t[1])]=t
 if t[0]=='A':args.setdefault(int(t[1]),{})[int(t[2])]=t
# Deliberately outward-loose constants. All arithmetic here is binary64,
# eligibility keeps a minimum margin >0.084 and is rounded further upward by 1e-5.
u16=2**-11;u32=2**-24;delta=6.198883056640625e-5
gamma32=(32*u32)/(1-32*u32)
sum_a=(1-u16)*(1-gamma32);sum_b=32*2**-25*(1+gamma32)
C=math.sqrt((1+sum_b/delta)/sum_a)*(1+2**-22)*(1+u32)**2
# Alternative deliberately conservative model if F16 subnormal matrix inputs flush.
flush_b=32*2**-14*(1+gamma32)
flush_C=math.sqrt((1+flush_b/delta)/sum_a)*(1+2**-22)*(1+u32)**2
fp8_factor=17/16;fp8_abs=math.sqrt(32)*2**-10
rows=[]
for ordinal,d in ds.items():
 if d[2]!='c32_wave1':continue
 fn=d[3];index=3 if '_prefix' in fn else 4 if '_up' in fn or '_post' in fn else 2
 a=args[ordinal][index];rid=int(a[5]);name=resources[rid][4];data=(ROOT/'inputs'/name).read_bytes()
 assert len(data)==32900 and sha(data)==expected[name],(name,sha(data),expected.get(name))
 assert int(a[6])==0 and int(a[7])==32900,'nonzero weight offset/unexpected span'
 assert all((x&127)!=127 for x in data[:4096]),'nonfinite packed matrix'
 v=struct.unpack('<8225f',data);bias=v[4096:8192];gamma=v[8192]
 assert math.isfinite(gamma) and all(math.isfinite(x) for x in bias)
 qn=fp8_factor*abs(gamma)*C+fp8_abs;kn=fp8_factor*C+fp8_abs
 score=(qn*kn*(1+gamma32)+max(bias))*(1+u32)+2**-149
 affine=(score*.044921875*(1+u32)+1.30078125)*(1+u32)+1e-5
 flush_score=((fp8_factor*abs(gamma)*flush_C+fp8_abs)*(fp8_factor*flush_C+fp8_abs)*(1+gamma32)+max(bias))*(1+u32)
 flush_affine=(flush_score*.044921875*(1+u32)+1.30078125)*(1+u32)+1e-5
 rows.append(dict(ordinal=ordinal,entry=fn,weight_resource=rid,weight_file=name,weight_sha256=sha(data),gamma=gamma,bias_min=min(bias),bias_max=max(bias),q_norm_bound=qn,k_norm_bound=kn,score_upper_bound=score,affine_upper_bound=affine,upper_clamp=1.5693359375,margin=1.5693359375-affine,eligible_under_isa_contract=affine<1.5693359375,flush_model_affine_upper=flush_affine,eligible_under_flush_model=flush_affine<1.5693359375))
receipt=dict(unconditional_proof=False,production_admitted=False,proof_parts=dict(mathematical_formula='closed under stated ISA contract, gamma32 exact expression',isa_support='stock f46 actual ELF/floatmode f0, official RDNA4 WMMA fused-FMA description, LLVM native RSQ 1ulp',half_semantics='84738 actual65536half x32positions and independent raw2dd1d8fe all pass',exception_domain='finite FP8 rawQK finite; half-square Inf normalizes zero; FP8 NaN propagation and old lower-NaN behavior preserved under FMA contract',routing='only exact certified packed-weight SHA; 3 unproved layers and unknown weights use stock; not yet implemented'),wmma_denormal_exception_contract='half input preservation supported by exhaustive actual84738; no universal hardware conformance claim',stock_path=str(STOCK),stock_sha256=SHA,ledger_sha256=sha(ledger.encode()),float_modes=modes,constants=dict(u16=u16,u32=u32,floor=delta,gamma32=gamma32,sum_a=sum_a,sum_b=sum_b,pre_fp8_unit_norm_bound=C,fp8_relative=fp8_factor,fp8_l2_absolute=fp8_abs),layers=rows,status='main independent proof review accepted gamma32 correction and exceptional source chain; candidate may be prepared only with seven exact-weight guards; no production admission')
(ROOT/'results/certificate.json').write_text(json.dumps(receipt,indent=2)+'\n')
for x in rows:print(x['ordinal'],x['entry'],'gamma',x['gamma'],'affine_upper',x['affine_upper_bound'],'eligible',x['eligible_under_isa_contract'])
