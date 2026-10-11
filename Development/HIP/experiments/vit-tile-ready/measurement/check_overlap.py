#!/usr/bin/env python3
"""Validate bounded timestamp evidence; does not certify numerical gold or speed."""
import argparse
import json
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('report', type=Path)
a = p.parse_args()
r = json.loads(a.report.read_text())
errors = []
if r.get('clock_scope') != 'gpu_global_realtime' or not (r.get('clock_units') or r.get('units')) or not r.get('clock_source'):
    errors.append('missing shared GPU-global clock contract')
if r.get('wait_timeouts') != 0:
    errors.append('timeout status is missing or nonzero')
for name, fields in [('producers', ('start', 'published')), ('consumers', ('enter', 'work_start', 'end'))]:
    rows = r.get(name, [])
    expected = r.get('expected_' + name)
    if not isinstance(expected, int) or expected <= 0 or len(rows) != expected:
        errors.append(name + ': count mismatch/missing expected count')
    ids = [x.get('id') for x in rows]
    if None in ids or len(set(ids)) != len(ids):
        errors.append(name + ': missing/duplicate ID')
    for x in rows:
        ts = [x.get(k) for k in fields]
        if any(type(t) is not int or t <= 0 for t in ts) or ts != sorted(ts):
            errors.append(name + ': invalid/missing/non-monotonic timestamps')
if errors:
    print(json.dumps({'valid': False, 'errors': errors}, indent=2))
    raise SystemExit(1)
last = max(x['published'] for x in r['producers'])
entered = sum(x['enter'] < last for x in r['consumers'])
useful = [x for x in r['consumers'] if x['work_start'] < last]
print(json.dumps({'valid': True, 'producer_last_publication': last,
                  'consumers_entered_before_last_publication': entered,
                  'consumers_work_started_before_last_publication': len(useful),
                  'maximum_observed_overlap_ticks': max((last - x['work_start'] for x in useful), default=0),
                  'useful_overlap_observed': bool(useful),
                  'scope': 'instrumented scheduling evidence only; not numerical gold or performance'}, indent=2))
