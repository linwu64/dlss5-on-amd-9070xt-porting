$ErrorActionPreference='Stop'
$processes=@(Get-Process|Where-Object {$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen|rtc_compile'}|Select-Object Id,ProcessName)
[pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');processes=$processes;disk_free_bytes=[IO.DriveInfo]::new('D:\').AvailableFreeSpace;gpu_lock_exists=(Test-Path 'D:\DLSSNR-Lab\gpu.lock')}|ConvertTo-Json -Depth 4
