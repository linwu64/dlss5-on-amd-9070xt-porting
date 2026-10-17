$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-bitexact-20261017'
$cases=@(foreach($case in Get-ChildItem $r -Directory|Where-Object {$_.Name -match '^c[1-5]-(abba|native-gold|gold|full)'}){
 $slots=@(foreach($slot in Get-ChildItem $case.FullName -Directory){$csv=Join-Path $slot.FullName 'out.csv';if(Test-Path $csv){
 [pscustomobject]@{name=$slot.Name;rows=@(Import-Csv $csv);hashes=@(foreach($f in Get-ChildItem $slot.FullName -Filter '*.f16'){[pscustomobject]@{name=$f.Name;sha256=(Get-FileHash $f.FullName).Hash}});stderr=[IO.File]::ReadAllText((Join-Path $slot.FullName 'stderr.log'))}
 }})
 [pscustomobject]@{name=$case.Name;slots=$slots}
})
[pscustomobject]@{cases=$cases;modules=@(Get-ChildItem "$r\HIP" -Recurse -Filter '*.hsaco'|ForEach-Object{[pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash}})}|ConvertTo-Json -Depth 8|Set-Content "$r\collected.json"
