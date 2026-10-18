param([Parameter(Mandatory=$true)][string]$SourceCommit)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$root='D:\DLSSNR-Lab\game-install-20261018-f9fix-r3';$release='D:\DLSSNR-Lab\release-044-f9fix';$out='D:\給網友打包';$sourceCommit=$SourceCommit
$games=@('C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64','C:\XboxGames\Onimusha- Way of the Sword\Content')
$lock=$null;$child=$null;$manifest=@();$next=[DateTime]::MinValue;$utf8=[Text.UTF8Encoding]::new($false)
function Idle {& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game busy/check failed'};if((Get-PSDrive D).Free -lt 100GB){throw 'disk below100GB'}}
function Watch {if([DateTime]::UtcNow -ge $script:next){Idle;$script:next=[DateTime]::UtcNow.AddSeconds(15)}}
function Hash($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Rewrite($path,$key,$value){
 $enc=[Text.Encoding]::GetEncoding(28591);$t=if(Test-Path -LiteralPath $path){$enc.GetString([IO.File]::ReadAllBytes($path))}else{''};$nl=if($t.Contains("`r`n")){"`r`n"}else{"`n"};$pat='(?m)^'+[regex]::Escape($key)+'=[^\r\n]*'
 if([regex]::IsMatch($t,$pat)){$t=[regex]::Replace($t,$pat,"$key=$value")}else{$t=$t.TrimEnd("`r","`n")+$nl+"$key=$value"+$nl};[IO.File]::WriteAllBytes($path,$enc.GetBytes($t))
}
function Restore {foreach($m in $script:manifest){Watch;$dst=Join-Path $games[$m.game] $m.relative;if($m.existed){Copy-Item -LiteralPath $m.backup -Destination $dst -Force;if((Hash $dst) -ne $m.sha256){throw "restore mismatch $dst"}}else{Remove-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue}}}
try{
 Idle;$lock=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);Idle
 New-Item -ItemType Directory -Force $root|Out-Null;if(Test-Path "$root\receipt.json"){throw 'completed receipt exists; preserve it'}
 $backup="$root\backup-$(Get-Date -Format yyyyMMdd-HHmmss)";New-Item -ItemType Directory -Force $backup|Out-Null
 $plans=@()
 foreach($idx in 0,1){
  $stage=if($idx -eq 0){"$out\OptiScaler-DLSS5-AMD-0.44"}else{"$out\OptiScaler-REFramework-DLSS5-AMD-0.44"};$base=$games[$idx];$rel='DLSS5-AMD\native-game-tiled-assets';$assets="$stage\$rel";$map=@{}
  # Shipped binary routes stay matched to the host already installed in each game.
  if(Test-Path "$base\dlss5-amd.addon64"){$map['dlss5-amd.addon64']="$release\payload\dlss5-amd.addon64"}
  foreach($n in 'LmxxfNrRuntime.dll','_storage_\LmxxfNrRuntime.dll'){if(Test-Path "$base\$n"){$map[$n]="$release\payload\LmxxfNrRuntime.dll"}}
  foreach($f in Get-ChildItem "$assets\HIP" -Recurse -File){$map["$rel\HIP\"+$f.FullName.Substring(("$assets\HIP\").Length)]=$f.FullName}
  foreach($f in Get-ChildItem "$assets\small" -File){$map["$rel\small\"+$f.Name]=$f.FullName}
  foreach($f in Get-ChildItem $assets -File|Where-Object {$_.Extension -in '.hlsl','.hlsli'}){$map["$rel\"+$f.Name]=$f.FullName}
  $map["$rel\post70-history-head.f16"]="$assets\post70-history-head.f16"
  foreach($f in Get-ChildItem "$stage\shaders" -File){$map['shaders\'+$f.Name]=$f.FullName}
  $map['DLSS5-AMD\default-config.txt']="$stage\DLSS5-AMD\default-config.txt"
  $rels=@($map.Keys)+@('DLSS5-AMD\custom-config.txt','DLSS5-AMD\native-game-flags.txt')
  foreach($n in $rels|Sort-Object -Unique){Watch;$dst=Join-Path $base $n;$exists=Test-Path -LiteralPath $dst;$bak=Join-Path "$backup\game-$idx" $n;$sha=$null
   if($exists){$sha=Hash $dst;New-Item -ItemType Directory -Force (Split-Path $bak)|Out-Null;Copy-Item -LiteralPath $dst -Destination $bak -Force;if((Hash $bak) -ne $sha){throw 'backup readback mismatch'}}
   $manifest += [pscustomobject]@{game=$idx;relative=$n;existed=$exists;sha256=$sha;backup=$bak}
  }
  $plans+=,[pscustomobject]@{game=$idx;map=$map}
 }
 $manifest|ConvertTo-Json -Depth 6|Set-Content "$backup\manifest.json"
 # Rollback restores/removes every file touched and verifies all saved bytes.
 $rb=@'
$ErrorActionPreference='Stop'
& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'exit game first'}
$games=@('C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64','C:\XboxGames\Onimusha- Way of the Sword\Content')
$held=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$next=[DateTime]::MinValue
try{foreach($m in (Get-Content '@MANIFEST@' -Raw|ConvertFrom-Json)){if([DateTime]::UtcNow -ge $next){& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game started'};$next=[DateTime]::UtcNow.AddSeconds(15)};$dst=Join-Path $games[$m.game] $m.relative;if($m.existed){New-Item -ItemType Directory -Force (Split-Path $dst)|Out-Null;Copy-Item -LiteralPath $m.backup -Destination $dst -Force;if((Get-FileHash -LiteralPath $dst).Hash -ne $m.sha256){throw "rollback mismatch $dst"}}else{Remove-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue}};'ROLLBACK_COMPLETE'}finally{$held.Dispose();Remove-Item D:\DLSSNR-Lab\gpu.lock}
'@
 [IO.File]::WriteAllText("$root\rollback.ps1",$rb.Replace('@MANIFEST@',"$backup\manifest.json"),$utf8)
 try{
  $installed=@()
  foreach($plan in $plans){$idx=$plan.game;$base=$games[$idx]
   foreach($n in $plan.map.Keys){Watch;$src=$plan.map[$n];$dst=Join-Path $base $n;New-Item -ItemType Directory -Force (Split-Path $dst)|Out-Null;Copy-Item -LiteralPath $src -Destination $dst -Force;$sha=Hash $src;if((Hash $dst) -ne $sha){throw "install readback mismatch $dst"};$installed+=[pscustomobject]@{game=$idx;relative=$n;sha256=$sha}}
   foreach($cfg in 'custom-config.txt','native-game-flags.txt'){$p="$base\DLSS5-AMD\$cfg";if($cfg -eq 'custom-config.txt' -or (Test-Path $p)){Rewrite $p 'DLSS5_MULTI_PASS' '0.5';Rewrite $p 'DLSS5_HOT_RELOAD' '1';Rewrite $p 'DLSS5_MULTI_PASS_HOTKEY' 'F9'}}
   $a="$base\DLSS5-AMD\native-game-tiled-assets";if(@(Get-ChildItem "$a\small" -File|Where-Object {$_.Name -ne 'model-manifest.json'}).Count -ne 93 -or @(Get-ChildItem "$a\HIP" -Recurse -Filter '*.hsaco').Count -ne 80){throw 'installed asset count'}
   Write-Output "INSTALLED game=$idx modules=80 small=93"
  }
  Watch;$g=$games[1];$env:LMXXF_WEIGHTS_DIR="$g\DLSS5-AMD\native-game-tiled-assets"
  $si=[Diagnostics.ProcessStartInfo]::new();$si.FileName="$release\payload\runtime-smoke.exe";$si.Arguments="`"$g\_storage_\LmxxfNrRuntime.dll`" `"$g\DLSS5-AMD\native-game-tiled-assets\HIP`" 32";$si.WorkingDirectory=$root;$si.UseShellExecute=$false;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
  $child=[Diagnostics.Process]::new();$child.StartInfo=$si;if(!$child.Start()){throw 'smoke start'};$o=$child.StandardOutput.ReadToEndAsync();$e=$child.StandardError.ReadToEndAsync();$start=[DateTime]::UtcNow
  try{while(!$child.HasExited){Start-Sleep -Milliseconds 100;Watch;if(([DateTime]::UtcNow-$start).TotalSeconds -gt 120){throw 'owned smoke timeout'}};$child.WaitForExit();$smoke=$child.ExitCode;if($smoke){throw "installed smoke exit=$smoke"}}finally{if(!$child.HasExited){$child.Kill();$child.WaitForExit()};$o.Result|Set-Content "$root\smoke.stdout.log";$e.Result|Set-Content "$root\smoke.stderr.log"}
  $configs=@();foreach($idx in 0,1){foreach($cfg in 'default-config.txt','custom-config.txt','native-game-flags.txt'){$p="$($games[$idx])\DLSS5-AMD\$cfg";if(Test-Path $p){$configs+=[pscustomobject]@{game=$idx;file=$cfg;sha256=(Hash $p);controls=@(Get-Content $p|Select-String '^DLSS5_(MULTI_PASS|HOT_RELOAD|MULTI_PASS_HOTKEY|TEMPORAL_MODE)='|ForEach-Object {$_.Line})}}}}
  [ordered]@{source_commit=$sourceCommit;version='0.44';games=$games;backup=$backup;rollback="$root\rollback.ps1";installed=$installed;configs=$configs;small_weights_per_game=93;modules_per_game=80;runtime_smoke_exit=$smoke;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8|Set-Content "$root\receipt.json"
  Write-Output "DEPLOY_COMPLETE backup=$backup runtime_smoke_exit=$smoke"
 }catch{$reason=$_;Restore;throw $reason}
}finally{if($child -and !$child.HasExited){$child.Kill()};if($lock){$lock.Dispose();Remove-Item D:\DLSSNR-Lab\gpu.lock};'LOCK_RELEASED'}
