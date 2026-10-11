#!/usr/bin/env python3
"""One same-Frame ABBA; original wall scope, no invented GPU or game FPS."""
import argparse,csv,hashlib,json,re
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('case',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
slots=['baseline-A1','compact-B1','compact-B2','baseline-A2'];result={'scope':'complete frozen HDR NativeGameFrame ProcessSubmittedFrame plus submission completion wall; not pure GPU, game frame FPS, resident peak or formal multi-round acceptance','discard_per_slot':80,'measured_per_slot':240,'slots':[],'sources':{}}
merged={'baseline':[],'compact':[]}
def stat(v):
 x=np.asarray(v,dtype=np.float64);assert len(v)>1 and np.isfinite(x).all()and(x>0).all();return {'n':len(v),'mean_ms':float(x.mean()),'median_ms':float(np.median(x)),'sd_ms':float(x.std(ddof=1)),'p90_ms':float(np.quantile(x,.9)),'p95_ms':float(np.quantile(x,.95)),'p99_ms':float(np.quantile(x,.99)),'max_ms':float(x.max())}
for slot in slots:
 d=a.case/slot;rows=list(csv.DictReader((d/'out.csv').open(encoding='utf-8-sig')));assert len(rows)==320 and [int(r['frame'])for r in rows]==list(range(320))
 edges=[r for r in rows if r['checked']=='1'];assert len(edges)==2 and all(int(r['invalid'])==0 and int(r['changed_half_values_from_first'])==0 for r in edges)
 variant='compact'if slot.startswith('compact')else'baseline';vals=[float(r['wall_ms'])for r in rows[80:]];merged[variant]+=vals
 s=(d/'stderr.log').read_text(encoding='utf-8-sig');pulse=re.search(r'submit_pulse resources.*?record_ok=(\d+).*?accepted=(\d+).*?reject_mask=(\d+).*?lifetime_pdl_calls=(\d+)',s);assert pulse and list(map(int,pulse.groups()))==[320,320,0,0]
 c=re.findall(r'COMPACT_WEIGHT key=(\S+) original_bytes=(\d+) live_bytes=(\d+) allocation_capacity=(\d+) legacy_key_present=(\d+)',s);assert len(c)==(8 if variant=='compact'else 0)
 if c:assert all(tuple(map(int,x[1:]))==(16777216,4194304,4194304,0)for x in c)
 raw=json.loads((d/'raw-sha.json').read_text(encoding='utf-8-sig'));assert len(raw)==2 and all(x['Hash'].lower()=='0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a'for x in raw)
 result['slots'].append({'slot':slot,'variant':variant,'statistics':stat(vals),'actual_pulse_records':320,'actual_pdl_calls':0,'raw_edges_same_gold':True})
 for name in ['out.csv','stdout.log','stderr.log','raw-sha.json']:
  f=d/name;result['sources'][slot+'/'+name]=hashlib.sha256(f.read_bytes()).hexdigest()
result['merged']={k:stat(v)for k,v in merged.items()}
b,c=result['merged']['baseline'],result['merged']['compact'];result['compact_minus_baseline']={k:c[k]-b[k]for k in ['mean_ms','median_ms','p90_ms','p95_ms','p99_ms','max_ms']};result['mean_percent']=(c['mean_ms']/b['mean_ms']-1)*100
result['control_drift_A2_minus_A1_mean_ms']=result['slots'][3]['statistics']['mean_ms']-result['slots'][0]['statistics']['mean_ms'];result['candidate_drift_B2_minus_B1_mean_ms']=result['slots'][2]['statistics']['mean_ms']-result['slots'][1]['statistics']['mean_ms']
result['resource_gate_independent']='Frame21471 actual owned weights -100663296B, pool/gather/noise unchanged. Single-operator77951 and fullFrame21471 exact. Speed and memory decisions separate.'
a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
