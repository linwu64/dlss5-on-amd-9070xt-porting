0.43 source bundle and binary provenance

The included re9-presr-source.tar.gz contains the unchanged modified GPL-3.0 OptiScaler host from upstream commit8f71f73bfc836a37936e7cee6701750ad4e8bfec and refreshed lmxxf MIT HIP/runtime sources at payload10982cf4. Host dxgi.dll SHA256 aa3761f2cdb0d9a4653732bd430019ff421b3ce9471fe3697b553dc6d71714a2 is unchanged from0.42. Host dependencies, license files and build instructions remain included.

The lmxxf subtree is refreshed from the current repository; packaging documentation is updated for0.43. Its SOURCE_COMMIT.txt pins the binary payload source10982cf4. Follow BUILD-SOURCE.txt and build-lmxxf-runtime.sh. HIP recipes are in third_party/lmxxf/hip/build-modules.ps1. Use the current rtc_compile.cpp, not the historical global compiler that ignored gfx1200.

Prevalidated final binaries/modules are reused; packaging does not rebuild the HIP modules or rerun ABBA. Formal local package receipts are in Development/releases/0.43 in the repository.
