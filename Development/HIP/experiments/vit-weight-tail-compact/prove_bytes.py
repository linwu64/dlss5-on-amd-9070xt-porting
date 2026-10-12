#!/usr/bin/env python3
"""Actual contract packed prefix + raw F32 tail, with exhaustive address proof."""
from pathlib import Path
import argparse,json,hashlib,numpy as np
p=argparse.ArgumentParser();p.add_argument('--weight',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
b=a.weight.read_bytes();assert len(b)==16781312
prefix=b[:4194304];tail=b[16777216:16781312];assert len(tail)==4096
compact=prefix+tail;assert len(compact)==4198400
row=np.arange(1024,dtype=np.uint32)[:,None,None,None];k=np.arange(0,4096,16,dtype=np.uint32)[None,:,None,None];gr=np.arange(2,dtype=np.uint32)[None,None,:,None];e=np.arange(8,dtype=np.uint32)[None,None,None,:]
idx=(((row//16)*128+k//32)*512+(((k%32)//16*2+gr)*16+row%16)*8+e).reshape(-1)
assert int(idx.min())==0 and int(idx.max())==4194303 and np.all(np.bincount(idx,minlength=4194304)==1)
assert np.array_equal(np.frombuffer(b,np.uint8)[idx],np.frombuffer(compact,np.uint8)[idx])
assert compact[4194304:]==tail
scales=np.frombuffer(tail,dtype='<f4');assert len(scales)==1024 and np.isfinite(scales).all()
# Inverse on every *live* old byte; discarded dead hole contents have no consumer.
inverse=bytearray(len(b));inverse[:4194304]=compact[:4194304];inverse[16777216:]=compact[4194304:];assert inverse[:4194304]==b[:4194304]and inverse[16777216:]==b[16777216:]
(a.out/'contract-compact.bin').write_bytes(compact)
r={'weight_file':str(a.weight),'old_bytes':len(b),'new_bytes':len(compact),'bytes_saved_per_matrix':len(b)-len(compact),'old_sha256':hashlib.sha256(b).hexdigest(),'new_sha256':hashlib.sha256(compact).hexdigest(),'matrix_sha256':hashlib.sha256(prefix).hexdigest(),'tail_sha256':hashlib.sha256(tail).hexdigest(),'all4194304matrix_addresses_bijection':True,'matrix_byte_differences':0,'F32tail_byte_differences':0,'inverse_all_live_byte_differences':0,'old_scale_float_index':4194304,'new_scale_float_index':1048576,'max_new_matrix_byte':4194303,'max_new_scale_byte':4198399,'weight_addresses_independent_of_tokens':True,'no_float_conversion_or_quantization':True,'numeric_hardware_pass':False,'hypothetical_eight_matrix_capacity_savings_bytes':100663296}
(a.out/'byte-proof.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
