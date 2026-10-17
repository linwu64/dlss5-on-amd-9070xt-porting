# Grouped downsample FP8 W16 — PASS

Down8/14/22/30: pooled E4M3 lattice values in byte LDS, W16 FP8 weights in a layout-tagged @ds-frag-f8w16 cache (same capacity in the measured fixed-mode session), two K16 WMMAs per K32 with original H(acc+sum) retained. Original padding/validity and pooling evaluation order retained. Missing export -> existing half path. Relative to accepted decoder mode3; rejected gather folding and other candidates disabled. Full1920x1152 Frame, Gold0900E489...0F4A, finite/repeat/Auto gates pass.

3 ABBA rounds, 240frames/slot drop80 (960/arm): mean delta -21.775/-17.083/-23.255us; p99 -34.692/-47.005/-10.743us. Pooled mean9.153535833->9.132831563ms (-20.704us), p99 -27.539us. Same host/modules in both arms. Original samples/identities in evidence.json; remote c3-* directories. No game installation/archive changes. Linux LLVM23 dual-target compilation plus actual COMGR target modules; gfx1200 compile only.
