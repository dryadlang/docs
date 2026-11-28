# @std/math

Numeric functions, constants and a seeded random generator, written in Dryad.

**Source:** `src/stdlib/@std/math/math.dryad`

## Import

```dryad
import { Math_Pi, Math_Sqrt, Math_Pow, Math_Sin, Math_Floor, Random } from "@std/math";

print(Math_Sqrt(2.0));
print(Math_Pow(2, 10));
print(Math_Floor(0.0 - 2.5));

let rng = new Random(42);
print(rng.nextInt(1, 6));
```

The package is a single module, so `@std/math` is also its barrel.

## Conventions

- Integer arguments are accepted wherever a float is; they are converted first.
- Floats follow IEEE 754. A domain error gives NaN (`Math_Sqrt(-1.0)`), a pole or overflow gives an
  infinity (`Math_Log(0.0)` is `-Infinity`, `Math_Exp(1000.0)` is `Infinity`).
- Functions that return an integer (`Math_Floor`, `Math_Ceil`, `Math_Round`, `Math_Trunc`) return the
  error `"value has no integer representation"` for NaN, infinities and floats outside the integer range.
- A non-number argument returns an `ArgumentException` message such as `"x must be a number"`.
- Results of `Math_Sqrt`, `Math_Exp`, `Math_Log*`, `Math_Sin`/`Cos`/`Tan`, `Math_Atan*`, `Math_Asin`,
  `Math_Acos` and `Math_Pow` are within a few units in the last place of the correctly rounded value.
- Dryad has no exponent literals and `%` only takes integers: write `0.001`, and use `Math_Fmod` for floats.

## Constants

| Name | Value |
|------|-------|
| `Math_Pi`, `Math_Tau` | π and 2π |
| `Math_E` | e |
| `Math_Ln2`, `Math_Ln10` | ln 2, ln 10 |
| `Math_Sqrt2` | √2 |
| `Math_MaxInt`, `Math_MinInt` | Largest and smallest integer (64-bit) |
| `Math_Infinity`, `Math_NaN` | IEEE infinity and NaN |

## API reference

### Classification, sign and comparison

| Function | Returns |
|----------|---------|
| `Math_IsNaN(x)` | `true` only for a float NaN (integers and non-numbers are `false`) |
| `Math_IsFinite(x)` | `true` for integers and finite floats; `false` for infinities, NaN and non-numbers |
| `Math_Abs(x)` | Absolute value, same type as `x` (`-0.0` gives `0.0`) |
| `Math_Sign(x)` | `-1`, `0` or `1` for integers; `-1.0`, `1.0`, or `x` itself for zeros and NaN |
| `Math_Min(a, b)`, `Math_Max(a, b)` | The smaller / larger argument, unchanged; NaN if either is NaN |
| `Math_Clamp(x, low, high)` | `x` limited to `[low, high]`; an error when `low > high` |

### Rounding

| Function | Returns |
|----------|---------|
| `Math_Trunc(x)` | Integer part, toward zero |
| `Math_Floor(x)` | Largest integer `<= x` |
| `Math_Ceil(x)` | Smallest integer `>= x` |
| `Math_Round(x)` | Nearest integer; halves round away from zero (`2.5` → `3`, `-2.5` → `-3`) |
| `Math_Fmod(x, y)` | Float remainder with the sign of `x` (exact); NaN when `y` is `0` or `x` is infinite |

### Powers, roots, logarithms

| Function | Returns |
|----------|---------|
| `Math_Sqrt(x)` | Square root as a float; NaN for negatives |
| `Math_IntSqrt(n)` | Largest integer `r` with `r * r <= n`, for integers `n >= 0` |
| `Math_Pow(base, exponent)` | Integer `base` and non-negative integer `exponent` give an integer (wrapping on overflow, like `*`); otherwise a float. Negative bases need an integral exponent (else NaN) |
| `Math_Exp(x)` | eˣ |
| `Math_Log(x)` | Natural logarithm; `-Infinity` at `0`, NaN for negatives |
| `Math_Log2(x)` | Base-2 logarithm; exact for powers of two |
| `Math_Log10(x)` | Base-10 logarithm; exact for powers of ten (`Math_Log10(1000)` is `3.0`) |
| `Math_Hypot(a, b)` | √(a² + b²) without intermediate overflow |

### Trigonometry (radians)

| Function | Returns |
|----------|---------|
| `Math_Sin(x)`, `Math_Cos(x)`, `Math_Tan(x)` | NaN for infinities, NaN, and \|x\| above about 3.37e9 (where argument reduction can no longer be exact) |
| `Math_Atan(x)` | In (-π/2, π/2) |
| `Math_Atan2(y, x)` | Angle of the point (x, y), in (-π, π] |
| `Math_Asin(x)`, `Math_Acos(x)` | NaN outside [-1, 1] |
| `Math_ToRadians(degrees)`, `Math_ToDegrees(radians)` | Unit conversion |

### Integers

| Function | Returns |
|----------|---------|
| `Math_Gcd(a, b)` | Greatest common divisor (non-negative) |
| `Math_Lcm(a, b)` | Least common multiple (non-negative); `0` if either is `0` |

### Random numbers

Not suitable for cryptography. `Random` is xorshift128 (period 2¹²⁸ − 1).

| Name | Returns |
|------|---------|
| `new Random(seed = null)` | A generator. The same integer seed always gives the same sequence; without a seed it is seeded from the clock and process id |
| `rng.nextUint32()` | Integer in [0, 2³²) |
| `rng.nextFloat()` | Float in [0.0, 1.0) with 53 random bits |
| `rng.nextInt(low, high)` | Integer in [low, high], both inclusive, without modulo bias. Bounds within ±2⁵³; errors for `low > high` or non-integers |
| `rng.nextBool()` | `true` or `false` |
| `rng.shuffle(items)` | Shuffles the array in place (Fisher–Yates) and returns it |
| `rng.choice(items)` | A random element, or `null` for an empty array |
| `Math_Random()` | `nextFloat()` from a shared default generator |
| `Math_RandomInt(low, high)` | `nextInt(low, high)` from the default generator |
| `Math_SetSeed(seed)` | `null`. Reseeds the default generator, so later calls repeat |
