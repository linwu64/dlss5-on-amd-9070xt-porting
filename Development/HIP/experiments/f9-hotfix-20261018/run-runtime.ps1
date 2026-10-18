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
 if(!(Idle)){throw 'game busy; runtime tests not started'};if((Get-PSDrive D).Free -lt 100GB){throw 'disk below100GB'}
 $held=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 Copy-Item D:\DLSSNR-Lab\release-044-f9fix\payload\LmxxfNrRuntime.dll "$r\runtime-stage\LmxxfNrRuntime.dll" -Force
 'DLSS5_MULTI_PASS=0.5'|Set-Content "$r\runtime-stage\DLSS5-AMD\custom-config.txt"
 $env:LMXXF_WEIGHTS_DIR=$assets;$env:DLSS5_NETWORK_HEIGHT='auto';$env:DLSS5_NETWORK_FREE_RES='0';$env:DLSS5_TEMPORAL_MODE='1';$env:DLSS5_FAST_NUMERIC='1';$env:DLSS5_VIT_ADAPTIVE='0';$env:DLSS5_HOT_RELOAD='1';$env:DLSS5_MULTI_PASS_HOTKEY='0';Remove-Item Env:DLSS5_MULTI_PASS -ErrorAction SilentlyContinue
 $env:SMALL_RUNTIME_CONFIG="$r\runtime-stage\DLSS5-AMD\custom-config.txt"
 RunOwned "$r\rt-switch.exe" "`"$r\runtime-stage\LmxxfNrRuntime.dll`" `"$modules`" 1280x720 10 1" "$r\runtime-switch-idle-r2"
 $mirror='C:\XboxGames\Onimusha- Way of the Sword\Content\DLSS5-AMD';$before=@{};foreach($n in 'default-config.txt','custom-config.txt','native-game-flags.txt'){if(Test-Path "$mirror\$n"){$before[$n]=(Get-FileHash "$mirror\$n").Hash}}
 RunOwned "$r\OnimushaWotS.exe" "`"$r\runtime-stage\LmxxfNrRuntime.dll`" `"$modules`" 1280x720 2 1" "$r\runtime-xbox-mirror-idle-r2"
 foreach($n in $before.Keys){if((Get-FileHash "$mirror\$n").Hash -ne $before[$n]){throw 'real game config changed during readonly alias path test'}}
 if((Get-Content "$r\runtime-xbox-mirror-idle-r2\stdout.log" -Raw) -notmatch [regex]::Escape($mirror)){throw 'Xbox mirror config not selected'}
 'ALL_RUNTIME_F9_AND_XBOX_MIRROR_PASS'
}finally{if($child -and !$child.HasExited){$child.Kill()};if($held){$held.Dispose();Remove-Item D:\DLSSNR-Lab\gpu.lock};'LOCK_RELEASED'}
