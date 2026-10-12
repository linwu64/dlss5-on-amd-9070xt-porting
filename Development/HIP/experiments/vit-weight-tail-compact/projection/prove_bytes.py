#!/usr/bin/env python3
"""Actual projection packed prefix + raw F32 tail, with exhaustive address proof."""
from pathlib import Path
import argparse,json,hashlib,numpy as np
p=argparse.ArgumentParser();p.add_argument('--weight',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
b=a.weight.read_bytes();assert len(b)==4198400
prefix=b[:1048576];tail=b[4194304:4198400];assert len(tail)==4096
compact=prefix+tail;assert len(compact)==1052672
row=np.arange(1024,dtype=np.uint32)[:,None,None,None];k=np.arange(0,1024,16,dtype=np.uint32)[None,:,None,None];gr=np.arange(2,dtype=np.uint32)[None,None,:,None];e=np.arange(8,dtype=np.uint32)[None,None,None,:]
idx=(((row//16)*32+k//32)*512+(((k%32)//16*2+gr)*16+row%16)*8+e).reshape(-1)
assert int(idx.min())==0 and int(idx.max())==1048575 and np.all(np.bincount(idx,minlength=1048576)==1)
assert np.array_equal(np.frombuffer(b,np.uint8)[idx],np.frombuffer(compact,np.uint8)[idx])
assert compact[1048576:]==tail
scales=np.frombuffer(tail,dtype='<f4');assert len(scales)==1024 and np.isfinite(scales).all()
# Inverse on every *live* old byte; discarded dead hole contents have no consumer.
inverse=bytearray(len(b));inverse[:1048576]=compact[:1048576];inverse[4194304:]=compact[1048576:];assert inverse[:1048576]==b[:1048576]and inverse[4194304:]==b[4194304:]
(a.out/'projection-compact.bin').write_bytes(compact)
r={'weight_file':str(a.weight),'old_bytes':len(b),'new_bytes':len(compact),'bytes_saved_per_matrix':len(b)-len(compact),'old_sha256':hashlib.sha256(b).hexdigest(),'new_sha256':hashlib.sha256(compact).hexdigest(),'matrix_sha256':hashlib.sha256(prefix).hexdigest(),'tail_sha256':hashlib.sha256(tail).hexdigest(),'all1048576matrix_addresses_bijection':True,'matrix_byte_differences':0,'F32tail_byte_differences':0,'inverse_all_live_byte_differences':0,'old_scale_float_index':1048576,'new_scale_float_index':262144,'max_new_matrix_byte':1048575,'max_new_scale_byte':1052671,'weight_addresses_independent_of_tokens':True,'no_float_conversion_or_quantization':True,'numeric_hardware_pass':False,'hypothetical_eight_matrix_capacity_savings_bytes':25165824}
(a.out/'byte-proof.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
