$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\auto-host-timing-20261012'
if(Test-Path "$r\modules"){throw 'private module stage already exists'}
New-Item -ItemType Directory "$r\modules"|Out-Null
Copy-Item 'D:\DLSSNR-Lab\vit-tail-production-final-20261012\modules-candidate\*.hsaco' "$r\modules"
if(@(Get-ChildItem "$r\modules" -Filter '*.hsaco' -File).Count -ne 43){throw '43 actual modules'}
if((Get-FileHash "$r\modules\vit-stream-fast.hsaco").Hash -ne 'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014'){throw 'current joint module'}
$expected=Get-Content "$r\modules-expected.json" -Raw|ConvertFrom-Json
if($expected.Count -ne 43){throw 'expected43 identity'}
foreach($f in $expected){$q=Join-Path "$r\modules" $f.file;if((Get-Item $q).Length -ne $f.bytes -or (Get-FileHash $q).Hash -ne $f.sha256){throw "expectedmodule identity $($f.file)"}}
'CURRENT_JOINT43_STAGED_NO_DEVICE_OPERATION' 
