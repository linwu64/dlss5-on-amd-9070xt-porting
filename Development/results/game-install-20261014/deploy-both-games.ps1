$ErrorActionPreference = 'Stop'
$root = 'D:\DLSSNR-Lab\game-install-20261014'
$games = @(
    'C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64',
    'C:\XboxGames\Onimusha- Way of the Sword\Content'
)
$hipRel = 'DLSS5-AMD\native-game-tiled-assets\HIP'

function Idle {
    & 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie'
    if ($LASTEXITCODE -ne 1) { throw 'game-check busy or failed' }
    if (Get-Process | Where-Object { $_.ProcessName -match 'Shipping|SB-Win64|Onimusha|^re9$|Magpie|SandFall|rtc_compile|benchmark|rt_bench|runtime-smoke' }) {
        throw 'game or GPU process active'
    }
}

Idle
if ([IO.DriveInfo]::new('D:\').AvailableFreeSpace -lt 100GB) { throw 'disk free space < 100GB' }

$expectedAddon = '91d8147188b950367d40ed041588a0591ccbc0d4627ff70702b9a4e68eb0cd26'
$expectedRuntime = '50c3b80b730fce925c65c83a803c42406e6644f03e0fb0ae71535bbd88567844'

if ((Get-FileHash "$root\dlss5-amd.addon64").Hash.ToLower() -ne $expectedAddon) { throw 'staged addon SHA mismatch' }
if ((Get-FileHash "$root\LmxxfNrRuntime.dll").Hash.ToLower() -ne $expectedRuntime) { throw 'staged runtime SHA mismatch' }
foreach ($arch in 'gfx1200', 'gfx1201') {
    if (@(Get-ChildItem "$root\HIP\$arch" -Filter '*.hsaco').Count -ne 40) { throw "staged $arch count != 40" }
}

# Build canonical SHA256SUMS for the 80 staged modules
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$stagedSums = @(Get-ChildItem "$root\HIP" -Recurse -Filter '*.hsaco' | Sort-Object FullName | ForEach-Object {
    $rel = $_.FullName.Substring(("$root\HIP\").Length).Replace('\', '/')
    "$((Get-FileHash $_.FullName).Hash.ToLower())  $rel"
})
if ($stagedSums.Count -ne 80) { throw "staged total hsaco != 80" }
[IO.File]::WriteAllLines("$root\HIP\SHA256SUMS", $stagedSums, $utf8NoBom)
foreach ($arch in 'gfx1200', 'gfx1201') {
    $archSums = @(Get-ChildItem "$root\HIP\$arch" -Filter '*.hsaco' | Sort-Object Name | ForEach-Object {
        "$((Get-FileHash $_.FullName).Hash.ToLower())  $($_.Name)"
    })
    [IO.File]::WriteAllLines("$root\HIP\$arch\SHA256SUMS", $archSums, $utf8NoBom)
}

$lock = [IO.File]::Open('D:\DLSSNR-Lab\gpu.lock', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    Idle
    # 1. Full backup of both games before touching anything
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupRoot = "$root\backup-$stamp"
    New-Item -ItemType Directory -Force $backupRoot | Out-Null

    $configBefore = @{}
    $oldBinaries = @{}

    for ($idx = 0; $idx -lt $games.Count; $idx++) {
        $base = $games[$idx]
        $bdir = "$backupRoot\game-$idx"
        New-Item -ItemType Directory -Force $bdir | Out-Null

        $rels = @(
            'dlss5-amd.addon64',
            'LmxxfNrRuntime.dll',
            '_storage_\LmxxfNrRuntime.dll',
            'DLSS5-AMD\default-config.txt',
            'DLSS5-AMD\custom-config.txt',
            'DLSS5-AMD\native-game-flags.txt',
            "$hipRel\SHA256SUMS",
            "$hipRel\gfx1200\SHA256SUMS",
            "$hipRel\gfx1201\SHA256SUMS"
        )
        $rels += @(Get-ChildItem "$root\HIP" -Filter '*.hsaco' -Recurse | ForEach-Object { "$hipRel\$($_.FullName.Substring(("$root\HIP\").Length))" })
        $rels += @(Get-ChildItem "$base\$hipRel" -Filter '*.hsaco' -Recurse | ForEach-Object { $_.FullName.Substring($base.Length + 1) })

        $manifest = @()
        foreach ($rel in ($rels | Sort-Object -Unique)) {
            $src = Join-Path $base $rel
            $exists = Test-Path $src
            $sha = ''
            if ($exists) {
                $sha = (Get-FileHash $src).Hash.ToLower()
                $dst = Join-Path $bdir $rel
                New-Item -ItemType Directory -Force (Split-Path -Parent $dst) | Out-Null
                Copy-Item $src $dst -Force
                if ((Get-FileHash $dst).Hash.ToLower() -ne $sha) { throw "backup readback mismatch for $src" }
            }
            $manifest += [ordered]@{ relative = $rel; existed = $exists; sha256 = $sha }
        }
        $manifest | ConvertTo-Json -Depth 5 | Set-Content "$bdir\manifest.json"

        foreach ($cfg in 'default-config.txt', 'custom-config.txt', 'native-game-flags.txt') {
            $cp = "$base\DLSS5-AMD\$cfg"
            if (Test-Path $cp) {
                $configBefore["$idx-$cfg"] = (Get-FileHash $cp).Hash.ToLower()
            }
        }
        foreach ($bin in 'dlss5-amd.addon64', 'LmxxfNrRuntime.dll', '_storage_\LmxxfNrRuntime.dll') {
            $bp = Join-Path $base $bin
            if (Test-Path $bp) {
                $oldBinaries["$idx-$bin"] = (Get-FileHash $bp).Hash.ToLower()
            }
        }
    }

    # Generate one-click rollback script
    $rb = @"
`$ErrorActionPreference = 'Stop'
& 'D:\DLSSNR-Lab\game-check.ps1' 'SB-Win64 Onimusha re9.exe SandFall Magpie'
if (`$LASTEXITCODE -ne 1) { throw 'exit game first' }
`$games = @('C:\Program Files (x86)\Steam\steamapps\common\StellarBlade\SB\Binaries\Win64', 'C:\XboxGames\Onimusha- Way of the Sword\Content')
`$lock = [IO.File]::Open('D:\DLSSNR-Lab\gpu.lock', [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    foreach (`$idx in 0, 1) {
        `$base = `$games[`$idx]
        `$m = Get-Content '$backupRoot\game-' + `$idx + '\manifest.json' -Raw | ConvertFrom-Json
        foreach (`$f in `$m) {
            `$dst = Join-Path `$base `$f.relative
            if (`$f.existed) {
                New-Item -ItemType Directory -Force (Split-Path -Parent `$dst) | Out-Null
                Copy-Item (Join-Path ('$backupRoot\game-' + `$idx) `$f.relative) `$dst -Force
                if ((Get-FileHash `$dst).Hash.ToLower() -ne `$f.sha256) { throw "restore mismatch `$dst" }
            } else {
                Remove-Item `$dst -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Output 'ROLLBACK_COMPLETE'
} finally {
    `$lock.Dispose()
    Remove-Item 'D:\DLSSNR-Lab\gpu.lock'
}
"@
    [IO.File]::WriteAllText("$root\rollback.ps1", $rb, $utf8NoBom)

    # 2. Deploy to Stellar Blade (idx 0) and Onimusha (idx 1) + run runtime-smoke on Onimusha's staged assets
    try {
        for ($idx = 0; $idx -lt $games.Count; $idx++) {
            Idle
            $base = $games[$idx]

            if (Test-Path "$base\dlss5-amd.addon64") {
                Copy-Item "$root\dlss5-amd.addon64" "$base\dlss5-amd.addon64" -Force
                if ((Get-FileHash "$base\dlss5-amd.addon64").Hash.ToLower() -ne $expectedAddon) { throw "addon readback failed in $base" }
            }
            foreach ($rtRel in 'LmxxfNrRuntime.dll', '_storage_\LmxxfNrRuntime.dll') {
                $rtDst = Join-Path $base $rtRel
                if (Test-Path $rtDst) {
                    Copy-Item "$root\LmxxfNrRuntime.dll" $rtDst -Force
                    if ((Get-FileHash $rtDst).Hash.ToLower() -ne $expectedRuntime) { throw "runtime readback failed in $rtDst" }
                }
            }

            foreach ($arch in 'gfx1200', 'gfx1201') {
                Copy-Item "$root\HIP\$arch\*.hsaco" "$base\$hipRel\$arch\" -Force
                Copy-Item "$root\HIP\$arch\SHA256SUMS" "$base\$hipRel\$arch\SHA256SUMS" -Force
                foreach ($f in Get-ChildItem "$root\HIP\$arch" -Filter '*.hsaco') {
                    $dstMod = "$base\$hipRel\$arch\$($f.Name)"
                    if ((Get-FileHash $dstMod).Hash.ToLower() -ne (Get-FileHash $f.FullName).Hash.ToLower()) {
                        throw "module readback mismatch: $dstMod"
                    }
                }
                if (@(Get-ChildItem "$base\$hipRel\$arch" -Filter '*.hsaco').Count -ne 40) {
                    throw "installed $arch module count != 40 in $base"
                }
            }
            Copy-Item "$root\HIP\SHA256SUMS" "$base\$hipRel\SHA256SUMS" -Force
            if ((Get-FileHash "$base\$hipRel\SHA256SUMS").Hash.ToLower() -ne (Get-FileHash "$root\HIP\SHA256SUMS").Hash.ToLower()) {
                throw "SHA256SUMS readback mismatch in $base"
            }

            # Verify user config files are byte-for-byte untouched
            foreach ($cfg in 'default-config.txt', 'custom-config.txt', 'native-game-flags.txt') {
                $cp = "$base\DLSS5-AMD\$cfg"
                if ($configBefore.ContainsKey("$idx-$cfg")) {
                    if ((Get-FileHash $cp).Hash.ToLower() -ne $configBefore["$idx-$cfg"]) {
                        throw "config file modified: $cp"
                    }
                }
            }
        }

        # Run runtime-smoke against staged LmxxfNrRuntime.dll + Onimusha's native-game-tiled-assets\HIP
        Idle
        $oniAssetsHip = "$($games[1])\$hipRel"
        $ErrorActionPreference = 'Continue'
        & 'D:\DLSSNR-Lab\release-042\payload\runtime-smoke.exe' "$root\LmxxfNrRuntime.dll" $oniAssetsHip 32 > "$root\smoke.stdout.log" 2> "$root\smoke.stderr.log"
        $smokeRc = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        if ($smokeRc -ne 0) { throw "runtime-smoke failed with exit code $smokeRc" }
        Write-Output "RUNTIME_SMOKE_OK exit=$smokeRc"

        # Verify Onimusha config files and modules are still untouched after smoke
        foreach ($cfg in 'default-config.txt', 'custom-config.txt', 'native-game-flags.txt') {
            $cp = "$($games[1])\DLSS5-AMD\$cfg"
            if ($configBefore.ContainsKey("1-$cfg")) {
                if ((Get-FileHash $cp).Hash.ToLower() -ne $configBefore["1-$cfg"]) {
                    throw "Onimusha config file modified after smoke: $cp"
                }
            }
        }
    } catch {
        Write-Error "Deploy failed, rolling back: $_"
        foreach ($idx in 0, 1) {
            $base = $games[$idx]
            $m = Get-Content "$backupRoot\game-$idx\manifest.json" -Raw | ConvertFrom-Json
            foreach ($f in $m) {
                $dst = Join-Path $base $f.relative
                if ($f.existed) {
                    Copy-Item (Join-Path "$backupRoot\game-$idx" $f.relative) $dst -Force
                } else {
                    Remove-Item $dst -Force -ErrorAction SilentlyContinue
                }
            }
        }
        throw
    }

    $receipt = [ordered]@{
        date = '2026-10-14'
        source_commit = 'be506729'
        backup_dir = $backupRoot
        rollback_script = "$root\rollback.ps1"
        addon_sha256 = $expectedAddon
        runtime_sha256 = $expectedRuntime
        hip_sha256sums_sha256 = (Get-FileHash "$root\HIP\SHA256SUMS").Hash.ToLower()
        stellar_blade = [ordered]@{
            path = $games[0]
            previous_addon_sha256 = $oldBinaries['0-dlss5-amd.addon64']
            installed_addon_sha256 = (Get-FileHash "$($games[0])\dlss5-amd.addon64").Hash.ToLower()
            hsaco_count = @(Get-ChildItem "$($games[0])\$hipRel" -Recurse -Filter '*.hsaco').Count
            config_untouched = $true
        }
        onimusha = [ordered]@{
            path = $games[1]
            previous_runtime_sha256 = $oldBinaries['1-LmxxfNrRuntime.dll']
            installed_runtime_sha256 = (Get-FileHash "$($games[1])\LmxxfNrRuntime.dll").Hash.ToLower()
            installed_storage_runtime_sha256 = (Get-FileHash "$($games[1])\_storage_\LmxxfNrRuntime.dll").Hash.ToLower()
            hsaco_count = @(Get-ChildItem "$($games[1])\$hipRel" -Recurse -Filter '*.hsaco').Count
            config_untouched = $true
        }
        runtime_smoke_exit = 0
    }
    $receipt | ConvertTo-Json -Depth 5 | Set-Content "$root\receipt.json"
    Write-Output "DEPLOY_BOTH_GAMES_SUCCESS backup=$backupRoot"
} finally {
    $lock.Dispose()
    Remove-Item 'D:\DLSSNR-Lab\gpu.lock'
    Write-Output 'LOCK_RELEASED'
}
