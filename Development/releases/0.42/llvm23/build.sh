#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../../.." && pwd)
out=/home/lmxxf/work/dlss5-release-042-build/prebuilt
mkdir -p "$out"
python3 "$root/Development/tools/llvm-fork/compile-modules.py" --hip "$root/hip" --bin /home/lmxxf/work/llvm-build-23/bin --out "$out" --targets gfx1200 gfx1201 --compiler-rows llvm23 --target-feature=-real-true16 --row-opts --jobs 4 > "$out/build.log" 2>&1
