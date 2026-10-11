$ErrorActionPreference='Stop';$r='D:\DLSSNR-Lab\mode3-stellar-live-audit-20261011';New-Item -ItemType Directory -Force $r|Out-Null
$game='C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64';$logs="$game\DLSS5-AMD\logs"
$processes=@(Get-Process|Where-Object {$_.ProcessName -match 'SB-Win64|Shipping|rtc_compile'}|Select-Object Id,ProcessName,Path,StartTime)
$processes|Select-Object Id,ProcessName,Path|Format-Table
$meta=@();if(Test-Path $logs){foreach($f in Get-ChildItem $logs -File){$meta+=@{name=$f.Name;path=$f.FullName;bytes=$f.Length;last_write=$f.LastWriteTimeUtc.ToString('o')};if($f.Extension -in @('.log','.txt')){Get-Content $f.FullName -Tail 140|Set-Content -Encoding UTF8 "$r\tail-$($f.Name)"}}}
@{processes=$processes;game_root=$game;log_files=$meta}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 "$r\live-state.json"
'READ_ONLY_GAME_AUDIT_NO_GPU_NO_CONFIG_WRITE'
