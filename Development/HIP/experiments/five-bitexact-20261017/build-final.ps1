$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-final-20261017'
New-Item -ItemType Directory -Force $r|Out-Null
Expand-Archive -Path 'D:\DLSSNR-Lab\five-final-source.zip' -DestinationPath $r -Force
Expand-Archive -Path 'D:\DLSSNR-Lab\five-final-prebuilt.zip' -DestinationPath $r -Force
function Idle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Genshin|YuanShen'}){throw 'game process active'}
}
Idle
if(Get-Process rtc_compile -ErrorAction SilentlyContinue){throw 'RTC active'}
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 Idle
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='powershell';$psi.Arguments="-NoProfile -ExecutionPolicy Bypass -File $r\source\hip\build-modules.ps1 -OutputDir $r\HIP -Compiler $r\rtc_compile-current.exe -RowOpts -PrebuiltDir $r\prebuilt";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow
 try{while(!$p.HasExited){if(!$p.WaitForExit(15000)){Idle};if(([DateTime]::UtcNow-$start).TotalMinutes -gt 20){throw 'build timeout'}};$p.WaitForExit();Write-Output "ACTUAL_BUILD_EXIT=$($p.ExitCode)";if($p.ExitCode -ne 0){throw 'build failed'}}finally{if(!$p.HasExited){& taskkill /PID $p.Id /T /F|Out-Null;$p.WaitForExit()};$o.Result|Set-Content "$r\build.stdout.log";$e.Result|Set-Content "$r\build.stderr.log"}
 foreach($arch in 'gfx1200','gfx1201'){if(@(Get-ChildItem "$r\HIP\$arch" -Filter '*.hsaco').Count -ne 40){throw "expected40 $arch"}}
 Write-Output 'CANONICAL_80_PASS'
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
