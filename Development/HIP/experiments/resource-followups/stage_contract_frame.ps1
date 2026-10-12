$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-contract-compact-frame-20261012'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
if(Test-Path "$r\modules"){throw 'private module staging already exists'}
New-Item -ItemType Directory "$r\modules"|Out-Null
Copy-Item "$base\modules-current\*.hsaco" "$r\modules"
Copy-Item 'D:\DLSSNR-Lab\vit-contract-compact-20261012\contract-compact.hsaco' "$r\modules\vit-contract-compact.hsaco"
if((Get-FileHash "$r\modules\vit-contract-compact.hsaco").Hash -ne '14facdb57be7b3864b913a99ebe42604c9add4ed4f8bf032b2b04235897ec83f'){throw 'newmoduleSHA'}
if(@(Get-ChildItem "$r\modules" -Filter '*.hsaco' -File).Count -ne 44){throw '44private modules'}
'THE_SAME_44_MODULE_FILES_FOR_BOTH_ROLES_NOT_DEVICE_OPERATION'
