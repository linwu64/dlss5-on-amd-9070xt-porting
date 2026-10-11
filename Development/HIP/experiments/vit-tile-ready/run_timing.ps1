param([ValidateSet('pair-abba','pair-abba-fair')][string]$Case='pair-abba',[ValidateSet('pair.exe','pair-fair.exe')][string]$Exe='pair.exe',[ValidateSet('run-manifest.json','fair-manifest.json')][string]$Manifest='run-manifest.json')
$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-tile-ready-timing-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle{& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game busy/check failed'};if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}}
Idle;if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\$Manifest" -Raw|ConvertFrom-Json
foreach($f in $m.files){$file=Join-Path $r $f.file;if((Get-Item $file).Length -ne $f.bytes -or (Get-FileHash $file).Hash -ne $f.sha256){throw "identity $($f.file)"}}
if((Get-FileHash "$r\canonical.hsaco").Hash -ne $m.canonical_expected){throw 'canonical module'}
if(Test-Path "$r\$Case"){throw 'existing case no retry'};New-Item -ItemType Directory "$r\$Case"|Out-Null
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$r\$Exe";$psi.WorkingDirectory=$r;$psi.Arguments="`"$r\canonical.hsaco`" `"$r\candidate.hsaco`" `"$r\input.bin`" `"$r\contract-w.bin`" `"$r\skip.bin`" `"$r\qkv-w.bin`" `"$r\$Case`" 640";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'};"CASE=$Case OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
 try{while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 60){throw 'own60s timeout no retry'}};$p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw "pair timing failed $($p.ExitCode)"}}
 finally{if(!$p.HasExited){$p.Kill();$p.WaitForExit()};$o.Result|Set-Content "$r\$Case\stdout.log";$e.Result|Set-Content "$r\$Case\stderr.log"}
 $rows=@(Import-Csv "$r\$Case\samples.csv");if($rows.Count -ne 120){throw 'sample row count'}
 foreach($slot in 0..3){$s=@($rows|Where-Object{[int]$_.slot -eq $slot});if($s.Count -ne 30 -or @($s|Where-Object{$_.warm -eq '0'}).Count -ne 20){throw 'per-slot count'};foreach($row in $s){if([double]$row.gpu_ms -le 0 -or [double]$row.wall_ms -le 0){throw 'invalid time'}}}
 'PAIR_ABBA_COMPLETE_NOT_FULL_FRAME_PERFORMANCE'
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
