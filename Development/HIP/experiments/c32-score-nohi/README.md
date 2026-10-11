# C32 score upper-clamp elimination: proof-first experiment

Base `b93cc043`, authorized after the WorkingPlan update. No production source,
configuration or game deployment changes. `prove.py` is CPU asset/ELF inspection
and a conservative analytic bound, not observed activation maxima. **Not yet
admitted for shader changes:** WMMA exceptional/denormal semantics require closure.

## Actual identity and source

Stock file `/home/lmxxf/work/dlss5-dx12-artifacts/c32-family-20261010/c32-wave1-fast.hsaco`
hashes to `f46b8af25841a9878ce34544f4b3465f71da36fec9f08f48ad33b48f08c1ee52`,
the previously verified FAST1 stock ELF. Disassembly was produced by the existing
LLVM23 `llvm-objdump -d --mcpu=gfx1201`, with no compilation/device access.
Actual score code uses lower-bound max then upper-bound compares/selects; it is
not already one fmed3. Old simplified `A-chain-LLVM23.s` is not used as evidence.
All exported `c32_wave1_*.kd` descriptors have floating mode `0xf0`: RNE and
preserved F32/F16 input/output subnormals. This establishes the programmed mode,
not an assumption that every matrix instruction necessarily obeys it.

Current recipe enables `CW_ACT_FMED3=1` and does not enable `CW_FMED3_CLAMP`.
`wave_owned_c32.inc` score site forms `acc + bias`, separately multiplies by
0.044921875 and adds 1.30078125, clamps to [1.03125,1.5693359375], then performs
bit exponent mapping. Only deletion of the upper bound is being considered.
Lower clamp, half-square single rounding, norm sum, native RSQ, FP8 conversion,
MMA order and bit mapping must remain unchanged.

The 50843 actual ledger binds ten layer instances to seven distinct exports.
Only their ten 32,900-byte attention weights were read from the frozen D: capture;
all bytes are checked against its original result-files manifest. QKV/projection
packed bytes contain no FP8 NaNs; scale and all 4096 F32 biases are finite.
The original gamma at F32 offset 8192 is read without re-quantization. Weights,
ledger and stock hashes are in `results/certificate.json`.

## Finite-domain analytic bound (conditional ISA contract)

Let x be a 32-component raw Q/K vector, S=sum(x_i²), h_i=HalfRNE(x_i²),
D the two F16-input/F32-accumulator sums, d=max(D,delta),
delta=6.198883056640625e-5. For preserved subnormal HalfRNE squares,
`h_i >= (1-2^-11)*x_i² - 2^-25`.
Under normal F32 summation of these nonnegative half values, deliberately using
32 rounding factors rather than the tighter count, define
`a=(1-2^-11)*(1-32*2^-24)` and
`b=32*2^-25*(1+32*2^-24)`. Then D>=a*S-b and
`S/d <= (1+b/delta)/a` (split at a*S-b=delta).

LLVM's AMDGPU source explicitly uses a 1-ULP contract for `v_rsq_f32`:
[AMDGPUCodeGenPrepare.cpp](https://github.com/llvm/llvm-project/blob/main/llvm/lib/Target/AMDGPU/AMDGPUCodeGenPrepare.cpp),
locally read at lines 901/913. It also notes flushing for this native operation;
d is at least delta and hence a normal F32 value, so its subnormal-input case
is not used. The arithmetic bound allows 2^-22 relative RSQ error (looser than
one normal F32 ULP) and two F32 multiplication roundings. Thus pre-FP8 norm is
bounded by `|gamma|*C` for Q and C for K, where C is emitted by the script.
This is a sourced error envelope, not a chosen empirical one-percent allowance.

E4M3FN nearest conversion obeys the loose component bound
`|quant(v)| <= (17/16)*|v| + 2^-10`; finite saturation only decreases magnitude.
By the triangle inequality, Q norm <= (17/16)*|gamma|*C+sqrt(32)*2^-10,
K norm <= (17/16)*C+sqrt(32)*2^-10. Cauchy-Schwarz plus F32 dot and affine
rounding allowances then gives the script's per-layer affine upper bound.
An additional 1e-5 outward allowance exceeds binary64 calculation error by
many orders. Eligibility margins are much larger than that allowance.

**Conditional results:** ordinals 0,1,2,3,4,156,157 have upper bounds
1.322..1.48472 below 1.5693359375. Ordinals 158,159,160 instead have bounds
1.75648,1.87577,1.81570: no certificate, and their original clamp must remain.
This does not prove that these final layers actually hit their clamp; failure
of a conservative bound is not a numerical counterexample.

## Exceptional-domain and remaining admission work

- Zero/small square sums use the strictly positive floor, already included in
  the bound. Signed zero cannot increase the score bound.
- Half-square overflow gives D=+Inf and native RSQ=0. Finite raw components then
  normalize to zero. This branch must be confirmed against the actual matrix
  exceptional contract, including how NaNs propagate from FP8 features.
- NaN score must still select the old lower clamp. NaN handling is not freely
  replaceable by a different min/max intrinsic. The original ternary max has
  NaN→lower behavior; preserve it exactly.
- FP8 format has no infinity, but MODE-based pack can emit NaN for an infinite
  intermediate. A descriptor mode alone is not proof of WMMA NaN propagation
  or Half subnormal retention. If a relevant WMMA instruction unconditionally
  flushes Half subnormals, the above lower bound is invalid and **must not be
  used**. No kernel candidate is generated until this is resolved.
- Shared chain exports serve both eligible and ineligible layers. Qualification
  must be tied to complete actual weight SHA, not only function name/gamma or
  sample max. Unknown weights/variants retain the old kernel.

No GPU query, shader compile, unit, Frame or performance claim has been made.
The next gate is independent review of these contracts. If it cannot be closed,
record a proof failure and stop, rather than escalating to random testing and
calling it lossless.
