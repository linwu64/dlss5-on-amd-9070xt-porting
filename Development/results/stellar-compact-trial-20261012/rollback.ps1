$ErrorActionPreference='Stop'
& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha Magpie'
if($LASTEXITCODE -ne 1){throw 'exit game first'}
$lease=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{Copy-Item 'D:\DLSSNR-Lab\stellar-compact-trial-20261012\backup\dlss5-amd.addon64' 'C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64\dlss5-amd.addon64' -Force}finally{$lease.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock'}
