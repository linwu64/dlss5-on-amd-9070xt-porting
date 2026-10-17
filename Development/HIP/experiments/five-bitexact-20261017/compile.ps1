param([string]$Module='deep_fast-packed-fast')
$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-bitexact-20261017'
function GameIdle {
 & powershell -NoProfile -ExecutionPolicy Bypass -File D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie'
 if($LASTEXITCODE -ne 1){throw 'game active/check failed'}
 if(Get-Process|Where-Object {$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|Wuthering|Genshin|YuanShen'}){throw 'game process active'}
}
GameIdle
if(Get-Process rtc_compile -ErrorAction SilentlyContinue){throw 'other RTC active'}
if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk below100GB'}
$owner=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try {
 GameIdle
 foreach($arch in 'gfx1201','gfx1200') {
  $psi=[Diagnostics.ProcessStartInfo]::new();$psi.FileName='D:\DLSSNR-Lab\rtc_compile.exe';$psi.Arguments="`"$r\HIP\$arch\$Module.hsaco`" `"$r\source\$Module.generated.hip`" comgr $arch";$psi.UseShellExecute=$false;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
  $p=[Diagnostics.Process]::new();$p.StartInfo=$psi;if(!$p.Start()){throw 'RTC start failed'};$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync()
  try {while(!$p.HasExited){if(!$p.WaitForExit(15000)){GameIdle}};$p.WaitForExit();if($p.ExitCode -ne 0){throw "compile $arch exit=$($p.ExitCode)"}}finally{if(!$p.HasExited){$p.Kill();$p.WaitForExit()};$stdout.Result|Set-Content "$r\compile-$arch.log";$stderr.Result|Set-Content "$r\compile-$arch.err"}
 }
}finally{$owner.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';Write-Output 'LOCK_RELEASED'}
