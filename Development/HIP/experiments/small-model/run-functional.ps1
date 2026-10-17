$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';$r='D:\DLSSNR-Lab\small-model-20261018';$lock='D:\DLSSNR-Lab\gpu.lock';$held=$null;$p=$null
function Idle {& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 StellarBlade Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game/check busy'};if((Get-PSDrive D).Free -lt 100GB){throw 'disk below100GB'}}
function RunOwned($exe,$arguments,$dir,$switchMode=$false){
 Idle;New-Item -ItemType Directory -Force $dir|Out-Null
 $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName=$exe;$si.Arguments=$arguments;$si.WorkingDirectory=$dir;$si.UseShellExecute=$false;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
 $si.EnvironmentVariables['SMALL_FRAME_CAPTURE']='1';if($switchMode){$si.EnvironmentVariables['SMALL_FRAME_SWITCH']='1'}else{$si.EnvironmentVariables.Remove('SMALL_FRAME_SWITCH')}
 $script:p=[Diagnostics.Process]::new();$p.StartInfo=$si;if(!$p.Start()){throw 'start'};$a=$p.StandardOutput.ReadToEndAsync();$b=$p.StandardError.ReadToEndAsync();$start=Get-Date;$next=(Get-Date).AddSeconds(15)
 try{while(!$p.HasExited){Start-Sleep -Milliseconds 100;if((Get-Date) -ge $next){Idle;$next=(Get-Date).AddSeconds(15)};if(((Get-Date)-$start).TotalSeconds -gt 180){throw 'own timeout'}};$p.WaitForExit();$code=$p.ExitCode;"exit=$code"|Set-Content "$dir\exit.txt";if($code){throw "owned test failed $code"}}
 finally{if(!$p.HasExited){$p.Kill();$p.WaitForExit()};$a.Result|Set-Content "$dir\stdout.log";$b.Result|Set-Content "$dir\stderr.log";$script:p=$null}
}
try{Idle;$held=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 RunOwned "$r\test-history-small.exe" '' "$r\history-small-shader"
 foreach($case in @(@('history-720',1,0,6,$false),@('switch-history-720',1,0,0,$true),@('ae-720',0,1,0,$false),@('free-frame',0,0,0,$false))){
  $name=$case[0];$d="$r\$name";if(Test-Path "$d\out.csv"){throw 'case already exists'};New-Item -ItemType Directory -Force "$d\DLSS5-AMD\logs"|Out-Null
  $flags=(Get-Content D:\DLSSNR-Lab\combined-vs041-20261006\base.flags -Raw)+"`nDLSS5_NETWORK_HEIGHT=720`nDLSS5_NETWORK_FREE_RES=$([int]($name -eq 'free-frame'))`nDLSS5_MULTI_PASS=0.5`nDLSS5_MULTI_PASS_PREDICT=1`nDLSS5_MULTI_PASS_SKIN_PROTECT=0`nDLSS5_TEMPORAL_MODE=$($case[1])`nDLSS5_VIT_ADAPTIVE=$($case[2])`nDLSS5_HOT_RELOAD=0`nDLSS5_MULTI_PASS_HOTKEY=0`nDLSS5_HIP_GRAPH=0`nDLSS5_OVERLAP=0`nDLSS5_SKIP_BLOCKS=`nDLSS5_FAST_NUMERIC=1`nDLSS5_HIP_MEMORY=0`n"
  $flags|Set-Content "$d\flags.txt";$flags|Set-Content "$d\DLSS5-AMD\native-game-flags.txt";Copy-Item "$r\frame-functional.exe" "$d\frame.exe"
  $args="`"$r\assets`" `"$d\flags.txt`" `"$r\functional-input.f16`" `"$d\out`" 12 $($case[1]) `"D:\DLSSNR-Lab\five-final-20261017\HIP\gfx1201`" $($case[3]) 0 0 0"
  RunOwned "$d\frame.exe" $args $d $case[4]
  $rows=@(Import-Csv "$d\out.csv");if($rows.Count -ne 12 -or @($rows|Where-Object {[int]$_.invalid -ne 0}).Count){throw 'functional invalid/frames'}
  if($name -eq 'history-720' -and (Get-FileHash "$d\out-frame-0.f16").Hash -ne (Get-FileHash "$d\out-frame-6.f16").Hash){throw 'history reset differs'}
  if($name -eq 'switch-history-720' -and (Get-FileHash "$d\out-frame-0.f16").Hash -ne (Get-FileHash "$d\out-frame-8.f16").Hash){throw 'switch-back Small differs'}
  Get-ChildItem $d -Filter '*.f16'|Get-FileHash|ConvertTo-Json|Set-Content "$d\hashes.json"
  Write-Output "PASS $name"
 }
}finally{if($p -and !$p.HasExited){$p.Kill()};if($held){$held.Dispose();Remove-Item $lock -ErrorAction SilentlyContinue};Write-Output 'LOCK_RELEASED'}
