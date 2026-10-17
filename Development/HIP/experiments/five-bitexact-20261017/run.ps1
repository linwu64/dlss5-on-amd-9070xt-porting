param([string]$CaseName,[ValidateSet('gold','abba')][string]$Kind='gold',[int]$Decoder=3,[int]$Gather=0,[int]$Down=0,[int]$Pool32=0,[int]$UpBody=0,[int]$BaseDecoder=0,[int]$BaseGather=0,[int]$BaseDown=0,[int]$BasePool32=0,[int]$BaseUpBody=0,[string]$HostFile='frame.exe')
$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-bitexact-20261017'
$baseR=$r
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$r\HIP\gfx1201\deep_fast-packed-fast.hsaco")){if(!(Test-Path $p)){throw "required asset $p"}}
if(!$CaseName){throw 'unique CaseName required'}
$Frames=if($Kind -eq 'gold'){3}else{240}
if((Get-Item "$base\input.f16").Length -ne 7464960 -or (Get-FileHash "$base\input.f16").Hash -ne 'fa3c18735ac5f105903614a18a9b1475966b9afd9dd4aeb0cd9cad7bc759ec9b'){throw 'HDR actual1296x720x8 SHA'}
if(Test-Path "$r\$CaseName"){throw "case exists: preserve evidence $CaseName"}
$case=New-Item -ItemType Directory "$r\$CaseName"
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
DLSS5_GAME_PROBE=0
DLSS5_HIP_NET_TIMING=0
DLSS5_HIP_NET_SPAN=0
DLSS5_HIP_INPUT_POLL=0
DLSS5_BENCH_PLAIN=1
DLSS5_FRAME_STATS=0
DLSS5_RESIDUAL_SEQUENCE=0
DLSS5_RESIDUAL_RGB=0
DLSS5_SKIP_BLOCKS=
'@
$flags+="`r`n"+$fixed+"`r`n"
$flags|Set-Content "$case\same.flags"
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 Idle
 foreach($slot in 'baseline-A1','candidate-B1','candidate-B2','baseline-A2'){
  $name=if($slot.StartsWith('candidate')){'candidate'}else{'baseline'}
  Idle
  $d=New-Item -ItemType Directory "$case\$slot"
  New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force|Out-Null
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
  Copy-Item "$r\$HostFile" "$d\frame.exe"
  $hipDir="$r\HIP\gfx1201"
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName="$d\frame.exe";$psi.WorkingDirectory=$d.FullName
  $psi.Arguments="`"$base\assets-common`" `"$case\same.flags`" `"$base\input.f16`" `"$d\out`" $Frames 0 `"$hipDir`" 0 1 0 0"
  $psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
  $psi.EnvironmentVariables['NR_C512_W16']='2'
  $psi.EnvironmentVariables['NR_C512_FFN_W16']='1'
  $psi.EnvironmentVariables['NR_C32_W16']='1'
  $psi.EnvironmentVariables['NR_VIT_W16']='7'
  $psi.EnvironmentVariables['NR_VIT_INTER_BYTE']='15'
  $psi.EnvironmentVariables['NR_DEC_F8_W16']=if($name -eq 'candidate'){[string]$Decoder}else{[string]$BaseDecoder}
  $psi.EnvironmentVariables['NR_VIT_WRITE_GATHER']=if($name -eq 'candidate'){[string]$Gather}else{[string]$BaseGather}
  $psi.EnvironmentVariables['NR_DS_F8_W16']=if($name -eq 'candidate'){[string]$Down}else{[string]$BaseDown}
  $psi.EnvironmentVariables['NR_POOL32_W16']=if($name -eq 'candidate'){[string]$Pool32}else{[string]$BasePool32}
  $psi.EnvironmentVariables['NR_UPBODY_F8_W16']=if($name -eq 'candidate'){[string]$UpBody}else{[string]$BaseUpBody}
  $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'}
  Write-Output "CASE=$CaseName SLOT=$slot ROLE=$name OWN_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
  try {
   while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){Idle;$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 90){throw 'own90s timeout no retry'}}
   $p.WaitForExit();Write-Output "ACTUAL_EXIT_CODE=$($p.ExitCode) SLOT=$slot ROLE=$name";if($p.ExitCode){throw "frame failed $name $($p.ExitCode)"}
  } finally {
   if(!$p.HasExited){$p.Kill();$p.WaitForExit()}
   $o.Result|Set-Content "$d\stdout.log";$e.Result|Set-Content "$d\stderr.log"
  }
  $rows=@(Import-Csv "$d\out.csv");$edges=@($rows|Where-Object {$_.checked -eq '1'});if($rows.Count -ne $Frames -or $edges.Count -ne 2 -or @($edges|Where-Object {[int]$_.invalid -ne 0 -or [int]$_.changed_half_values_from_first -ne 0}).Count){throw "actual240frames twofinite repeatededges $slot"}
  $log=Get-Content "$d\stderr.log" -Raw
  if($log -notmatch ("submit_pulse resources[^`r`n]*record_ok=$Frames[^`r`n]*accepted=$Frames")){throw "actualproductionAuto240records required $slot"}
  $summary=([regex]::Match($log,'C512_W16_SUMMARY[^\r\n]*')).Value
  $meas=@($rows | Select-Object -Skip $(if($Kind -eq 'gold'){0}else{80}) | ForEach-Object { [double]$_.wall_ms })
  $sorted=@($meas | Sort-Object)
  $mean=($meas | Measure-Object -Average).Average
  $med=$sorted[[int]($sorted.Count*0.5)]
  $p90=$sorted[[int]([math]::Floor(($sorted.Count-1)*0.90))]
  $p99=$sorted[[int]([math]::Floor(($sorted.Count-1)*0.99))]
  Write-Output ("SLOT={0,-14} mean={1:F4} med={2:F4} p90={3:F4} p99={4:F4} [{5}]" -f $slot,$mean,$med,$p90,$p99,$summary)
 }
 $ref='0900E489A397302B93074A878C694B9C3E7C3400CFE2DFDD3CC727ABE1050F4A'
 foreach($slot in 'baseline-A1','candidate-B1','candidate-B2','baseline-A2'){
  foreach($f in @("$case\$slot\out-first.f16","$case\$slot\out.f16")){if((Get-FileHash $f).Hash -ne $ref){throw "eightfirstlastraw fixedgold failed $f"}}
 }
 Write-Output "ABBA_DONE_$CaseName"
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
