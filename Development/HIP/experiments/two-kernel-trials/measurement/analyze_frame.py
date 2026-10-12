#!/usr/bin/env python3
import argparse,csv,json,hashlib,re
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args();roles=['baseline-A1','candidate-B1','candidate-B2','baseline-A2'];slots={};data={};runtime={}
def stat(v):return dict(n=len(v),mean_ms=float(np.mean(v)),median_ms=float(np.median(v)),sd_ms=float(np.std(v,ddof=1)),p95_ms=float(np.quantile(v,.95)),p99_ms=float(np.quantile(v,.99)),max_ms=float(np.max(v)))
for role in roles:
 d=a.directory/role;rows=list(csv.DictReader((d/'out.csv').open()));assert len(rows)==320 and [int(r['frame']) for r in rows]==list(range(320));edges=[r for r in rows if int(r['checked'])];assert len(edges)==2 and all(int(r['invalid'])==0 and int(r['changed_half_values_from_first'])==0 for r in edges)
 hashes=json.loads((d/'raw-sha.json').read_text(encoding='utf-8-sig'));assert len(hashes)==2 and all(x['Hash'].lower()=='0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a' for x in hashes)
 log=(d/'stderr.log').read_text();on=int(role.startswith('candidate'));expected=f'PREFIX_NT_SUMMARY requested={on} ready={on} candidate_calls={320 if on else 0} stock_calls={0 if on else 320}';assert expected in log
 assert re.search(r'submit_pulse resources[^\r\n]*record_ok=320[^\r\n]*accepted=320 reject_mask=0 lifetime_pdl_calls=0',log)
 for key in ['CONTRACT_COMPACT key=','PROJECTION_COMPACT key=']:assert log.count(key)==8
 runtime[role]=dict(prefix_summary=expected,auto_accepted=320,pdl_actual_calls=0,raw_edges=2)
 v=np.array([float(r['wall_ms']) for r in rows[80:]]);assert np.isfinite(v).all() and (v>0).all();data[role]=v;slots[role]=stat(v)|dict(csv_sha256=hashlib.sha256((d/'out.csv').read_bytes()).hexdigest(),frames=320,discard=80)
old=stat(np.concatenate([data[roles[0]],data[roles[3]]]));new=stat(np.concatenate([data[roles[1]],data[roles[2]]]))
before=json.loads((a.directory/'modules-preflight.json').read_text(encoding='utf-8-sig'));after=json.loads((a.directory/'modules-after.json').read_text(encoding='utf-8-sig'));assert len(before)==len(after)==44 and sorted(before,key=lambda x:x['file'])==sorted(after,key=lambda x:x['file'])
expected={'c32-wave1-fast.hsaco':'f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52','vit-stream-fast.hsaco':'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014','prefix-main-nt.hsaco':'761984e781c58f9587a9e6b3432f2b9c6c8713516e441ed21bc0aabdcb67f094'}
for name,sha in expected.items():assert next(x for x in before if x['file']==name)['sha256'].lower()==sha
flags={}
for line in (a.directory/'same.flags').read_text(encoding='utf-8-sig').splitlines():
 if line.startswith('DLSS5_') and '=' in line:k,v=line.split('=',1);flags[k]=v.strip()
for k in ['DLSS5_HIP_MEMORY','DLSS5_GAME_PROBE','DLSS5_HIP_INPUT_POLL']:assert flags[k]=='0'
# Runner used two unused alias names; actual keys are absent and bridge defaults false.
assert flags.get('DLSS5_NET_TIMING','0')=='0' and flags.get('DLSS5_HIP_SPAN_PROBE','0')=='0'
r=dict(actual_case=89008,actual_exit_code=0,slots=slots,old=old,new=new,delta_new_minus_old={k:new[k]-old[k] for k in old if k!='n'},control_mean_drift_ms=slots[roles[3]]['mean_ms']-slots[roles[0]]['mean_ms'],candidate_mean_drift_ms=slots[roles[2]]['mean_ms']-slots[roles[1]]['mean_ms'],runtime=runtime,modules=44,scope='single ABBA whole NativeGameFrame controlled old HDR menu replay; same private non-QPC exe NR0/1, current43 original modules plus NT sidecar; CPU Frame completion wall; warm80discard from320 each,480perarm; not gameFPS or cachemiss causality',probe_flag_correction='unused HIP_NET_TIMING/HIP_NET_SPAN written0; real NET_TIMING/HIP_SPAN_PROBE absent in actualflags and childenv cleared, defaultfalse per bridge; no rerun/no changed case',decision='STOP: numerical/identity gates pass, no reliable wholeFrame gain versus slot drift; no integration/no further trial',gpu_code_residency='candidate cold-loads extra sidecar, baseline does not; file manifest equality is not GPU residency equality')
a.out.parent.mkdir(parents=True,exist_ok=True);a.out.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:r[k] for k in ['old','new','delta_new_minus_old','control_mean_drift_ms','candidate_mean_drift_ms','decision']},indent=2))
