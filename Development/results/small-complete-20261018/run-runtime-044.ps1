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
 $env:LMXXF_WEIGHTS_DIR="$r\assets";$env:LMXXF_SHADER_DIR="$r\assets";$env:DLSS5_NETWORK_HEIGHT='auto';$env:DLSS5_NETWORK_FREE_RES='1';$env:DLSS5_MULTI_PASS='0.5';$env:DLSS5_FAST_NUMERIC='1';$env:DLSS5_VIT_ADAPTIVE='0';$env:DLSS5_TEMPORAL_MODE='1';$env:DLSS5_HOT_RELOAD='0'
 RunOwned "$r\rt-bench-044.exe" "`"$r\LmxxfNrRuntime-044.dll`" `"D:\DLSSNR-Lab\five-final-20261017\HIP\gfx1201`" 1280x720,1600x900,1001x777,1280x720 4 1" "$r\runtime-free-history-044-r2"
 Write-Output 'PASS Runtime Small free geometry and history across sizes'
}finally{if($p -and !$p.HasExited){$p.Kill()};if($held){$held.Dispose();Remove-Item $lock -ErrorAction SilentlyContinue};Write-Output 'LOCK_RELEASED'}
