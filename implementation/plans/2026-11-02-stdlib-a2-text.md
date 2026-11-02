# Stdlib A2 — Text Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two numeric T0 bridges (`float_to_int`, `int_to_float`) and build `@std/text` — byte-indexed UTF-8 string operations, ASCII transforms, split/join/replace, numeric parse/format, and a `StringBuilder` — entirely in Dryad on top of `@std/bytes`.

**Architecture:** `@std/text` converts a Dryad string to a `Buffer` once per operation, works on bytes with `@std/bytes`, and converts back once when it must return a string. Code-point helpers walk the UTF-8 bytes explicitly; no API mixes byte and code-point units. Only two new T0 intrinsics exist, for numeric conversion; all parsing and formatting stay in Dryad.

**Tech Stack:** C++17, Google Test, CMake, Dryad interpreter, `@std/buffers`, `@std/bytes`.

**Spec:** `docs/implementation/plans/2026-11-02-stdlib-expansion-design.md` (sections 8.3, 10/A2, 20)

## Global Constraints

- `Buffer` remains the only byte container; `@std/text` exports functions and one `StringBuilder` class, not a second byte type.
- Only two runtime changes: `syscall.float_to_int` and `syscall.int_to_float` (T0), both registered **after** `syscall.memmove` at the end of `register_all()` so existing intrinsic IDs do not shift.
- No other C++. No new T1/T2 intrinsics. No use of `__int_to_string` in new code.
- Value-returning APIs return `[value, error]`; side-effect APIs return `null` or an error string. Errors come from `@std/core/exceptions`.
- All indexes are **byte indexes into UTF-8**, matching `__string_length` and `Buffer`. Code-point operations are explicit functions.
- An operation converts a string to a `Buffer` at most once; substrings are produced from zero-copy slices.
- Build warning-free (`-Wall -Wextra -Werror`) and `ctest` green, serial and under `-j`.

## Review Focus

- `Text_CodePointAt("é", 1)` — a reader expects the continuation byte to be rejected, not decoded as a code point. Pinned by `Text_CodePointAtRejectsContinuationByte`.
- `Text_CharAt("é", 1)` — a reader expects the second **byte**, which is not valid UTF-8 on its own; the byte-index rule must be explicit. Pinned by `Text_CharAtUsesByteIndexes`.
- `Text_ParseInt("9223372036854775808", 10)` — a reader expects an error, not a wrapped negative. Pinned by `Text_ParseIntRejectsOverflow`.
- `Text_FormatFloat(-0.5, 0)` — a reader expects `"-1"` (round half away from zero) or a documented alternative. Pinned by `Text_FormatFloatRoundsHalfAwayFromZero`.
- `Text_Split("", ",")` — a reader expects `[""]`, not `[]`. Pinned by `Text_SplitEmptyString`.
- `Text_Trim` on a string containing `0xA0` — a reader expects only ASCII whitespace removed. Pinned by `Text_TrimOnlyAsciiWhitespace`.
- `StringBuilder` with 10 000 appends — a reader expects linear behaviour and correct output. Pinned by `StringBuilderManyAppends`.

## File Structure

- `src/stdlib/@std/text/text.dryad` — the module (functions, then `StringBuilder`).
- `src/tests/stdlib/text/text_test.dryad` — Dryad test functions.
- `src/tests/unit/text_test.cpp` — harness, one gtest per Dryad function.
- `docs/stdlib/text.md`, `docs/stdlib/README.md`, `docs/stdlib/dependency-graph.md` — documentation and layer rules.

---

### Task 1: Numeric T0 bridges

**Files:**
- Modify: `src/include/dryad/runtime/intrinsics_registry.h` (no signature change)
- Modify: `src/src/runtime/intrinsics_registry.cpp` (`register_all`, appended last; `register_misc_intrinsics` is *not* touched)
- Modify: `src/src/compiler/interpreter.cpp` (`setup_intrinsic_functions` allowlist)
- Test: `src/tests/unit/intrinsics_test.cpp`

**Interfaces:**
- Consumes: `IntrinsicsRegistry::register_intrinsic`.
- Produces: `syscall.float_to_int(float) -> integer | null` and `syscall.int_to_float(integer) -> float`, callable from Dryad as `__float_to_int` / `__int_to_float`.

- [ ] **Step 1: Write the failing intrinsic tests**

Append to `src/tests/unit/intrinsics_test.cpp`:

```cpp
TEST(IntrinsicsTest, FloatToIntTruncatesTowardZero) {
    auto& registry = IntrinsicsRegistry::instance();
    EXPECT_EQ(registry.call("syscall.float_to_int", {Value(3.9)}).as_integer(), 3);
    EXPECT_EQ(registry.call("syscall.float_to_int", {Value(-3.9)}).as_integer(), -3);
    EXPECT_EQ(registry.call("syscall.float_to_int", {Value(0.0)}).as_integer(), 0);
}

TEST(IntrinsicsTest, FloatToIntRejectsOutOfRangeAndNonFinite) {
    auto& registry = IntrinsicsRegistry::instance();
    EXPECT_TRUE(registry.call("syscall.float_to_int",
                              {Value(9223372036854775808.0)}).is_null());
    EXPECT_TRUE(registry.call("syscall.float_to_int",
                              {Value(-9223372036854775808.0 * 2.0)}).is_null());
    EXPECT_TRUE(registry.call("syscall.float_to_int",
                              {Value(std::numeric_limits<double>::infinity())}).is_null());
    EXPECT_TRUE(registry.call("syscall.float_to_int",
                              {Value(std::numeric_limits<double>::quiet_NaN())}).is_null());
}

TEST(IntrinsicsTest, IntToFloatConverts) {
    auto& registry = IntrinsicsRegistry::instance();
    EXPECT_DOUBLE_EQ(registry.call("syscall.int_to_float", {Value(int64_t(42))}).as_float(), 42.0);
    EXPECT_DOUBLE_EQ(registry.call("syscall.int_to_float", {Value(int64_t(-7))}).as_float(), -7.0);
}
```

Add `#include <limits>` and `#include <cstdint>` if not already present.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='IntrinsicsTest.FloatToInt*:IntrinsicsTest.IntToFloat*'`
Expected: FAIL with `Unknown intrinsic: syscall.float_to_int`.

- [ ] **Step 3: Register both intrinsics**

In `src/src/runtime/intrinsics_registry.cpp`, after the `syscall.memmove` registration at the end of `register_all()`:

```cpp
    // Appended after memmove for the same reason: IDs are positional and are
    // stored in .dryadc companions.
    register_intrinsic("syscall.float_to_int", [](const std::vector<Value>& args) -> Value {
        if (args.size() < 1 || !args[0].is_number()) {
            throw DryadException("syscall.float_to_int requires a number");
        }
        const double value = args[0].is_float() ? args[0].as_float()
                                                : static_cast<double>(args[0].as_integer());
        if (!std::isfinite(value) || value >= 9223372036854775808.0 ||
            value < -9223372036854775808.0) {
            return Value();
        }
        return Value(static_cast<int64_t>(value));
    });

    register_intrinsic("syscall.int_to_float", [](const std::vector<Value>& args) -> Value {
        if (args.size() < 1 || !args[0].is_integer()) {
            throw DryadException("syscall.int_to_float requires an integer");
        }
        return Value(static_cast<double>(args[0].as_integer()));
    });
```

Add `#include <cmath>` to that file. Truncation is `static_cast` (toward zero); `2^63` and `-2^63` bounds avoid undefined behaviour.

In `src/src/compiler/interpreter.cpp`, add `"syscall.float_to_int"` and `"syscall.int_to_float"` to the `intrinsic_names` list next to `"syscall.int_to_string"`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='IntrinsicsTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/src/runtime/intrinsics_registry.cpp src/src/compiler/interpreter.cpp src/tests/unit/intrinsics_test.cpp
git commit -m "feat(runtime): add float/int numeric bridges"
```

---

### Task 2: Text core — indexing, slicing, search, affixes

**Files:**
- Create: `src/stdlib/@std/text/text.dryad`
- Create: `src/tests/stdlib/text/text_test.dryad`
- Create: `src/tests/unit/text_test.cpp`
- Modify: `src/CMakeLists.txt` (add `tests/unit/text_test.cpp` next to `tests/unit/bytes_test.cpp`)

**Interfaces:**
- Consumes: `Buffer_New`, `Buffer_FromString`, `Buffer_AsString`, `Buffer_Read`, `Buffer_Len`, `Buffer_Slice`, `Buffer_Dispose`; `Bytes_ValidateRange`, `Bytes_Compare`; `__string_length`.
- Produces:
  - `Text_Length(text) -> [int, error]` (UTF-8 byte count)
  - `Text_CharAt(text, index) -> [string, error]` (one byte; may be invalid UTF-8 alone)
  - `Text_CodePointAt(text, byteIndex) -> [int, error]`
  - `Text_FromCodePoint(codePoint) -> [string, error]`
  - `Text_Slice(text, start, end) -> [string, error]`
  - `Text_Substring(text, start, count) -> [string, error]`
  - `Text_IndexOf(text, needle) -> [int, error]`
  - `Text_LastIndexOf(text, needle) -> [int, error]`
  - `Text_Includes(text, needle) -> [bool, error]`
  - `Text_StartsWith(text, prefix) -> [bool, error]`
  - `Text_EndsWith(text, suffix) -> [bool, error]`
  - `Text_Equals(a, b) -> [bool, error]`
  - `Text_Compare(a, b) -> [int, error]`
  - `Text_CodePoints(text) -> [[int], error]`
  - `Text_CharCount(text) -> [int, error]`

- [ ] **Step 1: Create the Dryad tests and the C++ harness**

`src/tests/stdlib/text/text_test.dryad`:

```dryad
// @std/text behavior tests, loaded by tests/unit/text_test.cpp.

import {
    Text_Length, Text_CharAt, Text_CodePointAt, Text_FromCodePoint,
    Text_Slice, Text_Substring, Text_IndexOf, Text_LastIndexOf,
    Text_Includes, Text_StartsWith, Text_EndsWith, Text_Equals, Text_Compare
} from "@std/text/text";

function text_test_length_is_bytes() {
    let ascii = Text_Length("abc");
    let utf8 = Text_Length("é");
    return ascii[1] == null && ascii[0] == 3 &&
           utf8[1] == null && utf8[0] == 2;
}

function text_test_char_at_uses_byte_indexes() {
    let first = Text_CharAt("é", 0);
    let second = Text_CharAt("é", 1);
    let bad = Text_CharAt("é", 2);
    return first[1] == null && Text_Length(first[0])[0] == 1 &&
           second[1] == null && Text_Length(second[0])[0] == 1 &&
           bad[1] != null;
}

function text_test_code_point_at() {
    let e = Text_CodePointAt("é", 0);
    let euro = Text_CodePointAt("€", 0);
    let emoji = Text_CodePointAt("😀", 0);
    return e[1] == null && e[0] == 233 &&
           euro[1] == null && euro[0] == 8364 &&
           emoji[1] == null && emoji[0] == 128512;
}

function text_test_code_point_at_rejects_continuation_byte() {
    let r = Text_CodePointAt("é", 1);
    return r[1] != null;
}

function text_test_from_code_point() {
    let e = Text_FromCodePoint(233);
    let euro = Text_FromCodePoint(8364);
    let emoji = Text_FromCodePoint(128512);
    let bad = Text_FromCodePoint(1114112);
    let surrogate = Text_FromCodePoint(55296);
    return e[1] == null && e[0] == "é" &&
           euro[1] == null && euro[0] == "€" &&
           emoji[1] == null && emoji[0] == "😀" &&
           bad[1] != null && surrogate[1] != null;
}

function text_test_slice_and_substring() {
    let s = Text_Slice("abcdef", 1, 4);
    let sub = Text_Substring("abcdef", 1, 3);
    let empty = Text_Slice("abcdef", 2, 2);
    let bad = Text_Slice("abcdef", 4, 2);
    return s[1] == null && s[0] == "bcd" &&
           sub[1] == null && sub[0] == "bcd" &&
           empty[1] == null && empty[0] == "" &&
           bad[1] != null;
}

function text_test_index_of_and_last_index_of() {
    let first = Text_IndexOf("abcabc", "bc");
    let last = Text_LastIndexOf("abcabc", "bc");
    let missing = Text_IndexOf("abcabc", "zz");
    let empty = Text_IndexOf("abc", "");
    let ok = first[1] == null && first[0] == 1 &&
             last[1] == null && last[0] == 4 &&
             missing[1] == null && missing[0] == -1 &&
             empty[1] == null && empty[0] == 0;
    return ok;
}

function text_test_includes_and_affixes() {
    let yes = Text_Includes("hello", "ell");
    let no = Text_Includes("hello", "zz");
    let starts = Text_StartsWith("hello", "he");
    let ends = Text_EndsWith("hello", "lo");
    let longer = Text_StartsWith("he", "hello");
    let ok = yes[1] == null && yes[0] &&
             no[1] == null && no[0] == false &&
             starts[1] == null && starts[0] &&
             ends[1] == null && ends[0] &&
             longer[1] == null && longer[0] == false;
    return ok;
}

function text_test_equals_and_compare() {
    let eq = Text_Equals("abc", "abc");
    let ne = Text_Equals("abc", "abd");
    let lt = Text_Compare("abc", "abd");
    let gt = Text_Compare("abd", "abc");
    let same = Text_Compare("abc", "abc");
    let ok = eq[1] == null && eq[0] &&
             ne[1] == null && ne[0] == false &&
             lt[1] == null && lt[0] == -1 &&
             gt[1] == null && gt[0] == 1 &&
             same[1] == null && same[0] == 0;
    return ok;
}

function text_test_code_points_and_char_count() {
    let points = Text_CodePoints("aé€");
    let count = Text_CharCount("aé€");
    let asciiCount = Text_CharCount("abc");
    let empty = Text_CodePoints("");
    let ok = points[1] == null && __runtime_array_length(points[0]) == 3 &&
             points[0][0] == 97 && points[0][1] == 233 && points[0][2] == 8364 &&
             count[1] == null && count[0] == 3 &&
             asciiCount[1] == null && asciiCount[0] == 3 &&
             empty[1] == null && __runtime_array_length(empty[0]) == 0;
    return ok;
}

function text_test_empty_strings() {
    let len = Text_Length("");
    let slice = Text_Slice("", 0, 0);
    let idx = Text_IndexOf("", "x");
    let starts = Text_StartsWith("", "");
    let ok = len[1] == null && len[0] == 0 &&
             slice[1] == null && slice[0] == "" &&
             idx[1] == null && idx[0] == -1 &&
             starts[1] == null && starts[0];
    return ok;
}
```

`src/tests/unit/text_test.cpp` — copy `src/tests/unit/bytes_test.cpp`, change the path to `/stdlib/text/text_test.dryad`, rename the helper to `run_text_test`, and the suite to `TextTest`. Declare one gtest per Dryad function:

```cpp
TEST(TextTest, LengthIsBytes) { EXPECT_TRUE(run_text_test("text_test_length_is_bytes").is_truthy()); }
TEST(TextTest, CharAtUsesByteIndexes) { EXPECT_TRUE(run_text_test("text_test_char_at_uses_byte_indexes").is_truthy()); }
TEST(TextTest, CodePointAt) { EXPECT_TRUE(run_text_test("text_test_code_point_at").is_truthy()); }
TEST(TextTest, CodePointAtRejectsContinuationByte) { EXPECT_TRUE(run_text_test("text_test_code_point_at_rejects_continuation_byte").is_truthy()); }
TEST(TextTest, FromCodePoint) { EXPECT_TRUE(run_text_test("text_test_from_code_point").is_truthy()); }
TEST(TextTest, SliceAndSubstring) { EXPECT_TRUE(run_text_test("text_test_slice_and_substring").is_truthy()); }
TEST(TextTest, IndexOfAndLastIndexOf) { EXPECT_TRUE(run_text_test("text_test_index_of_and_last_index_of").is_truthy()); }
TEST(TextTest, IncludesAndAffixes) { EXPECT_TRUE(run_text_test("text_test_includes_and_affixes").is_truthy()); }
TEST(TextTest, EqualsAndCompare) { EXPECT_TRUE(run_text_test("text_test_equals_and_compare").is_truthy()); }
TEST(TextTest, CodePointsAndCharCount) { EXPECT_TRUE(run_text_test("text_test_code_points_and_char_count").is_truthy()); }
TEST(TextTest, EmptyStrings) { EXPECT_TRUE(run_text_test("text_test_empty_strings").is_truthy()); }
```

Note: in the Dryad source `"é"` is the two-byte UTF-8 sequence `C3 A9`; `Text_CharAt("é", 0)` returns exactly one byte, which is not valid UTF-8 on its own. The test asserts the byte length rather than a literal, because the literal would depend on the editor encoding.

Add `tests/unit/text_test.cpp` to the `unit_tests` target in `src/CMakeLists.txt`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake -S src -B src/build && cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: FAIL — cannot import `@std/text/text`.

- [ ] **Step 3: Implement the module**

Create `src/stdlib/@std/text/text.dryad`:

```dryad
// @std/text/text.dryad
// Byte-indexed UTF-8 text operations over @std/bytes. Buffer is the only
// byte container; strings are converted once per operation.

import { ArgumentNullException, ArgumentOutOfRangeException, Exception } from "@std/core/exceptions";
import { Buffer_FromString, Buffer_AsString, Buffer_Read, Buffer_Len, Buffer_Slice } from "@std/buffers/buffer";
import { Bytes_ValidateRange, Bytes_Compare } from "@std/bytes/bytes";

function Text_ToBuffer(text) {
    if (text == null) {
        return ArgumentNullException("text");
    }
    return Buffer_FromString(text);
}

function Text_IsBuffer(value) {
    return __runtime_value_kind(value) != "string";
}
```

Implement each public function with this contract:

- Every function validates `text` is a string (`__runtime_value_kind(text) == "string"`); otherwise `ArgumentOutOfRangeException("text must be a string")`.
- Convert with `Text_ToBuffer`; if the result is a string, propagate it as the error.
- `Text_Length`: `[__string_length(text), null]`.
- `Text_CharAt`: bounds-check the byte index; return `[slice-as-string of one byte, null]`. A one-byte slice is produced with `Buffer_Slice(buf, index, index + 1)` then `Buffer_AsString`.
- `Text_DecodeCodePoint(buf, byteIndex)` — shared helper (not public API): decode 1–4 bytes; reject a continuation lead byte (`0x80..0xBF`), truncation, overlong forms, surrogates and values above `0x10FFFF`; return `[codePoint, error]`.
- `Text_CodePointAt`: delegate to `Text_DecodeCodePoint`.
- `Text_CharCount` and `Text_CodePoints`: walk with `Text_DecodeCodePoint`, advancing by the encoded length; both return an error on invalid UTF-8.
- `Text_FromCodePoint`: reject `< 0`, `> 0x10FFFF` and `0xD800..0xDFFF`; encode UTF-8 into a `Buffer_New(4)` and return it as a string.
- `Text_Slice` / `Text_Substring`: validate byte ranges (`0 <= start <= end <= length`); slice and convert back.
- `Text_IndexOf` / `Text_LastIndexOf`: byte-wise search with `Buffer_Read`; empty needle returns `0` / `length`; absent returns `-1`.
- `Text_Includes` delegates to `Text_IndexOf`.
- `Text_StartsWith` / `Text_EndsWith`: compare byte-wise; longer affix returns `false`; empty affix returns `true`.
- `Text_Equals`: byte length then `Bytes_Compare`.
- `Text_Compare`: `Bytes_Compare` on the two buffers.

Dispose every temporary `Buffer` before returning.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS, ten tests.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp src/CMakeLists.txt
git commit -m "feat(text): add byte-indexed core operations"
```

---

### Task 3: ASCII transforms, trim, repeat and padding

**Files:**
- Modify: `src/stdlib/@std/text/text.dryad`
- Modify: `src/tests/stdlib/text/text_test.dryad`
- Modify: `src/tests/unit/text_test.cpp`

**Interfaces:**
- Consumes: `Text_ToBuffer`, `Buf`-based helpers from Task 2.
- Produces:
  - `Text_ToLowerAscii(text) -> [string, error]`
  - `Text_ToUpperAscii(text) -> [string, error]`
  - `Text_Trim(text)`, `Text_TrimStart(text)`, `Text_TrimEnd(text) -> [string, error]`
  - `Text_Repeat(text, count) -> [string, error]`
  - `Text_PadStart(text, length, pad) -> [string, error]`
  - `Text_PadEnd(text, length, pad) -> [string, error]`

- [ ] **Step 1: Write the failing tests**

Append to `text_test.dryad` (and matching `TextTest` entries):

```dryad
function text_test_ascii_case() {
    let lower = Text_ToLowerAscii("AbC");
    let upper = Text_ToUpperAscii("aBc");
    let keep = Text_ToLowerAscii("éA");
    let ok = lower[1] == null && lower[0] == "abc" &&
             upper[1] == null && upper[0] == "ABC" &&
             keep[1] == null && Text_Length(keep[0])[0] == 3 &&
             Text_CharAt(keep[0], 0)[0] == Text_CharAt("é", 0)[0];
    return ok;
}

function text_test_trim_only_ascii_whitespace() {
    let all = Text_Trim("  \t\nabc\r ");
    let start = Text_TrimStart("  abc ");
    let end = Text_TrimEnd(" abc  ");
    let nbspChar = Text_FromCodePoint(160);
    let nbsp = Text_Trim(nbspChar[0] + "abc");
    let ok = all[1] == null && all[0] == "abc" &&
             start[1] == null && start[0] == "abc " &&
             end[1] == null && end[0] == " abc" &&
             nbsp[1] == null && Text_Length(nbsp[0])[0] == 5;
    return ok;
}

function text_test_repeat_and_pad() {
    let rep = Text_Repeat("ab", 3);
    let zero = Text_Repeat("ab", 0);
    let neg = Text_Repeat("ab", -1);
    let padStart = Text_PadStart("7", 3, "0");
    let padEnd = Text_PadEnd("7", 3, "0");
    let wide = Text_PadStart("abcd", 2, "0");
    let ok = rep[1] == null && rep[0] == "ababab" &&
             zero[1] == null && zero[0] == "" &&
             neg[1] != null &&
             padStart[1] == null && padStart[0] == "007" &&
             padEnd[1] == null && padEnd[0] == "700" &&
             wide[1] == null && wide[0] == "abcd";
    return ok;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.AsciiCase:TextTest.TrimOnlyAsciiWhitespace:TextTest.RepeatAndPad'`
Expected: FAIL — functions not exported.

- [ ] **Step 3: Implement**

- Case conversion maps `A..Z` ↔ `a..z` and leaves every other byte untouched.
- Whitespace set is exactly `0x20`, `0x09`, `0x0A`, `0x0D` (use the trim helpers shared with `@std/bytes` if they are exportable; otherwise implement locally).
- `Text_Repeat`: reject `count < 0`; guard `len * count` overflow (`count > 0 && len > 9223372036854775807 / count`); `count == 0` and `len == 0` return `""`.
- `Text_PadStart`/`Text_PadEnd`: `length <= byteLength` returns the original text; `pad` must be non-empty; repeat the pad, truncate to the needed byte count, concatenate on the correct side. Operate on bytes, not code points.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp
git commit -m "feat(text): add ascii case, trim, repeat and padding"
```

---

### Task 4: Split, join, replace

**Files:**
- Modify: `src/stdlib/@std/text/text.dryad`
- Modify: `src/tests/stdlib/text/text_test.dryad`
- Modify: `src/tests/unit/text_test.cpp`

**Interfaces:**
- Produces:
  - `Text_Split(text, separator) -> [[string], error]`
  - `Text_Join(parts, separator) -> [string, error]`
  - `Text_Replace(text, needle, replacement) -> [string, error]`
  - `Text_ReplaceAll(text, needle, replacement) -> [string, error]`

- [ ] **Step 1: Write the failing tests**

```dryad
function text_test_split() {
    let parts = Text_Split("a,b,,c", ",");
    let empty = Text_Split("", ",");
    let trailing = Text_Split("a,", ",");
    let missing = Text_Split("abc", ",");
    let ok = parts[1] == null && __runtime_array_length(parts[0]) == 4 &&
             parts[0][2] == "" &&
             empty[1] == null && __runtime_array_length(empty[0]) == 1 && empty[0][0] == "" &&
             trailing[1] == null && __runtime_array_length(trailing[0]) == 2 && trailing[0][1] == "" &&
             missing[1] == null && __runtime_array_length(missing[0]) == 1 && missing[0][0] == "abc";
    return ok;
}

function text_test_split_rejects_empty_separator() {
    let r = Text_Split("abc", "");
    return r[1] != null;
}

function text_test_join() {
    let parts = ["a", "b", "c"];
    let joined = Text_Join(parts, "-");
    let single = Text_Join(["a"], "-");
    let none = Text_Join([], "-");
    let ok = joined[1] == null && joined[0] == "a-b-c" &&
             single[1] == null && single[0] == "a" &&
             none[1] == null && none[0] == "";
    return ok;
}

function text_test_replace() {
    let first = Text_Replace("aaa", "a", "b");
    let all = Text_ReplaceAll("aaa", "a", "b");
    let none = Text_ReplaceAll("aaa", "z", "b");
    let emptyNeedle = Text_Replace("aaa", "", "b");
    let ok = first[1] == null && first[0] == "baa" &&
             all[1] == null && all[0] == "bbb" &&
             none[1] == null && none[0] == "aaa" &&
             emptyNeedle[1] != null;
    return ok;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.Split*:TextTest.Join:TextTest.Replace'`
Expected: FAIL.

- [ ] **Step 3: Implement**

- `Text_Split`: reject an empty separator; scan bytes for non-overlapping matches; `""` yields `[""]`; a trailing separator yields a trailing empty part.
- `Text_Join`: validate every element is a string; concatenate with the separator; `[]` yields `""`.
- `Text_Replace` / `Text_ReplaceAll`: reject an empty needle; replace byte-wise; build the result with repeated substrings joined (avoid O(n²) by collecting parts and joining).

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp
git commit -m "feat(text): add split, join and replace"
```

---

### Task 5: Numeric parse and format

**Files:**
- Modify: `src/stdlib/@std/text/text.dryad`
- Modify: `src/tests/stdlib/text/text_test.dryad`
- Modify: `src/tests/unit/text_test.cpp`

**Interfaces:**
- Consumes: `__float_to_int`, `__int_to_float` from Task 1.
- Produces:
  - `Text_ParseInt(text, base) -> [int, error]`
  - `Text_FormatInt(value, base) -> [string, error]`
  - `Text_ParseFloat(text) -> [float, error]`
  - `Text_FormatFloat(value, decimals) -> [string, error]`

- [ ] **Step 1: Write the failing tests**

```dryad
function text_test_parse_int() {
    let dec = Text_ParseInt("42", 10);
    let neg = Text_ParseInt("-17", 10);
    let hex = Text_ParseInt("ff", 16);
    let bin = Text_ParseInt("1010", 2);
    let badBase = Text_ParseInt("10", 3);
    let badDigit = Text_ParseInt("12", 2);
    let empty = Text_ParseInt("", 10);
    let spaces = Text_ParseInt(" 42", 10);
    let ok = dec[1] == null && dec[0] == 42 &&
             neg[1] == null && neg[0] == -17 &&
             hex[1] == null && hex[0] == 255 &&
             bin[1] == null && bin[0] == 10 &&
             badBase[1] != null && badDigit[1] != null &&
             empty[1] != null && spaces[1] != null;
    return ok;
}

function text_test_parse_int_rejects_overflow() {
    let tooBig = Text_ParseInt("9223372036854775808", 10);
    let minValue = Text_ParseInt("-9223372036854775808", 10);
    return tooBig[1] != null && minValue[1] == null &&
           minValue[0] == -9223372036854775807 - 1;
}

function text_test_format_int() {
    let dec = Text_FormatInt(42, 10);
    let neg = Text_FormatInt(-17, 10);
    let hex = Text_FormatInt(255, 16);
    let minValue = Text_FormatInt(-9223372036854775807 - 1, 10);
    let badBase = Text_FormatInt(1, 3);
    let ok = dec[1] == null && dec[0] == "42" &&
             neg[1] == null && neg[0] == "-17" &&
             hex[1] == null && hex[0] == "ff" &&
             minValue[1] == null && minValue[0] == "-9223372036854775808" &&
             badBase[1] != null;
    return ok;
}

function text_test_parse_float() {
    let whole = Text_ParseFloat("42");
    let frac = Text_ParseFloat("-3.5");
    let exp = Text_ParseFloat("1e3");
    let bad = Text_ParseFloat("1.2.3");
    let empty = Text_ParseFloat("");
    let ok = whole[1] == null && whole[0] == 42.0 &&
             frac[1] == null && frac[0] == -3.5 &&
             exp[1] == null && exp[0] == 1000.0 &&
             bad[1] != null && empty[1] != null;
    return ok;
}

function text_test_format_float() {
    let two = Text_FormatFloat(3.14159, 2);
    let zero = Text_FormatFloat(3.7, 0);
    let negHalf = Text_FormatFloat(-0.5, 0);
    let whole = Text_FormatFloat(42.0, 3);
    let badPrecision = Text_FormatFloat(1.0, 16);
    let ok = two[1] == null && two[0] == "3.14" &&
             zero[1] == null && zero[0] == "4" &&
             negHalf[1] == null && negHalf[0] == "-1" &&
             whole[1] == null && whole[0] == "42.000" &&
             badPrecision[1] != null;
    return ok;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.ParseInt*:TextTest.FormatInt:TextTest.ParseFloat:TextTest.FormatFloat'`
Expected: FAIL.

- [ ] **Step 3: Implement**

- `Text_ParseInt`: accept an optional `+`/`-`, at least one digit, no spaces or underscores; base must be `2`, `8`, `10` or `16`; validate each digit against the base; accumulate with overflow guard (`value > (9223372036854775807 - digit) / base`); handle the negative limit `-9223372036854775808` explicitly.
- `Text_FormatInt`: base must be `2`, `8`, `10` or `16`; lowercase digits; handle `0` and `-9223372036854775808` without negating (negating the minimum overflows).
- `Text_ParseFloat`: trim nothing; accept optional sign, digits with at most one `.`, and an optional `e`/`E` exponent with optional sign; require at least one mantissa digit; accumulate the integer part and fractional digits as integers with overflow guards; combine with `__int_to_float`; apply the exponent by repeated multiplication/division by 10.
- `Text_FormatFloat`: reject `decimals < 0 || decimals > 15` and non-finite values; round half away from zero — scale by `10^decimals`, add `0.5` to the absolute value, truncate with `__float_to_int`, then insert the decimal point and restore the sign. `decimals == 0` emits no point.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp
git commit -m "feat(text): add numeric parse and format"
```

---

### Task 6: StringBuilder

**Files:**
- Modify: `src/stdlib/@std/text/text.dryad`
- Modify: `src/tests/stdlib/text/text_test.dryad`
- Modify: `src/tests/unit/text_test.cpp`

**Interfaces:**
- Consumes: `Buffer_New`, `Buffer_Resize`, `Buffer_Write`, `Buffer_AsString`, `Bytes_Copy`, `Buffer_FromString`, `Buffer_Dispose`.
- Produces `class StringBuilder` with `append(text)`, `appendChar(ch)`, `appendBuffer(buf)`, `toString()`, `clear()`, `length()`. `length()` is the logical byte length, not capacity.

- [ ] **Step 1: Write the failing tests**

```dryad
function text_test_string_builder() {
    let sb = new StringBuilder(4);
    sb.append("ab");
    sb.appendChar("c");
    let mid = sb.toString();
    let len = sb.length();
    sb.clear();
    let cleared = sb.toString();
    let clearedLen = sb.length();
    sb.appendBuffer(null);
    let ok = mid == "abc" && len == 3 &&
             cleared == "" && clearedLen == 0;
    return ok;
}

function text_test_string_builder_growth() {
    let sb = new StringBuilder(2);
    let chunk = "0123456789";
    let i = 0;
    while (i < 1000) {
        sb.append(chunk);
        i = i + 1;
    }
    let out = sb.toString();
    let ok = sb.length() == 10000 && Text_Length(out)[0] == 10000 &&
             Text_CharAt(out, 0)[0] == "0" &&
             Text_CharAt(out, 9999)[0] == "9";
    return ok;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.StringBuilder*'`
Expected: FAIL — `StringBuilder` is not exported.

- [ ] **Step 3: Implement the class**

```dryad
class StringBuilder {
    constructor(initialCapacity = 16) {
        this._buffer = Buffer_New(initialCapacity);
        this._capacity = initialCapacity;
        this._length = 0;
    }
}
```

- `append(text)`: convert once; grow capacity (double until it fits, via `Buffer_Resize`); `Bytes_Copy` into the buffer at `_length`; update `_length`.
- `appendChar(ch)`: require a one-byte string; `Buffer_Write` at `_length`.
- `appendBuffer(buf)`: validate; `Bytes_Copy`.
- `toString()`: zero-copy slice `Buffer_Slice(_buffer, 0, _length)` then `Buffer_AsString`; empty returns `""`.
- `clear()`: set `_length = 0`, keep capacity (do not free).
- `length()`: return `_length`.
- Every method returns `null` or an error string (mutation), except `toString` (string) and `length` (integer). Dispose the temporary source buffers.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp
git commit -m "feat(text): add StringBuilder"
```

---

### Task 7: TextView

**Files:**
- Modify: `src/stdlib/@std/text/text.dryad`
- Modify: `src/tests/stdlib/text/text_test.dryad`
- Modify: `src/tests/unit/text_test.cpp`

**Interfaces:**
- Consumes: `Buffer_Slice`, `Buffer_AsString`, `Buffer_Len`, `Buffer_Dispose`; the UTF-8 decoder from Task 2.
- Produces `class TextView` — a non-owning view over a caller-provided `Buffer`:
  - `constructor(buffer, offset = 0, length = -1)` (`-1` means "to the end of the buffer")
  - `length() -> int` (bytes)
  - `slice(start, end) -> TextView | error`
  - `codePointAt(byteIndex) -> [int, error]`
  - `toString() -> string | error`

The view never frees the buffer; the caller must keep it alive.

- [ ] **Step 1: Write the failing tests**

```dryad
function text_test_text_view() {
    let buf = Buffer_FromString("aé€");
    let view = new TextView(buf, 0, 6);
    let len = view.length();
    let first = view.codePointAt(0);
    let second = view.codePointAt(1);
    let sub = view.slice(1, 3);
    let subText = sub.toString();
    let whole = view.toString();
    let ok = len == 6 &&
             first[1] == null && first[0] == 97 &&
             second[1] == null && second[0] == 233 &&
             subText == "é" &&
             whole == "aé€";
    Buffer_Dispose(buf);
    return ok;
}

function text_test_text_view_bounds() {
    let buf = Buffer_FromString("abc");
    let view = new TextView(buf, 1, 2);
    let text = view.toString();
    let badSlice = view.slice(0, 3);
    let ok = text == "bc" && badSlice != null;
    Buffer_Dispose(buf);
    return ok;
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.TextView*'`
Expected: FAIL — `TextView` is not exported.

- [ ] **Step 3: Implement**

Store `_buffer`, `_offset`, `_length`. Resolve `-1` to `Buffer_Len(buffer) - offset`. Validate `offset >= 0`, `length >= 0`, `offset + length <= Buffer_Len(buffer)` using the subtraction form. `slice` returns a new `TextView` with adjusted offset/length. `codePointAt` decodes relative to the view. `toString` slices the underlying buffer and converts once.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='TextTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/text/text.dryad src/tests/stdlib/text/text_test.dryad src/tests/unit/text_test.cpp
git commit -m "feat(text): add non-owning TextView"
```

---

### Task 8: Layer rules, docs and full verification

**Files:**
- Modify: `src/tests/unit/stdlib_layers_test.cpp` (`allowed_imports`)
- Create: `docs/stdlib/text.md`
- Modify: `docs/stdlib/README.md`
- Modify: `docs/stdlib/dependency-graph.md`

**Interfaces:**
- Consumes: `DRYAD_STDLIB_DIR` module tree.
- Produces: enforced `text → {core, buffers, bytes}` rule and documentation.

- [ ] **Step 1: Extend the layer rule and test**

In `stdlib_layers_test.cpp`, add `if (module == "text") return {"core", "buffers", "bytes"};` to `allowed_imports`. Add non-vacuity assertions for the new module and its edges:

```cpp
    ASSERT_EQ(graph.count("text"), 1u);
    EXPECT_EQ(graph["text"].count("bytes"), 1u);
    EXPECT_EQ(graph["text"].count("buffers"), 1u);
```

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='StdlibLayersTest.*'`
Expected: PASS. If it fails because `text` imports something else, fix the import, not the rule.

- [ ] **Step 2: Write `docs/stdlib/text.md`**

Document every exported function with its signature and error convention, the byte-vs-code-point rule, the ASCII whitespace set, the supported numeric bases (`2/8/10/16`), `Text_FormatFloat` precision bounds (`0..15`) and rounding rule, `StringBuilder` ownership/capacity behaviour, and three examples: slicing a UTF-8 string by code point, parsing and formatting an integer, and building a string in a loop.

- [ ] **Step 3: Update `docs/stdlib/README.md` and `dependency-graph.md`**

Add `├── text/           byte-indexed UTF-8 text and StringBuilder` to the module tree and a `Text | [text.md](text.md) | @std/text/text` row to the guides table. Add the `text → core/buffers/bytes` edges and the enforced rule to the dependency graph.

- [ ] **Step 4: Run the full suite**

Run: `cmake --build src/build -j$(nproc) && ctest --test-dir src/build --output-on-failure`
Expected: all tests PASS, no warnings.

- [ ] **Step 5: Commit**

```bash
git add src/tests/unit/stdlib_layers_test.cpp
git commit -m "test(stdlib): enforce the text module layers"

cd docs && git add stdlib/text.md stdlib/README.md stdlib/dependency-graph.md
git commit -m "docs(stdlib): document the text module"
```
