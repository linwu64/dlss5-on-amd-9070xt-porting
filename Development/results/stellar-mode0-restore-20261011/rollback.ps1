$ErrorActionPreference='Stop'
& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha Magpie'
if($LASTEXITCODE -ne 1){throw 'exit game before rollback'}
$rows=Get-Content 'D:\DLSSNR-Lab\stellar-mode0-restore-20261011\backups\20261011-144303\manifest.json' -Raw|ConvertFrom-Json
$lease=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{foreach($r in $rows){Copy-Item $r.backup $r.path -Force;if((Get-FileHash $r.path).Hash.ToLower() -ne $r.sha256){throw 'rollback SHA'}}}finally{$lease.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock'}
