#!/usr/bin/env python3
"""Independent one-round A/A disturbance screen; never labels CPU intervals GPU idle."""
import argparse,csv,hashlib,json
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--a1',type=Path,required=True);p.add_argument('--b1',type=Path,required=True);p.add_argument('--b2',type=Path,required=True);p.add_argument('--a2',type=Path,required=True);p.add_argument('--frames',type=int,default=320);p.add_argument('--discard',type=int,default=80);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
def stats(x):return {'n':len(x),'mean_ms':float(np.mean(x)),'median_ms':float(np.median(x)),'sd_ms':float(np.std(x,ddof=1)),'p95_ms':float(np.quantile(x,.95)),'p99_ms':float(np.quantile(x,.99)),'max_ms':float(np.max(x))}
slots={};values={}
for role in ['a1','b1','b2','a2']:
 path=getattr(a,role);rows=list(csv.DictReader(path.open(encoding='utf-8-sig')))
 if len(rows)!=a.frames or [int(r['frame']) for r in rows]!=list(range(a.frames)):raise ValueError(f'{role} frame count/order')
 x=np.array([float(r['wall_ms']) for r in rows[a.discard:]],dtype=np.float64)
 if len(x)<2 or not np.isfinite(x).all() or (x<0).any():raise ValueError(f'{role} nonfinite/negative/empty wall')
 slots[role]=stats(x)|{'csv':str(path),'csv_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'total_frames':len(rows),'discard':a.discard};values[role]=x
control=stats(np.concatenate([values['a1'],values['a2']]));marked=stats(np.concatenate([values['b1'],values['b2']]))
delta={k:marked[k]-control[k] for k in control if k!='n'};drift=slots['a2']['mean_ms']-slots['a1']['mean_ms'];bdrift=slots['b2']['mean_ms']-slots['b1']['mean_ms']
both_b_slower=min(slots['b1']['mean_ms'],slots['b2']['mean_ms'])>max(slots['a1']['mean_ms'],slots['a2']['mean_ms'])
resolved_slowdown=both_b_slower and delta['mean_ms']>abs(drift)
report={'slots':slots,'control':control,'marked':marked,'delta_marked_minus_control':delta,'control_mean_drift_ms':drift,'marked_mean_drift_ms':bdrift,'both_marked_slot_means_slower_than_both_controls':both_b_slower,'resolved_intrusive_mean_screen':resolved_slowdown,'scope':'one A/A screen of host QPC instrumentation under unchanged production Auto; Frame completion wall, not GPU duration/idle; p99 descriptive; manifest/source/raw/Auto/PDL admission must be verified independently','conclusion':'detectable host instrumentation disturbance; stop causal attribution' if resolved_slowdown else 'short screen did not resolve a systematic mean disturbance; not zero overhead or formal equivalence','gpu_execution_or_idle_attribution':'not observable from these host CSVs'}
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k] for k in ['control','marked','delta_marked_minus_control','control_mean_drift_ms','marked_mean_drift_ms','conclusion']},indent=2))
