$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$r='D:\DLSSNR-Lab\release-043';$out='D:\給網友打包'
$expected=@{};foreach($line in Get-Content "$r\HIP-SHA256SUMS"){$expected[$line.Substring(66)]=$line.Substring(0,64)}
$results=@()
foreach($name in 'Magpie-DLSS5-AMD-0.43','OptiScaler-DLSS5-AMD-0.43','OptiScaler-REFramework-DLSS5-AMD-0.43'){
 $file=Join-Path $out ($name+'.zip');$z=[IO.Compression.ZipFile]::OpenRead($file)
 try{
  $entries=@{};foreach($e in $z.Entries){$key=$e.FullName.Replace('\','/');if($entries.ContainsKey($key)){throw 'duplicate'};$entries[$key]=$e}
  function ReadText($key){$rr=[IO.StreamReader]::new($entries[$key].Open());try{return $rr.ReadToEnd()}finally{$rr.Dispose()}}
  $meta=ReadText 'release.json'|ConvertFrom-Json
  if($meta.version -ne '0.43' -or $meta.source_commit -ne '10982cf4' -or $meta.modules -ne 80){throw 'version/source'}
  $flags=ReadText 'DLSS5-AMD/default-config.txt'
  foreach($line in 'DLSS5_MULTI_PASS=1','DLSS5_MULTI_PASS_PREDICT=1','DLSS5_MULTI_PASS_SKIN_PROTECT=0','DLSS5_TEMPORAL_MODE=0','DLSS5_TEMPORAL_ENHANCE_STRENGTH=1'){if($flags -notmatch ('(?m)^'+[regex]::Escape($line)+'
?$')){throw "default $line"}}
  foreach($f in 'DLSS5-AMD/custom-config.txt','DLSS5-AMD/native-game-flags.txt'){if($entries.ContainsKey($f)){throw 'personal config'}}
  $mods=@($entries.Keys|Where-Object{$_ -match '^DLSS5-AMD/native-game-tiled-assets/HIP/(gfx1200|gfx1201)/[^/]+\.hsaco$'})
  if($mods.Count -ne 80){throw "modulecount $($mods.Count)"}
  $sums=ReadText 'SHA256SUMS.txt';$table=@{};foreach($l in ($sums -split "`n")){if($l.Trim()){$table[$l.Trim().Substring(66)]=$l.Substring(0,64)}}
  foreach($rel in $expected.Keys){if($table['DLSS5-AMD/native-game-tiled-assets/HIP/'+$rel] -ne $expected[$rel]){throw "module source $rel"}}
  $row='DLSS5-AMD/native-game-tiled-assets/post70-history-head.f16';if($entries[$row].Length -ne 64 -or $table[$row] -ne '77c745c4e1d84a6227a2224291d83c37d1e9bd18d45e95add166b1174225ce8f'){throw 'historyrow'}
  if(@($entries.Keys|Where-Object{$_ -match 'prefix-main-nt|candidate.hsaco|vtail|score-nohi|host_timing'}).Count){throw 'experimental payload'}
  $payload=@{version=$meta.version;source_commit=$meta.source_commit;package=$name;bytes=(Get-Item $file).Length;sha256=(Get-FileHash $file).Hash.ToLower();entries=$entries.Count;modules=$mods;module_sums=$expected;flags=$flags;release=$meta;addon_sha256=$table['dlss5-amd.addon64'];runtime_sha256=$table['LmxxfNrRuntime.dll'];entry_names=@($entries.Keys|Sort-Object)}
  $results+=$payload
 }finally{$z.Dispose()}
}
$results|ConvertTo-Json -Depth 10|Set-Content "$r\independent-package-metadata.json" -Encoding UTF8
'ALL3_CONTENT_DEFAULTS_MODULE_SOURCE80_PASS'
