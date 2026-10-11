$ErrorActionPreference='Stop'
$base='C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64'
$root='D:\DLSSNR-Lab\stellar-mode0-restore-20261011';New-Item -ItemType Directory -Force $root|Out-Null
$keys=@{DLSS5_TEMPORAL_MODE='0';DLSS5_MULTI_PASS='1';DLSS5_MULTI_PASS_PREDICT='0';DLSS5_FAST_HISTORY='0';DLSS5_TEMPORAL_HISTORY_EXPERIMENT='0'}
$processes=@(Get-Process|Where-Object {$_.ProcessName -match 'SB-Win64|Shipping'}|Select-Object Id,ProcessName,Path)
$envs=@();foreach($tier in @('User','Machine','Process')){foreach($k in $keys.Keys){$v=[Environment]::GetEnvironmentVariable($k,$tier);if($null -ne $v){$envs+=@{tier=$tier;key=$k;value=$v};if($v -ne $keys[$k]){throw "environment override $tier $k=$v; not changing system environment"}}}}
$backup="$root\backups\$(Get-Date -Format yyyyMMdd-HHmmss)";New-Item -ItemType Directory -Force $backup|Out-Null
$files=@('default-config.txt','custom-config.txt','native-game-flags.txt');$rows=@();$i=0
foreach($name in $files){$p="$base\DLSS5-AMD\$name";$copy="$backup\file-$i";Copy-Item $p $copy;$rows+=@{path=$p;backup=$copy;sha256=(Get-FileHash $p).Hash.ToLower();present=$true};$i++}
$rows|ConvertTo-Json|Set-Content -Encoding UTF8 "$backup\manifest.json"
$addon=(Get-FileHash "$base\dlss5-amd.addon64").Hash.ToLower()
@('$ErrorActionPreference=''Stop''','& D:\DLSSNR-Lab\game-check.ps1 ''SB-Win64 Onimusha Magpie''','if($LASTEXITCODE -ne 1){throw ''exit game before rollback''}',('$rows=Get-Content ''{0}\manifest.json'' -Raw|ConvertFrom-Json' -f $backup),'$lease=[IO.File]::Open(''D:\DLSSNR-Lab\gpu.lock'',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)','try{foreach($r in $rows){Copy-Item $r.backup $r.path -Force;if((Get-FileHash $r.path).Hash.ToLower() -ne $r.sha256){throw ''rollback SHA''}}}finally{$lease.Dispose();Remove-Item ''D:\DLSSNR-Lab\gpu.lock''}')|Set-Content "$backup\rollback.ps1"
function EditMode($p,$append){
 $bytes=[IO.File]::ReadAllBytes($p);$bom=$bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191;$off=if($bom){3}else{0};$text=[Text.Encoding]::UTF8.GetString($bytes,$off,$bytes.Length-$off);$pattern='(?m)^DLSS5_TEMPORAL_MODE=[^\r\n]*'
 if([regex]::IsMatch($text,$pattern)){$text=[regex]::Replace($text,$pattern,'DLSS5_TEMPORAL_MODE=0')}elseif($append){$nl=if($text.Contains("`r`n")){"`r`n"}else{"`n"};if(!$text.EndsWith("`n")){$text+=$nl};$text+='DLSS5_TEMPORAL_MODE=0'+$nl}
 [IO.File]::WriteAllText($p,$text,[Text.UTF8Encoding]::new($bom))
}
$lease=[IO.File]::Open('D:\DLSSNR-Lab\gpu.lock',[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{
 EditMode "$base\DLSS5-AMD\custom-config.txt" $true;EditMode "$base\DLSS5-AMD\native-game-flags.txt" $false
 $effective=@{};foreach($name in $files){foreach($line in [IO.File]::ReadAllLines("$base\DLSS5-AMD\$name")){if($line -match '^\s*(DLSS5_\w+)\s*=\s*(.*?)\s*$'){$effective[$matches[1]]=$matches[2]}}}
 foreach($tier in @('Machine','User','Process')){foreach($k in $keys.Keys){$v=[Environment]::GetEnvironmentVariable($k,$tier);if($null -ne $v){$effective[$k]=$v}}};foreach($k in $keys.Keys){if($effective[$k] -ne $keys[$k]){throw "effective config $k"}}
 if((Get-FileHash "$base\dlss5-amd.addon64").Hash.ToLower() -ne $addon){throw 'unexpected addon change'}
 $after=@();foreach($r in $rows){$after+=@{path=$r.path;sha256=(Get-FileHash $r.path).Hash.ToLower()}}
 $effective|ConvertTo-Json|Set-Content -Encoding UTF8 "$backup\effective-config.json";$after|ConvertTo-Json|Set-Content -Encoding UTF8 "$backup\after.json"
 @{processes_at_write=$processes;restart_required=($processes.Count -gt 0);mode='0';multi_pass='1';prediction='0';enhance_strength_preserved=$effective['DLSS5_TEMPORAL_ENHANCE_STRENGTH'];addon_sha256=$addon;dll_written=$false;modules_written=$false;onimusha_written=$false;environment_overrides=$envs;backup=$backup;rollback="$backup\rollback.ps1";gpu_work=$false}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 "$root\receipt.json"
 "CONFIG_RESTORED_MODE0 MP1 PRED0 restart_required=$($processes.Count -gt 0) backup=$backup NO_DLL_NO_GPU"
}catch{foreach($r in $rows){Copy-Item $r.backup $r.path -Force};throw}finally{$lease.Dispose();Remove-Item 'D:\DLSSNR-Lab\gpu.lock';'LOCK_RELEASED'}
