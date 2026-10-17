#!/usr/bin/env python3
"""Recompute ABBA means and linear-interpolated p99 from collected raw CSV rows.
Usage: analyze.py evidence.json [case-prefix]. Input is saved collect.ps1 output.
"""
import json,sys,statistics
j=json.load(open(sys.argv[1],encoding='utf-8-sig'))
def q(v,p):
 v=sorted(v);x=(len(v)-1)*p;i=int(x);return v[i]+(v[min(i+1,len(v)-1)]-v[i])*(x-i)
allv=[[],[]]
for case in j['cases']:
 if '-abba-' not in case['name'] or (len(sys.argv)>2 and not case['name'].startswith(sys.argv[2]+'-')):continue
 vs=[[],[]]
 for slot in case['slots']:
  role=int(slot['name'].startswith('candidate'));v=[float(r['wall_ms']) for r in slot['rows'][80:]];vs[role]+=v
  assert len(v)==160
  assert len({h['sha256'].lower() for h in slot['hashes']}) == 1
 for i in range(2):allv[i]+=vs[i]
 print(case['name'], [(round(statistics.mean(v),6),round(q(v,.99),6)) for v in vs], 'delta',round(statistics.mean(vs[1])-statistics.mean(vs[0]),6),round(q(vs[1],.99)-q(vs[0],.99),6))
if allv[0]:print('POOLED',[(statistics.mean(v),q(v,.99)) for v in allv],'delta',statistics.mean(allv[1])-statistics.mean(allv[0]),q(allv[1],.99)-q(allv[0],.99))
