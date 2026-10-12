$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-contract-compact-frame-20261012'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$m=Get-Content "$r\frame-timing-manifest.json" -Raw|ConvertFrom-Json
foreach($f in $m.files){$p=Join-Path $r $f.file;if((Get-Item $p).Length -ne $f.bytes -or (Get-FileHash $p).Hash -ne $f.sha256){throw "identity $($f.file)"}}
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$r\modules\deep_fast-packed-fast.hsaco")){if(!(Test-Path $p)){throw "required asset $p"}}
if((Get-Item "$base\input.f16").Length -ne 7464960 -or (Get-FileHash "$base\input.f16").Hash -ne 'fa3c18735ac5f105903614a18a9b1475966b9afd9dd4aeb0cd9cad7bc759ec9b'){throw 'HDR actual1296x720x8 SHA'}
if((Get-FileHash "$r\modules\deep_fast-packed-fast.hsaco").Hash -ne '11a25ae3fea75f83763ab6d5729c4f426dabda11299d1be6092d142b810e27b8'){throw 'canonical expand module'}
$gold=Get-Content "$r\frame-gold\modules-after.json" -Raw|ConvertFrom-Json
if($gold.Count -ne 44){throw 'gold44module receipt'}
foreach($x in $gold){$p=Join-Path "$r\modules" $x.file;if((Get-Item $p).Length -ne $x.bytes -or (Get-FileHash $p).Hash -ne $x.sha256){throw 'gold module identity mismatch'}}
foreach($role in 'baseline','candidate'){foreach($file in 'out-first.f16','out.f16'){if((Get-FileHash "$r\frame-gold\$role\$file").Hash -ne '0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a'){throw 'gold admission'}}}
if(Test-Path "$r\frame-abba"){throw 'existing case no retry'}
$case=New-Item -ItemType Directory "$r\frame-abba"
$flags=Get-Content "$base\base.flags" -Raw
$fixed=@'
DLSS5_NETWORK_HEIGHT=1080
DLSS5_NETWORK_1080_ROWS=1152
DLSS5_NETWORK_FREE_RES=0
DLSS5_STYLE=1
DLSS5_HIP_PDL=1
DLSS5_HIP_SUBMIT_PULSE=auto
DLSS5_HIP_GRAPH=0
DLSS5_FAST_NUMERIC=1
DLSS5_VIT_ADAPTIVE=0
DLSS5_MULTI_PASS=1
DLSS5_MULTI_PASS_PREDICT=0
DLSS5_MULTI_PASS_SKIN_PROTECT=0
DLSS5_MULTI_PASS_HOTKEY=none
DLSS5_HOT_RELOAD=0
DLSS5_TEMPORAL_MODE=0
DLSS5_FAST_HISTORY=0
DLSS5_TEMPORAL_HISTORY_EXPERIMENT=0
DLSS5_TEST_SUBMISSION_TIMING=0
DLSS5_HIP_MEMORY=0
DLSS5_BENCH_PLAIN=1
DLSS5_FRAME_STATS=0
DLSS5_RESIDUAL_SEQUENCE=0
DLSS5_RESIDUAL_RGB=0
DLSS5_SKIP_BLOCKS=
'@
$flags+="`r`n"+$fixed+"`r`n"
$flags|Set-Content "$case\same.flags"
Get-ChildItem "$r\modules" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-preflight.json"
Get-FileHash "$base\input.f16","$base\base.flags","$case\same.flags","$base\assets-common\noise.f32"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$case\source-preflight.json"
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 foreach($slot in 'baseline-A1','candidate-B1','candidate-B2','baseline-A2'){
  $name=if($slot.StartsWith('candidate')){'candidate'}else{'baseline'}
  Idle
  $d=New-Item -ItemType Directory "$case\$slot"
  New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force|Out-Null
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
  Copy-Item "$r\frame.exe" "$d\frame.exe"
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$d\frame.exe";$psi.WorkingDirectory=$d.FullName
  $psi.Arguments="`"$base\assets-common`" `"$case\same.flags`" `"$base\input.f16`" `"$d\out`" 320 0 `"$r\modules`" 0 1 0 0"
  $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
  $psi.EnvironmentVariables['NR_VIT_CONTRACT_COMPACT']=if($name -eq 'candidate'){'1'}else{'0'}
  $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
  "CASE=frame-abba SLOT=$slot ROLE=$name OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
  try {
   while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 90){throw 'own90s timeout no retry'}}
   $p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode) SLOT=$slot ROLE=$name";if($p.ExitCode){throw "frame failed $name $($p.ExitCode)"}
  } finally {
   if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
   $o.Result|Set-Content "$d\stdout.log";$e.Result|Set-Content "$d\stderr.log"
  }
  $rows=@(Import-Csv "$d\out.csv");$edges=@($rows|Where-Object {$_.checked -eq '1'});if($rows.Count -ne 320 -or $edges.Count -ne 2 -or @($edges|Where-Object {[int]$_.invalid -ne 0 -or [int]$_.changed_half_values_from_first -ne 0}).Count){throw 'actual320frames twofinite repeatededges'}
  $log=Get-Content "$d\stderr.log" -Raw
  if($log -notmatch 'submit_pulse resources[^\r\n]*record_ok=320[^\r\n]*accepted=320'){throw 'actualproductionAuto320records required'}
  if($name -eq 'candidate'){if($log -notmatch 'CONTRACT_COMPACT_COLD requested=1 ready=1' -or ([regex]::Matches($log,'CONTRACT_COMPACT key=')).Count -ne 8){throw 'actual8compactkeys ready'}}else{if($log -notmatch 'CONTRACT_COMPACT_COLD requested=0 ready=0' -or $log -match 'CONTRACT_COMPACT key='){throw 'baselineNoCompact'}}
  Get-FileHash "$d\out-first.f16","$d\out.f16"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$d\raw-sha.json"
 }
 $ref='0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A'
 foreach($slot in 'baseline-A1','candidate-B1','candidate-B2','baseline-A2'){
  foreach($f in @("$case\$slot\out-first.f16","$case\$slot\out.f16")){if((Get-FileHash $f).Hash -ne $ref){throw 'eightfirstlastraw fixedgold failed'}}

 }
 Get-ChildItem "$r\modules" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-after.json"
 $before=Get-Content "$case\modules-preflight.json" -Raw|ConvertFrom-Json;$after=Get-Content "$case\modules-after.json" -Raw|ConvertFrom-Json
 if($before.Count -ne $after.Count){throw 'module count changed'}
 foreach($x in $before){$y=@($after|Where-Object {$_.file -eq $x.file});if($y.Count -ne 1 -or $y[0].sha256 -ne $x.sha256){throw 'module source changed'}}
 'FRAME_ABBA_COMPLETED_ALL8RAW_GOLD_NOT_GAME_FPS_NO_FORMAL_ACCEPTANCE'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
