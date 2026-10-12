
// New ABI-name, identical argument layout/math; only scalar tail address differs.
#if VIT_CONTRACT_BYTE_EDGE && VIT_QKV_F8W
WAVE void vit_stream_contract_frag_bout_compactw(const float*in,const float*w,const float*skip,float*out,uint tokens,uint inputs,uint outputs,const uint*reuse_gate){if(reuse_gate&&reuse_gate[0])return;if(inputs==4096&&outputs==1024)vit_contract_blocked_body<false,false,false,false,true,true,1048576>(in,w,skip,out,tokens);}
#endif
