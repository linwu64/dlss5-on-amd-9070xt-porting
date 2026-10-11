$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-tile-ready-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle{
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\run-manifest.json" -Raw|ConvertFrom-Json
foreach($f in $m.files){$p=Join-Path $r $f.file;if((Get-Item $p).Length -ne $f.bytes -or (Get-FileHash $p).Hash -ne $f.sha256){throw "identity $($f.file)"}}
if((Get-FileHash "$r\canonical.hsaco").Hash -ne $m.canonical_expected){throw 'canonical module'}
if(Test-Path "$r\pair-gate"){throw 'existing result no retry'}
New-Item -ItemType Directory "$r\pair-gate"|Out-Null
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$r\pair.exe";$psi.WorkingDirectory=$r
 $psi.Arguments="`"$r\canonical.hsaco`" `"$r\candidate.hsaco`" `"$r\input.bin`" `"$r\contract-w.bin`" `"$r\skip.bin`" `"$r\qkv-w.bin`" `"$r\pair-gate`" 640"
 $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
 "CASE=pair-gate OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
 try{
  while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 60){throw 'own60s timeout no retry'}}
  $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw "pair failed $($p.ExitCode)"}
 }finally{
  if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
  $o.Result|Set-Content "$r\pair-gate\stdout.log";$e.Result|Set-Content "$r\pair-gate\stderr.log"
 }
 $expected=(Get-FileHash "$r\contract-gold.bin").Hash
 foreach($name in 'original1','original2','ready-ordered','ready-anyorder','ready-anyorder2'){if((Get-FileHash "$r\pair-gate\$name.contract.bin").Hash -ne $expected){throw "captured contract gold $name"}}
 Get-ChildItem "$r\pair-gate" -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$r\pair-gate\result-files.json"
 'PAIR_ALL_RAW_GATES_PASS_NOT_FULL_NETWORK_NOT_PERFORMANCE'
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
