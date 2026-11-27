# @std/io

`@std/io` is written entirely in Dryad. The C++ runtime only exposes primitive filesystem operations (`open`, `read`, `write`, `close`, `mkdir`, `unlink`, `readdir`, and so on). Path cleaning, backends, streams, and error messages live in this module.

## Layout

| Module | Role |
|--------|------|
| `io_errors.dryad` | `ValidatePath`, `NormalizePath`, error helpers |
| `path.dryad` | `Path.join`, `dirname`, `basename`, `extension`, `ensureDirectory` |
| `vfs.dryad` | `VFS`, `MemoryBackend`, `NativeBackend` |
| `file.dryad` | `Fs_ReadFile`, `Fs_WriteFile`, `Fs_Exists`, `Fs_RemoveFile`, `Fs_ListDirectory`, `Fs_Mkdir`, `Fs_SetBackend` |
| `filehandle.dryad` | Handle that accumulates writes and supports append |
| `io_concurrency.dryad` | `ThreadSafeVFS` — non-reentrant lock around one VFS |
| `stream.dryad` | Abstract `Stream`, `SeekOrigin` |
| `filestream.dryad` | `FileStream`, `FileMode`, `File_Open`, `File_ReadAllText`, `File_WriteAllText` |
| `memory_stream.dryad` | `MemoryStream` over a `Buffer` |

## Quick start

In-memory backend (no disk):

```dryad
import { Fs_ReadFile, Fs_WriteFile, Fs_SetBackend } from "@std/io/file";
import { MemoryBackend } from "@std/io/vfs";

Fs_SetBackend(MemoryBackend());
Fs_WriteFile("/test.txt", "Hello");
let content = Fs_ReadFile("/test.txt");
```

Native filesystem (the default):

```dryad
import { Fs_WriteFile, Fs_ReadFile, Fs_RemoveFile } from "@std/io/file";

Fs_WriteFile("notes.txt", "On disk");
let text = Fs_ReadFile("notes.txt");
Fs_RemoveFile("notes.txt");
```

Stream API, which creates missing parent directories:

```dryad
import { File_WriteAllText, File_ReadAllText, File_Delete } from "@std/io/file";
import { Path } from "@std/io/path";

let path = Path.join("output", "report.txt");
File_WriteAllText(path, "Hello");
let text = File_ReadAllText(path);
File_Delete(path);
```

Set `DRYAD_STDLIB_DIR` when the standard library is not on the default path.

## Error model

I/O functions return **values**. Success is `null` (or the payload, for reads). Failure is a string from `@std/core/exceptions`. Nothing is thrown across the language boundary.

```dryad
let err = Fs_WriteFile("", "x");
if (err != null) {
    print(err);   // "Path cannot be null or empty"
}
```

`Fs_Exists` is a boolean. A disposed VFS or a null path yields `false`, not an error string, so `if (Fs_Exists(path))` cannot treat a failure as "the file is there".

`Stream_IsError(value)` is true when `value` is not a stream (no `read` / `close`). Use it on the result of `File_Open`.

## Paths

`NormalizePath` and `Path.*` clean paths in Dryad, before any backend sees them:

| Input | Result |
|-------|--------|
| `a\\b\\c` | `a/b/c` |
| `foo/../bar` | `bar` |
| `/tmp/../hello.txt` | `/hello.txt` |
| `a//b` | `a/b` |
| `Path.join("foo", "/tmp/out.txt")` | `/tmp/out.txt` (absolute right-hand side wins) |
| a `0` byte anywhere in the path | rejected |

`..` that would climb above a relative path is kept (`../x` stays `../x`). `..` above an absolute root is dropped (`/../x` is `/x`).

A `0` byte is rejected because the operating system would stop the path at that byte and open a different file than the one Dryad checked. `ValidatePath` returns `"Path contains a null byte"`. `MemoryBackend` and `NativeBackend` both go through `ValidatePath`, so `/tmp/../hello.txt` and `/hello.txt` are the same key.

`Path.ensureDirectory` and `File_Open` in write modes create real directories with `__mkdir`. They are not routed through the in-memory VFS.

## VFS

```dryad
import { VFS, MemoryBackend, VFS_WriteFile, VFS_ReadFile, VFS_Dispose } from "@std/io/vfs";

let vfs = VFS(MemoryBackend());
VFS_WriteFile(vfs, "/dir/a.txt", "a");
let text = VFS_ReadFile(vfs, "/dir/a.txt");
VFS_Dispose(vfs);
```

`MemoryBackend` stores full normalized paths in one map. `Fs_ListDirectory("/dir")` returns the full keys under that prefix (`/dir/a.txt`), not bare names. `NativeBackend.listDirectory` returns the names from the operating system (`a.txt`). Do not mix the two shapes.

`NativeBackend.readFile` checks that the read result is a string. A failed read is `IOException`, and the descriptor is closed. `NativeBackend.writeFile` requires every byte to be written.

After `VFS_Dispose`, reads and writes return `ObjectDisposedException`. `VFS_Exists` returns `false`.

## FileHandle

```dryad
import { Fs_SetBackend } from "@std/io/file";
import { MemoryBackend } from "@std/io/vfs";
import { FileHandle, FileHandle_Write, FileHandle_Read, FileHandle_Close } from "@std/io/filehandle";

Fs_SetBackend(MemoryBackend());
let writer = FileHandle("/notes.txt", "write");
FileHandle_Write(writer, "ab");
FileHandle_Write(writer, "cd");   // same handle accumulates: file is "abcd"
FileHandle_Close(writer);
```

Modes are `"read"`, `"write"`, and `"append"`.

- `write` starts empty and replaces the file with everything written on this handle.
- `append` seeds from the current file when it exists, then adds. A failed seed read is returned as an error and is not concatenated into the file.
- `read` on a write/append handle, or any use after `close`, returns an error string.

## FileStream

`File_Open(path, mode)` returns a `FileStream` or an error string.

| `FileMode` | Value | Opens with |
|------------|-------|------------|
| `Read` | 0 | `__open_read` |
| `Write` | 1 | `__open_write` (create or truncate) |
| `ReadWrite` | 2 | `__open_readwrite` |
| `Append` | 3 | `__open_append`, then seek to end |

`read` and `write` take a `Buffer`, an offset, and a count. They return the byte count, or an error string. `close` is idempotent.

## ThreadSafeVFS

`FileLock_Acquire` fails immediately with `"FileLock already held"` if the lock is taken. It does not spin. The runtime is single-threaded; a waiting loop would hang the caller forever, including a re-entrant call on the same lock.

```dryad
import { MemoryBackend } from "@std/io/vfs";
import { ThreadSafeVFS, ThreadSafeVFS_WriteFile, ThreadSafeVFS_ReadFile } from "@std/io/io_concurrency";

let vfs = ThreadSafeVFS(MemoryBackend());
ThreadSafeVFS_WriteFile(vfs, "/a.txt", "one");
let text = ThreadSafeVFS_ReadFile(vfs, "/a.txt");
```

## What stays in C++

These are the filesystem primitives. Higher-level behavior is not added here.

| Intrinsic | Contract |
|-----------|----------|
| `__open_read`, `__open_write`, `__open_append`, `__open_readwrite`, `__open` | One descriptor. A `0` byte in the path returns `-1`. Descriptors are opened close-on-exec. |
| `__read(fd, n)` | Up to `n` bytes. Interrupted and short reads are retried until `n` bytes or end of file. `-1` if the first read fails. |
| `__write(fd, text)` | Every byte, retrying short and interrupted writes. `-1` on error. |
| `__read_buffer` | One read into a `Buffer`, retrying only when the call is interrupted. The count may be shorter than requested. |
| `__write_buffer` | Writes the whole range, retrying short and interrupted writes. |
| `__close`, `__lseek`, `__fsync`, `__fstat` | One syscall each. |
| `__exists`, `__filesize`, `__readdir`, `__mkdir`, `__unlink` | One syscall each. `__readdir` skips `.` and `..`. |
| `__normalize_path` | Separator swap only. Prefer `NormalizePath` / `Path.*`, which also apply `.` and `..`. |

## Examples

```bash
src/build/bin/dryad docs/examples/04-io/io_examples.dryad
src/build/bin/dryad docs/examples/04-io/file_io_usage.dryad
src/build/bin/dryad docs/examples/04-io/stream_usage.dryad
src/build/bin/dryad docs/examples/04-io/paths.dryad
```
