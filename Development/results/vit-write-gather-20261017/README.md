# Producer-side ViT gather folding — STOP

Down30 writes directly in ViT order, Block38 writes directly in decoder raster/channel order, preserving Up39 vector loads. Gold 0900E489...0F4A 0 bit-diff. Compared with accepted decoder mode3; same host and module set in both arms, other candidates disabled.

Three ABBA rounds (240/slot, drop80): mean deltas +0.000513 / +0.001659 / +0.014902 ms; p99 +0.014445 / -0.037833 / +0.007254 ms. Pooled mean 9.128203125 -> 9.133894583 ms (+5.691us); pooled p99 -3.487us. No speed gain; not merged. Original samples remain in evidence.json and remote c2-* directories. Reduction in dispatches/index capacity is not a measured speed gain. No game or release modification.
