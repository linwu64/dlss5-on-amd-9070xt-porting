param([string]$Addon,[string]$SHA)
$ErrorActionPreference='Stop'
$case='D:\DLSSNR-Lab\stellar-compact-trial-20261012';$base='C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64';$dest="$base\dlss5-amd.addon64"
function Idle{& D:\DLSSNR-Lab\game-check.ps1 'SB-Win64 Onimusha re9.exe SandFall Magpie';if($LASTEXITCODE -ne 1){throw 'game/check busy'};if(Get-Process|Where-Object{$_.ProcessName -match 'Shipping|SB-Win64|Onimusha|Magpie|rtc_compile'}){throw 'game or RTC active'}}
Idle;if((Get-FileHash $Addon).Hash.ToLower() -ne $SHA){throw 'payload SHA'};if([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB){throw 'disk<100GB'}
$lock=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 Idle;$backup="$case\backup";New-Item -ItemType Directory $backup -ErrorAction Stop|Out-Null
 $old=(Get-FileHash $dest).Hash.ToLower();if($old -ne '9413682f3185d1e9327ce7ce76be96ee88aad794f528799152ebaa3f2a7f85f3'){throw "unexpected installed addon $old"}
 $files=@();$files+=Get-Item "$base\DLSS5-AMD\default-config.txt","$base\DLSS5-AMD\custom-config.txt","$base\DLSS5-AMD\native-game-flags.txt";$files+=Get-ChildItem "$base\DLSS5-AMD\native-game-tiled-assets\HIP" -File -Recurse;$files+=Get-Item "$base\DLSS5-AMD\native-game-tiled-assets\post70-history-head.f16";$files+=Get-ChildItem $base -Filter '*runtime*.dll' -File
 $before=@($files|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLower()}});$before|ConvertTo-Json -Depth 4|Set-Content "$case\preserved-files.json"
 $effective=@{};foreach($name in 'default-config.txt','custom-config.txt','native-game-flags.txt'){Copy-Item "$base\DLSS5-AMD\$name" "$backup\$name";foreach($line in [IO.File]::ReadAllLines("$base\DLSS5-AMD\$name")){if($line -match '^\s*(DLSS5_\w+)\s*=\s*(.*?)\s*$'){$effective[$matches[1]]=$matches[2]}}}
 $overrides=@();foreach($tier in 'Machine','User','Process'){foreach($k in @($effective.Keys)){$v=[Environment]::GetEnvironmentVariable($k,$tier);if($null -ne $v){$overrides+=@{tier=$tier;key=$k;value=$v};$effective[$k]=$v}}}
 foreach($kv in @{DLSS5_TEMPORAL_MODE='0';DLSS5_MULTI_PASS='1';DLSS5_MULTI_PASS_PREDICT='0';DLSS5_MULTI_PASS_SKIN_PROTECT='0'}.GetEnumerator()){if(!$effective.ContainsKey($kv.Key) -or $effective[$kv.Key] -ne $kv.Value){throw "config differs $($kv.Key)"}}
 $effective|ConvertTo-Json|Set-Content "$case\effective-config.json";Copy-Item $dest "$backup\dlss5-amd.addon64"
 @('$ErrorActionPreference=''Stop''','& D:\DLSSNR-Lab\game-check.ps1 ''SB-Win64 Onimusha Magpie''','if($LASTEXITCODE -ne 1){throw ''exit game first''}','$lease=[IO.File]::Open(''D:\DLSSNR-Lab\gpu.lock'',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)',"try{Copy-Item '$backup\dlss5-amd.addon64' '$dest' -Force}finally{`$lease.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock'}")|Set-Content "$case\rollback.ps1"
 try{Idle;Copy-Item $Addon $dest -Force;if((Get-FileHash $dest).Hash.ToLower() -ne $SHA){throw 'installed readback'};foreach($f in $before){if((Get-FileHash $f.path).Hash.ToLower() -ne $f.sha256){throw "preserved file changed $($f.path)"}}}
 catch{Idle;Copy-Item "$backup\dlss5-amd.addon64" $dest -Force;throw}
 @{source_commit='1b4c898f210cfcf2f67dfa138e695ae3ca022d0c';previous_addon_sha256=$old;addon_sha256=$SHA;target=$dest;backup=$backup;rollback="$case\rollback.ps1";config_bytes_unchanged=$true;modules_bytes_unchanged=$true;hsaco_count=@($files|Where-Object{$_.Extension -eq '.hsaco'}).Count;environment_overrides=$overrides;game_running_at_write=$false;gpu_experiment=$false;onimusha_written=$false;runtime_written=$false;compact_default=1;c32_nohi_included=$false;actual_exit_code=0}|ConvertTo-Json -Depth 5|Set-Content "$case\receipt.json"
 'DEPLOYED SUCCESS NO_GAME_STARTED'
}finally{$lock.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
