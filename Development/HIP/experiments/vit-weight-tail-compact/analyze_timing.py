#!/usr/bin/env python3
import argparse,csv,json,hashlib,re
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
roles=['baseline-A1','candidate-B1','candidate-B2','baseline-A2'];slots={};values={}
def stats(x):return dict(n=len(x),mean_ms=float(np.mean(x)),median_ms=float(np.median(x)),sd_ms=float(np.std(x,ddof=1)),p95_ms=float(np.quantile(x,.95)),p99_ms=float(np.quantile(x,.99)),max_ms=float(max(x)))
for role in roles:
 d=a.directory/role;rows=list(csv.DictReader((d/'out.csv').open()));assert len(rows)==320 and [int(r['frame']) for r in rows]==list(range(320))
 edges=[r for r in rows if int(r['checked'])];assert len(edges)==2 and all(int(r['invalid'])==0 and int(r['changed_half_values_from_first'])==0 for r in edges)
 log=(d/'stderr.log').read_text();assert re.search(r'submit_pulse resources[^\r\n]*record_ok=320[^\r\n]*accepted=320',log)
 iscandidate=role.startswith('candidate');assert log.count('CONTRACT_COMPACT key=')==(8 if iscandidate else 0)
 assert f'CONTRACT_COMPACT_COLD requested={int(iscandidate)} ready={int(iscandidate)}' in log
 raw=json.loads((d/'raw-sha.json').read_text(encoding='utf-8-sig'));assert len(raw)==2 and all(x['Hash'].lower()=='0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a' for x in raw)
 x=np.array([float(r['wall_ms']) for r in rows[80:]]);assert np.isfinite(x).all();values[role]=x;slots[role]=stats(x)|dict(csv_sha256=hashlib.sha256((d/'out.csv').read_bytes()).hexdigest(),actual_frames=320,discard=80,raw_edges=2,auto_records=320,compact_keys=8 if iscandidate else 0)
before=json.loads((a.directory/'modules-preflight.json').read_text(encoding='utf-8-sig'));after=json.loads((a.directory/'modules-after.json').read_text(encoding='utf-8-sig'));assert len(before)==len(after)==44 and sorted(before,key=lambda x:x['file'])==sorted(after,key=lambda x:x['file'])
base=stats(np.concatenate([values['baseline-A1'],values['baseline-A2']]));candidate=stats(np.concatenate([values['candidate-B1'],values['candidate-B2']]))
r=dict(actual_handle=67984,actual_exit_code=0,slots=slots,baseline=base,candidate=candidate,delta_candidate_minus_baseline={k:candidate[k]-base[k] for k in base if k!='n'},control_mean_drift_ms=slots['baseline-A2']['mean_ms']-slots['baseline-A1']['mean_ms'],candidate_mean_drift_ms=slots['candidate-B2']['mean_ms']-slots['candidate-B1']['mean_ms'],scope='one ABBA four fresh processes; same NativeGameFrame executable, HDR input, 44 immutable modules; 320 frames/slot discard80; CPU Frame wall completion, not game FPS or pure kernel time; cold sidecar/hash/setup outside window; no memory/diagnostic logging in measured frames; n480 per arm p99 descriptive')
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['baseline','candidate','delta_candidate_minus_baseline','control_mean_drift_ms','candidate_mean_drift_ms']},indent=2))
