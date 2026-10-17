#!/usr/bin/env python3
"""CPU-only evidence generation; writes metadata/hashes, never DLL/weight contents.
Requires pinned DLSSNR-AMD checkout at191b97b541 and the supplied DLLs/packs.
Upstream region functions are imported from its MIT-licensed model tools.
"""
import argparse,collections,csv,hashlib,importlib.util,json,re,struct,sys
from pathlib import Path
p=argparse.ArgumentParser(__doc__)
p.add_argument('--dll',type=Path,required=True);p.add_argument('--old-dll',type=Path,required=True)
p.add_argument('--upstream',type=Path,required=True);p.add_argument('--packs',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
pins=Path(__file__).with_name('provenance.json')
if pins.exists():
 for rel,sha in json.loads(pins.read_text())['source_sha256'].items():assert hashlib.sha256((a.upstream/rel).read_bytes()).hexdigest()==sha,rel
tools=a.upstream/'linux/package/model-tools';sys.path.insert(0,str(tools))
import unpack_swin_family as sw,unpack_splitswin as sp,unpack_vit as vt,unpack_preblock as pre,unpack_postblock as post
# Independent PE and record framing reader.
def u(data,o,fmt):
 n=struct.calcsize(fmt);assert 0<=o<=len(data)-n,(o,n,len(data));return struct.unpack_from(fmt,data,o)
def digest(x):return hashlib.sha256(x).hexdigest()
def pe(data):
 assert data[:2]==b'MZ';po=u(data,0x3c,'<I')[0];assert data[po:po+4]==b'PE\0\0'
 count=u(data,po+6,'<H')[0];os=u(data,po+20,'<H')[0];opt=po+24;assert u(data,opt,'<H')[0]==0x20b
 sections=[]
 for i in range(count):
  e=opt+os+40*i;vs,va,sz,raw=u(data,e+8,'<4I');assert raw+sz<=len(data);sections.append(dict(name=data[e:e+8].rstrip(b'\0').decode(),rva=va,virtual_size=vs,file_offset=raw,file_size=sz))
 def offset(rva,size):
  hits=[s['file_offset']+rva-s['rva'] for s in sections if 0<=rva-s['rva'] and rva-s['rva']+size<=s['file_size']];assert len(hits)==1;return hits[0]
 rr,rs=u(data,opt+128,'<II');ro=offset(rr,rs);out=[]
 def walk(rel,path=()):
  assert len(path)<8;named,ids=u(data,ro+rel+12,'<HH')
  for i in range(named+ids):
   n,v=u(data,ro+rel+16+8*i,'<II')
   if n&0x80000000:
    no=ro+(n&0x7fffffff);ln=u(data,no,'<H')[0];name=data[no+2:no+2+ln*2].decode('utf-16le')
   else:name=str(n)
   if v&0x80000000:walk(v&0x7fffffff,path+(name,))
   else:
    rva,size,cp,res=u(data,ro+v,'<4I');off=offset(rva,size);out.append(dict(path='/'.join(path+(name,)),rva=rva,file_offset=off,size=size,codepage=cp,sha256=digest(data[off:off+size])))
 walk(0);return dict(image_base=u(data,opt+24,'<Q')[0],sections=sections,resources=out)
def records(data,res):
 start=res['file_offset'];raw=data[start:start+res['size']];assert u(raw,0,'<Q')[0]==len(raw);pos=8;out=[]
 while pos<len(raw):
  begin=pos;ln=u(raw,pos,'<Q')[0];pos+=8;assert 0<ln<=4096;name=raw[pos:pos+ln].decode('ascii');pos+=ln
  span=u(raw,pos,'<Q')[0];body=pos+8;inner,size,dev=u(raw,body,'<QQI');assert inner==span and body+span<=len(raw)
  typ,layout,ndim=u(raw,body+20+size,'<IIQ');assert ndim<=32;shape=list(u(raw,body+36+size,'<'+'I'*ndim));assert span==36+size+4*ndim
  out.append(dict(name=name,record_offset=begin,body_offset=body,payload_offset=body+20,file_offset=start+body+20,payload_size=size,body_size=span,device=dev,type=typ,layout=layout,storage_shape=shape,sha256=digest(raw[body+20:body+20+size])))
  pos=body+span
 assert pos==len(raw) and len({x['name']for x in out})==len(out);return out
new=a.dll.read_bytes();old=a.old_dll.read_bytes();pn=pe(new);po=pe(old)
assert digest(new)=='2bc19bc09a7b89dd44f73e2ac0108fcc586e2154bdd0830f242f4f040e28789f'
ht=next(r for r in pn['resources']if '/WEIGHTS_HT/' in r['path']);oh=next(r for r in po['resources']if '/WEIGHTS_HT/' in r['path']);assert ht['sha256']==oh['sha256']
rs=next(r for r in pn['resources']if '/WEIGHTS_CC_SMALL_FP8/' in r['path'])
rnew=records(new,rs);rold=records(new,ht);assert len(rnew)==77 and len(rold)==153
D=json.loads((tools/'descriptor-small.json').read_text());assert D['dll_sha256']==digest(new)
role={0:0,1:1,2:4,3:5,4:8,5:9,6:14,7:15,8:22,9:23,10:30,**{i:i+20 for i in range(11,19)},19:39,20:40,21:47,22:48,23:55,24:56,25:61,26:62,27:65,28:66,29:69,30:70}
R={x['name']:x for x in rnew};O={x['name']:x for x in rold}
# Structural layer rows, not the static table's stale example extents.
text=(a.upstream/'linux/src/core/nr_native_plan_data_small.hpp').read_text()
rows=[]
for raw,kind,skip,original,sx,sy in re.findall(r'\{"([^"]+)", Kind::(\w+), (-?\d+), (true|false), (-?\d+), (-?\d+)\}',text):
 w=raw.split();assert len(w)==19
 rows.append(dict(block=int(w[0]),layer=int(w[1]),type=w[17],kernel=w[18],kind=kind,skip_record=int(skip),skip_original=original=='true',sx=int(sx),sy=int(sy),shift_mask=(-int(sx)>0)+2*(-int(sy)>0),source_block=int(w[15]),skip_block=int(w[16]),input_channels=int(w[11]),output_channels=int(w[12]),raw_row=raw))
assert len(rows)==76
cpp=(a.upstream/'windows/package/model-tools/dlssnr_extract_small_tables.hpp').read_text()
types=re.findall(r'"([^"]+)"',cpp.split('kTypes[] = {',1)[1].split('};',1)[0])
cpp_layers=[tuple(map(int,v))for v in re.findall(r'\{(\d+), (\d+), (\d+), (\d+), (\d+)\}',cpp.split('kLayers[] = {',1)[1].split('};',1)[0])]
assert len(cpp_layers)==76
for b,l,t,ci,co in cpp_layers:
 d=D['blocks'][b]['layers'][l];assert d['type']==types[t] and [ci,co]==[d['input_channels'],d['output_channels']]
cpp_entries=dict(re.findall(r'\{"([^"]+)", "([0-9a-f]{64})"\}',cpp.split('kEntries[] = {',1)[1].split('};',1)[0]))
assert len(cpp_entries)==255
regions=[];layers=[]
for b in D['blocks']:
 for l in b['layers']:
  bi=b['index'];li=l['index'];name=f'block{bi}.layer{li}.layer';rec=R[name];t=l['type'];ci=l['input_channels'];co=l['output_channels'];oldname=f'block{role[bi]}.layer{li}.layer'
  rec['block']=bi;rec['layer']=li;rec['semantic_type']=t;rec['channels']=[ci,co];rec['legacy_role']=role[bi];rec['payload_same_as_legacy_role']=rec['sha256']==O[oldname]['sha256']
  if t.startswith('CCTinlayoutFusedPre'):parts=pre.REGIONS
  elif t.startswith('CCTinlayoutFusedPost'):parts=post.REGIONS
  elif t.startswith('CCTinlayoutFusedSwin'):
   c=min(ci,co);parts=sw.regions(c,c//32,ci,co)
  elif t=='CCSplitSwin16HFfwd':
   parts=[('mix_A',0,262144,512,512,None,'fp8_bit_scattered'),('group_expand_Q0',262144,393216,2048,64,None,'fp8_bit_scattered'),('group_contract_Q2',393216,524288,512,256,None,'fp8_bit_scattered')]
  elif t in sp.LAYOUT:
   parts=[]
   for n,k,o,N,K in sp.LAYOUT[t]:
    size=N*K if k=='matrix' else N*2 if k=='fp16' else N;parts.append((n,o,o+size,N,K,None,k))
  elif t in vt.LAYOUT:
   N,K,header,tail,split=vt.LAYOUT[t];parts=[]
   if header:parts.append(('header',0,header,None,None,None,'raw'))
   parts.append(('weight',header,header+N*K,N,K,None,'matrix_qkv_tiles' if split==3 else 'matrix'))
   if tail:parts.append(('skip_weight',header+N*K,header+N*K+tail*2,None,None,None,'fp16'))
   if rec['payload_size']>header+N*K+2*tail:parts.append(('tail',header+N*K+2*tail,rec['payload_size'],None,None,None,'raw'))
  elif t=='CCVit1DAttention':parts=[('opaque_attention_blob',0,2,None,None,None,'raw')]
  else:raise AssertionError(t)
  used=[]
  for part,start,end,N,K,inner,dtype in parts:
   assert 0<=start<=end<=rec['payload_size'],(name,part,end,rec['payload_size'])
   shape=[N,K] if N and K else [((end-start)//2) if dtype in ('fp16','scalar') else end-start]
   if part=='attn_pos_bias':shape=[(32 if "PreBlock" in t or "PostBlock" in t else min(ci,co))//32,64,64]
   if part=='scalars_b':shape=[(32 if 'PreBlock' in t or 'PostBlock' in t else min(ci,co))//32];dtype='fp32_with_padding'
   if t=='CCTinlayoutFusedPreBlockSwin1H' and part=='input_lift':shape=[32,16]
   if t=='CCTinlayoutFusedPostBlockSwin1H' and part=='out_project':shape=[16,32]
   if t=='CCVit1DQKV' and part=='header':shape=[32];dtype='fp32'
   if t=='CCSplitSwin16HQKVAttn' and part=='tail':shape=[16];dtype='fp32'
   storage_shape=shape[:];semantic_note=''
   if part=='scalars_b':storage_shape=[(end-start)//4]
   c=32 if t.startswith('CCTinlayoutFusedPre') or t.startswith('CCTinlayoutFusedPost') else min(ci,co)
   if part in ('residual_scale','attn_residual_scale','upsample_gain'):
    shape=[c];dtype='fp16_region_with_padding_or_shared_gain';semantic_note='physical file includes padding; C>=64 upsample_gain requires16 coefficients from residual_scale tail'
   if part=='mlp_mid':semantic_note='stored grouped [C,128]; logical dense [C,4C] has structural zeros'
   if part=='mix_A':shape=[8,64,512]
   if part=='group_expand_Q0':shape=[8,256,64]
   if part=='group_contract_Q2':shape=[8,64,256]
   regions.append(dict(record=name,type=t,part=part,dtype='E4M3' if dtype.startswith('matrix') or dtype.startswith('fp8') else dtype,shape=shape,physical_storage_shape=storage_shape,semantic_note=semantic_note,relative_offset=start,file_offset=rec['file_offset']+start,bytes=end-start,inner_tiles=inner,sha256=digest(new[rec['file_offset']+start:rec['file_offset']+end]),source_permutation='ff_a/ff_q0/ff_q2' if dtype=='fp8_bit_scattered' else 'QKV 1024-byte alternating tiles' if dtype=='matrix_qkv_tiles' else 'see pinned unpacker'))
   used.append((start,end))
  used.sort();p0=0
  for lo,hi in used:
   if lo>p0:regions.append(dict(record=name,type=t,part='unclassified_gap',dtype='raw',shape=[lo-p0],relative_offset=p0,file_offset=rec['file_offset']+p0,bytes=lo-p0,inner_tiles=None,sha256=digest(new[rec['file_offset']+p0:rec['file_offset']+lo]),source_permutation='none'))
   p0=max(p0,hi)
  assert p0==rec['payload_size'],(name,p0,rec['payload_size'])
# Byte-preserving NRMODEL1 container inventory; individual checksums match both tables.
def pack(path,sumsfile):
 d=path.read_bytes();assert d[:8]==b'NRMODEL1';n,z=u(d,8,'<II');assert z==0;p0=16;ent=[];expected={n:h for h,n in (ln.split(None,1)for ln in sumsfile.read_text().splitlines() if ln.strip())}
 for i in range(n):
  ln=u(d,p0,'<I')[0];p0+=4;name=d[p0:p0+ln].decode();p0+=ln;off,size=u(d,p0,'<QQ');p0+=16;assert off%256==0 and off+size<=len(d);sha=digest(d[off:off+size]);assert expected[name]==sha and cpp_entries[name]==sha
  m=re.search(r'(block\d+\.layer\d+\.layer)(?:\.([^.]+))?\.bin$',name);record=m[1];part=m[2] or 'opaque_record';match=next((s for s in regions if s['record']==record and s['part']==part),None)
  shape=match['shape'] if match else [size];dtype=match['dtype'] if match else 'opaque record' if part=='opaque_record' else 'raw';src_off=match['file_offset'] if match else R.get(record,{}).get('file_offset')
  ent.append(dict(name=name,record=record,part=part,shape=shape,dtype=dtype,pack_offset=off,bytes=size,source_region_file_offset=src_off,sha256=sha,permutation_required=bool(match and match['dtype']=='E4M3')))
 assert len(expected)==n
 return dict(bytes=len(d),sha256=digest(d),count=n,entries=ent)
small=pack(a.packs/'dlssnr-small.bin',tools/'model-files-small.sha256')
assert small['sha256']=='7e966e2639dbec6596aa0bac3b8761137d2c40ca8cb4aca30df7ca10043c6e33'
# HT checksum verification separately, without Small region associations.
dold=(a.packs/'dlssnr.bin').read_bytes();count,zero=u(dold,8,'<II');assert count==599 and digest(dold)=='2b41c888cf4155b8958c665ba64018ab0bd25c85fc71a2b6db86d0d04d1f7fbd'
head=[]
for label,data,recordmap,block in [('old',old,None,70),('small',new,R,30)]:
 rr=records(data,next(x for x in pe(data)['resources']if ('/WEIGHTS_HT/' if label=='old' else '/WEIGHTS_CC_SMALL_FP8/') in x['path']));rec=next(x for x in rr if x['name']==f'block{block}.layer0.layer');raw=data[rec['file_offset']+20784:rec['file_offset']+21808];h=[bytearray(64)for i in range(16)]
 def bits(i,pos):return sum(((i>>p)&1)<<j for j,p in enumerate(pos))
 for i in range(512):row=bits(i,[2,5,6,7]);col=bits(i,[0,1,3,4,8]);h[row][2*col:2*col+2]=raw[2*i:2*i+2]
 live=[i for i,x in enumerate(h)if any(x)];assert live==[0,2,4,6]
 if label=='old':assert digest(h[6])=='77c745c4e1d84a6227a2224291d83c37d1e9bd18d45e95add166b1174225ce8f'
 head.append(dict(model=label,live_rows=live,RGB_rows=[0,2,4],history_row=6,history_f16_sha256=digest(h[6]),history_f16_bytes=64))
blends=[]
for resource,rr in [(rs,rnew),(ht,rold)]:
 q=next(x for x in rr if 'blend_scale' in x['name']);blob=new[q['file_offset']:q['file_offset']+2];blends.append(dict(resource=resource['path'],name=q['name'],file_offset=q['file_offset'],bits=f'0x{int.from_bytes(blob,"little"):04X}',value=struct.unpack('<e',blob)[0]))
summary=dict(dll=dict(path=str(a.dll),bytes=len(new),sha256=digest(new),version='310.9.16.0',pe=pn),old_dll_sha256=digest(old),old_resource_sha256=oh['sha256'],old_resource_identical=True,counts=dict(blocks=31,layers=len(rows),small_resource_records=len(rnew),ht_resource_records=len(rold),small_pack_entries=small['count'],ht_pack_entries=count),small_resource=rs,small_pack=dict(bytes=small['bytes'],sha256=small['sha256']),ht_pack=dict(bytes=len(dold),sha256=digest(dold)),blends=blends,post_heads=head,records_equal_to_legacy_roles=[x['name']for x in rnew if x.get('payload_same_as_legacy_role')],role_mapping=role)
for name,obj in [('summary.json',summary),('resources.json',pn),('records-small.json',rnew),('records-ht.json',rold),('subtensors-small.json',regions),('layers-small.json',rows),('pack-small.json',small)]:
 (a.out/name).write_text(json.dumps(obj,ensure_ascii=False,indent=2)+'\n')
for filename,values,keys in [('records-small.csv',rnew,['name','semantic_type','channels','storage_shape','file_offset','payload_offset','payload_size','sha256']),('subtensors-small.csv',regions,['record','part','dtype','shape','relative_offset','file_offset','bytes','physical_storage_shape','semantic_note','source_permutation']),('pack-small.csv',small['entries'],['name','record','part','dtype','shape','pack_offset','source_region_file_offset','bytes','sha256']),('layers-small.csv',rows,['block','layer','type','kind','input_channels','output_channels','source_block','skip_block','skip_record','sx','sy','shift_mask','legacy_role'])]:
 with (a.out/filename).open('w',newline='') as f:
  w=csv.writer(f,lineterminator='\n');w.writerow(keys)
  for v in values:w.writerow([json.dumps(v[k]) if isinstance(v.get(k),(list,dict)) else (role[v['block']]if k=='legacy_role' else v.get(k,''))for k in keys])
print(json.dumps({k:v for k,v in summary.items()if k in ['counts','small_pack','ht_pack','blends','post_heads','records_equal_to_legacy_roles']},indent=2))
