# Stdlib A1 — Bytes and Buffers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add offset-aware `memmove` to the runtime and build `@std/bytes`, a Dryad-only operations module over the existing `Buffer`, so text, encoding, JSON and networking no longer copy byte by byte.

**Architecture:** One new T0 intrinsic (`syscall.memmove`) exposes the CPU/OS memory move with source and destination offsets. Everything above it is Dryad: `@std/bytes` validates ranges, uses `Buffer` as the only byte container, returns errors by value, and reuses zero-copy `Buffer_Slice` for trim operations. `Buffer_CopyTo` is rewritten on top of the same intrinsic.

**Tech Stack:** C++17, Google Test, CMake, Dryad stdlib and interpreter.

**Spec:** `docs/implementation/plans/2026-11-02-stdlib-expansion-design.md` (sections 8.3, 10/A1, 13, 20)

## Global Constraints

- `Buffer` remains the only byte container. `@std/bytes` exports functions, not a second type.
- No stdlib logic in C++. The only runtime change is `syscall.memmove` (T0), registered **last** so existing intrinsic IDs stored in `.dryadc` companions do not shift.
- Value-returning APIs return `[value, error]`; side-effect APIs return `null` on success or an error string. Errors come from `@std/core/exceptions`.
- All ranges are validated in Dryad **before** calling the intrinsic; the intrinsic is a no-op on invalid handles or offsets.
- No new T1/T2 intrinsics. No use of `__int_to_string` in new code.
- Public signatures in this plan are fixed; later modules import them verbatim.
- Build must stay warning-free (`-Wall -Wextra -Werror`) and `ctest` green.

## Review Focus

- `Buffer_CopyTo(buf, buf, 1, 4)` on the same buffer — a reader expects a correct overlapping copy, not corrupted bytes. Pinned by `BufferTest.CopyToOverlappingSameBuffer`.
- `Bytes_Copy` with `count == 0` at the end offset — a reader expects success, not an out-of-bounds error. Pinned by `BytesTest.CopyZeroLengthAtEnd`.
- `Bytes_Trim` on an all-whitespace buffer — a reader expects an empty buffer, not an error or original bytes. Pinned by `BytesTest.TrimAllWhitespace`.
- `Bytes_FromHex("abc")` — a reader expects an error, not a silent partial byte. Pinned by `BytesTest.FromHexRejectsOddLength`.
- `Bytes_ToHex` on bytes `0x00, 0x0F, 0xA5, 0xFF` — a reader expects lowercase `"000fa5ff"`. Pinned by `BytesTest.ToHexKnownVector`.
- `Bytes_Concat` when the first buffer is a slice — a reader expects the slice view, not the whole parent, to be concatenated. Pinned by `BytesTest.ConcatUsesSliceView`.

---

### Task 1: `memmove` T0 intrinsic

**Files:**
- Modify: `src/include/dryad/runtime/intrinsics.h` (`MemoryManager::memmove`, `Intrinsics::memmove`)
- Modify: `src/src/runtime/intrinsics.cpp` (implementation)
- Modify: `src/src/runtime/intrinsics_registry.cpp` (`register_all`, append last)
- Modify: `src/src/compiler/interpreter.cpp` (`setup_intrinsic_functions` allowlist)
- Test: `src/tests/unit/buffer_intrinsics_test.cpp`

**Interfaces:**
- Consumes: `MemoryManager::get_metadata`, `AllocationMetadata::size/data` (existing private helpers).
- Produces: `syscall.memmove(destHandle, destOffset, srcHandle, srcOffset, count) -> null`, callable from Dryad as `__memmove(...)`; `Intrinsics::memmove(int64_t, int64_t, int64_t, int64_t, int64_t)`.

- [ ] **Step 1: Write the failing intrinsic tests**

Append to `src/tests/unit/buffer_intrinsics_test.cpp`:

```cpp
TEST(MemoryIntrinsicsTest, MemmoveWithOffsets) {
    Intrinsics intr;
    Value src = intr.alloc_bytes(8);
    Value dst = intr.alloc_bytes(8);
    for (int i = 0; i < 4; ++i) {
        intr.buffer_set(src.as_integer(), i, 10 + i);
    }

    Value moved = intr.memmove(dst.as_integer(), 2, src.as_integer(), 1, 3);
    EXPECT_TRUE(moved.is_null());
    EXPECT_EQ(intr.buffer_get(dst.as_integer(), 1).as_integer(), 0);
    EXPECT_EQ(intr.buffer_get(dst.as_integer(), 2).as_integer(), 11);
    EXPECT_EQ(intr.buffer_get(dst.as_integer(), 3).as_integer(), 12);
    EXPECT_EQ(intr.buffer_get(dst.as_integer(), 4).as_integer(), 13);

    intr.free_bytes(src.as_integer());
    intr.free_bytes(dst.as_integer());
}

TEST(MemoryIntrinsicsTest, MemmoveOverlapForward) {
    Intrinsics intr;
    Value buf = intr.alloc_bytes(6);
    for (int i = 0; i < 5; ++i) {
        intr.buffer_set(buf.as_integer(), i, i + 1);
    }

    Value moved = intr.memmove(buf.as_integer(), 1, buf.as_integer(), 0, 4);
    EXPECT_TRUE(moved.is_null());
    EXPECT_EQ(intr.buffer_get(buf.as_integer(), 0).as_integer(), 1);
    EXPECT_EQ(intr.buffer_get(buf.as_integer(), 1).as_integer(), 1);
    EXPECT_EQ(intr.buffer_get(buf.as_integer(), 2).as_integer(), 2);
    EXPECT_EQ(intr.buffer_get(buf.as_integer(), 3).as_integer(), 3);
    EXPECT_EQ(intr.buffer_get(buf.as_integer(), 4).as_integer(), 4);

    intr.free_bytes(buf.as_integer());
}

TEST(MemoryIntrinsicsTest, MemmoveRejectsOutOfBounds) {
    Intrinsics intr;
    Value src = intr.alloc_bytes(4);
    Value dst = intr.alloc_bytes(4);

    EXPECT_TRUE(intr.memmove(dst.as_integer(), 2, src.as_integer(), 0, 3).is_null());
    EXPECT_EQ(intr.buffer_get(dst.as_integer(), 2).as_integer(), 0);
    EXPECT_TRUE(intr.memmove(dst.as_integer(), -1, src.as_integer(), 0, 1).is_null());
    EXPECT_TRUE(intr.memmove(dst.as_integer(), 0, src.as_integer(), 0, -1).is_null());

    intr.free_bytes(src.as_integer());
    intr.free_bytes(dst.as_integer());
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='MemoryIntrinsicsTest.Memmove*'`
Expected: FAIL to compile with `memmove` not declared.

- [ ] **Step 3: Implement and register the intrinsic**

Add to `src/include/dryad/runtime/intrinsics.h`:

```cpp
static Value memmove(int64_t dest_handle, int64_t dest_offset,
                     int64_t src_handle, int64_t src_offset, int64_t count);
```

and the matching non-static member on `Intrinsics`.

Implementation in `src/src/runtime/intrinsics.cpp` follows `MemoryManager::memcpy`: reject `count < 0`, missing/freed handles, negative offsets, and `offset + count > size`; then `std::memmove(meta->data + dest_offset, src->data + src_offset, count)`. Return `Value()` in every case, success or rejection, matching `memcpy`.

Register in `src/src/runtime/intrinsics_registry.cpp` **at the end of `register_all()`**, not inside `register_memory_intrinsics()`:

```cpp
void IntrinsicsRegistry::register_all() {
    register_file_io_intrinsics();
    // ... existing registrations unchanged ...
    register_poller_intrinsics();

    // Appended last on purpose: intrinsic IDs are positional and are stored
    // in .dryadc companions. Inserting earlier would shift existing IDs.
    register_intrinsic("syscall.memmove", [](const std::vector<Value>& args) -> Value {
        if (args.size() < 5) {
            throw DryadException("syscall.memmove requires 5 integer arguments");
        }
        for (size_t i = 0; i < 5; ++i) {
            if (!args[i].is_integer()) {
                throw DryadException("syscall.memmove requires 5 integer arguments");
            }
        }
        return MemoryManager::memmove(args[0].as_integer(), args[1].as_integer(),
                                      args[2].as_integer(), args[3].as_integer(),
                                      args[4].as_integer());
    });
}
```

Add `"syscall.memmove"` to the `intrinsic_names` list in `src/src/compiler/interpreter.cpp` next to `"syscall.memcpy"`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='MemoryIntrinsicsTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/include/dryad/runtime/intrinsics.h src/src/runtime/intrinsics.cpp src/src/runtime/intrinsics_registry.cpp src/src/compiler/interpreter.cpp src/tests/unit/buffer_intrinsics_test.cpp
git commit -m "feat(runtime): add offset-aware memmove intrinsic"
```

---

### Task 2: `Buffer_CopyTo` on top of `memmove`

**Files:**
- Modify: `src/stdlib/@std/buffers/buffer.dryad` (`Buffer_CopyTo`)
- Test: `src/tests/stdlib/buffers/buffer_test.dryad`, `src/tests/unit/buffer_test.cpp`

**Interfaces:**
- Consumes: `__memmove` from Task 1; `Buffer_GetActualHandle` and `Buffer_GetOffset` (existing).
- Produces: unchanged `Buffer_CopyTo(buf, dest, destOffset, count)` signature; overlapping copies are now defined and correct.

- [ ] **Step 1: Write the failing regression tests**

Append to `src/tests/stdlib/buffers/buffer_test.dryad`:

```dryad
function test_buffer_copy_to_overlap_same_buffer() {
    let buf = Buffer_New(6);
    Buffer_Write(buf, 0, 1);
    Buffer_Write(buf, 1, 2);
    Buffer_Write(buf, 2, 3);
    Buffer_Write(buf, 3, 4);
    let err = Buffer_CopyTo(buf, buf, 1, 4);
    let ok = err == null &&
             Buffer_Read(buf, 0) == 1 &&
             Buffer_Read(buf, 1) == 1 &&
             Buffer_Read(buf, 2) == 2 &&
             Buffer_Read(buf, 3) == 3 &&
             Buffer_Read(buf, 4) == 4;
    Buffer_Dispose(buf);
    return ok;
}

function test_buffer_copy_to_from_slice() {
    let src = Buffer_New(6);
    Buffer_Write(src, 2, 77);
    Buffer_Write(src, 3, 78);
    let slice = Buffer_Slice(src, 2, 4);
    let dst = Buffer_New(2);
    let err = Buffer_CopyTo(slice, dst, 0, 2);
    let ok = err == null &&
             Buffer_Read(dst, 0) == 77 &&
             Buffer_Read(dst, 1) == 78;
    Buffer_Dispose(dst);
    Buffer_Dispose(src);
    return ok;
}
```

Append to `src/tests/unit/buffer_test.cpp`:

```cpp
TEST(BufferTest, CopyToOverlappingSameBuffer) {
    EXPECT_TRUE(run_buffer_test("test_buffer_copy_to_overlap_same_buffer").is_truthy());
}

TEST(BufferTest, CopyToFromSlice) {
    EXPECT_TRUE(run_buffer_test("test_buffer_copy_to_from_slice").is_truthy());
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BufferTest.CopyToOverlappingSameBuffer:BufferTest.CopyToFromSlice'`
Expected: `CopyToOverlappingSameBuffer` FAILS (byte-by-byte loop corrupts the source); `CopyToFromSlice` may pass and is a guard.

- [ ] **Step 3: Replace the byte loop**

In `Buffer_CopyTo`, keep all existing validation and replace the loop with:

```dryad
    __memmove(
        Buffer_GetActualHandle(dest),
        Buffer_GetOffset(dest) + destOffset,
        Buffer_GetActualHandle(buf),
        Buffer_GetOffset(buf),
        count
    );
    return null;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BufferTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/buffers/buffer.dryad src/tests/stdlib/buffers/buffer_test.dryad src/tests/unit/buffer_test.cpp
git commit -m "perf(buffers): copy with memmove instead of a byte loop"
```

---

### Task 3: `@std/bytes` core (copy, fill, compare, equals)

**Files:**
- Create: `src/stdlib/@std/bytes/bytes.dryad`
- Create: `src/tests/stdlib/bytes/bytes_test.dryad`
- Create: `src/tests/unit/bytes_test.cpp`
- Modify: `src/CMakeLists.txt` (add `tests/unit/bytes_test.cpp` to `unit_tests`)

**Interfaces:**
- Consumes: `Buffer_New`, `Buffer_Read`, `Buffer_Write`, `Buffer_Len`, `Buffer_GetActualHandle`, `Buffer_GetOffset`, `__memmove`, `__runtime_value_kind`, exception factories.
- Produces:
  - `Bytes_Copy(dst, dstOffset, src, srcOffset, count) -> null | error`
  - `Bytes_Fill(buf, offset, count, value) -> null | error`
  - `Bytes_Compare(a, b) -> [int, error]` (`-1`, `0`, `1`)
  - `Bytes_Equals(a, b) -> [bool, error]`

- [ ] **Step 1: Write the failing Dryad tests and harness**

Create `src/tests/stdlib/bytes/bytes_test.dryad`:

```dryad
// @std/bytes behavior tests, loaded by tests/unit/bytes_test.cpp.

import {
    Bytes_Copy,
    Bytes_Fill,
    Bytes_Compare,
    Bytes_Equals
} from "@std/bytes/bytes";

import {
    Buffer_New,
    Buffer_Read,
    Buffer_Write,
    Buffer_Len,
    Buffer_Slice,
    Buffer_Dispose
} from "@std/buffers/buffer";

function bytes_test_copy_roundtrip() {
    let src = Buffer_New(4);
    Buffer_Write(src, 0, 10);
    Buffer_Write(src, 1, 20);
    Buffer_Write(src, 2, 30);
    Buffer_Write(src, 3, 40);
    let dst = Buffer_New(4);
    let err = Bytes_Copy(dst, 0, src, 0, 4);
    let ok = err == null &&
             Buffer_Read(dst, 0) == 10 &&
             Buffer_Read(dst, 1) == 20 &&
             Buffer_Read(dst, 2) == 30 &&
             Buffer_Read(dst, 3) == 40;
    Buffer_Dispose(dst);
    Buffer_Dispose(src);
    return ok;
}

function bytes_test_copy_offsets() {
    let src = Buffer_New(4);
    Buffer_Write(src, 1, 7);
    Buffer_Write(src, 2, 8);
    let dst = Buffer_New(4);
    let err = Bytes_Copy(dst, 2, src, 1, 2);
    let ok = err == null &&
             Buffer_Read(dst, 1) == 0 &&
             Buffer_Read(dst, 2) == 7 &&
             Buffer_Read(dst, 3) == 8;
    Buffer_Dispose(dst);
    Buffer_Dispose(src);
    return ok;
}

function bytes_test_copy_zero_length_at_end() {
    let src = Buffer_New(2);
    let dst = Buffer_New(2);
    let err = Bytes_Copy(dst, 2, src, 2, 0);
    let ok = err == null;
    Buffer_Dispose(dst);
    Buffer_Dispose(src);
    return ok;
}

function bytes_test_copy_rejects_bad_range() {
    let src = Buffer_New(2);
    let dst = Buffer_New(2);
    let e1 = Bytes_Copy(dst, 0, src, 0, 3);
    let e2 = Bytes_Copy(dst, 1, src, 0, 2);
    let e3 = Bytes_Copy(dst, 0, src, -1, 1);
    let ok = e1 != null && e2 != null && e3 != null;
    Buffer_Dispose(dst);
    Buffer_Dispose(src);
    return ok;
}

function bytes_test_fill() {
    let buf = Buffer_New(4);
    let err = Bytes_Fill(buf, 1, 2, 255);
    let ok = err == null &&
             Buffer_Read(buf, 0) == 0 &&
             Buffer_Read(buf, 1) == 255 &&
             Buffer_Read(buf, 2) == 255 &&
             Buffer_Read(buf, 3) == 0;
    Buffer_Dispose(buf);
    return ok;
}

function bytes_test_compare_equal() {
    let a = Buffer_New(2);
    let b = Buffer_New(2);
    Buffer_Write(a, 0, 5);
    Buffer_Write(a, 1, 6);
    Buffer_Write(b, 0, 5);
    Buffer_Write(b, 1, 6);
    let r = Bytes_Compare(a, b);
    let ok = r[1] == null && r[0] == 0;
    Buffer_Dispose(a);
    Buffer_Dispose(b);
    return ok;
}

function bytes_test_compare_orders() {
    let a = Buffer_New(2);
    let b = Buffer_New(2);
    Buffer_Write(a, 0, 1);
    Buffer_Write(b, 0, 2);
    let r1 = Bytes_Compare(a, b);
    let r2 = Bytes_Compare(b, a);
    let ok = r1[1] == null && r1[0] == -1 && r2[1] == null && r2[0] == 1;
    Buffer_Dispose(a);
    Buffer_Dispose(b);
    return ok;
}

function bytes_test_equals_length_mismatch() {
    let a = Buffer_New(2);
    let b = Buffer_New(3);
    let r = Bytes_Equals(a, b);
    let ok = r[1] == null && r[0] == false;
    Buffer_Dispose(a);
    Buffer_Dispose(b);
    return ok;
}
```

Create `src/tests/unit/bytes_test.cpp` by copying `src/tests/unit/buffer_test.cpp` and changing only the `read_file` path to `DRYAD_TEST_DIR "/stdlib/bytes/bytes_test.dryad"`, the helper name to `run_bytes_test`, and the prefix in the test names to `BytesTest`. Declare one gtest per Dryad function:

```cpp
TEST(BytesTest, CopyRoundtrip) { EXPECT_TRUE(run_bytes_test("bytes_test_copy_roundtrip").is_truthy()); }
TEST(BytesTest, CopyOffsets) { EXPECT_TRUE(run_bytes_test("bytes_test_copy_offsets").is_truthy()); }
TEST(BytesTest, CopyZeroLengthAtEnd) { EXPECT_TRUE(run_bytes_test("bytes_test_copy_zero_length_at_end").is_truthy()); }
TEST(BytesTest, CopyRejectsBadRange) { EXPECT_TRUE(run_bytes_test("bytes_test_copy_rejects_bad_range").is_truthy()); }
TEST(BytesTest, Fill) { EXPECT_TRUE(run_bytes_test("bytes_test_fill").is_truthy()); }
TEST(BytesTest, CompareEqual) { EXPECT_TRUE(run_bytes_test("bytes_test_compare_equal").is_truthy()); }
TEST(BytesTest, CompareOrders) { EXPECT_TRUE(run_bytes_test("bytes_test_compare_orders").is_truthy()); }
TEST(BytesTest, EqualsLengthMismatch) { EXPECT_TRUE(run_bytes_test("bytes_test_equals_length_mismatch").is_truthy()); }
```

Add `tests/unit/bytes_test.cpp` to the `unit_tests` target in `src/CMakeLists.txt` next to `tests/unit/buffer_test.cpp`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake -S src -B src/build && cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.*'`
Expected: FAIL — cannot import `@std/bytes/bytes` (file does not exist).

- [ ] **Step 3: Implement the module**

Create `src/stdlib/@std/bytes/bytes.dryad` with:

```dryad
// @std/bytes/bytes.dryad
// Byte operations over @std/buffers Buffer. Buffer is the only byte container.

import { ArgumentNullException, ArgumentOutOfRangeException, IndexOutOfRangeException, Exception } from "@std/core/exceptions";
import { Buffer_New, Buffer_Read, Buffer_Write, Buffer_Len, Buffer_GetActualHandle, Buffer_GetOffset } from "@std/buffers/buffer";

function Bytes_LengthOrError(buf) {
    let len = Buffer_Len(buf);
    if (__runtime_value_kind(len) != "integer") {
        return len;
    }
    return len;
}

function Bytes_ValidateRange(buf, offset, count) {
    if (buf == null) {
        return ArgumentNullException("buffer");
    }
    let len = Bytes_LengthOrError(buf);
    if (__runtime_value_kind(len) != "integer") {
        return len;
    }
    if (offset < 0 || count < 0 || offset + count > len) {
        return ArgumentOutOfRangeException("Byte range out of bounds");
    }
    return null;
}
```

Then implement the four public functions on top of `Bytes_ValidateRange`:

- `Bytes_Copy(dst, dstOffset, src, srcOffset, count)`: validate both ranges; call `__memmove` with `Buffer_GetActualHandle` + `Buffer_GetOffset`; return `null`.
- `Bytes_Fill(buf, offset, count, value)`: validate range; reject `value < 0 || value > 255`; loop `i` from `0` to `count - 1` calling `__buffer_set(Buffer_GetActualHandle(buf), Buffer_GetOffset(buf) + offset + i, value)`; return `null`. (No offset-aware memset exists yet; do not add one.)
- `Bytes_Compare(a, b)`: validate both buffers; loop over `min(lenA, lenB)` comparing `__buffer_get` (use actual handle + offset from the Buffer helpers); return `0` when all equal and lengths match, `-1`/`1` by first differing byte, otherwise by length. Return `[result, null]`.
- `Bytes_Equals(a, b)`: if lengths differ return `[false, null]`; otherwise reuse the comparison loop and return `[cmp == 0, null]`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.*'`
Expected: PASS, all eight tests.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/bytes/bytes.dryad src/tests/stdlib/bytes/bytes_test.dryad src/tests/unit/bytes_test.cpp src/CMakeLists.txt
git commit -m "feat(bytes): add copy, fill, compare and equals"
```

---

### Task 4: Search and predicates

**Files:**
- Modify: `src/stdlib/@std/bytes/bytes.dryad`
- Modify: `src/tests/stdlib/bytes/bytes_test.dryad`
- Modify: `src/tests/unit/bytes_test.cpp`

**Interfaces:**
- Consumes: `Bytes_Compare`, `Bytes_ValidateRange` from Task 3.
- Produces:
  - `Bytes_IndexOf(buf, byte) -> [int, error]` (`-1` when absent)
  - `Bytes_LastIndexOf(buf, byte) -> [int, error]`
  - `Bytes_Contains(buf, byte) -> [bool, error]`
  - `Bytes_StartsWith(buf, prefix) -> [bool, error]`
  - `Bytes_EndsWith(buf, suffix) -> [bool, error]`

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/stdlib/bytes/bytes_test.dryad`:

```dryad
function bytes_test_index_of() {
    let buf = Buffer_New(4);
    Buffer_Write(buf, 1, 9);
    Buffer_Write(buf, 3, 9);
    let first = Bytes_IndexOf(buf, 9);
    let last = Bytes_LastIndexOf(buf, 9);
    let missing = Bytes_IndexOf(buf, 7);
    let ok = first[1] == null && first[0] == 1 &&
             last[1] == null && last[0] == 3 &&
             missing[1] == null && missing[0] == -1;
    Buffer_Dispose(buf);
    return ok;
}

function bytes_test_contains() {
    let buf = Buffer_New(2);
    Buffer_Write(buf, 0, 42);
    let yes = Bytes_Contains(buf, 42);
    let no = Bytes_Contains(buf, 43);
    let ok = yes[1] == null && yes[0] && no[1] == null && no[0] == false;
    Buffer_Dispose(buf);
    return ok;
}

function bytes_test_starts_ends_with() {
    let buf = Buffer_New(4);
    Buffer_Write(buf, 0, 1);
    Buffer_Write(buf, 1, 2);
    Buffer_Write(buf, 2, 3);
    Buffer_Write(buf, 3, 4);
    let prefix = Buffer_New(2);
    Buffer_Write(prefix, 0, 1);
    Buffer_Write(prefix, 1, 2);
    let suffix = Buffer_New(2);
    Buffer_Write(suffix, 0, 3);
    Buffer_Write(suffix, 1, 4);
    let longer = Buffer_New(5);
    let s1 = Bytes_StartsWith(buf, prefix);
    let s2 = Bytes_EndsWith(buf, suffix);
    let s3 = Bytes_StartsWith(buf, longer);
    let ok = s1[1] == null && s1[0] &&
             s2[1] == null && s2[0] &&
             s3[1] == null && s3[0] == false;
    Buffer_Dispose(buf);
    Buffer_Dispose(prefix);
    Buffer_Dispose(suffix);
    Buffer_Dispose(longer);
    return ok;
}
```

Add matching `TEST(BytesTest, ...)` entries that call these functions.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.IndexOf:BytesTest.Contains:BytesTest.StartsEndsWith'`
Expected: FAIL — functions not found.

- [ ] **Step 3: Implement the functions**

All five validate their buffers with `Bytes_ValidateRange(buf, 0, len)` (or the existing length helper), compare whole buffers by walking `__buffer_get` using the buffer's actual handle and offset, and return the documented `[value, error]` pair. `Bytes_StartsWith` returns `false` when `prefix` is longer than `buf`; `Bytes_EndsWith` compares the tail. Byte arguments outside `0..255` return `ArgumentOutOfRangeException`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/bytes/bytes.dryad src/tests/stdlib/bytes/bytes_test.dryad src/tests/unit/bytes_test.cpp
git commit -m "feat(bytes): add search and prefix/suffix predicates"
```

---

### Task 5: Concat, repeat and trim

**Files:**
- Modify: `src/stdlib/@std/bytes/bytes.dryad`
- Modify: `src/tests/stdlib/bytes/bytes_test.dryad`
- Modify: `src/tests/unit/bytes_test.cpp`

**Interfaces:**
- Consumes: `Bytes_Copy`, `Bytes_LengthOrError`, `Buffer_Slice`, `Buffer_New`.
- Produces:
  - `Bytes_Concat(a, b) -> [Buffer, error]`
  - `Bytes_Repeat(buf, count) -> [Buffer, error]`
  - `Bytes_Trim(buf) -> [Buffer, error]` (zero-copy slice)
  - `Bytes_TrimStart(buf) -> [Buffer, error]`
  - `Bytes_TrimEnd(buf) -> [Buffer, error]`

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/stdlib/bytes/bytes_test.dryad`:

```dryad
function bytes_test_concat() {
    let a = Buffer_New(2);
    Buffer_Write(a, 0, 1);
    Buffer_Write(a, 1, 2);
    let b = Buffer_New(2);
    Buffer_Write(b, 0, 3);
    Buffer_Write(b, 1, 4);
    let r = Bytes_Concat(a, b);
    let out = r[0];
    let ok = r[1] == null &&
             Buffer_Len(out) == 4 &&
             Buffer_Read(out, 0) == 1 &&
             Buffer_Read(out, 1) == 2 &&
             Buffer_Read(out, 2) == 3 &&
             Buffer_Read(out, 3) == 4;
    Buffer_Dispose(out);
    Buffer_Dispose(a);
    Buffer_Dispose(b);
    return ok;
}

function bytes_test_concat_uses_slice_view() {
    let parent = Buffer_New(4);
    Buffer_Write(parent, 2, 55);
    Buffer_Write(parent, 3, 66);
    let slice = Buffer_Slice(parent, 2, 4);
    let other = Buffer_New(1);
    Buffer_Write(other, 0, 77);
    let r = Bytes_Concat(slice, other);
    let out = r[0];
    let ok = r[1] == null &&
             Buffer_Len(out) == 3 &&
             Buffer_Read(out, 0) == 55 &&
             Buffer_Read(out, 1) == 66 &&
             Buffer_Read(out, 2) == 77;
    Buffer_Dispose(out);
    Buffer_Dispose(other);
    Buffer_Dispose(parent);
    return ok;
}

function bytes_test_repeat() {
    let buf = Buffer_New(2);
    Buffer_Write(buf, 0, 7);
    Buffer_Write(buf, 1, 8);
    let r = Bytes_Repeat(buf, 3);
    let out = r[0];
    let ok = r[1] == null &&
             Buffer_Len(out) == 6 &&
             Buffer_Read(out, 0) == 7 &&
             Buffer_Read(out, 1) == 8 &&
             Buffer_Read(out, 2) == 7 &&
             Buffer_Read(out, 5) == 8;
    let empty = Bytes_Repeat(buf, 0);
    let ok2 = empty[1] == null && Buffer_Len(empty[0]) == 0;
    Buffer_Dispose(empty[0]);
    Buffer_Dispose(out);
    Buffer_Dispose(buf);
    return ok && ok2;
}

function bytes_test_trim() {
    let buf = Buffer_New(5);
    Buffer_Write(buf, 0, 32);
    Buffer_Write(buf, 1, 9);
    Buffer_Write(buf, 2, 65);
    Buffer_Write(buf, 3, 10);
    Buffer_Write(buf, 4, 32);
    let all = Bytes_Trim(buf);
    let start = Bytes_TrimStart(buf);
    let end = Bytes_TrimEnd(buf);
    let ok = all[1] == null && Buffer_Len(all[0]) == 1 && Buffer_Read(all[0], 0) == 65 &&
             start[1] == null && Buffer_Len(start[0]) == 2 && Buffer_Read(start[0], 0) == 65 &&
             end[1] == null && Buffer_Len(end[0]) == 3 && Buffer_Read(end[0], 0) == 9;
    Buffer_Dispose(buf);
    return ok;
}

function bytes_test_trim_all_whitespace() {
    let buf = Buffer_New(2);
    Buffer_Write(buf, 0, 32);
    Buffer_Write(buf, 1, 10);
    let r = Bytes_Trim(buf);
    let ok = r[1] == null && Buffer_Len(r[0]) == 0;
    Buffer_Dispose(buf);
    return ok;
}
```

Add matching `TEST(BytesTest, ...)` entries.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.Concat*:BytesTest.Repeat:BytesTest.Trim*'`
Expected: FAIL — functions not found.

- [ ] **Step 3: Implement the functions**

- `Bytes_Concat`: read both lengths, `Buffer_New(lenA + lenB)`, `Bytes_Copy` both parts, return `[out, null]`. Dispose the output and return `[null, error]` on failure.
- `Bytes_Repeat`: reject `count < 0`; `Buffer_New(len * count)`; copy the source into each slot. `count == 0` returns an empty buffer.
- Trim family: treat `0x20`, `0x09`, `0x0A`, `0x0D` as whitespace; compute first/last non-whitespace with `Buffer_Read`; return `Buffer_Slice(buf, first, last + 1)` (or `Buffer_Slice(buf, 0, 0)` when all whitespace). Document in the module header that the result is a non-owning view and the parent must outlive it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/bytes/bytes.dryad src/tests/stdlib/bytes/bytes_test.dryad src/tests/unit/bytes_test.cpp
git commit -m "feat(bytes): add concat, repeat and zero-copy trim"
```

---

### Task 6: Hex encoding

**Files:**
- Modify: `src/stdlib/@std/bytes/bytes.dryad`
- Modify: `src/tests/stdlib/bytes/bytes_test.dryad`
- Modify: `src/tests/unit/bytes_test.cpp`

**Interfaces:**
- Consumes: `Buffer_New`, `Buffer_Read`, `Buffer_Write`, `Buffer_FromString`, `__bytes_to_string`.
- Produces:
  - `Bytes_ToHex(buf) -> [string, error]` (lowercase)
  - `Bytes_FromHex(text) -> [Buffer, error]`

- [ ] **Step 1: Write the failing tests**

Append to `src/tests/stdlib/bytes/bytes_test.dryad`:

```dryad
function bytes_test_to_hex_known_vector() {
    let buf = Buffer_New(4);
    Buffer_Write(buf, 0, 0);
    Buffer_Write(buf, 1, 15);
    Buffer_Write(buf, 2, 165);
    Buffer_Write(buf, 3, 255);
    let r = Bytes_ToHex(buf);
    let ok = r[1] == null && r[0] == "000fa5ff";
    Buffer_Dispose(buf);
    return ok;
}

function bytes_test_from_hex_roundtrip() {
    let lower = Bytes_FromHex("000fa5ff");
    let upper = Bytes_FromHex("000FA5FF");
    let ok = lower[1] == null && upper[1] == null &&
             Buffer_Len(lower[0]) == 4 &&
             Buffer_Read(lower[0], 2) == 165 &&
             Buffer_Read(upper[0], 2) == 165 &&
             Buffer_Read(upper[0], 3) == 255;
    Buffer_Dispose(lower[0]);
    Buffer_Dispose(upper[0]);
    return ok;
}

function bytes_test_from_hex_rejects_odd_length() {
    let r = Bytes_FromHex("abc");
    return r[1] != null && r[0] == null;
}

function bytes_test_from_hex_rejects_non_hex() {
    let r = Bytes_FromHex("zz");
    return r[1] != null && r[0] == null;
}

function bytes_test_from_hex_empty() {
    let r = Bytes_FromHex("");
    let ok = r[1] == null && Buffer_Len(r[0]) == 0;
    Buffer_Dispose(r[0]);
    return ok;
}
```

Add matching `TEST(BytesTest, ...)` entries.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.ToHex*:BytesTest.FromHex*'`
Expected: FAIL — functions not found.

- [ ] **Step 3: Implement the functions**

- `Bytes_ToHex`: build the result with a local `["0","1",…,"f"]` array and string concatenation, two digits per byte, lowercase. Do not call `__int_to_string`.
- `Bytes_FromHex`: convert the input to bytes with `Buffer_FromString`; reject odd length; map `'0'..'9'`, `'a'..'f'`, `'A'..'F'`; anything else returns `[null, Exception("Invalid hex digit")]`; allocate `Buffer_New(len / 2)` and write each pair.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytesTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/stdlib/@std/bytes/bytes.dryad src/tests/stdlib/bytes/bytes_test.dryad src/tests/unit/bytes_test.cpp
git commit -m "feat(bytes): add hex encoding"
```

---

### Task 7: Layer check, dependency matrix and docs

**Files:**
- Create: `src/tests/unit/stdlib_layers_test.cpp`
- Modify: `src/CMakeLists.txt` (add `tests/unit/stdlib_layers_test.cpp`)
- Create: `docs/stdlib/bytes.md`
- Create: `docs/stdlib/dependency-graph.md`
- Modify: `docs/stdlib/README.md` (module tree and guides table)

**Interfaces:**
- Consumes: the module tree on disk (`DRYAD_STDLIB_DIR`).
- Produces: a failing test on upward imports or cycles; documented layers and byte module API.

- [ ] **Step 1: Write the failing layer test**

Create `src/tests/unit/stdlib_layers_test.cpp`:

```cpp
#include <gtest/gtest.h>
#include <filesystem>
#include <fstream>
#include <map>
#include <regex>
#include <set>
#include <string>
#include <vector>

using namespace std::filesystem;

namespace {

std::map<std::string, std::set<std::string>> load_imports() {
    std::map<std::string, std::set<std::string>> graph;
    const std::regex import_re(R"(@std/([A-Za-z0-9_]+)/)");
    for (const auto& entry : recursive_directory_iterator(DRYAD_STDLIB_DIR)) {
        if (!entry.is_regular_file() || entry.path().extension() != ".dryad") {
            continue;
        }
        const auto rel = relative(entry.path(), DRYAD_STDLIB_DIR);
        auto part = rel.begin();
        if (part == rel.end() || part->string() != "@std") {
            continue;
        }
        ++part;
        if (part == rel.end()) {
            continue;
        }
        const std::string module = part->string();

        std::ifstream in(entry.path());
        std::string line;
        while (std::getline(in, line)) {
            if (line.find("from \"") == std::string::npos) {
                continue;
            }
            for (std::sregex_iterator it(line.begin(), line.end(), import_re), end; it != end; ++it) {
                graph[module].insert((*it)[1].str());
            }
        }
        graph.try_emplace(module);
    }
    return graph;
}

std::set<std::string> allowed_imports(const std::string& module) {
    if (module == "bytes") return {"core", "buffers"};
    if (module == "buffers") return {"core"};
    return {}; // no rule yet for other modules in this wave
}

} // namespace

TEST(StdlibLayersTest, BytesAndBuffersRespectLayers) {
    auto graph = load_imports();
    for (const auto& [module, imports] : graph) {
        const auto allowed = allowed_imports(module);
        if (allowed.empty()) {
            continue;
        }
        for (const auto& dep : imports) {
            EXPECT_TRUE(allowed.count(dep) == 1)
                << module << " may not import @std/" << dep;
        }
    }
}

TEST(StdlibLayersTest, NoImportCycles) {
    auto graph = load_imports();
    std::map<std::string, int> state; // 0 unvisited, 1 visiting, 2 done
    std::function<bool(const std::string&)> visit = [&](const std::string& node) {
        if (state[node] == 1) return false;
        if (state[node] == 2) return true;
        state[node] = 1;
        for (const auto& dep : graph[node]) {
            if (graph.count(dep) && !visit(dep)) return false;
        }
        state[node] = 2;
        return true;
    };
    for (const auto& [module, _] : graph) {
        EXPECT_TRUE(visit(module)) << "import cycle involving @std/" << module;
    }
}
```

Add `#include <functional>` and `tests/unit/stdlib_layers_test.cpp` to the `unit_tests` target.

- [ ] **Step 2: Run the test to verify the baseline**

Run: `cmake -S src -B src/build && cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='StdlibLayersTest.*'`
Expected: PASS for the current tree. If `BytesAndBuffersRespectLayers` fails, fix the offending import in `bytes.dryad`/`buffer.dryad` rather than widening the rule.

- [ ] **Step 3: Write the docs**

Create `docs/stdlib/bytes.md` with the API table from this plan (signatures, error convention, slice ownership note, trim whitespace set, hex lowercase rule) and three examples: copy between slices, concat, hex round-trip.

Create `docs/stdlib/dependency-graph.md` with the layer table (`L0` runtime, `L1` T0, `L2` buffers, `L3` bytes/text/encoding/math/time/collections, `L4` contracts, `L5` domains), the current edges, and the rule that `bytes` may import only `core` and `buffers`.

Update `docs/stdlib/README.md`: add `├── bytes/          byte operations over Buffer` to the module tree and a `Bytes | [bytes.md](bytes.md) | @std/bytes/bytes` row to the guides table.

- [ ] **Step 4: Run the full suite**

Run: `cmake --build src/build -j$(nproc) && ctest --test-dir src/build --output-on-failure`
Expected: all tests PASS, no compiler warnings.

- [ ] **Step 5: Commit**

```bash
git add src/tests/unit/stdlib_layers_test.cpp src/CMakeLists.txt
git commit -m "test(stdlib): enforce byte module layers and import acyclicity"

cd docs && git add stdlib/bytes.md stdlib/dependency-graph.md stdlib/README.md && git commit -m "docs(stdlib): document bytes module and dependency layers"
```

---

### Task 8: Copy benchmark

**Files:**
- Create: `src/benchmarks/bytes_bench.cpp`
- Modify: `src/CMakeLists.txt` (`DRYAD_BUILD_BENCHMARKS` block)

**Interfaces:**
- Consumes: `Intrinsics::memmove`, `Intrinsics::buffer_get`, `Intrinsics::buffer_set`, `Intrinsics::alloc_bytes`, `Intrinsics::free_bytes`.
- Produces: a manual benchmark proving that the `memmove` path is faster than the byte-by-byte loop that `Buffer_CopyTo` used before Task 2.

- [ ] **Step 1: Create the benchmark**

`src/benchmarks/bytes_bench.cpp`:

```cpp
#include <chrono>
#include <cstdio>
#include "dryad/runtime/intrinsics.h"

using namespace dryad;

int main() {
    constexpr int64_t kSize = 1 << 16;
    constexpr int kRuns = 3;

    Intrinsics intr;
    Value src = intr.alloc_bytes(kSize);
    Value dst = intr.alloc_bytes(kSize);
    const int64_t sh = src.as_integer();
    const int64_t dh = dst.as_integer();
    for (int64_t i = 0; i < kSize; ++i) {
        intr.buffer_set(sh, i, i & 0xFF);
    }

    const auto t0 = std::chrono::steady_clock::now();
    for (int r = 0; r < kRuns; ++r) {
        intr.memmove(dh, 0, sh, 0, kSize);
    }
    const auto t1 = std::chrono::steady_clock::now();
    for (int r = 0; r < kRuns; ++r) {
        for (int64_t i = 0; i < kSize; ++i) {
            Value v = intr.buffer_get(sh, i);
            intr.buffer_set(dh, i, v.as_integer());
        }
    }
    const auto t2 = std::chrono::steady_clock::now();

    const auto ms = [](auto a, auto b) {
        return std::chrono::duration<double, std::milli>(b - a).count();
    };
    std::printf("memmove: %.3f ms\nbyte loop: %.3f ms\n", ms(t0, t1), ms(t1, t2));

    intr.free_bytes(sh);
    intr.free_bytes(dh);
    return 0;
}
```

- [ ] **Step 2: Wire the benchmark target**

In `src/CMakeLists.txt`, replace the `DRYAD_BUILD_BENCHMARKS` TODO body with:

```cmake
    add_executable(bytes_bench src/benchmarks/bytes_bench.cpp)
    target_link_libraries(bytes_bench PRIVATE dryad_runtime)
```

- [ ] **Step 3: Build and run it**

Run: `cmake -S src -B src/build-bench -DDRYAD_BUILD_BENCHMARKS=ON && cmake --build src/build-bench --target bytes_bench -j$(nproc) && src/build-bench/bytes_bench`
Expected: both lines print; `memmove` is at least an order of magnitude faster than `byte loop`. Record both numbers in the task's commit message.

- [ ] **Step 4: Commit**

```bash
git add src/benchmarks/bytes_bench.cpp src/CMakeLists.txt
git commit -m "bench(bytes): compare memmove against the old byte loop"
```
