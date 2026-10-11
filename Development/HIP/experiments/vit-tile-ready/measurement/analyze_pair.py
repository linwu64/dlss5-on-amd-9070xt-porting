#!/usr/bin/env python3
"""One bounded ABBA microcase, with initialization charged in GPU/wall time."""
import argparse,csv,json,statistics,hashlib
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('csv',type=Path);p.add_argument('output',type=Path);p.add_argument('--symmetric-readback',action='store_true');a=p.parse_args()
rows=list(csv.DictReader(a.csv.open()));assert len(rows)==120,'expected four slots * 30 samples'
result={'input_csv_sha256':hashlib.sha256(a.csv.read_bytes()).hexdigest(),'scope':('traceoff bounded pair; symmetric per-pair D2H outside window; not fullFrame or game FPS' if a.symmetric_readback else 'ASYMMETRIC original case: candidate-only D2H outside window; not fair performance evidence'),'slots':[]}
def stats(v):
 x=np.array(v,dtype=np.float64);assert np.isfinite(x).all() and (x>0).all()
 return {'n':len(v),'mean_ms':float(x.mean()),'median_ms':float(np.median(x)),'sd_ms':float(x.std(ddof=1)),'p90_ms':float(np.quantile(x,.9)),'p99_ms':float(np.quantile(x,.99)),'max_ms':float(x.max())}
merged={'original':{'gpu':[],'wall':[]},'anyorder':{'gpu':[],'wall':[]}}
for slot in range(4):
 s=[r for r in rows if int(r['slot'])==slot];assert [int(r['frame'])for r in s]==list(range(30))
 variant='anyorder' if slot in (1,2) else 'original'
 assert all(r['variant']==variant and int(r['warm'])==int(int(r['frame'])<10)for r in s)
 m=[r for r in s if r['warm']=='0'];entry={'slot':slot,'variant':variant}
 for field in ('gpu','wall'):
  v=[float(r[field+'_ms'])for r in m];entry[field]=stats(v);merged[variant][field]+=v
 result['slots'].append(entry)
result['merged']={v:{f:stats(x)for f,x in d.items()}for v,d in merged.items()}
result['candidate_minus_original']={f:{'mean_ms':result['merged']['anyorder'][f]['mean_ms']-result['merged']['original'][f]['mean_ms'],'p99_ms':result['merged']['anyorder'][f]['p99_ms']-result['merged']['original'][f]['p99_ms']}for f in ('gpu','wall')}
result['control_drift_A2_minus_A1']={f:result['slots'][3][f]['mean_ms']-result['slots'][0][f]['mean_ms']for f in ('gpu','wall')}
result['candidate_drift_B2_minus_B1']={f:result['slots'][2][f]['mean_ms']-result['slots'][1][f]['mean_ms']for f in ('gpu','wall')}
a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
