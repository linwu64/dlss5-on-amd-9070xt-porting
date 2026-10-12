$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\vit-contract-compact-20261012'
$games='Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Client-Win64|Genshin|YuanShen'
function Idle {& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game check busy'};if(Get-Process|Where-Object {$_.ProcessName -match $games -or $_.ProcessName -eq 'rtc_compile'}){throw 'game/compiler active'}}
Idle
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'D free below100GB'}
$m=Get-Content "$r\kernel-source.json" -Raw|ConvertFrom-Json
if((Get-FileHash "$r\contract-compact.generated.hip").Hash -ne $m.sources.'contract-compact.generated.hip'){throw 'sourceSHA'}
New-Item -ItemType Directory -Force "$r\cache"|Out-Null
if(Test-Path "$r\contract-compact.hsaco"){throw 'existing compiled artifact no repeat'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='D:\DLSSNR-Lab\build-0927\rtc_compile.exe';$psi.Arguments="`"$r\contract-compact.hsaco`" `"$r\contract-compact.generated.hip`" comgr gfx1201";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.EnvironmentVariables['RTC_EXTRA_OPTS']='';$psi.EnvironmentVariables['TEMP']="$r\cache";$psi.EnvironmentVariables['TMP']="$r\cache"
 $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'start failed'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow;$next=$start.AddSeconds(15);"COMPILE row=contract-compact compiler=actualCOMGR opts=empty target=gfx1201 PID=$($p.Id)"
 try {while(!$p.HasExited){Start-Sleep -Milliseconds 100;if([DateTime]::UtcNow -ge $next){if(Get-Process|Where-Object {$_.ProcessName -match $games}){throw 'game began'};$next=[DateTime]::UtcNow.AddSeconds(15)};if(([DateTime]::UtcNow-$start).TotalSeconds -gt 90){throw 'own90s timeout no repeat'}};$p.WaitForExit();"ACTUAL_EXIT_CODE=$($p.ExitCode)";if($p.ExitCode){throw 'compile failed'}}
 finally {if(!$p.HasExited){$p.Kill();$p.WaitForExit()};$o.Result|Set-Content "$r\compile.stdout.log";$e.Result|Set-Content "$r\compile.stderr.log"}
 Get-FileHash "$r\contract-compact.hsaco"|Select-Object Path,Hash|ConvertTo-Json|Set-Content "$r\module-sha.json"
 'COMGR_COMPILE_PASS_NOT_NUMERICAL_GOLD'
} finally {$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
