$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-projection-compact-frame-20261012'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
if(Test-Path "$r\modules"){throw 'private module staging already exists'}
New-Item -ItemType Directory "$r\modules"|Out-Null
Copy-Item "$base\modules-current\*.hsaco" "$r\modules"
Copy-Item 'D:\DLSSNR-Lab\vit-contract-compact-20261012\contract-compact.hsaco' "$r\modules\vit-contract-compact.hsaco"
if((Get-FileHash "$r\modules\vit-contract-compact.hsaco").Hash -ne '14facdb57be7b3864b913a99ebe42604c9add4ed4f8bf032b2b04235897ec83f'){throw 'newmoduleSHA'}
Copy-Item 'D:\DLSSNR-Lab\vit-projection-compact-20261012\projection-compact.hsaco' "$r\modules\vit-projection-compact.hsaco"
if((Get-FileHash "$r\modules\vit-projection-compact.hsaco").Hash -ne '8cd0807f1364dfc4cc9cd13bdd96bca042fd2ab3db9e05e62d64d7762be15de6'){throw 'projectionmoduleSHA'}
if(@(Get-ChildItem "$r\modules" -Filter '*.hsaco' -File).Count -ne 45){throw '45private modules'}
'THE_SAME_45_MODULE_FILES_FOR_BOTH_ROLES_NOT_DEVICE_OPERATION'
