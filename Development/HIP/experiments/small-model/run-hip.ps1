param([string]$Case='probe-exact',[string]$Fast='0',[int]$Frames=12,[string]$InputName='input1152.f32',[switch]$Switch,[switch]$ExpectFallback,[int]$Predict=0,[string]$Size='',[string[]]$Modes=@('1','0.5'))
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$r='D:\DLSSNR-Lab\small-model-20261018';$lock='D:\DLSSNR-Lab\gpu.lock';$held=$null;$child=$null;$savedManifest=$false
function Idle {
 & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 StellarBlade Onimusha re9.exe SandFall LOP-Win64'
 if($LASTEXITCODE -ne 1){throw 'game running or check failed'}
 if(Get-Process -ErrorAction SilentlyContinue|Where-Object {$_.ProcessName -match '^network-probe$|^frame$|^bench(mark)?$|^clock_observe_telemetry$'}){throw 'GPU experiment process already running'}
 if((Get-PSDrive D).Free -lt 100GB){throw 'disk below 100GB'}
}
try {
 Idle;$held=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 $b=[Text.Encoding]::UTF8.GetBytes("small-hip pid=$PID case=$Case UTC=$([DateTime]::UtcNow.ToString('o'))");$held.Write($b,0,$b.Length);$held.Flush()
 if($ExpectFallback){Move-Item "$r\assets\small\model-manifest.json" "$r\assets\small\model-manifest.saved";$savedManifest=$true}
 foreach($mode in $Modes){
  Idle;$out="$r\$Case\$mode";if(Test-Path $out){throw 'preserve existing case'};New-Item -ItemType Directory -Force $out|Out-Null
  $env:SMALL_PROBE_SIZE=$Size;$env:DLSS5_HIP_SWIN_RUN='1';$env:DLSS5_HIP_VIT_STREAM='3';$env:DLSS5_MULTI_PASS=$mode;$env:DLSS5_FAST_NUMERIC=$Fast;$env:DLSS5_MULTI_PASS_PREDICT=[string]$Predict;$env:DLSS5_MULTI_PASS_SKIN_PROTECT='0';$env:DLSS5_VIT_ADAPTIVE='0';$env:DLSS5_HIP_FAST='1'
  $arguments=@("$r\assets",'D:\DLSSNR-Lab\five-final-20261017\HIP\gfx1201',"$r\$InputName","$out\output.f32",[string]$Frames)
  if($Switch -and $mode -eq '0.5'){$arguments+=@('switch')}
  $child=Start-Process "$r\network-probe.exe" -ArgumentList $arguments -WorkingDirectory $r -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru
  $null=$child.Handle;$start=Get-Date
  while(-not $child.WaitForExit(15000)){
   & D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 StellarBlade Onimusha re9.exe SandFall LOP-Win64'
   if($LASTEXITCODE -ne 1 -or ((Get-Date)-$start).TotalSeconds -gt 180){Stop-Process -Id $child.Id -Force;throw '15s watcher game/check failure or timeout'}
  }
  $child.WaitForExit();$code=$child.ExitCode;"exit=$code"|Set-Content "$out\exit.txt";$child=$null
  if($code -ne 0){Get-Content "$out\stderr.log" -Tail 12;throw "HIP mode $mode failed $code"}
  $expectedMode=if($ExpectFallback){'1'}else{$mode}
  if(!(Select-String -Path "$out\stdout.log" -SimpleMatch -Pattern "RESULT model=$expectedMode ")){throw 'requested model did not execute'}
  Get-FileHash "$out\output.f32"|ConvertTo-Json|Set-Content "$out\hashes.json"
 }
 if($ExpectFallback -and (Get-FileHash "$r\$Case\1\output.f32").Hash -ne (Get-FileHash "$r\$Case\0.5\output.f32").Hash){throw 'fallback differs from 1x'}
}finally{
 if($child -and !$child.HasExited){Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue}
 if($savedManifest){Move-Item "$r\assets\small\model-manifest.saved" "$r\assets\small\model-manifest.json"}
 if($held){$held.Dispose();Remove-Item $lock -ErrorAction SilentlyContinue}
}
