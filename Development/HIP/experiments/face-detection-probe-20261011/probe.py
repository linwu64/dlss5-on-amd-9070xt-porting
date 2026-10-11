#!/usr/bin/env python3
"""Actual YuNet CPU face detection on an old frozen HDR menu; no game hook."""
from pathlib import Path
import argparse,time,json,hashlib,platform
import cv2,numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--raw',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
cv2.setNumThreads(1);start=time.perf_counter();raw=np.fromfile(a.raw,'<f2').reshape(720,1296,4);assert np.isfinite(raw).all();v=np.maximum(raw[...,:3].astype('f8'),0)*3.997892599151139;v=v/(1+v);v=np.where(v<=.0031308,12.92*v,1.055*np.power(v,1/2.4)-.055);rgb=np.uint8(np.clip(v,0,1)*255+.5);bgr=cv2.cvtColor(rgb,cv2.COLOR_RGB2BGR);prepare_ms=(time.perf_counter()-start)*1000
runs=[];labels=['right_eye','left_eye','nose_tip','right_mouth_corner','left_mouth_corner'];detector=None
for width in (1296,640):
 t=time.perf_counter();height=round(720*width/1296);inp=bgr if width==1296 else cv2.resize(bgr,(width,height),interpolation=cv2.INTER_AREA);resize_ms=(time.perf_counter()-t)*1000
 t=time.perf_counter();detector=cv2.FaceDetectorYN_create(str(a.model),'',(width,height),.9,.3,5000,cv2.dnn.DNN_BACKEND_OPENCV,cv2.dnn.DNN_TARGET_CPU);create_ms=(time.perf_counter()-t)*1000
 t=time.perf_counter();_,faces=detector.detect(inp);detect_ms=(time.perf_counter()-t)*1000;sx,sy=1296/width,720/height;items=[]
 if faces is not None:
  for row in faces:
   box=[float(row[0]*sx),float(row[1]*sy),float(row[2]*sx),float(row[3]*sy)];points={labels[k]:[float(row[4+2*k]*sx),float(row[5+2*k]*sy)] for k in range(5)};items.append(dict(confidence=float(row[14]),bbox_xywh_original=box,landmarks_original=points,detector_raw=list(map(float,row))))
 runs.append(dict(input_width=width,input_height=height,scale_to_original=[sx,sy],padding=[0,0],score_threshold=.9,nms_threshold=.3,top_k=5000,backend='DNN_BACKEND_OPENCV',target='DNN_TARGET_CPU',threads=1,resize_ms=resize_ms,create_load_ms=create_ms,first_detect_ms=detect_ms,CPU_e2e_ms=prepare_ms+resize_ms+create_ms+detect_ms,face_count=len(items),faces=items))
 if width==1296 and items:break # First successful actual full-resolution proof is sufficient.
selected=next((r for r in runs if r['faces']),None)
if not selected:raise RuntimeError('No face at predefined0.9 threshold/full+640; not fabricating boxes')
image=Image.fromarray(rgb);d=ImageDraw.Draw(image);font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',22)
for face in selected['faces']:
 x,y,w,h=face['bbox_xywh_original'];d.rectangle((x,y,x+w,y+h),outline=(0,255,100),width=3);d.text((max(0,x),max(0,y-29)),f"YuNet CPU {face['confidence']:.4f}",font=font,fill=(0,255,100),stroke_width=1,stroke_fill='black')
 for name,(xx,yy) in face['landmarks_original'].items():d.ellipse((xx-3,yy-3,xx+3,yy+3),fill=(255,180,0))
d.rectangle((0,0,1296,34),fill=(0,0,0));d.text((8,2),'旧冻结菜单 / 实际YuNet CPU检测 / 非当前游玩截图',font=font,fill='white');image.save(a.out/'annotated.png')
report=dict(model_sha256=hashlib.sha256(a.model.read_bytes()).hexdigest(),model_bytes=a.model.stat().st_size,input_raw_sha256=hashlib.sha256(a.raw.read_bytes()).hexdigest(),input_raw_format='1296x720RGBA16F old frozen menu; sameNN MODE0 decoded output',display_transform='fixed shared exposure3.997892599151139 -> perchannelReinhard -> sRGB -> uint8RGB; BGR given to OpenCV',input_conversion_read_ms=prepare_ms,opencv_version=cv2.__version__,platform=platform.platform(),machine=platform.machine(),runs=runs,selected_input_size=[selected['input_width'],selected['input_height']],real_model_inference=True,manual_boxes=False,game_changed=False,GPU_used=False,scope='one old menu CPU proof, single cold detect; not realtime/Windows9070XT performance or game-face accuracy benchmark; face box+5landmarks are not segmentation mask.')
(a.out/'detections.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(selected,indent=2));print(a.out/'annotated.png')
