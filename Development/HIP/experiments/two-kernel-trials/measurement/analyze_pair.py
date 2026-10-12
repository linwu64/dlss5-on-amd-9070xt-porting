#!/usr/bin/env python3
import argparse,csv,json,hashlib,re
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();rows=list(csv.DictReader((a.directory/'samples.csv').open()));assert len(rows)==120
values={};slots={}
def stat(x):return dict(n=len(x),mean_ms=float(np.mean(x)),median_ms=float(np.median(x)),sd_ms=float(np.std(x,ddof=1)),p99_ms=float(np.quantile(x,.99)),max_ms=float(np.max(x)))
for slot in range(4):
 r=[x for x in rows if int(x['slot'])==slot];role=int(slot in [1,2]);assert len(r)==30 and [int(x['iteration']) for x in r]==list(range(30)) and all(int(x['role'])==role and int(x['warm'])==int(int(x['iteration'])<10) for x in r)
 values[slot]={}
 for metric in ['gpu_ms','wall_ms']:
  x=np.array([float(z[metric]) for z in r[10:]]);assert np.isfinite(x).all() and (x>0).all();values[slot][metric]=x
 slots[str(slot)]=dict(role=role,**{m:stat(x) for m,x in values[slot].items()})
metrics={}
for m in ['gpu_ms','wall_ms']:
 old=stat(np.concatenate([values[0][m],values[3][m]]));new=stat(np.concatenate([values[1][m],values[2][m]]));metrics[m]=dict(old=old,new=new,delta_new_minus_old={k:new[k]-old[k] for k in old if k!='n'},control_mean_drift_ms=slots['3'][m]['mean_ms']-slots['0'][m]['mean_ms'],candidate_mean_drift_ms=slots['2'][m]['mean_ms']-slots['1'][m]['mean_ms'],both_candidate_means_faster_than_both_controls=max(slots['1'][m]['mean_ms'],slots['2'][m]['mean_ms'])<min(slots['0'][m]['mean_ms'],slots['3'][m]['mean_ms']))
log=(a.directory/'stdout.log').read_text();assert len(re.findall(r'^EDGE slot=',log,re.M))==8 and not re.search(r'(?:byte_diff|nan|guard_diff)=[1-9]',log)
out=dict(actual_case=662786,actual_exit_code=0,slots=slots,metrics=metrics,edges=8,edge_byte_nan_guard_differences=0,csv_sha256=hashlib.sha256((a.directory/'samples.csv').read_bytes()).hexdigest(),scope='one-process ABBA isolated one-QKV kernel, ordinary launches; event outer and host submission-completion wall; 10warm20measure per slot,40perarm; p99 interpolates roughly one tail sample; not production Auto or Frame speed',decision='coordinator decides screen signal versus drift; no extrapolation to eight-layer/fullFrame/FPS')
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(out,indent=2)+'\n');print(json.dumps(metrics,indent=2))
