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

`Stream_IsError(value)` is true when `value` is not a stream instance. Use it on the result of `File_Open`. It is safe on any value, including the error string itself.

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

## API reference

Every name below is exported by the `@std/io` barrel. "Error" means an error
message string (see [Error model](#error-model)); nothing here throws.

### Files through the global VFS (`@std/io/file`)

These go through one process-wide VFS, a `NativeBackend` until
`Fs_SetBackend` replaces it.

| Function | Returns |
|----------|---------|
| `Fs_ReadFile(path)` | File text, or an error |
| `Fs_WriteFile(path, content)` | `null`, or an error. Replaces the file |
| `Fs_Exists(path)` | `true` / `false`. Never an error |
| `Fs_RemoveFile(path)` | `null`, or an error |
| `Fs_ListDirectory(path)` | Array of entries (shape depends on the backend, see [VFS](#vfs)), or an error |
| `Fs_Mkdir(path)` | `null`, or an error |
| `Fs_SetBackend(backend)` | `null`. Disposes the previous global VFS |
| `Fs_ReadFileAsync(path)`, `Fs_WriteFileAsync(path, content)`, `Fs_ExistsAsync(path)`, `Fs_RemoveFileAsync(path)`, `Fs_ListDirectoryAsync(path)`, `Fs_MkdirAsync(path)` | A `Promise` already resolved with the synchronous result. Errors resolve too; they do not reject |

### VFS instances (`@std/io/vfs`)

| Function | Returns |
|----------|---------|
| `VFS(backend)` | A VFS object over `MemoryBackend()` or `NativeBackend()` |
| `VFS_ReadFile(vfs, path)` | File text, or an error |
| `VFS_WriteFile(vfs, path, content)` | `null`, or an error |
| `VFS_ListDirectory(vfs, path)` | Array of entries, or an error. An empty path lists `/` |
| `VFS_RemoveFile(vfs, path)` | `null`, or an error |
| `VFS_Exists(vfs, path)` | `true` / `false`. `false` after dispose |
| `VFS_Mkdir(vfs, path)` | `null`, or an error |
| `VFS_Dispose(vfs)` | `null`. Later calls return `ObjectDisposedException` |
| `MemoryBackend()` | In-memory backend: one map of normalized full paths |
| `NativeBackend()` | Backend over the runtime filesystem intrinsics |
| `FileSystemBackend()` | A description string only. Backends are not pluggable: the VFS dispatches on `backend.type` (`"memory"` or `"native"`) |

### Paths (`@std/io/path`)

| Function | Returns |
|----------|---------|
| `Path_Join(a, b)` | Normalized `a/b`; `b` wins when absolute. Error for an empty `a` or a `0` byte |
| `Path_Dirname(path)` | Parent directory: `"/"` for `/file`, `"."` when there is no `/` |
| `Path_Basename(path)` | Last segment (`/srv/app/` gives `app`) |
| `Path_Extension(path)` | Last `.suffix` of the basename including the dot; `""` for none or dotfiles (`.bashrc`) |
| `Path_EnsureDirectory(path)` | `null` once the directory and its parents exist on disk, or an error |
| `Path_EnsureParentForFile(path)` | `Path_EnsureDirectory(Path_Dirname(path))` |
| `Path` | Object with `join`, `dirname`, `basename`, `extension` and `ensureDirectory` members |

`Path_EnsureDirectory` and `Path_EnsureParentForFile` always use the real
filesystem, whatever the global VFS backend is.

### Path validation and error factories (`@std/io/io_errors`)

| Function | Returns |
|----------|---------|
| `ValidatePath(path)` | `null` when usable; an error for null, empty, or containing a `0` byte |
| `NormalizePath(path)` | `/` separators, `.` and `..` applied, repeated `/` collapsed. Returns the input unchanged when it cannot be normalized |
| `InvalidPathError(path)` | `"Invalid path: <path>"` |
| `FileNotFoundError(path)` | `"File not found: <path>"` |
| `DirectoryNotFoundError(path)` | `"Directory not found: <path>"` |
| `AccessDeniedError(path)` | `"Access denied: <path>"` |
| `FileAlreadyExistsError(path)` | `"File already exists: <path>"` |
| `InvalidOperationError(operation, reason)` | `"<operation> failed: <reason>"` |

### File handles (`@std/io/filehandle`)

| Function | Returns |
|----------|---------|
| `FileHandle(path, mode)` | A handle over the global VFS. `mode` is `"read"`, `"write"` or `"append"` |
| `FileHandle_Read(handle)` | File text, or an error (closed, or not a read handle) |
| `FileHandle_Write(handle, content)` | `null`, or an error. See [FileHandle](#filehandle) for how writes accumulate |
| `FileHandle_Close(handle)`, `FileHandle_Dispose(handle)` | `null`. Idempotent |
| `FileHandle_IsOpen(handle)` | `true` until closed; `false` for `null` |
| `FileHandle_GetPath(handle)`, `FileHandle_GetMode(handle)` | The path or mode given to `FileHandle`; `null` for a `null` handle |

### Streams (`@std/io/stream`, `@std/io/filestream`, `@std/io/memory_stream`)

All streams share one shape: `canRead`, `canWrite`, `canSeek`, `length` and
`position` properties, and `read(buffer, offset, count)`,
`write(buffer, offset, count)`, `seek(offset, origin)`, `flush()` and
`close()`. `read` and `write` return a byte count or an error.

| Name | Description |
|------|-------------|
| `SeekOrigin_Begin`, `SeekOrigin_Current`, `SeekOrigin_End` | `0`, `1`, `2` (POSIX `whence`). Also `SeekOrigin.Begin` etc. |
| `Stream_IsStream(value)` | `true` for a stream instance. Safe on anything, including error strings |
| `Stream_IsError(value)` | `!Stream_IsStream(value)`: use it on what `File_Open` returned |
| `FileMode_Read`, `FileMode_Write`, `FileMode_ReadWrite`, `FileMode_Append` | `0`–`3`. Also `FileMode.Read` etc. See [FileStream](#filestream) |
| `File_Open(path, mode)` | A `FileStream`, or an error. Write modes create missing parent directories. `mode` defaults to `FileMode_Read` |
| `File_ReadAllText(path)` | The whole file as text, or an error. Reads until it has the full length |
| `File_WriteAllText(path, content)` | `null`, or an error (including a short write). Creates parent directories |
| `File_Exists(path)` | `true` / `false` on the real filesystem; `false` for invalid paths |
| `File_Delete(path)` | `null`, or an error when the file is missing or cannot be removed |
| `MemoryStream_New(capacity)` | Writable, growable stream over a new buffer |
| `MemoryStream_FromString(text)` | Read-only stream over the UTF-8 bytes of `text` |
| `MemoryStream_FromBuffer(buffer, writable)` | Stream over an existing `Buffer`, which it does not own. `writable` defaults to `false` |
| `MemoryStream_ToString(stream)` | The stream's contents as text, or `ObjectDisposedException` after `close` |
| `MemoryStream_GetBuffer(stream)` | The underlying `Buffer` (not a copy), or an error after `close` |

`File_*` here works on the real filesystem through file descriptors. `Fs_*`
goes through the global VFS. Pick one per file.

### Locking (`@std/io/io_concurrency`)

| Function | Returns |
|----------|---------|
| `FileLock()` | An unlocked lock |
| `FileLock_Acquire(lock)` | `null`, or `"FileLock already held"`. Never waits |
| `FileLock_Release(lock)` | `null` |
| `ThreadSafeVFS(backend)` | A VFS with a `FileLock` |
| `ThreadSafeVFS_ReadFile`, `ThreadSafeVFS_WriteFile`, `ThreadSafeVFS_Exists`, `ThreadSafeVFS_RemoveFile`, `ThreadSafeVFS_ListDirectory`, `ThreadSafeVFS_Mkdir` | Same as the `VFS_*` function of that name, run while holding the lock. An error if the lock is already held |

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
