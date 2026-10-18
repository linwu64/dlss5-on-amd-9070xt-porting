0.44 source bundle and binary provenance

The archive includes the unchanged modified GPL-3.0 OptiScaler host at upstream8f71f73bfc836a37936e7cee6701750ad4e8bfec (dxgi.dll SHA256 aa3761f2cdb0d9a4653732bd430019ff421b3ce9471fe3697b553dc6d71714a2) and current lmxxf MIT HIP/runtime source. SOURCE_COMMIT.txt pins the exact binary source commit recorded by release.json.

Follow BUILD-SOURCE.txt and build-lmxxf-runtime.sh. HIP recipes remain in third_party/lmxxf/hip/build-modules.ps1. The 80 gfx1200/gfx1201 modules are reused from validated10982cf4; hosts are rebuilt for Small geometry, AE, MODE1 and hot switching. Small's93 weights and manifest coexist with the Original model.

Packaging checks all modules, all Small weight hashes, 44 shader compilation jobs per package, RE9 runtime smoke and every ZIP file's readback hash. Small differs from Original by design. Validation is in Development/results/small-complete-20261018 and formal receipts in Development/releases/0.44.

2026-10-18 F9 hotfix: host/runtime rebuilt with safe post-process output ownership, resident per-model caches and pre-wait preparation, immediate in-memory hotkeys and the writable Xbox Onimusha config mirror. Exact source commit is pinned in SOURCE_COMMIT.txt and release.json.
