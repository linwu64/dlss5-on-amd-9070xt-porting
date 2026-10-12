#!/usr/bin/env python3
"""Generate a private seven-weight-only experiment; no shared source mutation."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[4];here=Path(__file__).parent
spec=importlib.util.spec_from_file_location('recipes',r/'Development/tools/llvm-fork/compile-modules.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
name,compiler,source,defs,files,opts=next(x for x in m.recipe(r/'hip') if x[0]=='c32-wave1-fast')
needle='affine=cw_clampf(score*.044921875f+1.30078125f,1.03125f,1.5693359375f)'
assert source.count(needle)==1
source=source.replace(needle,'affine=maxf(score*.044921875f+1.30078125f,1.03125f)')
entries=re.findall(r'CW_ENTRY void (c32_wave1_\w+)\(',source)
for entry in entries:source=source.replace('CW_ENTRY void '+entry+'(', 'CW_ENTRY void '+entry+'_nohi(')
(a.output/'candidate-canonical.hip').write_text(source)
cert=json.loads((here/'results/certificate.json').read_text());eligible=[x for x in cert['layers'] if x['eligible_under_isa_contract']]
assert len(eligible)==7
(a.output/'candidate-source.json').write_text(json.dumps(dict(row=name,compiler=compiler,defines=defs,opts=opts,source_sha256=hashlib.sha256(source.encode()).hexdigest(),entries=entries,allowed_weight_sha256=[x['weight_sha256'] for x in eligible],unproved_ordinals=[x['ordinal'] for x in cert['layers'] if not x['eligible_under_isa_contract']],profile='FAST1 1920x1152 only first experiment; norm900 and unknown profiles stock',change='delete score upper clamp only; keep original ternary lower max and all arithmetic order'),indent=2)+'\n')
print('CANDIDATE_SOURCE_SHA',hashlib.sha256(source.encode()).hexdigest(),'CERTIFIED_WEIGHTS',len(eligible),'UNPROVED',3)
