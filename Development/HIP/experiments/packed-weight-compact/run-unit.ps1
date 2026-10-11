$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\packed-weight-compact-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\unit-manifest.json" -Raw|ConvertFrom-Json
foreach($f in $m.files){$p=Join-Path $r $f.file;if((Get-Item $p).Length -ne $f.bytes -or (Get-FileHash $p).Hash -ne $f.sha256){throw "identity $($f.file)"}}
if((Get-FileHash "$r\canonical.hsaco").Hash -ne '11a25ae3fea75f83763ab6d5729c4f426dabda11299d1be6092d142b810e27b8'){throw 'canonical module'}
if(Test-Path "$r\unit-gold"){throw 'existing case no retry'}
New-Item -ItemType Directory "$r\unit-gold"|Out-Null
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$r\unit.exe";$psi.WorkingDirectory=$r
 $psi.Arguments="`"$r\canonical.hsaco`" `"$r\input.bin`" `"$r\weight.bin`" `"$r\gold.bin`" `"$r\unit-gold`""
 $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
 "CASE=unit-gold OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
 try {
  while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 60){throw 'own60s timeout no retry'}}
  $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw "unit failed $($p.ExitCode)"}
 } finally {
  if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
  $o.Result|Set-Content "$r\unit-gold\stdout.log";$e.Result|Set-Content "$r\unit-gold\stderr.log"
 }
 $expected=(Get-FileHash "$r\gold.bin").Hash
 foreach($name in 'original-0','original-1','compact-0','compact-1'){if((Get-FileHash "$r\unit-gold\$name.bin").Hash -ne $expected){throw "captured gold $name"}}
 Get-ChildItem "$r\unit-gold" -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$r\unit-gold\result-files.json"
 'COMPACT_UNIT_ALL_RAW_GATES_PASS_NOT_FULL_NETWORK_NOT_PERFORMANCE'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
