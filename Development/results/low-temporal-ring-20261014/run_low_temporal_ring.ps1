$ErrorActionPreference='Stop'
$lab='D:\DLSSNR-Lab\low-temporal-ring-20261014'
$base='D:\DLSSNR-Lab\combined-vs041-20261006'
$hipDir='D:\DLSSNR-Lab\c512-w16-20261014\HIP\gfx1201'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'

function Idle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/RTC active'}
}

Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below 100GB'}
foreach($p in @("$base\base.flags","$base\input.f16","$base\assets-common\noise.f32","$hipDir\deep_fast-packed-fast.hsaco")){
 if(!(Test-Path $p)){throw "required asset $p"}
}

$baseFlags = Get-Content "$base\base.flags" -Raw

function Build-Flags([int]$mode, [int]$asyncSubmit, [int]$residualSeq) {
 $fixed = @"
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
DLSS5_TEMPORAL_MODE=$mode
DLSS5_FAST_HISTORY=0
DLSS5_TEMPORAL_HISTORY_EXPERIMENT=0
DLSS5_TEST_SUBMISSION_TIMING=0
DLSS5_TEST_ASYNC_SUBMIT=$asyncSubmit
DLSS5_HIP_MEMORY=1
DLSS5_GAME_PROBE=0
DLSS5_NET_TIMING=0
DLSS5_HIP_SPAN_PROBE=0
DLSS5_HIP_INPUT_POLL=0
DLSS5_BENCH_PLAIN=0
DLSS5_FRAME_STATS=0
DLSS5_RESIDUAL_SEQUENCE=$residualSeq
DLSS5_RESIDUAL_RGB=0
DLSS5_SKIP_BLOCKS=
"@
 return $baseFlags + "`r`n" + $fixed + "`r`n"
}

function Run-Frame([string]$runDir, [string]$flagsContent, [int]$frames, [int]$edgesOnly, [int]$ringVal) {
 Idle
 if(Test-Path $runDir){Remove-Item $runDir -Recurse -Force}
 $d = New-Item -ItemType Directory $runDir -Force
 New-Item -ItemType Directory "$d\DLSS5-AMD\logs" -Force | Out-Null
 $flagsContent | Set-Content "$d\DLSS5-AMD\native-game-flags.txt"
 $flagsContent | Set-Content "$d\same.flags"
 Copy-Item "$lab\frame.exe" "$d\frame.exe"

 $psi = [Diagnostics.ProcessStartInfo]::new()
 $psi.FileName = "$d\frame.exe"
 $psi.WorkingDirectory = $d.FullName
 $psi.Arguments = "`"$base\assets-common`" `"$d\same.flags`" `"$base\input.f16`" `"$d\out`" $frames 1 `"$hipDir`" 0 $edgesOnly 0 0"
 $psi.UseShellExecute = $false
 $psi.RedirectStandardOutput = $true
 $psi.RedirectStandardError = $true
 foreach($key in @($psi.EnvironmentVariables.Keys)){
  if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){
   $psi.EnvironmentVariables.Remove($key)
  }
 }
 $psi.EnvironmentVariables['NR_LOW_TEMPORAL_RING'] = "$ringVal"
  if($edgesOnly -eq 0){$psi.EnvironmentVariables['NR_LOW_TEMPORAL_FIXED_DT'] = '0.016'}

 $p = [Diagnostics.Process]::new()
 $p.StartInfo = $psi
 if(!$p.Start()){throw "start failed $runDir"}
 $o = $p.StandardOutput.ReadToEndAsync()
 $e = $p.StandardError.ReadToEndAsync()
 $start = [DateTime]::UtcNow
 $next = $start.AddSeconds(15)
 try {
  while(!$p.HasExited){
   Start-Sleep -Milliseconds 100
   if([DateTime]::UtcNow -ge $next){Idle; $next = [DateTime]::UtcNow.AddSeconds(15)}
   if(([DateTime]::UtcNow - $start).TotalSeconds -gt 120){throw "timeout $runDir"}
  }
  $p.WaitForExit()
  if($p.ExitCode){throw "frame failed $runDir exit=$($p.ExitCode)"}
 } finally {
  if(!$p.HasExited){$p.Kill(); $p.WaitForExit()}
  $o.Result | Set-Content "$d\stdout.log"
  $e.Result | Set-Content "$d\stderr.log"
 }
 Remove-Item "$d\frame.exe" -Force -ErrorAction SilentlyContinue
}

$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 Write-Output "=== 1. Unit tests ==="
 Idle
 & "$lab\test_low_frequency.exe" 1 | Tee-Object -FilePath "$lab\unit_test_low_frequency.log"
 if($LASTEXITCODE -ne 0){throw "test_low_frequency failed"}
 Idle
 & "$lab\test_temporal_enhancement.exe" 1 | Tee-Object -FilePath "$lab\unit_test_temporal_enhancement.log"
 if($LASTEXITCODE -ne 0){throw "test_temporal_enhancement failed"}

 Write-Output "=== 2. Gold bit-exact verification (MODE 2 & MODE 3, sync & async submit, 12 frames, residualSeq=2) ==="
 $goldSummary = [ordered]@{}
 foreach($asyncSubmit in @(0, 1)){
  $subTag = if($asyncSubmit -eq 1){"async"}else{"sync"}
  foreach($mode in @(2, 3)){
   $flagsContent = Build-Flags -mode $mode -asyncSubmit $asyncSubmit -residualSeq 2
   foreach($ring in @(0, 1)){
    $dir = "$lab\gold-$subTag-mode$mode-ring$ring"
    Run-Frame -runDir $dir -flagsContent $flagsContent -frames 12 -edgesOnly 0 -ringVal $ring
   }
   $d0 = "$lab\gold-$subTag-mode$mode-ring0"
   $d1 = "$lab\gold-$subTag-mode$mode-ring1"
   $h0_first = (Get-FileHash "$d0\out-first.f16").Hash
   $h1_first = (Get-FileHash "$d1\out-first.f16").Hash
   $h0_last  = (Get-FileHash "$d0\out.f16").Hash
   $h1_last  = (Get-FileHash "$d1\out.f16").Hash
   $matchFirst = ($h0_first -eq $h1_first)
   $matchLast  = ($h0_last -eq $h1_last)
   Write-Output "GOLD sub=$subTag mode=$mode first_match=$matchFirst last_match=$matchLast first_sha=$h1_first last_sha=$h1_last"
   if(!$matchFirst -or !$matchLast){
    throw "Gold SHA mismatch for sub=$subTag mode=$mode!"
   }
   $goldSummary["$subTag-mode$mode"] = [ordered]@{
    ring0_first_sha256 = $h0_first
    ring1_first_sha256 = $h1_first
    ring0_last_sha256  = $h0_last
    ring1_last_sha256  = $h1_last
    bit_exact          = $true
   }
   Remove-Item "$d0\*.f16","$d0\*.ppm","$d1\*.f16","$d1\*.ppm" -Force -ErrorAction SilentlyContinue
  }
 }
 $goldSummary | ConvertTo-Json -Depth 4 | Set-Content "$lab\gold-summary.json" -Encoding UTF8

 Write-Output "=== 3. ABBA Timing (MODE 3, sync & async submit, 24 frames, edges_only=1, 3 rounds) ==="
 foreach($asyncSubmit in @(0, 1)){
  $subTag = if($asyncSubmit -eq 1){"async"}else{"sync"}
  $flagsContent = Build-Flags -mode 3 -asyncSubmit $asyncSubmit -residualSeq 2
  for($r = 1; $r -le 3; $r++){
   $slots = @(
    @{ name = "A1-ring0"; ring = 0 },
    @{ name = "B1-ring1"; ring = 1 },
    @{ name = "B2-ring1"; ring = 1 },
    @{ name = "A2-ring0"; ring = 0 }
   )
   foreach($s in $slots){
    $dir = "$lab\abba-$subTag-r$r\$($s.name)"
    Run-Frame -runDir $dir -flagsContent $flagsContent -frames 24 -edgesOnly 1 -ringVal $s.ring
    Remove-Item "$dir\*.f16","$dir\*.ppm" -Force -ErrorAction SilentlyContinue
    $rows = @(Import-Csv "$dir\out.csv") | Select-Object -Skip 4
    $vals = @($rows | ForEach-Object { [double]$_.wall_ms } | Sort-Object)
    $med = if($vals.Count % 2 -eq 1){ $vals[[int]($vals.Count/2)] } else { ($vals[$vals.Count/2 - 1] + $vals[$vals.Count/2]) / 2.0 }
    Write-Output ("ABBA sub={0} r={1} slot={2} steady_median_ms={3:F3}" -f $subTag, $r, $s.name, $med)
   }
  }
 }

 Write-Output "LOW_TEMPORAL_RING_ALL_PASS"
} finally {
 $owner.Dispose()
 Remove-Item 'D:\DLSSNR-Lab\gpu.lock' -Force -ErrorAction SilentlyContinue
 Write-Output "LOCK_RELEASED"
}
