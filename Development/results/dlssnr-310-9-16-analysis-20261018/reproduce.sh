#!/usr/bin/env bash
set -euo pipefail
# Arguments: pinned upstream checkout, new DLL, old310.8 DLL, external scratch directory.
upstream=${1:?191b97b541 source tree}
new_dll=${2:?310.9.16 DLL}
old_dll=${3:?310.8.0 DLL}
analysis_scratch=${4:?external scratch directory}
report_dir=$(cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$analysis_scratch/python" "$analysis_scratch/cpp" "$report_dir/plans"
bash "$upstream/linux/package/model-tools/extract_model.sh" "$new_dll" "$analysis_scratch/python"
g++ -std=c++17 -O2 "$upstream/windows/package/model-tools/dlssnr_extract_model.cpp" -o "$analysis_scratch/extractor-native"
"$analysis_scratch/extractor-native" "$new_dll" "$analysis_scratch/cpp"
cmp "$analysis_scratch/python/dlssnr.bin" "$analysis_scratch/cpp/dlssnr.bin"
cmp "$analysis_scratch/python/dlssnr-small.bin" "$analysis_scratch/cpp/dlssnr-small.bin"
g++ -std=c++17 -O2 "$report_dir/plan_probe.cpp" "$upstream/linux/src/core/nr_native_plan.cpp" -I "$upstream" -o "$analysis_scratch/plan_probe"
while read -r w h; do
 for model in small old; do
  "$analysis_scratch/plan_probe" "$w" "$h" "$model" > "$report_dir/plans/${w}x${h}-${model}.txt"
 done
done <<'GEOMETRIES'
1920 1080
1600 900
1280 720
2560 1440
3840 2160
1288 720
1600 908
1001 777
1919 1079
320 320
1920 1152
1600 960
1280 768
GEOMETRIES
python3 "$report_dir/analyze.py" --dll "$new_dll" --old-dll "$old_dll" --upstream "$upstream" --packs "$analysis_scratch/python" --out "$report_dir"
