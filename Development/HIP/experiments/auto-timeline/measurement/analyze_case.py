#!/usr/bin/env python3
"""Validate actual A/A small artifacts and pool marked host intervals by raw ticks."""
import argparse,csv,hashlib,json,re,subprocess,sys
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('directory',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();here=Path(__file__).parent;a.output.mkdir(parents=True,exist_ok=True)
roles=['baseline-A1','candidate-B1','candidate-B2','baseline-A2'];gold='0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a';allsegments=[];qpc_outer=[];wallsteady=[];logs={};frequency=set();files={}
names=['t0_frame_begin','t1_input_begin','t2_input_end','t3_hip_begin','t4_hip_end','t5_network_end','t6_output_begin','t7_output_end','t8_process_return','t9_completion_begin','t10_completion_end'];labels=['frame_preamble_cpu','input_record_submit_cpu','before_hip_cpu','hip_enqueue_api_cpu','after_hip_bridge_cpu','before_output_cpu','output_record_submit_cpu','process_tail_cpu','caller_before_completion_cpu','caller_completion_cpu']
for role in roles:
 d=a.directory/role;on=int(role.startswith('candidate'));subprocess.run([sys.executable,str(here/'analyze_host_marks.py'),str(d/'out.host.csv'),'--expected-on',str(on),'--output',str(a.output/(role+'-marks.json'))],check=True,stdout=subprocess.DEVNULL)
 r=list(csv.DictReader((d/'out.csv').open()));h=list(csv.DictReader((d/'out.host.csv').open()));assert len(r)==len(h)==320
 assert all(abs(float(x['wall_ms'])-float(y['frame_wall_ms']))<=1e-6 for x,y in zip(r,h))
 edges=[x for x in r if int(x['checked'])];assert len(edges)==2 and all(int(x['invalid'])==0 and int(x['changed_half_values_from_first'])==0 for x in edges)
 hashes=json.loads((d/'raw-sha.json').read_text(encoding='utf-8-sig'));assert len(hashes)==2 and all(x['Hash'].lower()==gold for x in hashes)
 stderr=(d/'stderr.log').read_text();stdout=(d/'stdout.log').read_text();line=next(x for x in stderr.splitlines() if x.startswith('submit_pulse resources '));assert 'record_ok=320' in line and 'accepted=320' in line and 'reject_mask=0' in line and 'lifetime_pdl_calls=0' in line
 assert re.search(rf'HOST_TIMING on={on} frames=320 [^\r\n]*qpc_failures=0',stdout)
 logs[role]=dict(auto_runtime_summary=line,host_summary=next(x for x in stdout.splitlines() if x.startswith('HOST_TIMING')),raw_sha256=gold,edges=2)
 for row in h:frequency.add(int(row['qpc_frequency']))
 if on:
  for row in h[80:]:
   t=[int(row[n]) for n in names];f=int(row['qpc_frequency']);allsegments.append([(b-a)*1000/f for a,b in zip(t,t[1:])]);qpc_outer.append((t[-1]-t[0])*1000/f);wallsteady.append(float(row['frame_wall_ms']))
 for n in ['out.csv','out.host.csv','stdout.log','stderr.log','raw-sha.json']:files[role+'/'+n]=hashlib.sha256((d/n).read_bytes()).hexdigest()
assert len(frequency)==1 and len(allsegments)==480
before=json.loads((a.directory/'modules-preflight.json').read_text(encoding='utf-8-sig'));after=json.loads((a.directory/'modules-after.json').read_text(encoding='utf-8-sig'));assert len(before)==len(after)==43 and sorted(before,key=lambda x:x['file'])==sorted(after,key=lambda x:x['file']);assert next(x for x in before if x['file']=='vit-stream-fast.hsaco')['sha256'].lower()=='da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014'
flags=(a.directory/'same.flags').read_text(encoding='utf-8-sig')
for key in ['DLSS5_HIP_MEMORY','DLSS5_GAME_PROBE','DLSS5_NET_TIMING','DLSS5_HIP_SPAN_PROBE','DLSS5_HIP_INPUT_POLL']:
 assert re.search(r'^'+key+r'=0\s*$',flags,re.M),key
subprocess.run([sys.executable,str(here/'analyze_aa.py'),'--a1',str(a.directory/roles[0]/'out.csv'),'--b1',str(a.directory/roles[1]/'out.csv'),'--b2',str(a.directory/roles[2]/'out.csv'),'--a2',str(a.directory/roles[3]/'out.csv'),'--output',str(a.output/'independent-aa.json')],check=True,stdout=subprocess.DEVNULL)
def stats(x):return dict(n=len(x),mean_ms=float(np.mean(x)),median_ms=float(np.median(x)),p95_ms=float(np.quantile(x,.95)),p99_ms=float(np.quantile(x,.99)),max_ms=float(np.max(x)))
x=np.array(allsegments);report=dict(actual_handle=31627,actual_exit_code=0,raw_numeric_and_format_pass=True,instrumentation_equivalence_proven=False,qpc_frequency=next(iter(frequency)),marked_steady_samples=480,cpu_intervals={k:stats(x[:,i]) for i,k in enumerate(labels)},qpc_outer=stats(np.array(qpc_outer)),qpc_outer_minus_existing_wall=stats(np.array(qpc_outer)-np.array(wallsteady)),runtime=logs,file_sha256=files,module_manifest_sha256=hashlib.sha256((a.directory/'modules-preflight.json').read_bytes()).hexdigest(),scope='standalone actual NativeGameFrame replay of the old frozen HDR menu input; Auto production path; host QPC intervals can include blocking; no GPU schedule evidence; not current gameplay FPS',gpu_execution_idle_overlap='not observable / not inferred',decision='two marked slots slower than both controls; approximately24us positive difference cannot be separated from drift, zero overhead/unmodified GPU schedule not established; host phase distribution is descriptive only; no repeat')
(a.output/'independent-host-and-admission.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:v['mean_ms'] for k,v in report['cpu_intervals'].items()},indent=2))
