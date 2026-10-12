$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-v-tail-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\pair-manifest.json" -Raw|ConvertFrom-Json
foreach($f in $m.files){$p=Join-Path $r $f.file;if((Get-Item $p).Length -ne $f.bytes -or (Get-FileHash $p).Hash -ne $f.sha256){throw "identity $($f.file)"}}
if((Get-FileHash "$r\canonical.hsaco").Hash -ne 'da1b4ae9af3c1d2889f86e530b915971494ff2a58156a6abab2813dfb2d26014'){throw 'canonical module'}
if(Test-Path "$r\pair-screen"){throw 'existing case no retry'}
New-Item -ItemType Directory "$r\pair-screen"|Out-Null
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$r\pair.exe";$psi.WorkingDirectory=$r
 $psi.Arguments="`"$r\canonical.hsaco`" `"$r\candidate.hsaco`" `"$r\input.bin`" `"$r\weight.bin`" `"$r\gold.bin`" `"$r\pair-screen`""
 $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
 "CASE=pair-screen OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
 try {
  while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 60){throw 'own60s timeout no retry'}}
  $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw "unit failed $($p.ExitCode)"}
 } finally {
  if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
  $o.Result|Set-Content "$r\pair-screen\stdout.log";$e.Result|Set-Content "$r\pair-screen\stderr.log"
 }
 $rows=@(Import-Csv "$r\pair-screen\samples.csv");if($rows.Count -ne 120){throw '120sample rows'}
 $l=Get-Content "$r\pair-screen\stdout.log" -Raw
 if(([regex]::Matches($l,'EDGE slot=')).Count -ne 8 -or $l -match '(byte_diff|nan|guard_diff)=[1-9]'){throw '8edge gold'}
 'VTAIL_BOUNDED_PAIR_SCREEN_COMPLETE_NOT_FRAME_ACCEPTANCE'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
