param([string]$Root='C:\DLSSNR-Small-20261018',[string]$Suffix='',[string]$Executable='ngx-oracle.exe')
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$lock='D:\DLSSNR-Lab\gpu.lock';$owner=[guid]::NewGuid().ToString();$held=$null;$child=$null
function Check-Idle {
 & "$Root\game-check.ps1" 'SB-Win64 StellarBlade Onimusha re9.exe SandFall LOP-Win64'
 if($LASTEXITCODE -ne 1){throw 'game running or game-check failed'}
 if(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -match '^ngx-oracle|^bench(mark)?$|^frame$'}){throw 'GPU experiment process already running'}
 if((Get-PSDrive ([IO.Path]::GetPathRoot($Root).Substring(0,1))).Free -lt 100GB){throw 'experiment disk below 100 GB'}
}
try {
 Check-Idle
 if((Get-FileHash "$Root\new\nvngx_dlssnr.dll").Hash -ne '2bc19bc09a7b89dd44f73e2ac0108fcc586e2154bdd0830f242f4f040e28789f'){throw 'new DLL SHA mismatch'}
 if((Get-FileHash "$Root\old\nvngx_dlssnr.dll").Hash -ne 'e16bcf15e16e13f527491cdf7845b2fe6521a738d8f7c9c721866a8496e1fc8e'){throw 'old DLL SHA mismatch'}
 $held=[IO.File]::Open($lock,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read)
 $b=[Text.Encoding]::UTF8.GetBytes("small-oracle owner=$owner pid=$PID started=$([DateTime]::UtcNow.ToString('o'))");$held.Write($b,0,$b.Length);$held.Flush()
 foreach($job in @(@('old',1),@('new',1),@('new',2),@('new',0))){
  Check-Idle
  $name="$($job[0])-preset$($job[1])$Suffix";$out="$Root\$name";if(Test-Path $out){throw "case exists, preserve evidence: $out"};New-Item -ItemType Directory $out | Out-Null
  $arguments=@("$Root\_nvngx.dll","$Root\$($job[0])","$Root\input",$out,"$($job[1])")
  $child=Start-Process "$Root\$Executable" -ArgumentList $arguments -WorkingDirectory $Root -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru
  $null=$child.Handle
  $begin=Get-Date
  while(-not $child.WaitForExit(15000)){
   & "$Root\game-check.ps1" 'SB-Win64 StellarBlade Onimusha re9.exe SandFall LOP-Win64'
   if($LASTEXITCODE -ne 1 -or ((Get-Date)-$begin).TotalSeconds -gt 180){Stop-Process -Id $child.Id -Force;throw '15s watchdog: game/check error or timeout'}
  }
  $child.WaitForExit();$code=$child.ExitCode;"exit=$code" | Set-Content "$out\exit.txt"
  if($code -ne 0){throw "$name failed $code"};$child=$null
  Get-ChildItem $out -Filter '*.rgb32' | Get-FileHash | ConvertTo-Json | Set-Content "$out\hashes.json"
 }
} finally {
 if($child -and -not $child.HasExited){Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue}
 if($held){$held.Dispose();Remove-Item $lock -ErrorAction SilentlyContinue}
}
