$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-final-20261017'
function Idle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game busy/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Genshin|YuanShen'}){throw 'game process active'}
}
Idle
if(Get-Process rtc_compile,rtc_compile-current -ErrorAction SilentlyContinue){throw 'RTC active'}
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 Idle
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='powershell';$psi.Arguments="-NoProfile -ExecutionPolicy Bypass -File $r\source\hip\build-modules.ps1 -OutputDir $r\HIP\gfx1200 -Compiler $r\rtc_compile-current.exe -Targets gfx1200 -RowOpts -PrebuiltDir $r\prebuilt";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow
 try{while(!$p.HasExited){if(!$p.WaitForExit(15000)){Idle};if(([DateTime]::UtcNow-$start).TotalMinutes -gt 15){throw 'build timeout'}};$p.WaitForExit();Write-Output "ACTUAL_TARGET_FIX_EXIT=$($p.ExitCode)";if($p.ExitCode -ne 0){throw 'build failed'}}finally{if(!$p.HasExited){& taskkill /PID $p.Id /T /F|Out-Null;$p.WaitForExit()};$o.Result|Set-Content "$r\target-fix.stdout.log";$e.Result|Set-Content "$r\target-fix.stderr.log"}
 $utf8=New-Object Text.UTF8Encoding($false)
 $lines=@(foreach($arch in 'gfx1200','gfx1201'){foreach($f in Get-ChildItem "$r\HIP\$arch" -Filter '*.hsaco'|Sort-Object Name){(Get-FileHash $f.FullName).Hash.ToLower()+"  $arch/"+$f.Name}})
 if($lines.Count -ne 80){throw '80 required'}
 [IO.File]::WriteAllLines("$r\HIP\SHA256SUMS",$lines,$utf8)
 Write-Output 'TARGET_FIX_DONE'
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
