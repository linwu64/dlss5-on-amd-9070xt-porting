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
 if(!(Idle)){throw 'game busy'};if((Get-PSDrive D).Free -lt 100GB){throw 'disk below100GB'}
 $held=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 $env:DLSS5_HIP_FAST='1';$env:DLSS5_FAST_NUMERIC='1';$env:DLSS5_MULTI_PASS='0.5';$env:DLSS5_MULTI_PASS_PREDICT='1';$env:DLSS5_MULTI_PASS_SKIN_PROTECT='0';$env:DLSS5_VIT_ADAPTIVE='0';$env:DLSS5_HIP_SWIN_RUN='1';$env:DLSS5_HIP_VIT_STREAM='3';$env:DLSS5_HIP_PDL='1';$env:DLSS5_TEMPORAL_MODE='0';$env:DLSS5_SKIP_BLOCKS=''
 RunOwned "$r\deferred-switch.exe" "`"$assets`" `"$modules`" history" "$r\history-row-cache-idle-r3"
 foreach($mode in '0.5','1'){
  $case=if($mode -eq '0.5'){'history-switch-1080-idle-r3'}else{'history-original-1080-idle-r3'};$d="$r\$case";if(Test-Path $d){throw 'case exists'};New-Item -ItemType Directory -Force "$d\DLSS5-AMD\logs"|Out-Null
  $flags=(Get-Content D:\DLSSNR-Lab\combined-vs041-20261006\base.flags -Raw)+"`nDLSS5_NETWORK_HEIGHT=1080`nDLSS5_NETWORK_1080_ROWS=1152`nDLSS5_NETWORK_FREE_RES=0`nDLSS5_MULTI_PASS=$mode`nDLSS5_DIRECT_IO=3`nDLSS5_VIT_ADAPTIVE=0`nDLSS5_TEMPORAL_MODE=1`nDLSS5_MULTI_PASS_PREDICT=1`nDLSS5_HOT_RELOAD=0`nDLSS5_MULTI_PASS_HOTKEY=0`nDLSS5_SKIP_BLOCKS=`nDLSS5_FAST_NUMERIC=1`nDLSS5_HIP_GRAPH=0`nDLSS5_OVERLAP=0`n"
  $flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt";$flags|Set-Content "$r\$case.flags";Copy-Item "$r\frame-history-f9fix.exe" "$d\frame.exe"
  $env:SMALL_FRAME_CAPTURE='1';$env:SMALL_FRAME_DIRECT_TEST='1';Remove-Item Env:SMALL_FRAME_SWITCH -ErrorAction SilentlyContinue
  if($mode -eq '0.5'){$env:SMALL_FRAME_HISTORY_TEST='1'}else{Remove-Item Env:SMALL_FRAME_HISTORY_TEST -ErrorAction SilentlyContinue}
  $frames=if($mode -eq '0.5'){16}else{6}
  RunOwned "$d\frame.exe" "`"$assets`" `"$r\$case.flags`" `"D:\DLSSNR-Lab\small-model-20261018\functional-input.f16`" `"$d\out`" $frames 1 `"$modules`" 0 0 0 0" "$d\execution"
  if(@(Import-Csv "$d\out.csv"|Where-Object {[int]$_.invalid -ne 0}).Count){throw 'history output invalid'}
  Get-ChildItem $d -Filter '*.f16'|Get-FileHash|ConvertTo-Json|Set-Content "$d\hashes.json"
 }
 $d="$r\history-switch-1080-idle-r3";if((Get-FileHash "$d\out-frame-0.f16").Hash -ne (Get-FileHash "$d\out-frame-12.f16").Hash){throw 'Small history reset round-trip'}
 'ALL_SAME_SIZE_HISTORY_ROW_BLEND_PASS'
}finally{if($child -and !$child.HasExited){$child.Kill()};if($held){$held.Dispose();Remove-Item D:\DLSSNR-Lab\gpu.lock};'LOCK_RELEASED'}
