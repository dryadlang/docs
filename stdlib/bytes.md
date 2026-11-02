# @std/bytes

Byte operations over `Buffer` — copy, fill, compare, search, concat, trim, and hex.

**Source:** `src/stdlib/@std/bytes/bytes.dryad`

## Import

```dryad
import {
    Bytes_Copy, Bytes_Fill, Bytes_Compare, Bytes_Equals,
    Bytes_IndexOf, Bytes_Concat, Bytes_Trim, Bytes_ToHex, Bytes_FromHex
} from "@std/bytes/bytes";
```

`Buffer` (from `@std/buffers/buffer`) is the only byte container. Offsets and counts are in bytes; byte values are integers `0..255`.

## Error convention

- Functions that produce no value return `null | error`: `null` on success, otherwise an error from `@std/core/exceptions`.
- Functions that produce a value return `[value, error]`: on success `error` is `null`; on failure `value` is a neutral default (`null`, `false`, `0`, or `-1`) and `error` is set.
- A `null` buffer yields `ArgumentNullException`; out-of-range offsets, counts or byte values yield `ArgumentOutOfRangeException`.
- Hex parsing errors (odd length, invalid digit) yield `Exception`.

## API

| Function | Returns | Description |
|----------|---------|-------------|
| `Bytes_Copy(dst, dstOffset, src, srcOffset, count)` | `null \| error` | Copy `count` bytes (overlap-safe) |
| `Bytes_Fill(buf, offset, count, value)` | `null \| error` | Set `count` bytes from `offset` to `value` |
| `Bytes_Compare(a, b)` | `[-1 \| 0 \| 1, error]` | Lexicographic compare; shorter prefix sorts first |
| `Bytes_Equals(a, b)` | `[bool, error]` | Same length and contents |
| `Bytes_IndexOf(buf, byte)` | `[index, error]` | First index of `byte`, `-1` if absent |
| `Bytes_LastIndexOf(buf, byte)` | `[index, error]` | Last index of `byte`, `-1` if absent |
| `Bytes_Contains(buf, byte)` | `[bool, error]` | Whether `byte` occurs |
| `Bytes_StartsWith(buf, prefix)` | `[bool, error]` | Prefix test |
| `Bytes_EndsWith(buf, suffix)` | `[bool, error]` | Suffix test |
| `Bytes_Concat(a, b)` | `[Buffer, error]` | New buffer with `a` followed by `b` |
| `Bytes_Repeat(buf, count)` | `[Buffer, error]` | New buffer with `buf` repeated `count` times |
| `Bytes_Trim(buf)` | `[Buffer, error]` | View without leading and trailing whitespace |
| `Bytes_TrimStart(buf)` | `[Buffer, error]` | View without leading whitespace |
| `Bytes_TrimEnd(buf)` | `[Buffer, error]` | View without trailing whitespace |
| `Bytes_ToHex(buf)` | `[string, error]` | Lowercase hex encoding |
| `Bytes_FromHex(text)` | `[Buffer, error]` | Decode hex text into a new buffer |

## Ownership

- `Bytes_Concat`, `Bytes_Repeat` and `Bytes_FromHex` return new buffers; the caller disposes them with `Buffer_Dispose`.
- `Bytes_Trim`, `Bytes_TrimStart` and `Bytes_TrimEnd` return **zero-copy, non-owning views** of the input. The parent buffer must outlive the view; do not dispose the parent while the view is in use.

## Whitespace

Trim removes these bytes only: `0x20` (space), `0x09` (tab), `0x0A` (LF), `0x0D` (CR).

## Hex

`Bytes_ToHex` always emits lowercase digits (`0-9a-f`). `Bytes_FromHex` accepts both lowercase and uppercase digits, and requires an even number of digits.

## Examples

Copy between slices:

```dryad
let src = Buffer_FromString("Hello");
let dst = Buffer_New(5);
let err = Bytes_Copy(dst, 0, src, 0, 5);
```

Concat:

```dryad
let a = Buffer_FromString("foo");
let b = Buffer_FromString("bar");
let joined = Bytes_Concat(a, b);
if (joined[1] == null) {
    let text = Buffer_AsString(joined[0]);   // "foobar"
    Buffer_Dispose(joined[0]);
}
```

Hex round-trip:

```dryad
let buf = Buffer_FromString("Hi");
let hex = Bytes_ToHex(buf);          // ["4869", null]
let back = Bytes_FromHex(hex[0]);    // [Buffer("Hi"), null]
```

## Limitations

Byte operations use bitwise operators, and AOT evaluation of bitwise operators is not implemented yet (see [syntax.md](../language/syntax.md)). The interpreter and bytecode VM are the supported tiers.
