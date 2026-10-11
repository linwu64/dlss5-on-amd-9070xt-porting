from pathlib import Path
import argparse,json,hashlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);p.add_argument('--remote-name',required=True);a=p.parse_args()
b=a.build.resolve();r=Path(__file__).resolve().parents[4];old=Path('/home/lmxxf/work/dlss5-vit-tile-ready-build/run-manifest.json');m=json.loads(old.read_text())
for f in m['files']:
 src=b/f['file'] if f['file'] in ('candidate.hsaco','pair.exe') else Path(f['local_source'])
 if not src.exists() and f['file']=='pair.exe':src=old.parent/'pair.exe'
 data=src.read_bytes();f.update(local_source=str(src),bytes=len(data),sha256=hashlib.sha256(data).hexdigest())
 subprocess.run(['scp',str(src),'amd9070:D:/DLSSNR-Lab/'+a.remote_name+'/'+f['file']],check=True)
(b/'run-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
s=(Path(__file__).with_name('run.ps1')).read_text().replace('vit-tile-ready-20261012',a.remote_name);(b/'run.ps1').write_text(s)
for name in ('run-manifest.json','run.ps1'):
 subprocess.run(['scp',str(b/name),'amd9070:D:/DLSSNR-Lab/'+a.remote_name+'/'],check=True)
print('STAGE_COMPLETE',a.remote_name)
