$ErrorActionPreference='Stop'
$r='D:\DLSSNR-Lab\five-bitexact-20261017'
New-Item -ItemType Directory -Force "$r\HIP\gfx1201","$r\HIP\gfx1200","$r\source"|Out-Null
foreach($arch in 'gfx1200','gfx1201') {
 $files=@(Get-ChildItem "D:\DLSSNR-Lab\game-install-20261014\HIP\$arch" -Filter '*.hsaco')
 if($files.Count -ne 40){throw "expected40baseline $arch got $($files.Count)"}
 $files|Copy-Item -Destination "$r\HIP\$arch"
}
Get-ChildItem "$r\HIP" -Recurse -Filter '*.hsaco'|ForEach-Object{[pscustomobject]@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash}}|ConvertTo-Json|Set-Content "$r\baseline-modules.json"
