$ErrorActionPreference = 'Stop'
& 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie'
if ($LASTEXITCODE -ne 1) { throw 'exit game first' }
$games = @('C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64', 'C:\XboxGames\Onimusha- Way of the Sword\Content')
$lock = [IO.File]::Open('D:\DLSSNR-Lab\gpu.lock', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    foreach ($idx in 0, 1) {
        $base = $games[$idx]
        $m = Get-Content 'D:\DLSSNR-Lab\game-install-20261014\backup-20261014-233615\game-' + $idx + '\manifest.json' -Raw | ConvertFrom-Json
        foreach ($f in $m) {
            $dst = Join-Path $base $f.relative
            if ($f.existed) {
                New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
                Copy-Item (Join-Path ('D:\DLSSNR-Lab\game-install-20261014\backup-20261014-233615\game-' + $idx) $f.relative) $dst -Force
                if ((Get-FileHash $dst).Hash.ToLower() -ne $f.sha256) { throw "restore mismatch $dst" }
            } else {
                Remove-Item $dst -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Output 'ROLLBACK_COMPLETE'
} finally {
    $lock.Dispose()
    Remove-Item 'D:\DLSSNR-Lab\gpu.lock'
}