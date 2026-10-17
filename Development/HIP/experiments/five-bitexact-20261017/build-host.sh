#!/usr/bin/env bash
set -euo pipefail
out=${1:?output directory}
mkdir -p "$out"
x86_64-w64-mingw32-g++-posix -w -std=c++17 -O2 -static -municode -D_WIN32_WINNT=0x0A00 -DNATIVE_GAME_TILED_VERIFICATION -DDLSS5_USE_HIP -DHIP_SWIN_PERSISTENT=1 -I src -I Development/HIP Development/HIP/benchmark_live_capture.cpp -o "$out/frame.exe" -ld3d12 -ldxgi -ld3dcompiler -ldxguid
