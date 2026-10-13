$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-042'
function Idle { & 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game busy'};if(Get-Process rtc_compile -ErrorAction SilentlyContinue){throw 'RTC busy'} }
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
$psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='powershell.exe';$psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\release-042\build-comgr.ps1 -OutputDir D:\DLSSNR-Lab\release-042\HIP -SourceDir D:\DLSSNR-Lab\release-042\source\hip -Compiler D:\DLSSNR-Lab\build-0927\rtc_compile.exe -RowOpts';$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
$p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start'};"COMGR_OWNER_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
try{while(!$p.HasExited){Start-Sleep -Milliseconds 200;if([DateTime]::UtcNow -ge $next){& 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game started'};$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 1800){throw 'ownedbuild timeout'}};$p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw 'build failed'}}finally{if(!$p.HasExited){taskkill /PID $p.Id /T /F|Out-Null;$p.WaitForExit()};$o.Result|Set-Content "$r\comgr.stdout.log";$e.Result|Set-Content "$r\comgr.stderr.log"}
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
