$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-042'
if(Test-Path "$r\source"){throw 'existing stage'}
Expand-Archive "$r\source.zip" "$r\source"
New-Item -ItemType Directory "$r\payload"|Out-Null
Copy-Item 'D:\DLSSNR-Lab\release-041\payload\runtime-smoke.exe' "$r\payload"
foreach($n in 'SOURCE-README.txt','HOST-LICENSE.txt','CORE-LICENSE.txt'){Copy-Item "D:\DLSSNR-Lab\release-041\$n" "$r\$n"}
'042_STAGE_NO_DEVICE'
