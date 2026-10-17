#!/usr/bin/env python3
"""Read back immutable experiment receipts (never runs GPU work)."""
from pathlib import Path
import subprocess,json,csv,hashlib,statistics
ROOT=Path(__file__).resolve().parents[4];out=ROOT/'Development/results/small-model-20261018';out.mkdir(exist_ok=True)
def copy(host,remote,local):
 local.parent.mkdir(parents=True,exist_ok=True)
 subprocess.run(['scp',f'{host}:{remote}',str(local)],check=True,stdout=subprocess.DEVNULL)
for case in ['small-1080-gold']+[f'small-1080-abba-r{i}'for i in range(1,4)]:
 copy('amd9070',f'D:/DLSSNR-Lab/small-model-20261018/{case}/gold.json',out/'frame'/case/'gold.json')
 for slot in ['baseline-A1','candidate-B1','candidate-B2','baseline-A2']:
  for file in ['out.csv','stdout.log','stderr.log','slot.flags']:
   copy('amd9070',f'D:/DLSSNR-Lab/small-model-20261018/{case}/{slot}/{file}',out/'frame'/case/slot/file)
for case in ['probe-real-exact','probe-real-fast-switch','probe-missing-small']:
 for mode in ['1','0.5']:
  for file in ['stdout.log','stderr.log','exit.txt','hashes.json']:
   copy('amd9070',f'D:/DLSSNR-Lab/small-model-20261018/{case}/{mode}/{file}',out/'hip'/case/mode/file)
for file in ['stdout.log','stderr.log','exit.txt']:
 copy('amd9070',f'D:/DLSSNR-Lab/small-model-20261018/hotkey-test/{file}',out/'hotkey'/file)
for suffix in ['', '-observe','-capture','-real','-real-capture']:
 for name in ['old-preset1','new-preset1','new-preset2','new-preset0']:
  for file in ['stdout.log','stderr.log','hashes.json','exit.txt']:
   copy('rtx5090',f'C:/DLSSNR-Small-20261018/{name}{suffix}/{file}',out/'oracle'/(name+suffix)/file)
  if 'capture' in suffix:
   copy('rtx5090',f'C:/DLSSNR-Small-20261018/{name}{suffix}/launch-observe.txt',out/'oracle'/(name+suffix)/'launch-observe.txt')

def readj(p):
 b=p.read_bytes();return json.loads(b.decode('utf-16')if b[:2]==b'\xff\xfe'else b.decode('utf-8-sig'))
rounds=[];pooled={'A':[],'B':[]}
for i in range(1,4):
 d=out/'frame'/f'small-1080-abba-r{i}';r={'round':i,'slots':[]};times={'A':[],'B':[]}
 for slot in ['baseline-A1','candidate-B1','candidate-B2','baseline-A2']:
  rows=list(csv.DictReader((d/slot/'out.csv').open(encoding='utf-8-sig')));assert len(rows)==240
  edges=[x for x in rows if x['checked']=='1'];assert len(edges)==2 and all(x['invalid']=='0'and x['changed_half_values_from_first']=='0'for x in edges)
  t=[float(x['wall_ms'])for x in rows[80:]];group='A'if slot.startswith('baseline')else'B';times[group]+=t;pooled[group]+=t
  st=sorted(t);r['slots'].append(dict(slot=slot,samples=len(t),mean=statistics.mean(t),median=statistics.median(t),p99=st[int((len(t)-1)*.99)]))
 for k in ['A','B']:
  st=sorted(times[k]);r[k]=dict(samples=len(st),mean=statistics.mean(st),median=statistics.median(st),p99=st[int((len(st)-1)*.99)])
 r['delta_mean_ms']=r['B']['mean']-r['A']['mean'];assert r['delta_mean_ms']<0
 rounds.append(r)
pool={}
for k,vs in pooled.items():
 st=sorted(vs);pool[k]=dict(samples=len(vs),mean=statistics.mean(vs),median=statistics.median(vs),p99=st[int((len(st)-1)*.99)])
result=dict(rounds=rounds,pooled=pool,speedup=pool['A']['mean']/pool['B']['mean'],time_reduction_percent=100*(1-pool['B']['mean']/pool['A']['mean']),versus_043_9_121_time_reduction_percent=100*(1-pool['B']['mean']/9.121))
(out/'performance.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result['pooled']));print('time reduction',result['time_reduction_percent'])
for stimulus in ['', '-real']:
 def hashes(name,extra=''):
  a=readj(out/'oracle'/(name+stimulus+extra)/'hashes.json');return [v['Hash']for v in a]
 assert hashes('old-preset1')==hashes('new-preset1')
 assert hashes('new-preset0')==hashes('new-preset2')
 for name in ['old-preset1','new-preset1','new-preset0','new-preset2']:
  assert hashes(name)==hashes(name,'-capture')
  if not stimulus:assert len(set(hashes(name)))==1
print('Oracle: Preset1=old, default=Preset2, capture preserves API: PASS, synthetic+real')
