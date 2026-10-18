param([string]$ReceiptSuffix='')
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$r='D:\DLSSNR-Lab\f9-hotfix-20261018';$assets='D:\DLSSNR-Lab\small-model-20261018\assets';$modules='D:\DLSSNR-Lab\five-final-20261017\HIP\gfx1201';$held=$null;$child=$null
function Idle {& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie' | Out-Host;return ($LASTEXITCODE -eq 1)}
function RunOwned($exe,$arguments,$dir){
 if(!(Idle)){throw 'game started'};if(Test-Path $dir){throw "preserve case $dir"};New-Item -ItemType Directory -Force $dir|Out-Null
 $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=$exe;$si.Arguments=$arguments;$si.WorkingDirectory=$dir;$si.UseShellExecute=$false;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
 $script:child=[Diagnostics.Process]::new();$child.StartInfo=$si;if(!$child.Start()){throw 'start failed'};$o=$child.StandardOutput.ReadToEndAsync();$e=$child.StandardError.ReadToEndAsync();$start=Get-Date;$next=(Get-Date).AddSeconds(15)
 try{while(!$child.HasExited){Start-Sleep -Milliseconds 100;if((Get-Date) -ge $next){if(!(Idle)){throw '15s watcher game started'};$next=(Get-Date).AddSeconds(15)};if(((Get-Date)-$start).TotalSeconds -gt 180){throw 'owned180s timeout'}};$child.WaitForExit();$code=$child.ExitCode;"exit=$code"|Set-Content "$dir\exit.txt";if($code){throw "owned test failed $code"}}
 finally{if(!$child.HasExited){$child.Kill();$child.WaitForExit()};$o.Result|Set-Content "$dir\stdout.log";$e.Result|Set-Content "$dir\stderr.log";$script:child=$null}
 Write-Output "PASS $dir"
}
try{
 $start=Get-Date;while(!(Idle)){Write-Output 'WAIT_GAME_EXIT (no GPU lock held)';Start-Sleep -Seconds 15;if(((Get-Date)-$start).TotalMinutes -gt 30){throw 'game did not exit; no GPU work run'}}
 if((Get-PSDrive D).Free -lt 100GB){throw 'disk below100GB'}
 $held=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 $env:DLSS5_HIP_FAST='1';$env:DLSS5_FAST_NUMERIC='1';$env:DLSS5_MULTI_PASS='0.5';$env:DLSS5_MULTI_PASS_PREDICT='1';$env:DLSS5_MULTI_PASS_SKIN_PROTECT='0';$env:DLSS5_VIT_ADAPTIVE='0';$env:DLSS5_HIP_SWIN_RUN='1';$env:DLSS5_HIP_VIT_STREAM='3';$env:DLSS5_HIP_PDL='1';$env:DLSS5_TEMPORAL_MODE='0';$env:DLSS5_SKIP_BLOCKS=''
 RunOwned "$r\deferred-switch.exe" "`"$assets`" `"$modules`"" "$r\deferred-warm$ReceiptSuffix"
 RunOwned "$r\deferred-switch.exe" "`"$assets`" `"$modules`" cold" "$r\deferred-cold$ReceiptSuffix"
 $env:DLSS5_VIT_ADAPTIVE='1';RunOwned "$r\deferred-switch.exe" "`"$assets`" `"$modules`"" "$r\deferred-ae$ReceiptSuffix"
 foreach($height in 1080,900){
  $name="direct-switch-$height$ReceiptSuffix";$d="$r\$name";if(Test-Path $d){throw 'case exists'};New-Item -ItemType Directory -Force "$d\DLSS5-AMD\logs"|Out-Null
  $flags=(Get-Content D:\DLSSNR-Lab\combined-vs041-20261006\base.flags -Raw)+"`nDLSS5_NETWORK_HEIGHT=$height`nDLSS5_NETWORK_1080_ROWS=1152`nDLSS5_NETWORK_FREE_RES=0`nDLSS5_MULTI_PASS=0.5`nDLSS5_DIRECT_IO=3`nDLSS5_VIT_ADAPTIVE=1`nDLSS5_HIP_SWIN_RUN=1`nDLSS5_HIP_VIT_STREAM=3`nDLSS5_MULTI_PASS_PREDICT=1`nDLSS5_MULTI_PASS_SKIN_PROTECT=0`nDLSS5_TEMPORAL_MODE=0`nDLSS5_HOT_RELOAD=0`nDLSS5_MULTI_PASS_HOTKEY=0`nDLSS5_OVERLAP=0`nDLSS5_SKIP_BLOCKS=`nDLSS5_FAST_NUMERIC=1`nDLSS5_HIP_GRAPH=0`n"
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt";$flags|Set-Content "$r\$name.flags";Copy-Item "$r\frame-f9fix.exe" "$d\frame.exe"
  # RunOwned owns the result subdirectory; config root remains beside the executable.
  $env:SMALL_FRAME_SWITCH='1';$env:SMALL_FRAME_CAPTURE='1';$env:SMALL_FRAME_DIRECT_TEST='1'
  RunOwned "$d\frame.exe" "`"$assets`" `"$r\$name.flags`" `"D:\DLSSNR-Lab\combined-vs041-20261006\input.f16`" `"$d\out`" 12 0 `"$modules`" 0 0 0 0" "$d\execution"
  $rows=@(Import-Csv "$d\out.csv");if($rows.Count -ne 12 -or @($rows|Where-Object {[int]$_.invalid -ne 0}).Count){throw 'direct output finite/frames'}
  if((Get-FileHash "$d\out-frame-0.f16").Hash -ne (Get-FileHash "$d\out-frame-8.f16").Hash){throw 'Small AE direct output round-trip differs'}
  Get-ChildItem $d -Filter '*.f16'|Get-FileHash|ConvertTo-Json|Set-Content "$d\hashes.json"
 }
 'ALL_F9_GPU_GATES_PASS'
}finally{if($child -and !$child.HasExited){$child.Kill()};if($held){$held.Dispose();Remove-Item D:\DLSSNR-Lab\gpu.lock};'LOCK_RELEASED'}
