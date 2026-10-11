#!/usr/bin/env python3
"""Pixel-exact CPU comparison of old frozen HDR menu, not current gameplay."""
from pathlib import Path
import argparse,json,hashlib,re
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('data',type=Path);p.add_argument('out',type=Path);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
r=a.data;log=(r/'stdout.log').read_text();g=re.search(r'PAIR nw=(\d+) valid_h=(\d+) processing_h=(\d+) decoded=(\d+)x(\d+) FRAME_RUN_CALLS=(\d+) EXTRA_DECODES=(\d+)',log);assert g
w,h,ph,dw,dh,runs,decodes=map(int,g.groups());assert (runs,decodes)==(1,1)
x0,y0,fw,fh=map(int,re.search(r'PAIR_FIT x=(\d+) y=(\d+) w=(\d+) h=(\d+)',log).groups())
x=np.fromfile(r/'pair-encoded-input.rgba32f','<f4').reshape(ph,w,4);b=np.fromfile(r/'pair-encoded-before.rgb32f','<f4').reshape(ph,w,3);c=np.fromfile(r/'pair-encoded-after.rgb32f','<f4').reshape(ph,w,3)
hb=np.fromfile(r/'pair-decoded-before.rgba16f','<f2').reshape(dh,dw,4);hc=np.fromfile(r/'pair-decoded-after.rgba16f','<f2').reshape(dh,dw,4)
assert all(np.isfinite(v).all()for v in (x,b,c,hb,hc));assert np.array_equal(b[h:].view('u4'),c[h:].view('u4'));assert np.array_equal(hb[...,3].view('u2'),hc[...,3].view('u2'))
def metric(v,z):
 v=v.astype('f8');z=z.astype('f8');d=np.abs(z-v);return dict(mae=float(d.mean()),rmse=float(np.sqrt(np.mean(d*d))),p50=float(np.quantile(d,.5)),p95=float(np.quantile(d,.95)),p99=float(np.quantile(d,.99)),maximum=float(d.max()),changed_pixel_fraction=float(np.mean(np.any(d!=0,axis=-1))) if d.ndim==3 else float(np.mean(d!=0)),signed_mean_change=float((z-v).mean()))
# Fixed shared exposure, inherited from the audited20261009 pair. Never auto-expose each side.
exposure=3.997892599151139
def display(v):
 z=np.maximum(v.astype('f8'),0)*exposure;z=z/(1+z);return np.where(z<=.0031308,z*12.92,1.055*np.power(z,1/2.4)-.055)
DB,DC=display(hb[...,:3]),display(hc[...,:3]);luma=np.array([.2126,.7152,.0722]);d=np.abs(DC-DB);pmax=d.max(axis=2)
report=dict(scope='Old frozen1296x720 HDR menu captured before20261009, not current gameplay; cold spatial enhancement only, not flicker or quality gold',run_calls=runs,extra_decodes=decodes,geometry=dict(encoded=[w,h,ph],decoded=[dw,dh],fit=[x0,y0,fw,fh]),encoded_valid_rgb=metric(b[:h],c[:h]),encoded_fit_rgb=metric(b[y0:y0+fh,x0:x0+fw],c[y0:y0+fh,x0:x0+fw]),raw_decoded_HDR_rgb=metric(hb[...,:3],hc[...,:3]),raw_decoded_HDR_weighted_Y=metric(hb[...,:3].astype('f8')@luma,hc[...,:3].astype('f8')@luma),display_rgb=metric(DB,DC),display_weighted_Yprime=metric(DB@luma,DC@luma),display_max_pixel_thresholds={str(t)+'/255':float(np.mean(pmax>t/255))for t in (1,2,4,8)},display_u8_changed_pixel_fraction=float(np.mean(np.any(np.rint(DB*255)!=np.rint(DC*255),axis=2))),encoded_residual=dict(mode0_MAE_to_encoded_original=float(np.abs(b[:h]-x[:h,:,:3]).mean()),mode3_MAE_to_encoded_original=float(np.abs(c[:h]-x[:h,:,:3]).mean()),delta_MAE=float(np.abs(c[:h]-b[:h]).mean())),padding72rows_bit_identity=True,decoded_alpha_bit_identity=True,all_finite=True,display_mapping=dict(exposure=exposure,mapping='same exposure -> per-channel Reinhard -> sRGB',negative_display_only_clamped_zero=True,actual_HDR_display_transform_unknown=True,weighted_Yprime='fixed Rec709 numeric weights on display-coded RGB, not nits/JND'),raw={f.name:dict(bytes=f.stat().st_size,sha256=hashlib.sha256(f.read_bytes()).hexdigest())for f in r.glob('pair-*')if f.suffix in ('.rgb32f','.rgba32f','.rgba16f')},no_PSNR_quality_claim=True)
fontpath='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc';font=ImageFont.truetype(fontpath,20);small=ImageFont.truetype(fontpath,16)
def img(v):return Image.fromarray(np.uint8(np.clip(v,0,1)*255+.5))
ib,ic=img(DB),img(DC)
# Explicit signed displayRGB delta aroundneutral gray; x4 is visualization only.
diff=img(.5+(DC-DB)*4)
canvas=Image.new('RGB',(dw*3,dh+90),(20,20,20));draw=ImageDraw.Draw(canvas)
draw.text((12,6),'旧冻结HDR菜单 / same NN, same decoder / MODE3 strength1 cold / 非本次游玩截图',font=font,fill='white')
for i,(v,title)in enumerate(((ib,'MODE0: 原单遍NR输出'),(ic,'MODE3: 单遍增强 s=1'),(diff,'显示RGB有符号差分 ×4（中灰=0，可能截断）'))):canvas.paste(v,(i*dw,90));draw.text((i*dw+12,43),title,font=font,fill='white')
canvas.save(a.out/'comparison.png')
# Fixed spatial ROIs; both sides receive identical nearest-neighbor enlargement.
rois=[('脸部/头发',(730,40,970,280)),('衣料/材质',(740,300,980,540)),('金属/反光',(90,330,330,570)),('暗部/地面',(350,440,590,680))]
zoom=3;tiles=[]
for label,box in rois:
 tile=Image.new('RGB',(240*zoom*3,240*zoom+62),(20,20,20));dr=ImageDraw.Draw(tile);dr.text((10,4),label+'：原图坐标'+str(box)+'；像素放大×3，非锐化',font=small,fill='white')
 for i,(im,title)in enumerate(((ib,'MODE0'),(ic,'MODE3 s1'),(diff,'signed delta ×4'))):tile.paste(im.crop(box).resize((720,720),Image.Resampling.NEAREST),(i*720,62));dr.text((i*720+10,30),title,font=small,fill='white')
 tile.save(a.out/('crop-'+str(len(tiles)+1)+'-x3.png'));tiles.append(tile)
z=Image.new('RGB',(2160,sum(t.height for t in tiles)),(20,20,20));yy=0
for tile in tiles:z.paste(tile,(0,yy));yy+=tile.height
report['ROIs']=[dict(label=l,box=b,zoom=zoom)for l,b in rois];report['difference_visualization']='signed difference in displayRGB x4 centered at gray. Not alternate exposure, not quality-error heatmap.'
def range_counts(v):
 return dict(components=int(v.size),pixels=int(np.prod(v.shape[:-1])),strict_below_zero_components=int(np.count_nonzero(v<0)),strict_above_one_components=int(np.count_nonzero(v>1)),outside_1e_minus6_components=int(np.count_nonzero((v< -1e-6)|(v>1+1e-6))),exact_zero_components=int(np.count_nonzero(v==0)),exact_one_components=int(np.count_nonzero(v==1)))
report['encoded_valid_range_counts']=dict(before=range_counts(b[:h]),after=range_counts(c[:h]),newly_at_or_beyond_zero_components=int(np.count_nonzero((c[:h]<=0)&(b[:h]>0))),newly_at_or_beyond_one_components=int(np.count_nonzero((c[:h]>=1)&(b[:h]<1))),note='Outcome counts, not hardware clipping/headroom gate counters. Tiny float EPS outside range is reported separately from tolerance1e-6.')
(a.out/'stats.json').write_text(json.dumps(report,indent=2)+'\n');print(a.out/'comparison.png');print(a.out/'crop-1-x3.png')
