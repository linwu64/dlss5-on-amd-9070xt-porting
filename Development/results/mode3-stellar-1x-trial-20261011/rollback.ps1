$ErrorActionPreference='Stop'
& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha Magpie'
if($LASTEXITCODE -ne 1){throw 'game busy'}
$rows=Get-Content 'D:\DLSSNR-Lab\mode3-stellar-1x-trial-20261011\backups\20261011-114301\manifest.json' -Raw|ConvertFrom-Json
$lease=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{foreach($r in $rows){if($r.present){Copy-Item $r.backup $r.path -Force;if((Get-FileHash $r.path).Hash -ne $r.sha){throw 'restore hash'}}elseif(Test-Path $r.path){Remove-Item $r.path}}}finally{$lease.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock'}
