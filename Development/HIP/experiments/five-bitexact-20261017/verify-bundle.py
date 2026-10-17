#!/usr/bin/env python3
"""Verify downloaded Windows ZIP paths, all 80 SHA entries, and actual ELF targets."""
import argparse, hashlib, json, subprocess, zipfile
from pathlib import Path
p=argparse.ArgumentParser(__doc__)
p.add_argument('zip',type=Path);p.add_argument('out',type=Path);p.add_argument('--readobj',required=True)
a=p.parse_args()
with zipfile.ZipFile(a.zip) as z:
 for entry in z.infolist():
  name=entry.filename.replace('\\','/')
  if not name.startswith('HIP/') or '..' in Path(name).parts:raise ValueError(name)
  dest=a.out/name
  if entry.is_dir():dest.mkdir(parents=True,exist_ok=True)
  else:dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(entry))
h=a.out/'HIP';files=sorted(h.glob('*/*.hsaco'));assert len(files)==80
lines=(h/'SHA256SUMS').read_text(encoding='utf-8-sig').splitlines();assert len(lines)==80
for line in lines:
 sha,name=line.split(None,1);assert hashlib.sha256((h/name).read_bytes()).hexdigest()==sha.lower(),name
rows=[]
for f in files:
 meta=subprocess.check_output([a.readobj,'--file-headers',str(f)],text=True)
 assert 'EF_AMDGPU_MACH_AMDGCN_'+f.parent.name.upper() in meta,(f,meta)
 rows.append(dict(path=str(f.relative_to(h)),sha256=hashlib.sha256(f.read_bytes()).hexdigest(),architecture=f.parent.name))
for arch in ('gfx1200','gfx1201'):assert sum(x['architecture']==arch for x in rows)==40
(a.out/'verified-80.json').write_text(json.dumps(rows,indent=2)+'\n')
print('80 modules: SHA256 and actual ELF architecture PASS')
