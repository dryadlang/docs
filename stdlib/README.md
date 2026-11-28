# Standard Library (@std)

The Dryad standard library is **100% written in Dryad** and built on compiler intrinsics (`__syscall_*`, `__runtime_*`). Application code should use `@std/*` — never call intrinsics directly.

**Source:** `src/stdlib/@std/` (46 modules)

## Architecture

```
Application code
  ↓
@std/* high-level API (TcpClient, readFile, Promise, HttpClient)
  ↓
@std/* mid-level (Socket, VFS, Buffer, Stream)
  ↓
Compiler intrinsics (__socket, __open_read, __alloc_bytes, …)
  ↓
C++ runtime / OS syscalls
```

**Error model:** functions return error strings from `@std/core/exceptions` — no thrown exceptions across the language boundary.

## Module tree

```
@std/
├── core/           IDisposable, IEnumerable, exception factories
├── buffers/        Buffer — managed byte arrays
├── bytes/          byte operations over Buffer
├── text/           byte-indexed UTF-8 text and StringBuilder
├── json/           JSON parse and stringify
├── collections/    List, Map, Set, Queue
├── io/             VFS, streams, paths, file I/O
├── async/          Promise, event loop, threads
└── net/            sockets, TCP/UDP, TLS, HTTP
```

## Guides

Every package is importable from `@std/<package>`, which resolves to its barrel
(`@std/net` → `net/net.dryad`). Individual modules (`@std/io/vfs`) stay importable.

| Package | Guide | Import |
|---------|-------|--------|
| Core | [core.md](core.md) | `@std/core` |
| Buffers | [buffers.md](buffers.md) | `@std/buffers` |
| Bytes | [bytes.md](bytes.md) | `@std/bytes` |
| Text | [text.md](text.md) | `@std/text` |
| JSON | [json.md](json.md) | `@std/json` |
| Collections | [collections.md](collections.md) | `@std/collections` |
| I/O | [io.md](io.md) | `@std/io` |
| Async | [async.md](async.md) | `@std/async` |
| Threading | [async-threading.md](async-threading.md) | `@std/async/threading` |
| Networking | [net.md](net.md) | `@std/net` |

## Naming

- Public functions are `Type_PascalCase`: `Buffer_FromString`, `Fs_ReadFile`, `Promise_Resolve`,
  `TcpClient_Connect`. The prefix is the type or area the function belongs to.
- Classes, interfaces and constant groups are PascalCase: `List`, `IDisposable`, `FileMode_Read`.
- Methods and object members are camelCase: `list.get(0)`, `Path.join(a, b)`.
- Helpers start with an underscore (`_List_ensureIndex`) and are not part of the API, even though the
  module system can import them. (The language also has an `internal` modifier; the stdlib does not use it yet.)
- `StdlibNamingTest` enforces the function rule for every module in `src/stdlib`.

### Renamed APIs

Names from before the convention still work as deprecated aliases: each module ends with
`let oldName = NewName; // @deprecated`, and barrels re-export them. They will be removed in a future
release, so new code should use the names on the right.

<details>
<summary>All renamed names</summary>

| Module | Old name | New name |
|--------|----------|----------|
| `@std/async/event_loop` | `EventLoop_pendingCount` | `EventLoop_PendingCount` |
| `@std/async/event_loop` | `EventLoop_pump` | `EventLoop_Pump` |
| `@std/async/event_loop` | `EventLoop_runTurn` | `EventLoop_RunTurn` |
| `@std/async/event_loop` | `EventLoop_schedule` | `EventLoop_Schedule` |
| `@std/async/promise` | `Promise_all` | `Promise_All` |
| `@std/async/promise` | `Promise_await` | `Promise_Await` |
| `@std/async/promise` | `Promise_flush` | `Promise_Flush` |
| `@std/async/promise` | `Promise_race` | `Promise_Race` |
| `@std/async/promise` | `Promise_reject` | `Promise_Reject` |
| `@std/async/promise` | `Promise_resolve` | `Promise_Resolve` |
| `@std/async/promise` | `Promise_wrap` | `Promise_Wrap` |
| `@std/async/threading/thread` | `Thread_hardwareConcurrency` | `Thread_HardwareConcurrency` |
| `@std/async/threading/thread` | `Thread_parallel` | `Thread_Parallel` |
| `@std/async/threading/thread` | `Thread_sleepMs` | `Thread_SleepMs` |
| `@std/async/threading/thread` | `Thread_startAsync` | `Thread_StartAsync` |
| `@std/async/threading/thread_pool` | `ThreadPool_map` | `ThreadPool_Map` |
| `@std/io/file` | `exists` | `Fs_Exists` |
| `@std/io/file` | `existsAsync` | `Fs_ExistsAsync` |
| `@std/io/file` | `listDirectory` | `Fs_ListDirectory` |
| `@std/io/file` | `listDirectoryAsync` | `Fs_ListDirectoryAsync` |
| `@std/io/file` | `mkdir` | `Fs_Mkdir` |
| `@std/io/file` | `mkdirAsync` | `Fs_MkdirAsync` |
| `@std/io/file` | `readFile` | `Fs_ReadFile` |
| `@std/io/file` | `readFileAsync` | `Fs_ReadFileAsync` |
| `@std/io/file` | `removeFile` | `Fs_RemoveFile` |
| `@std/io/file` | `removeFileAsync` | `Fs_RemoveFileAsync` |
| `@std/io/file` | `setVFSBackend` | `Fs_SetBackend` |
| `@std/io/file` | `writeFile` | `Fs_WriteFile` |
| `@std/io/file` | `writeFileAsync` | `Fs_WriteFileAsync` |
| `@std/io/filehandle` | `FileHandle_close` | `FileHandle_Close` |
| `@std/io/filehandle` | `FileHandle_dispose` | `FileHandle_Dispose` |
| `@std/io/filehandle` | `FileHandle_getMode` | `FileHandle_GetMode` |
| `@std/io/filehandle` | `FileHandle_getPath` | `FileHandle_GetPath` |
| `@std/io/filehandle` | `FileHandle_isOpen` | `FileHandle_IsOpen` |
| `@std/io/filehandle` | `FileHandle_read` | `FileHandle_Read` |
| `@std/io/filehandle` | `FileHandle_write` | `FileHandle_Write` |
| `@std/io/filestream` | `File_delete` | `File_Delete` |
| `@std/io/filestream` | `File_exists` | `File_Exists` |
| `@std/io/filestream` | `File_open` | `File_Open` |
| `@std/io/filestream` | `File_readAllText` | `File_ReadAllText` |
| `@std/io/filestream` | `File_writeAllText` | `File_WriteAllText` |
| `@std/io/io_concurrency` | `FileLock_acquire` | `FileLock_Acquire` |
| `@std/io/io_concurrency` | `FileLock_release` | `FileLock_Release` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_exists` | `ThreadSafeVFS_Exists` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_listDirectory` | `ThreadSafeVFS_ListDirectory` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_mkdir` | `ThreadSafeVFS_Mkdir` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_readFile` | `ThreadSafeVFS_ReadFile` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_removeFile` | `ThreadSafeVFS_RemoveFile` |
| `@std/io/io_concurrency` | `ThreadSafeVFS_writeFile` | `ThreadSafeVFS_WriteFile` |
| `@std/io/memory_stream` | `MemoryStream_fromBuffer` | `MemoryStream_FromBuffer` |
| `@std/io/memory_stream` | `MemoryStream_fromString` | `MemoryStream_FromString` |
| `@std/io/memory_stream` | `MemoryStream_getBuffer` | `MemoryStream_GetBuffer` |
| `@std/io/memory_stream` | `MemoryStream_new` | `MemoryStream_New` |
| `@std/io/memory_stream` | `MemoryStream_toString` | `MemoryStream_ToString` |
| `@std/io/path` | `Path_basename` | `Path_Basename` |
| `@std/io/path` | `Path_dirname` | `Path_Dirname` |
| `@std/io/path` | `Path_ensureDirectory` | `Path_EnsureDirectory` |
| `@std/io/path` | `Path_ensureParentForFile` | `Path_EnsureParentForFile` |
| `@std/io/path` | `Path_extension` | `Path_Extension` |
| `@std/io/path` | `Path_join` | `Path_Join` |
| `@std/io/stream` | `Stream_isError` | `Stream_IsError` |
| `@std/io/stream` | `Stream_isStream` | `Stream_IsStream` |
| `@std/io/vfs` | `VFS_dispose` | `VFS_Dispose` |
| `@std/io/vfs` | `VFS_exists` | `VFS_Exists` |
| `@std/io/vfs` | `VFS_listDirectory` | `VFS_ListDirectory` |
| `@std/io/vfs` | `VFS_mkdir` | `VFS_Mkdir` |
| `@std/io/vfs` | `VFS_readFile` | `VFS_ReadFile` |
| `@std/io/vfs` | `VFS_removeFile` | `VFS_RemoveFile` |
| `@std/io/vfs` | `VFS_writeFile` | `VFS_WriteFile` |
| `@std/net/dns` | `Net_resolveHost` | `Net_ResolveHost` |
| `@std/net/dns` | `Net_resolveHostOrError` | `Net_ResolveHostOrError` |
| `@std/net/http/http_client` | `HttpClient_create` | `HttpClient_Create` |
| `@std/net/http/http_response` | `HttpResponse_parse` | `HttpResponse_Parse` |
| `@std/net/http/http_url` | `Http_parseUrl` | `Http_ParseUrl` |
| `@std/net/network_stream` | `NetworkStream_fromSocket` | `NetworkStream_FromSocket` |
| `@std/net/socket` | `Socket_fromFd` | (internal, no replacement) |
| `@std/net/socket` | `Socket_isSocket` | `Socket_IsSocket` |
| `@std/net/socket_async` | `Socket_connectAsync` | `Socket_ConnectAsync` |
| `@std/net/socket_async` | `Socket_receiveAsync` | `Socket_ReceiveAsync` |
| `@std/net/socket_async` | `Socket_sendAsync` | `Socket_SendAsync` |
| `@std/net/socket_async` | `TcpClient_connectAsync` | `TcpClient_ConnectAsync` |
| `@std/net/tcp_client` | `TcpClient_connect` | `TcpClient_Connect` |
| `@std/net/tcp_client` | `TcpClient_wrap` | (internal, no replacement) |
| `@std/net/tls_stream` | `TlsStream_connect` | `TlsStream_Connect` |
| `@std/net/tls_stream` | `TlsStream_isAvailable` | `TlsStream_IsAvailable` |
| `@std/net/udp_client` | `UdpClient_create` | `UdpClient_Create` |

</details>

## Quick examples

```dryad
import { List } from "@std/collections";
import { Fs_ReadFile, Fs_WriteFile } from "@std/io";
import { Buffer_FromString } from "@std/buffers";
import { Promise_Resolve } from "@std/async";
```

## Design documents

| Document | Description |
|----------|-------------|
| [STDLIB_ARCHITECTURE.md](../implementation/architecture/STDLIB_ARCHITECTURE.md) | Design philosophy, namespace layout |
| [STDLIB_IMPLEMENTATION_PLAN.md](../implementation/architecture/STDLIB_IMPLEMENTATION_PLAN.md) | Phase 4 implementation plan |
| [self_hosted_native_system.md](../specification/theory/self_hosted_native_system.md) | Original VFS/HTTP/async design |

## Examples

| Category | Path |
|----------|------|
| Buffers | `docs/examples/02-buffers/` |
| Collections | `docs/examples/03-collections/` |
| I/O | `docs/examples/04-io/` |
| Async | `docs/examples/05-async/` |
| Networking | `docs/examples/06-net/` |

## Diagram

See [stdlib PlantUML diagram](../diagrams/dryad-language/parts/11-stdlib.puml).
