$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\isa-epilogue-clean-20261014'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$r\HIP-base\gfx1201\deep_fast-packed-fast.hsaco","$r\HIP-cand\gfx1201\deep_fast-packed-fast.hsaco")){if(!(Test-Path $p)){throw "required asset $p"}}
if((Get-Item "$base\input.f16").Length -ne 7464960 -or (Get-FileHash "$base\input.f16").Hash -ne 'fa3c18735ac5f105903614a18a9b1475966b9afd9dd4aeb0cd9cad7bc759ec9b'){throw 'HDR actual1296x720x8 SHA'}
if(Test-Path "$r\frame-gold"){Remove-Item "$r\frame-gold" -Recurse -Force}
$case=New-Item -ItemType Directory "$r\frame-gold"
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
DLSS5_HIP_MEMORY=1
DLSS5_GAME_PROBE=0
DLSS5_NET_TIMING=0
DLSS5_HIP_SPAN_PROBE=0
DLSS5_HIP_INPUT_POLL=0
DLSS5_BENCH_PLAIN=1
DLSS5_FRAME_STATS=0
DLSS5_RESIDUAL_SEQUENCE=0
DLSS5_RESIDUAL_RGB=0
DLSS5_SKIP_BLOCKS=
'@
$flags+="`r`n"+$fixed+"`r`n"
$flags|Set-Content "$case\same.flags"
Get-ChildItem "$r\HIP-base\gfx1201" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-base-preflight.json"
Get-ChildItem "$r\HIP-cand\gfx1201" -Filter '*.hsaco' -File|ForEach-Object{[pscustomobject]@{file=$_.Name;bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$case\modules-cand-preflight.json"
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 foreach($role in 'baseline','candidate'){
  Idle
  $d=New-Item -ItemType Directory "$case\$role"
  New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force|Out-Null
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
  Copy-Item "$r\frame.exe" "$d\frame.exe"
  $modDir=if($role -eq 'baseline'){"$r\HIP-base\gfx1201"}else{"$r\HIP-cand\gfx1201"}
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$d\frame.exe";$psi.WorkingDirectory=$d.FullName
  $psi.Arguments="`"$base\assets-common`" `"$case\same.flags`" `"$base\input.f16`" `"$d\out`" 3 0 `"$modDir`" 0 0 0 0"
  $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
  $psi.EnvironmentVariables['NR_C512_W16']='2'
  $psi.EnvironmentVariables['NR_C512_FFN_W16']='1'
  $psi.EnvironmentVariables['NR_C32_W16']='1'
  $psi.EnvironmentVariables['NR_VIT_W16']='7'
  $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
  Write-Output "CASE=frame-gold ROLE=$role OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
  try {
   while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 90){throw 'own90s timeout no retry'}}
   $p.WaitForExit();Write-Output "ACTUAL_EXIT_CODE=$($p.ExitCode) ROLE=$role";if($p.ExitCode){throw "frame failed $role $($p.ExitCode)"}
  } finally {
   if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
   $o.Result|Set-Content "$d\stdout.log";$e.Result|Set-Content "$d\stderr.log"
  }
  $rows=@(Import-Csv "$d\out.csv");if($rows.Count -ne 3 -or @($rows|Where-Object {[int]$_.invalid -ne 0 -or [int]$_.changed_half_values_from_first -ne 0}).Count){throw "three actualfinite repeat frames $role"}
  $log=Get-Content "$d\stderr.log" -Raw
  if($log -notmatch 'submit_pulse resources[^\r\n]*record_ok=3[^\r\n]*accepted=3 reject_mask=0 lifetime_pdl_calls=0'){throw "actualproductionAuto three records required $role"}
  $firstSha=(Get-FileHash "$d\out-first.f16").Hash
  $lastSha=(Get-FileHash "$d\out.f16").Hash
  $summary=([regex]::Match($log,'C512_W16_SUMMARY[^\r\n]*')).Value
  Write-Output "ROLE=$role FIRST_SHA=$firstSha LAST_SHA=$lastSha SUMMARY=[$summary]"
 }
 $ref='0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A'
 foreach($role in 'baseline','candidate'){
  foreach($f in @("$case\$role\out-first.f16","$case\$role\out.f16")){
   if((Get-FileHash $f).Hash -ne $ref){throw "SHA mismatch in $f"}
  }
 }
 Write-Output 'ISA_EPILOGUE_CLEAN_FRAME_GOLD_PASS_ALL_ROLES_BIT_EXACT'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
