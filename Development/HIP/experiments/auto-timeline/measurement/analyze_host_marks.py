#!/usr/bin/env python3
"""Validate and summarize raw host QPC boundaries; these are never GPU durations."""
import argparse,csv,json,hashlib
from pathlib import Path
import numpy as np
p=argparse.ArgumentParser();p.add_argument('csv',type=Path);p.add_argument('--frames',type=int,default=320);p.add_argument('--discard',type=int,default=80);p.add_argument('--expected-on',type=int,choices=[0,1],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
names=['t0_frame_begin','t1_input_begin','t2_input_end','t3_hip_begin','t4_hip_end','t5_network_end','t6_output_begin','t7_output_end','t8_process_return','t9_completion_begin','t10_completion_end']
labels=['frame_preamble_cpu','input_record_submit_cpu','before_hip_cpu','hip_enqueue_api_cpu','after_hip_bridge_cpu','before_output_cpu','output_record_submit_cpu','process_tail_cpu','caller_before_completion_cpu','caller_completion_cpu']
rows=list(csv.DictReader(a.csv.open(encoding='utf-8-sig')))
if len(rows)!=a.frames or [int(r['frame']) for r in rows]!=list(range(a.frames)):raise ValueError('frame count/order')
if any(int(r['on'])!=a.expected_on for r in rows):raise ValueError('instrumentation flag differs from actual arm')
values=[];wall=[];frequency=None
for r in rows:
 tick=[int(r[n]) for n in names];f=int(r['qpc_frequency']);w=float(r['frame_wall_ms'])
 if not np.isfinite(w) or w<0:raise ValueError('nonfinite/negative Framewall')
 wall.append(w)
 if a.expected_on:
  if f<=0 or any(x<=0 for x in tick) or any(b<a for a,b in zip(tick,tick[1:])):raise ValueError('invalid/nonmonotone raw QPC marks')
  if frequency is not None and f!=frequency:raise ValueError('clock frequency changed')
  frequency=f;values.append([1000*(b-a)/f for a,b in zip(tick,tick[1:])]+[1000*(tick[-1]-tick[0])/f])
 elif any(tick):raise ValueError('off arm emitted nonzero marks')
def stats(x):return dict(n=len(x),mean_ms=float(np.mean(x)),median_ms=float(np.median(x)),p95_ms=float(np.quantile(x,.95)),p99_ms=float(np.quantile(x,.99)),max_ms=float(np.max(x)))
result=dict(csv=str(a.csv),csv_sha256=hashlib.sha256(a.csv.read_bytes()).hexdigest(),frames=len(rows),discard=a.discard,on=a.expected_on,qpc_frequency=frequency,frame_wall=stats(np.array(wall[a.discard:])),scope='adjacent CPU QPC intervals, including any blocking inside calls; no GPU execution/idle/overlap claim',gpu_attribution='unobservable from host marks')
if a.expected_on:
 x=np.array(values[a.discard:]);result['cpu_intervals']={k:stats(x[:,i]) for i,k in enumerate(labels)};result['outer_qpc_interval']=stats(x[:,-1]);result['qpc_outer_minus_existing_wall_ms']=stats(x[:,-1]-np.array(wall[a.discard:]));result['outer_difference_scope']='different host timestamp endpoints/measurement overhead; never interpreted as GPU gap'
a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
