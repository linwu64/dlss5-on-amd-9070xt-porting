# C32 score upper-clamp elimination: proof-first experiment

Base `b93cc043`, authorized after the WorkingPlan update. No production source,
configuration or game deployment changes. `prove.py` is CPU asset/ELF inspection
and a conservative analytic bound, not observed activation maxima. Mathematics/ISA semantics, exact-weight routing and bounded hardware gates are
recorded separately below; the single Frame ABBA is complete: STOP, no reliable performance benefit; production remains unchanged.

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
`g32=32*2^-24/(1-32*2^-24)`,
`a=(1-2^-11)*(1-g32)` and `b=32*2^-25*(1+g32)`. Then D>=a*S-b and
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
  used**. This was an initial-stage condition; the later primitive and certificate closure below resolved it.
- Shared chain exports serve both eligible and ineligible layers. Qualification
  must be tied to complete actual weight SHA, not only function name/gamma or
  sample max. Unknown weights/variants retain the old kernel.

The preceding paragraph records the initial proof stage. Subsequent actual primitive, mapped and Frame gates are recorded below.
The next gate is independent review of these contracts. If it cannot be closed,
record a proof failure and stop, rather than escalating to random testing and
calling it lossless.

## Closed proof domain and actual gates

The norm WMMA **outputs F32**, not Half. Its Half inputs multiply exact ones;
32 nonnegative F32 accumulation terms use the standard gamma32 error bound,
independent of association. The stock programmed rounding/denormal modes and
public fused-FMA instruction contract are the machine model for this proof.
The authorized 84738 single dispatch exhausts all 65,536 Half input bit patterns
in each of the 32 positions of the original two-K16 norm operand. It returned
zero finite/subnormal bit differences, zero signed-infinity differences, zero
NaN-class differences and zero numeric-zero differences. Independent Python
Half-to-F32 decoding of all 2,097,152 downloaded results agrees; raw SHA
`2dd1d8feb5f1e5bf92096a29543702fd8f0ae1740bf5e6cbd01c7fe007e05eba`.
This rejects the suspected fixed-flush behavior for this instruction/mode. It
is semantic evidence, not a random maximum-activation proof or portable ISA test.
The alternative flush-model certificate has **zero** qualified layers and remains
recorded to show why that premise mattered.

Exception cases close under the same published FMA/format contracts:

- For finite FP8 feature components and finite packed coefficients, raw Q/K
  dot magnitudes are at most `32*448²`, hence finite F32. No raw F32 overflow is
  possible. Half-square overflow produces positive infinity; the nonnegative
  norm sum is infinity, IEEE native RSQ gives zero, and finite raw components
  normalize to signed zero. The primitive confirms the Half infinity input
  propagates through the norm WMMA.
- A feature FP8 NaN propagates through each weighted Q/K dot, including a zero
  coefficient, under fused-FMA NaN semantics. The raw vector and Half norm are
  NaN. The original denominator max selects the positive floor for NaN; the
  raw NaN remains NaN through multiplication and site3 MODE-based FP8 packing.
  Its score dot is NaN, and the **unchanged original ternary lower max** selects
  the lower value. Applying or removing the upper min then gives the same bits.
  No NaN-payload identity is claimed. FP8 E4M3FN has no infinity; actual packed
  weights are finite and the site's MODE saturation/NaN behavior is unchanged.
- Zero/small norms use the positive floor already covered by `a*S-b`. Every
  nonzero finite raw Q/K sum is on the FP8-product lattice (at least 2^-18 in
  magnitude); finite norm denominators are at most `32*65504`. With the actual
  finite nonzero scales, norm multiplications stay normal F32, so their relative
  rounding bounds apply. Signed zeros cannot increase the bound.

Main independently reviewed the formula, required the exact gamma32 expression,
and accepted preparing a candidate only for the seven certified full-weight SHAs.
This is a lossless statement **under the locked machine/model domain**, not an
unqualified promise for arbitrary devices, macros, weights or FP formats.

The clone changes only the score upper clamp and names new exports `_nohi`.
Actual ISA retains Half-square/RSQ/F16 and FP8 WMMA counts and separate affine
multiply/add; all five relevant function types lose their 32 upper comparisons.
Static total instruction counts decrease for three types but increase for two;
that is not a speed result. Private host routing hashes complete immutable packed
weights once, cold-verifies selected stock `f46b8af..` and the clone, and preloads
the clone plus five functions **before producer waits**. Run uses only cached
function handles and certified GPU pointers; last three layers/unknown weights
retain stock. First scope is FAST1/1920x1152/MP1/graph0/ordinary temporal mode.

Actual mapped unit 51888 passed four independently poisoned runs against the
frozen real output, all 17,694,720 bytes, no FP8 NaNs and unchanged 256-byte tails.
Actual Frame gate 72895 passed baseline/nohi three-frame raw/finite/repeat checks;
both first and last hashes are `0900e489a397302b93074a878c694b9c3e7c3400cfe2dfdd3cc727abe1050f4a`.
Actual candidate routing was 21 NoHi / 9 stock, seven certified pointers; baseline
was 0 / 30. Both retained active persistent Swin and three actual Auto-pulse
records/acceptances. These are numerical/dispatch gates, not performance. Main
owns the one subsequent ABBA and its adoption decision.

## Final decision — 2026-10-12

Actual Frame ABBA `25355` completed with four child exits 0, eight equal first/last gold hashes and exact route counters. Mean wall delta was −5.269 µs and p99 delta −17.790 µs, while control drift was +47.546 µs and candidate drift +19.875 µs. **STOP: mathematical/correctness success, no reliable Frame speed benefit; do not enable by default.** Independent timing evidence is retained by the sibling `bound-and-compact` experiment, without duplicating raw CSVs here.

These A runs used the original `b93cc043` shared header before B was merged. Both private-tree generators now reject a different header SHA or `HIP_COMPACT_VIT_EXPAND`, requiring an original-baseline checkout for reproduction. This final guard change was not rebuilt or run on the GPU; it does not change the already measured candidate.
