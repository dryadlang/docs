# @std/text

Byte-indexed UTF-8 text operations, ASCII transforms, split/join/replace, numeric
parse/format, `StringBuilder`, and `TextView`.

**Source:** `src/stdlib/@std/text/text.dryad`

## Import

```dryad
import {
    Text_Length, Text_CharAt, Text_CodePointAt, Text_FromCodePoint,
    Text_Slice, Text_Substring, Text_IndexOf, Text_LastIndexOf,
    Text_Includes, Text_StartsWith, Text_EndsWith, Text_Equals, Text_Compare,
    Text_CodePoints, Text_CharCount,
    Text_ToLowerAscii, Text_ToUpperAscii, Text_Trim, Text_TrimStart, Text_TrimEnd,
    Text_Repeat, Text_PadStart, Text_PadEnd,
    Text_Split, Text_Join, Text_Replace, Text_ReplaceAll,
    Text_ParseInt, Text_FormatInt, Text_ParseFloat, Text_FormatFloat,
    StringBuilder, TextView
} from "@std/text/text";
```

Strings are converted to a `Buffer` (from `@std/buffers/buffer`) once per operation and
never mutated in place. Every operation that returns a value returns a `[value, error]`
tuple; the text module itself owns no memory beyond the temporaries it allocates and
disposes inside each call.

## Error convention

- Functions that produce a value return `[value, error]`: on success `error` is `null`; on
  failure `value` is a neutral default (`""`, `0`, `0.0`, `false`, `-1`, `[]`, or `null`)
  and `error` is set.
- Methods that produce no value (`StringBuilder.append*`, `StringBuilder.clear`) return
  `null | error`.
- A non-string argument yields `ArgumentOutOfRangeException`; a `null` argument yields
  `ArgumentNullException`. A `null` buffer yields `ArgumentNullException`; out-of-range byte
  indices, code points, counts, bases, or `decimals` yield `ArgumentOutOfRangeException`.
- Invalid UTF-8 (bad leading byte, truncation, overlong form, surrogate, or values above
  `0x10FFFF`) yields `Exception`. Numeric parse failures (no digits, invalid digit,
  overflow, unexpected trailing characters) yield `ArgumentOutOfRangeException`.

## Byte vs code point

`@std/text` is **byte-indexed**: offsets, indices, lengths, and `start`/`end`/`count`
arguments are **bytes**, not Unicode code points. Multi-byte characters therefore occupy
more than one index.

| Function | Unit of measure |
|----------|-----------------|
| `Text_Length`, `Text_CharAt` | bytes |
| `Text_Slice`, `Text_Substring` | byte offsets |
| `Text_IndexOf`, `Text_LastIndexOf` | byte indices |
| `Text_Repeat`, `Text_PadStart`, `Text_PadEnd` | byte length |
| `Text_CodePointAt`, `Text_CodePoints`, `Text_CharCount`, `Text_FromCodePoint` | code points |

For example, `"é"` is 2 bytes and 1 code point: `Text_Length("é")` is `2`,
`Text_CharCount("é")` is `1`, and `Text_CodePointAt("é", 0)` is `233` (U+00E9).

`Text_CharAt(text, index)` returns the **single byte** at `index` as a one-byte string —
it does not decode. Slicing inside a multi-byte character produces a partial (invalid)
UTF-8 byte sequence; `Text_CodePointAt`, `Text_CodePoints` and `Text_CharCount` validate
UTF-8 and reject such input with an error.

## API

### Inspection and access

| Function | Returns | Description |
|----------|---------|-------------|
| `Text_Length(text)` | `[int, error]` | Byte length of `text` |
| `Text_CharAt(text, index)` | `[string, error]` | The single byte at byte `index` |
| `Text_CodePointAt(text, byteIndex)` | `[int, error]` | Decoded code point at `byteIndex` |
| `Text_FromCodePoint(codePoint)` | `[string, error]` | Encode a code point as UTF-8 |
| `Text_Slice(text, start, end)` | `[string, error]` | Bytes `[start, end)` |
| `Text_Substring(text, start, count)` | `[string, error]` | `count` bytes from byte `start` |
| `Text_CodePoints(text)` | `[[int], error]` | Array of every code point |
| `Text_CharCount(text)` | `[int, error]` | Number of code points |

### Search and comparison

| Function | Returns | Description |
|----------|---------|-------------|
| `Text_IndexOf(text, needle)` | `[int, error]` | First byte index of `needle`, `-1` if absent |
| `Text_LastIndexOf(text, needle)` | `[int, error]` | Last byte index of `needle`, `-1` if absent |
| `Text_Includes(text, needle)` | `[bool, error]` | Whether `needle` occurs |
| `Text_StartsWith(text, prefix)` | `[bool, error]` | Prefix test |
| `Text_EndsWith(text, suffix)` | `[bool, error]` | Suffix test |
| `Text_Equals(a, b)` | `[bool, error]` | Same byte content |
| `Text_Compare(a, b)` | `[-1 \| 0 \| 1, error]` | Bytewise lexicographic compare |

### ASCII transforms, trim, repeat and pad

| Function | Returns | Description |
|----------|---------|-------------|
| `Text_ToLowerAscii(text)` | `[string, error]` | Lowercase `A`–`Z` only |
| `Text_ToUpperAscii(text)` | `[string, error]` | Uppercase `a`–`z` only |
| `Text_Trim(text)` | `[string, error]` | Strip leading and trailing ASCII whitespace |
| `Text_TrimStart(text)` | `[string, error]` | Strip leading ASCII whitespace |
| `Text_TrimEnd(text)` | `[string, error]` | Strip trailing ASCII whitespace |
| `Text_Repeat(text, count)` | `[string, error]` | `text` repeated `count` times |
| `Text_PadStart(text, length, pad)` | `[string, error]` | Left-pad to byte `length` with `pad` |
| `Text_PadEnd(text, length, pad)` | `[string, error]` | Right-pad to byte `length` with `pad` |

### Split, join and replace

| Function | Returns | Description |
|----------|---------|-------------|
| `Text_Split(text, separator)` | `[[string], error]` | Split on `separator` (empty rejected) |
| `Text_Join(parts, separator)` | `[string, error]` | Join an array of strings |
| `Text_Replace(text, needle, replacement)` | `[string, error]` | Replace the first occurrence |
| `Text_ReplaceAll(text, needle, replacement)` | `[string, error]` | Replace every non-overlapping occurrence |

### Numeric parse and format

| Function | Returns | Description |
|----------|---------|-------------|
| `Text_ParseInt(text, base)` | `[int, error]` | Parse a signed integer |
| `Text_FormatInt(value, base)` | `[string, error]` | Format an integer (lowercase digits) |
| `Text_ParseFloat(text)` | `[float, error]` | Parse a decimal float |
| `Text_FormatFloat(value, decimals)` | `[string, error]` | Format a float with `decimals` places |

## ASCII whitespace

Trim removes exactly these bytes: `0x20` (space), `0x09` (tab), `0x0A` (LF), `0x0D` (CR).
No other Unicode whitespace is trimmed.

## Numeric bases

`Text_ParseInt` and `Text_FormatInt` accept base `2`, `8`, `10`, or `16` only. Parsing
accepts an optional single leading `'+'`/`'-'` followed by one or more digits; it accepts
uppercase and lowercase hex digits (`0-9`, `a-f`, `A-F`) but no whitespace, underscores,
or `0x` prefix. `Text_FormatInt` always emits lowercase digits; `0` yields `"0"` and
negative values get a leading `'-'`. `INT64_MIN` (`-9223372036854775808`) is representable
in both directions.

## Float parsing and formatting

`Text_ParseFloat` accepts an optional sign, a decimal mantissa, and an optional `e`/`E`
exponent. Overflow — an exponent or scaled mantissa beyond the double range, such as
`"1e309"`, `"1e1000"`, or a large mantissa scaled up — returns a `Float overflow` error;
underflow (e.g. `"1e-400"`) returns `0.0` rather than an error.

`Text_FormatFloat(value, decimals)` requires `decimals` in `0..15`. Non-finite values
(`NaN`, `+Inf`, `-Inf`) are rejected, and a finite value whose scaled magnitude reaches 2^63
(roughly `|value| × 10^decimals ≥ 9.22e18`) returns a range error. Rounding is **half away
from zero**: the magnitude is rounded at `0.5`, then the sign is reapplied, so `-0.5`
formats to `-1` (with `decimals=0`) and `3.7` to `4`. A negative value that rounds to zero
is written with a leading `'-'` (printf-style negative zero), e.g. `Text_FormatFloat(-0.4, 0)`
is `"-0"`.

## StringBuilder

`StringBuilder` builds a string incrementally in an owned internal `Buffer`, avoiding the
quadratic copying of repeated string concatenation.

```dryad
let sb = new StringBuilder(8);   // initial capacity, default 16, minimum 1
sb.append("foo");
sb.appendChar("b");
sb.appendBuffer(someBufferSlice);
let text = sb.toString();
let n = sb.length();             // bytes accumulated so far
sb.clear();                      // reset length to 0, keep capacity
```

| Method | Returns | Description |
|--------|---------|-------------|
| `constructor(initialCapacity = 16)` | — | Allocate the internal buffer |
| `append(text)` | `null \| error` | Append a string (UTF-8 bytes) |
| `appendChar(ch)` | `null \| error` | Append a single-byte string |
| `appendBuffer(buf)` | `null \| error` | Append the bytes of a `Buffer` |
| `toString()` | `string` | Snapshot the accumulated bytes as a string |
| `clear()` | `null` | Reset the length to `0`, keep capacity |
| `length()` | `int` | Number of bytes accumulated |
| `dispose()` | `null` | Release the internal buffer; reset capacity and length to `0` |

**Ownership:** the builder owns its internal `Buffer`; the caller should call `dispose()`
when finished to release it. The buffer is never exposed to callers and must not be
disposed directly. `dispose()` is idempotent — calling it twice is safe — and after it
returns, `append`/`appendChar`/`appendBuffer` report the disposed-buffer error, `length()`
is `0`, and `toString()` returns `""`. Capacity starts at `initialCapacity` (clamped to a
minimum of `1`; a non-integer argument falls back to `16`) and doubles as needed, with the
doubling guarded against 64-bit overflow.

## TextView

`TextView` is a **non-owning view** over a caller-provided `Buffer`. It never allocates or
disposes the buffer; the caller must keep the buffer alive for as long as the view is used.

```dryad
let buf = Buffer_FromString("aé€");
let view = new TextView(buf, 0, 6);   // offset, length (length -1 = to the end)
let n = view.length();                // 6 bytes
let cp = view.codePointAt(1);         // [233, null] — the 'é'
let sub = view.slice(1, 3);           // a TextView over bytes [1, 3)
let text = view.toString();           // "aé€"
Buffer_Dispose(buf);                  // caller owns and frees the buffer
```

| Method | Returns | Description |
|--------|---------|-------------|
| `constructor(buffer, offset = 0, length = -1)` | — | Resolve and validate `[offset, length)` |
| `length()` | `int` | Byte length of the view (or the constructor error) |
| `slice(start, end)` | `TextView` | A sub-view over bytes `[start, end)` |
| `codePointAt(byteIndex)` | `[int, error]` | Decoded code point at `byteIndex` |
| `toString()` | `string` | Snapshot the view's bytes as a string |

If the constructor arguments are invalid (`null` buffer, negative offset, out-of-range
length, or a range that ends inside a multi-byte code point), the error is recorded and
every method returns it. `codePointAt` additionally rejects a byte index whose UTF-8
sequence runs past the view boundary.

## Examples

Slice by code point — distinguish bytes from code points:

```dryad
let text = "aé€";                       // 3 code points, 6 bytes
let bytes = Text_Length(text);          // [6, null]
let chars = Text_CharCount(text);       // [3, null]

// 'é' (U+00E9) lives at byte offsets [1, 3); slice it out:
let cp = Text_CodePointAt(text, 1);     // [233, null]
let e = Text_Slice(text, 1, 3);         // ["é", null]
```

Parse and format an integer:

```dryad
let parsed = Text_ParseInt("ff", 16);   // [255, null]
let hex = Text_FormatInt(parsed[0], 16); // ["ff", null]
let negative = Text_FormatInt(-17, 10);  // ["-17", null]
```

Build a string in a loop:

```dryad
let sb = new StringBuilder();
let i = 0;
while (i < 10) {
    let n = Text_FormatInt(i, 10);
    sb.append(n[0]);
    i = i + 1;
}
let joined = sb.toString();             // "0123456789"
sb.dispose();                           // release the internal buffer
```

## Limitations

String functions call the same byte operations as `@std/bytes`; AOT evaluation of the
bitwise operators they rely on is not implemented yet (see
[syntax.md](../language/syntax.md)). The interpreter and bytecode VM are the supported
tiers.
