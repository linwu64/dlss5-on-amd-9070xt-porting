$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-final-20261017'
Expand-Archive -Path "$r\smoke-shaders.zip" -DestinationPath $r -Force
function Idle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Genshin|YuanShen|rtc_compile'}){throw 'game/RTC active'}
}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 Idle
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='D:\DLSSNR-Lab\release-042\payload\runtime-smoke.exe';$psi.Arguments="`"$r\LmxxfNrRuntime.dll`" `"$r\HIP`" 32";$psi.WorkingDirectory=$r;$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 foreach($key in @($psi.EnvironmentVariables.Keys)){if($key.StartsWith('NR_') -or $key.StartsWith('DLSS5_') -or $key.StartsWith('SP_')){$psi.EnvironmentVariables.Remove($key)}}
 $psi.EnvironmentVariables['LMXXF_WEIGHTS_DIR']='D:\DLSSNR-Lab\combined-vs041-20261006\assets-common';$psi.EnvironmentVariables['LMXXF_SHADER_DIR']="$r\shaders"
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow
 try{while(!$p.HasExited){if(!$p.WaitForExit(15000)){Idle};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 120){throw 'smoke timeout'}};$p.WaitForExit();Write-Output "ACTUAL_RUNTIME_SMOKE_EXIT=$($p.ExitCode)";if($p.ExitCode -ne 0){throw 'smoke failed'}}finally{if(!$p.HasExited){$p.Kill();$p.WaitForExit()};$o.Result|Set-Content "$r\runtime-smoke.stdout.log";$e.Result|Set-Content "$r\runtime-smoke.stderr.log"}
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
