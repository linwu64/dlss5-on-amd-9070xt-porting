# Fused Up56/62/66 W16 FP8 — STOP

Up projection W16 FP8 variants built with canonical LLVM23 recipe for gfx1200/gfx1201. Original F16 paths preserved in both source and modules; main production source is unchanged.

First bounded test activated Up56/62 only: Gold0900 matches; 3 ABBA rounds (240/slot discard80,960/arm) mean deltas -0.670/-2.868/+14.202us, pooled +3.5547us; p99 +25.502/+3.083/+26.752us, pooled +20.987us. STOP for that form.

Independent dispatch trace (timing not used) confirms Up56/62 new *_up_lb_sh_f8w16 functions each3 calls, accepted decoder Up39/48 new functions each3 calls and four grouped Down *_f8w16 functions each3 calls. Up66 remained c32_wave1_up_b8: canonical CW_UP_LOW_BYTES=0 omitted original byte-low exports, so the first test did not exercise Up66. This corrects the original plan's assumption.

To complete the candidate, a distinct bounded host connects Body65 byte output to the already compiled c32_wave1_up_b8_lb_f8w16 export when mode1 and C32W16Mode1; baseline retains float Body65 -> old Up66. c5-full-native-gold actually invokes new Up66 (c32_stock_calls=3 vs baseline0). It FAILS Gold: candidate first raw differs in 2,768,436/3,732,480 half values from reference; all frames finite and internally repeatable. Gold wrapper throws/returns failure and releases lock. No performance test was run for this full form. Cause not isolated; do not attribute the failure to FP8 arithmetic or hardware generally.

Both forms remain experimental only. Raw first frames and original failed run are retained under remote five-bitexact-20261017/c5-full-native-gold; evidence.json preserves hashes, CSV and stderr. Graph and prior stopped routes were not reopened. Installed games and release archives unchanged.
