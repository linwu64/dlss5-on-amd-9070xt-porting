$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\prefix-main-th-frame-default-style-20261012'
if(Test-Path "$r\modules"){throw 'existing stage no overwrite'}
New-Item -ItemType Directory "$r\modules"|Out-Null
Copy-Item 'D:\DLSSNR-Lab\vit-tail-production-final-20261012\modules-candidate\*.hsaco' "$r\modules"
Copy-Item 'D:\DLSSNR-Lab\prefix-main-th-20261012\candidate.hsaco' "$r\modules\prefix-main-nt.hsaco"
if(@(Get-ChildItem "$r\modules" -Filter '*.hsaco' -File).Count -ne 44){throw 'original43+oneprivate sidecar'}
if((Get-FileHash "$r\modules\vit-stream-fast.hsaco").Hash -ne 'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014'){throw 'currentjoint no V'}
if((Get-FileHash "$r\modules\c32-wave1-fast.hsaco").Hash -ne 'f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52'){throw 'stockf46'}
if((Get-FileHash "$r\modules\prefix-main-nt.hsaco").Hash -ne '761984e781c58f9587a9e6b3432f2b9c6c8713516e441ed21bc0aabdcb67f094'){throw 'candidate761'}
'PREFIX_FRAME_COLD_STAGE_NO_DEVICE_OPERATION'
