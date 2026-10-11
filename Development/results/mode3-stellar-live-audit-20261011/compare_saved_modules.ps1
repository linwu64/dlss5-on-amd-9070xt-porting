$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\mode3-stellar-live-audit-20261011'
$old='D:\DLSSNR-Lab\mode1-runtime-ready-20261008\DLSS5-AMD\native-game-tiled-assets\HIP'
$gamePrefix='C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64\DLSS5-AMD\native-game-tiled-assets\HIP\'
# Read previously verified installed manifest; do not re-open or change the game.
$expected=Get-Content 'D:\DLSSNR-Lab\mode3-stellar-1x-trial-20261011\backups\20261011-114301\modules-readonly.json' -Raw|ConvertFrom-Json
$rows=@();foreach($e in $expected|Where-Object {$_.path.EndsWith('.hsaco')}){
 if(!$e.path.StartsWith($gamePrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'installed module root'}
 $rel=$e.path.Substring($gamePrefix.Length);$f=Join-Path $old $rel;$sha=(Get-FileHash $f).Hash.ToLower();$rows+=@{relative=$rel;old_path=$f;old_sha256=$sha;installed_deployment_sha256=$e.sha.ToLower();same=($sha -eq $e.sha.ToLower())}
}
$oldCount=@(Get-ChildItem $old -Recurse -File -Filter '*.hsaco').Count
if($oldCount -ne 79 -or $rows.Count -ne 79 -or @($rows|Where-Object {!$_.same}).Count){throw 'old menu/current installation module identity mismatch'}
@{old_root=$old;installed_manifest='deployment82751 verified all79 untouched';old_actual_hsaco_count=$oldCount;compared=$rows.Count;all_equal=$true;game_files_opened=$false;gpu_run=$false;rows=$rows}|ConvertTo-Json -Depth 5|Set-Content -Encoding UTF8 "$r\old-menu-vs-installed-modules.json"
'ACTUAL_OLD_MENU_79_MODULES_MATCH_DEPLOYMENT_MANIFEST_NO_GAME_ACCESS_NO_GPU'
