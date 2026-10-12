$ErrorActionPreference='Stop'
$expected=@{ 'build.ps1'='133527A38A8B21D15186D7980E93CFB5ABAA00E8544BCBF5DC271A01B7CFD5E1';'candidate.hip'='49BAF406263D00BA74045CF06CBBFB0E29352F8B13EE075D39047A524FA7F9E3';'source.json'='1B96187D13F5DAB49B45E4B30A763A2B4807DC8F31C83DA8FCDD6DBFC5EFCE20' }
foreach($name in $expected.Keys){$p="D:\DLSSNR-Lab\$name";$f=Get-Item $p;if(!$f.CreationTimeUtc.ToString('o').StartsWith('2026-10-12T12:16:02.') -or (Get-FileHash $p).Hash -ne $expected[$name]){throw 'do not remove unknown file'}}
foreach($name in $expected.Keys){Remove-Item "D:\DLSSNR-Lab\$name";"REMOVED_CONFIRMED_NEW_OWN_FILE D:\DLSSNR-Lab\$name"}
