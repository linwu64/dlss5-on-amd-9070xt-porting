#!/usr/bin/env python3
"""Compare actual ELF STT_FUNC byte bodies; not filenames or whole ELF hashes."""
import argparse,struct,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('old',type=Path);p.add_argument('new',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def functions(path):
 b=path.read_bytes();assert b[:6]==b'\x7fELF\x02\x01';off=struct.unpack_from('<Q',b,40)[0];esz,n=struct.unpack_from('<HH',b,58);ss=[struct.unpack_from('<IIQQQQIIQQ',b,off+i*esz) for i in range(n)];out={}
 for s in ss:
  if s[1]!=2:continue
  strings=ss[s[6]];strs=b[strings[4]:strings[4]+strings[5]]
  for i in range(s[4],s[4]+s[5],s[9]):
   name,info,other,idx,value,size=struct.unpack_from('<IBBHQQ',b,i)
   if info&15!=2 or not size or not 0<idx<len(ss):continue
   sh=ss[idx];start=sh[4]+value-sh[3];fn=strs[name:strs.index(b'\0',name)].decode();out[fn]=b[start:start+size]
 return out
old,new=functions(a.old),functions(a.new);rows=[]
for name,b in old.items():
 c=new.get(name);rows.append(dict(function=name,old_bytes=len(b),new_bytes=len(c) if c is not None else None,identical=c==b,old_sha256=hashlib.sha256(b).hexdigest(),new_sha256=hashlib.sha256(c).hexdigest() if c is not None else None))
r=dict(old_module_sha256=hashlib.sha256(a.old.read_bytes()).hexdigest(),new_module_sha256=hashlib.sha256(a.new.read_bytes()).hexdigest(),old_functions=len(old),identical=sum(x['identical'] for x in rows),different_or_missing=sum(not x['identical'] for x in rows),extra_functions=sorted(set(new)-set(old)),functions=rows,scope='raw STT_FUNC instruction bytes, no relocation normalization; differences require inspection, not automatic numerical failure')
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(r,indent=2)+'\n');print({k:v for k,v in r.items() if k!='functions'})
