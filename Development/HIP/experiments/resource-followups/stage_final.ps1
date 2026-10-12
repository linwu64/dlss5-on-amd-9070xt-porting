$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-tail-production-final-20261012'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
foreach($role in 'baseline','candidate'){
 if(Test-Path "$r\modules-$role"){throw 'finalprivate modules alreadyexist'}
 New-Item -ItemType Directory "$r\modules-$role"|Out-Null
 Copy-Item "$base\modules-current\*.hsaco" "$r\modules-$role"
 if(@(Get-ChildItem "$r\modules-$role" -Filter '*.hsaco' -File).Count -ne 43){throw '43actualmodulefiles'}
}
Copy-Item 'D:\DLSSNR-Lab\vit-tail-joint-20261012\joint-vit-stream-fast.hsaco' "$r\modules-candidate\vit-stream-fast.hsaco" -Force
if((Get-FileHash "$r\modules-baseline\vit-stream-fast.hsaco").Hash -ne '877eaf122f827af6e00824582f5ca918b5d61499d4ad7c7cde7ab6e422516a57'){throw 'stock877e'}
if((Get-FileHash "$r\modules-candidate\vit-stream-fast.hsaco").Hash -ne 'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014'){throw 'jointda1b'}
'FORMAL_43_OLD_NEW_MODULE_STAGING_NOT_DEVICE_OPERATION'
