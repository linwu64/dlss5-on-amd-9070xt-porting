#!/usr/bin/env python3
"""Append the semantic probe to the frozen production recipe; do not reconfigure math."""
import argparse,importlib.util,json,hashlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
r=Path(__file__).resolve().parents[4]
spec=importlib.util.spec_from_file_location('recipes',r/'Development/tools/llvm-fork/compile-modules.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
row=next(x for x in m.recipe(r/'hip') if x[0]=='c32-wave1-fast');name,compiler,source,defines,files,opts=row
probe=(Path(__file__).parent/'norm_primitive.hip').read_text();source+='\n'+probe
(a.output/'primitive-canonical.hip').write_text(source)
(a.output/'primitive-source.json').write_text(json.dumps(dict(base='b93cc043',row=name,compiler=compiler,defines=defines,files=[str(x) for x in files],opts=opts,source_sha256=hashlib.sha256(source.encode()).hexdigest(),probe_sha256=hashlib.sha256(probe.encode()).hexdigest(),entry='c32_nohi_norm_primitive',required_float_mode='0xf0',scope='semantic primitive only, no network candidate or timing'),indent=2)+'\n')
print('SOURCE_SHA',hashlib.sha256(source.encode()).hexdigest(),'COMPILER',compiler,'OPTS',opts)
