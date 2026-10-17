#!/usr/bin/env python3
"""Convert pinned 310.9.16 resources to the existing HIP logical weight layout.
Run from repository root; recovered layout NPZ assets under release/ are required.
Small uses legacy kernel-role filenames in a separate directory; manifest records logical IDs.
"""
import argparse,hashlib,json,sys,tempfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[4];sys.path.insert(0,str(ROOT/'Development'))
from native_c32_reference import unpack_bytes as c32
from native_c64_reference import unpack_bytes as mh
from native_split_weights import unpack as split
from native_split_reference import bits,matrix as splitmatrix
from native_upsample48_reference import unpack as up
from native_upsample66_reference import unpack as up32
from native_decoder_entry_reference import unpack as decoder
from native_post70_reference import unpack as post
from native_vit_linear_reference import matrix as vitmatrix,unpack_residual
from native_vit_qkv_reference import unpack as vitqkv
from preblock_mix_reference import unpack_mix
from decode_tinlayout_global import e4m3fn
p=argparse.ArgumentParser(__doc__);p.add_argument('--dll',type=Path,required=True);p.add_argument('--model',choices=['small','original'],required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--compare',type=Path);a=p.parse_args()
blob=a.dll.read_bytes();sha=hashlib.sha256(blob).hexdigest();assert sha=='2bc19bc09a7b89dd44f73e2ac0108fcc586e2154bdd0830f242f4f040e28789f'
evidence=ROOT/'Development/results/dlssnr-310-9-16-analysis-20261018'
records=json.loads((evidence/('records-small.json' if a.model=='small' else 'records-ht.json')).read_text())
raw={x['name']:np.frombuffer(blob,dtype=np.uint8,count=x['payload_size'],offset=x['file_offset']).copy() for x in records}
roles={int(k):v for k,v in json.loads((evidence/'summary.json').read_text())['role_mapping'].items()} if a.model=='small' else dict(zip(range(71),range(71)))
a.output.mkdir(parents=True,exist_ok=True);files={};compared=[]
def save(name,values,compare=True):
 name=name.replace('block70-','post70-')
 arr=np.asarray(values,dtype='<f4').ravel();assert np.isfinite(arr).all(),name
 if a.compare and compare:
  ref=a.compare/(name+'.f32');half=ref.with_suffix('.f16')
  previous=np.fromfile(ref,'<f4') if ref.exists() else np.fromfile(half,'<f2').astype('<f4')
  assert previous.shape==arr.shape,(name,previous.size,arr.size)
  n=int(np.count_nonzero(previous.view('u4')!=arr.view('u4')))
  if n:raise AssertionError((name,'mismatches',n,'max_abs',float(abs(previous-arr).max())))
  compared.append(name)
 # Preserve every bit; use half only when widening it is lossless, including signed zeros.
 h=arr.astype('<f2');exact=np.array_equal(h.astype('<f4').view('u4'),arr.view('u4'))
 dest=a.output/(name+('.f16' if exact else '.f32'));dest.write_bytes(h.tobytes() if exact else arr.tobytes())
 other=dest.with_suffix('.f32' if exact else '.f16')
 if other.exists():other.unlink()
 files[dest.name]={'elements':int(arr.size),'bytes':dest.stat().st_size,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest(),'logical_f32_sha256':hashlib.sha256(arr.tobytes()).hexdigest()}
def body(role,param,first=None):
 w1,w2,q,k,v,pr,bias,sc,fs,ats=param
 save(f'block{role}-ffn',np.concatenate([np.zeros(512) if first is None else first.ravel(),w1.ravel(),w2.ravel(),fs]))
 save(f'block{role}-attention',np.concatenate([x.ravel() for x in [q,k,v,pr,bias,np.array([sc]),ats]]))
def mhbody(role,param):
 f,qkv,pr,bias,sc,ss=param
 save(f'block{role}-ffn',np.concatenate([f[x].ravel()for x in ['W1','W2','W3','skip']]))
 save(f'block{role}-attention',np.concatenate([x.ravel()for x in [*qkv,pr,bias,sc,ss]]))
with tempfile.TemporaryDirectory(prefix='small-weights-') as td:
 t=Path(td)
 def disk(r,name='temp.weights'):
  f=t/name;f.write_bytes(r.tobytes());return f
 for block,role in roles.items():
  r=raw[f'block{block}.layer0.layer']
  if role==0:
   ordinary=np.concatenate([r[:8208],r[9232:]])
   body(role,c32(ordinary),unpack_mix(r.view('<f2').astype('f4')))
  elif role in [1,2,3,4,67,68,69]:
   body(role,c32(r))
   if role==4:
    l=np.load('release/preblock-ffn-byte-layout/layout.npz');v=np.empty((64,32),'f4');v[l['w1_hidden'][:2048],l['w1_input'][:2048]]=e4m3fn(r[20656:22704]);save('block4-ds',v)
  elif role in range(5,23):
   mhbody(role,mh(r))
   if role in [8,14,22]:
    c={8:64,14:128,22:256}[role];offset={64:0xf130,128:0x30230,256:0xa8440}[c];v=np.empty((2*c,c),'f4')
    if c==64:l=np.load('release/native-c64/ffn-layout/layout.npz');oi,ii=l['w1_hidden'][:2*c*c],l['w1_input'][:2*c*c]
    else:l=np.load(f'release/native-c{c}/ds-layout/layout.npz');oi,ii=l['output'],l['input']
    v[oi,ii]=e4m3fn(r[offset:]);save(f'block{role}-ds',v)
  elif role in list(range(23,31))+list(range(40,48)):
   for layer in range(4):disk(raw[f'block{block}.layer{layer}.layer'],f'block{block}-{layer}.weights')
   fw,fp,qkv,bias,sc,pr=split(t,block)
   save(f'block{role}-ffwd',np.concatenate([fw[x].ravel()for x in ['pre','expand','contract']]))
   save(f'block{role}-ffwd-projection',np.concatenate([fp['matrix'].ravel(),fp['skip']]))
   save(f'block{role}-attention',np.concatenate([x.ravel()for x in [*qkv,pr['matrix'],bias,sc,pr['skip']]]))
   if role==30:
    v=np.empty((1024,512),'f4');v[bits(524288,[3,6,7,8,9,10,11,12,13,14]),bits(524288,[1,0,4,5,2,15,16,17,18])]=e4m3fn(raw[f'block{block}.layer4.layer'][:524288]);save('head-matrix',v)
  elif role in range(31,39):
   # Layer 3 Attention has no trainable matrix; QKV temperatures live in layer 2.
   save(f'block{role}-expand',vitmatrix(r[:4194304],1024,4096))
   for layer,name,inputs in [(1,'contract',4096),(4,'projection',1024)]:
    v,ss=unpack_residual(disk(raw[f'block{block}.layer{layer}.layer']),inputs);save(f'block{role}-{name}',np.concatenate([v.ravel(),ss]))
   v,sc=vitqkv(disk(raw[f'block{block}.layer2.layer']));save(f'block{role}-qkv',np.concatenate([x.ravel()for x in [*v,sc]]))
  elif role==39:
   v,ss=decoder(disk(r));save('decoder39-weights',np.concatenate([v.ravel(),ss]))
  elif role in [48,56,62,66]:
   v,ss,param=(up32 if role==66 else up)(disk(r));save(f'block{role}-weights',np.concatenate([v.ravel(),ss]))
   (body if role==66 else mhbody)(role,param)
  elif role in range(49,66):mhbody(role,mh(r))
  elif role==70:
   param,sm,ss,head=post(disk(r));body(role,param)
   for suffix,v in [('scales',np.concatenate([sm,ss])),('head',head)]:save('post70-'+suffix,v)
   full_head=np.empty((16,32),'f4');full_head[bits(512,[2,5,6,7]),bits(512,[0,1,3,4,8])]=r[0x5130:].view('<f2')
   save('post70-history-head',full_head[6],compare=False)
   expected='c4c5f5189360756001e96abb43a482396ac8bde56f6ac4c7c19ae63db01d0980' if a.model=='small' else '77c745c4e1d84a6227a2224291d83c37d1e9bd18d45e95add166b1174225ce8f'
   assert files['post70-history-head.f16']['sha256']==expected

  else:raise AssertionError(role)
 blend=raw['block30.layer0.blend_scale' if a.model=='small' else 'block70.layer0.blend_scale'].view('<f2')[0]
 manifest={'format':'DLSS5-HIP-logical-v1','model':a.model,'source_dll_sha256':sha,'logical_to_legacy_role':roles,'blend_scale':float(blend),'blend_half_bits':f'0x{int(np.asarray(blend,dtype="<f2").view("<u2")):04X}','files':files,'old_asset_comparisons':compared,'gpu_validated':False}
 (a.output/'model-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print(json.dumps({'model':a.model,'files':len(files),'bytes':sum(x['bytes']for x in files.values()),'old_compared':len(compared)}))
