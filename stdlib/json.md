# @std/json

JSON ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)) parsing and serialization,
written in Dryad on top of `@std/text`.

**Source:** `src/stdlib/@std/json/` — `json.dryad` is the barrel, `parse.dryad` holds
`Json_Parse` and `Json_IsValid`, and `stringify.dryad` holds `Json_Stringify` and
`Json_StringifyPretty`.

## Import

```dryad
import { Json_Parse, Json_Stringify, Json_StringifyPretty, Json_IsValid } from "@std/json";
```

## Example

```dryad
import { Json_Parse, Json_Stringify, Json_StringifyPretty } from "@std/json";

let parsed = Json_Parse("{\"name\": \"dryad\", \"tags\": [\"lang\", \"vm\"], \"stars\": 42}");
if (parsed[1] != null) {
    print(parsed[1]);
} else {
    let doc = parsed[0];
    print(doc.name);          // dryad
    print(doc.tags[1]);       // vm
    doc.stars = doc.stars + 1;
    print(Json_Stringify(doc)[0]);
    // {"name":"dryad","stars":43,"tags":["lang","vm"]}
    print(Json_StringifyPretty(doc, 2)[0]);
}
```

## API

| Function | Returns | Description |
|----------|---------|-------------|
| `Json_Parse(text)` | `[value, error]` | Parse one JSON value |
| `Json_IsValid(text)` | `bool` | Whether `text` is exactly one valid JSON value |
| `Json_Stringify(value)` | `[string, error]` | Compact JSON text |
| `Json_StringifyPretty(value, indent = 2)` | `[string, error]` | Indented JSON text |

## Value mapping

| JSON | Dryad |
|------|-------|
| object | object (`__runtime_create_object()`); members read with `obj.key` or `__runtime_object_get` |
| array | array |
| string | string (UTF-8) |
| number without fraction or exponent that fits in 64 bits | integer |
| any other number | float, correctly rounded |
| `true` / `false` | boolean |
| `null` | `null` |

`Json_Parse("-0")` is the integer `0`, `Json_Parse("1e2")` is the float `100.0`, and
`Json_Parse("9223372036854775808")` (one above the int64 maximum) is a float. Duplicate
object keys keep the last value.

## Parsing

`Json_Parse` follows the RFC grammar strictly: no comments, no trailing commas, no
single quotes, no leading zeros, no unquoted keys. Strings decode every escape,
including `\uXXXX` surrogate pairs; an unpaired surrogate is an error. Raw control
characters (below `0x20`) inside strings are rejected; other bytes are copied as is.

Errors name the problem and where it is, counting lines from 1 and columns in bytes from
1:

```text
JSON parse error: Unexpected ']' at line 1, column 7          // "[1, 2,]"
JSON parse error: Expected ':' at line 1, column 6            // "{\"a\" 1}"
JSON parse error: Leading zeros are not allowed at line 1, column 2
JSON parse error: Number out of range at line 1, column 1     // "1e400"
JSON parse error: Unexpected 'x' after the value at line 2, column 3
```

A non-string argument gives `JSON parse error: text must be a string`.

## Serialization

- Object keys are written in byte order, so the same value always gives the same text.
- Integers are written as integers. Floats use the shortest text that reads back as
  exactly the same value (`Text_FormatFloatShortest`), so `0.1 + 0.2` gives
  `0.30000000000000004` and `100.0` stays `100.0`. Parsing that text gives the float
  back, so integers and floats survive a round trip.
- Strings escape `"`, `\`, `\n`, `\r`, `\t`, `\b`, `\f` and other control characters
  (`\u0001`). Non-ASCII UTF-8 is written as is.
- A class instance is written through its `toJson()` method, which returns any
  JSON-compatible value. An instance without one is an error.
- NaN, infinities, functions and classes have no JSON form and give an error, as in
  `JSON stringify error: NaN and infinities have no JSON form`.

`Json_StringifyPretty(value, indent)` takes a number of spaces (`0..10`; `0` means
compact) or a string such as `"\t"`. Each item goes on its own line. Empty arrays and
objects stay `[]` and `{}`.

## Nesting limit

Both directions keep their own stack instead of recursing, so nesting is not bounded by
the interpreter's call depth. More than 512 levels is an error:
`JSON parse error: Nesting deeper than 512 levels ...` when parsing, and
`JSON stringify error: nesting deeper than 512 levels (a cycle?)` when writing. An object
that contains itself hits this limit.

## Performance

The parser and writer are written in Dryad and run at interpreter speed: tens of
kilobytes per second. `@std/json` suits configuration files and API payloads, not bulk
data.
