$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\release-043'
Expand-Archive "$r\config043.zip" "$r\scripts" -Force

function Idle { & 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game busy'};if(Get-Process -ErrorAction SilentlyContinue|Where-Object {$_.ProcessName -like 'rtc_compile*'}){throw 'RTC busy'} }
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
Idle
$psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='powershell.exe';$psi.Arguments='-NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\release-043\package-043.ps1 -SourceCommit 10982cf4';$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
$p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start'};"PACKAGE_OWNER_PID=$($p.Id)";$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15)
try{while(!$p.HasExited){Start-Sleep -Milliseconds 200;if([DateTime]::UtcNow -ge $next){& 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game started'};$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 3600){throw 'ownedbuild timeout'}};$p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw 'build failed'}}finally{if(!$p.HasExited){taskkill /PID $p.Id /T /F|Out-Null;$p.WaitForExit()};$o.Result|Set-Content "$r\package.stdout.log";$e.Result|Set-Content "$r\package.stderr.log"}
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
