$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-043';$final='D:\DLSSNR-Lab\five-final-20261017';$old='D:\DLSSNR-Lab\release-042'
if(Test-Path "$r\source"){throw '0.43 source stage already exists; inspect rather than overwrite'}
New-Item -ItemType Directory -Force "$r\payload","$r\HIP"|Out-Null
Expand-Archive "$r\source043.zip" "$r\source"
Expand-Archive "$r\config043.zip" "$r\scripts"
Copy-Item "$final\dlss5-amd.addon64","$final\LmxxfNrRuntime.dll" "$r\payload"
Copy-Item "$old\payload\runtime-smoke.exe" "$r\payload"
Copy-Item "$final\HIP\*" "$r\HIP" -Recurse -Force
Copy-Item "$final\HIP\SHA256SUMS" "$r\HIP-SHA256SUMS"
foreach($n in 'HOST-LICENSE.txt','CORE-LICENSE.txt','post70-history-head.f16'){Copy-Item "$old\$n" "$r\$n"}
# Source archive and SOURCE-README are uploaded from the current repository, not inherited.
$expected=@{};foreach($line in Get-Content "$r\HIP-SHA256SUMS"){$expected[$line.Substring(66)]=$line.Substring(0,64)}
if($expected.Count -ne 80){throw 'manifest count'}
foreach($rel in $expected.Keys){if((Get-FileHash (Join-Path "$r\HIP" $rel)).Hash -ne $expected[$rel]){throw "reused module mismatch $rel"}}
if((Get-FileHash "$r\payload\dlss5-amd.addon64").Hash -ne '2cefc60d50906d9a5dcf542f1c890819fcaa01b2d712047423d303b8f0475e5b'){throw 'addon identity'}
if((Get-FileHash "$r\payload\LmxxfNrRuntime.dll").Hash -ne 'bc7b77049f828e1500bfe447d9f09c963b38b2c5584c104f65650e5127f8decd'){throw 'runtime identity'}
'REUSED_VERIFIED_PAYLOAD80_STAGE_NO_DEVICE'
