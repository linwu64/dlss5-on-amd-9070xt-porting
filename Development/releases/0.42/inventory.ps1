$ErrorActionPreference='Stop'
Get-ChildItem 'D:\給網友打包' -Recurse -Depth 1|Where-Object{$_.Name -match '0.41|0.42'}|Select-Object FullName,Length|ConvertTo-Json
Get-ChildItem 'D:\DLSSNR-Lab\release-041\prebuilt' -Recurse -File|Select-Object FullName,Length|ConvertTo-Json
Get-Content 'D:\DLSSNR-Lab\release-041\HIP\gfx1201\manifest.json' -Raw
