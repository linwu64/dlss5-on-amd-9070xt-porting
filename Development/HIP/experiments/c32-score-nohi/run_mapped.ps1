$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\c32-score-nohi-mapped-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game check busy or unknown'}
 if(Get-Process | Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk <100GB'}
$m=Get-Content "$r\run-manifest.json" -Raw | ConvertFrom-Json
foreach($x in $m.files){$p=Join-Path $r $x.file;if((Get-Item $p).Length -ne $x.bytes -or (Get-FileHash $p).Hash -ne $x.sha256){throw "identity $($x.file)"}}
if(Test-Path "$r\run"){throw 'existing case; no automatic retry'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 Idle
 New-Item -ItemType Directory "$r\run" | Out-Null
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$r\mapped-unit.exe";$psi.WorkingDirectory=$r
 $psi.Arguments="`"$r\stock.hsaco`" `"$r\candidate.hsaco`" `"$r\input.fp8`" `"$r\ffn.bin`" `"$r\attention.bin`" `"$r\gold.fp8`" `"$r\run`"";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
 "CASE=mapped_gold OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
 try {
  while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 60){throw 'own60s timeout; no retry'}}
  $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)"
  if($p.ExitCode){throw "mapped unit fail $($p.ExitCode); no upper-clamp candidate admission"}
 } finally {
  if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
  $o.Result|Set-Content "$r\run\stdout.log";$e.Result|Set-Content "$r\run\stderr.log"
 }
 foreach($name in 'stock0','stock1','clone0','clone1'){if((Get-Item "$r\run\$name.fp8").Length -ne 17694720 -or (Get-FileHash "$r\run\$name.fp8").Hash -ne (Get-FileHash "$r\gold.fp8").Hash){throw "output logical span/gold $name"}}
 Get-ChildItem "$r\run" -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$r\run\result-files.json"
 'MAPPED_REAL_GOLD_PASS_NOT_FULL_NETWORK_NOT_PERFORMANCE'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
