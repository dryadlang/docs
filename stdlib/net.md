# @std/net

Blocking TCP/UDP sockets, DNS resolution, optional TLS, and a minimal HTTP client. Requires `--allow-net` (or `DRYAD_ALLOW_NET=1`).

## Modules

| Module | Purpose |
|--------|---------|
| `constants.dryad` | `SocketDomain`, `SocketType`, `Shutdown` |
| `socket.dryad` | Low-level TCP `Socket` class |
| `network_stream.dryad` | `NetworkStream extends Stream` |
| `tcp_client.dryad` | `TcpClient_Connect(host, port)` |
| `tcp_listener.dryad` | `TcpListener` server facade |
| `udp_client.dryad` | UDP send/receive |
| `dns.dryad` | Hostname → IPv4 resolution |
| `tls_stream.dryad` | TLS client wrapper (requires OpenSSL build) |
| `socket_async.dryad` | Promise wrappers over blocking socket I/O |
| `net_errors.dryad` | Error helpers |
| `http/http_client.dryad` | Minimal HTTP GET/POST client |
| `http/http_url.dryad` | URL parsing |
| `http/http_headers.dryad` | Header map |
| `http/http_request.dryad` | Request builder |
| `http/http_response.dryad` | Response parser |
| `net.dryad` | Barrel imports |

## Quick start — TCP

```dryad
import { TcpClient_Connect } from "@std/net";
import { Buffer_FromString, Buffer_AsString, Buffer_Dispose } from "@std/buffers";

let client = TcpClient_Connect("127.0.0.1", 8080);
if (client._lastError == null && client.connected) {
    let buf = Buffer_FromString("hello");
    client.send(buf, 0, 5);
    client.receive(buf, 0, 5);
    print(Buffer_AsString(buf));
    Buffer_Dispose(buf);
    client.close();
}
```

## Quick start — HTTP

```dryad
import { HttpClient_Create } from "@std/net";

let response = HttpClient_Create().get("http://127.0.0.1:8080/");
if (__runtime_value_kind(response) == "instance") {
    print(response.statusCode);
    print(response.body);
} else {
    print(response);   // error message
}
```

## Quick start — UDP

```dryad
import { UdpClient } from "@std/net";
import { Buffer_New, Buffer_FromString, Buffer_Slice, Buffer_AsString } from "@std/buffers";

let server = new UdpClient();
server.bind("127.0.0.1", 0);           // 0: let the OS pick a port
let port = server.localPort();

let client = new UdpClient();
client.sendTo("127.0.0.1", port, Buffer_FromString("ping"), 0, 4);

let buf = Buffer_New(64);
let packet = server.receiveFrom(buf, 0, 64);   // { nbytes, host, port }
print(Buffer_AsString(Buffer_Slice(buf, 0, packet.nbytes)));
client.close();
server.close();
```

## API reference

Every name below is exported by the `@std/net` barrel. Calls return an error
message string on failure instead of throwing; check with `Socket_IsSocket`,
`__runtime_value_kind(x) == "instance"`, or `== null` for `null`-on-success
calls.

### Constants (`@std/net/constants`)

| Name | Value |
|------|-------|
| `SocketDomain_IPv4`, `SocketDomain_IPv6` | `2`, `10` (`AF_INET`, `AF_INET6`) |
| `SocketType_Stream`, `SocketType_Datagram` | `1`, `2` (`SOCK_STREAM`, `SOCK_DGRAM`) |
| `Shutdown_Read`, `Shutdown_Write`, `Shutdown_Both` | `0`, `1`, `2` (`SHUT_RD`, `SHUT_WR`, `SHUT_RDWR`) |
| `SocketDomain`, `SocketType`, `Shutdown` | The same values as objects: `SocketDomain.IPv4`, `Shutdown.Both`, ... |

### DNS (`@std/net/dns`)

| Function | Returns |
|----------|---------|
| `Net_ResolveHost(host)` | IPv4 address string. IP literals are returned as is without a lookup. `null` when resolution fails |
| `Net_ResolveHostOrError(host, operation)` | `[ip, null]`, or `[null, "<operation>: failed to resolve host"]` |

### Sockets (`@std/net/socket`, `@std/net/socket_async`)

`new Socket(domain, type)` wraps one descriptor. Properties: `connected`,
`closed`, `listening`. Methods: `connect(host, port)`, `bind(host, port)`,
`listen(backlog = 128)`, `accept()`, `send(buffer, offset, count)`,
`receive(buffer, offset, count)`, `sendTo(host, port, buffer, offset, count)`,
`receiveFrom(buffer, offset, count)` (returns `{ nbytes, host, port }`),
`localPort()`, `shutdown(how)`, `close()`, `dispose()`. `send` / `receive`
return a byte count; the others return `null` on success. `shutdown(how)`
takes `Shutdown_Read`, `Shutdown_Write` or `Shutdown_Both`; any other value
returns an error instead of reaching the system call.

| Function | Returns |
|----------|---------|
| `Socket_IsSocket(value)` | `true` for a `Socket`. Safe on any value, including error strings |
| `Socket_ConnectAsync(socket, host, port)` | `Promise` resolving to `null`, rejecting with the error |
| `Socket_SendAsync(socket, buffer, offset, count)` | `Promise` of the byte count; rejects with the error |
| `Socket_ReceiveAsync(socket, buffer, offset, count)` | `Promise` of the byte count; rejects with the error |
| `TcpClient_ConnectAsync(host, port)` | `Promise` of a connected `TcpClient`; rejects with the connection error |

The async helpers schedule the blocking call on the event loop: the promise
settles on the next `Promise_Flush()` / loop turn, and the call still blocks
while it runs.

### TCP (`@std/net/tcp_client`, `@std/net/tcp_listener`, `@std/net/network_stream`)

| Name | Description |
|------|-------------|
| `TcpClient_Connect(host, port)` | A `TcpClient`. Check `client.connected`; on failure `client._lastError` holds the error |
| `TcpClient` | `connected`, `send(buffer, offset, count)`, `receive(buffer, offset, count)`, `getStream()`, `close()`, `dispose()` |
| `new TcpListener(host, port, backlog = 128)` | Server facade. `start()` binds and listens (port `0` picks one; read it from `listener.port`), `accept()` returns a `TcpClient`, `stop()`. `isListening` |
| `NetworkStream` | A `Stream` over a connected socket. `canRead` / `canWrite` are `true` while the socket is connected, `canSeek` is `false`; `read(buffer, offset, count)` / `write(buffer, offset, count)` return a byte count or an error; `flush()` returns `null`; `length`, `position` and `seek(offset, origin)` return a "not seekable" error; `close()` closes the socket |
| `NetworkStream_FromSocket(socket)` | A `NetworkStream`, or an error when `socket` is not a connected `Socket` |

### UDP (`@std/net/udp_client`)

| Name | Description |
|------|-------------|
| `new UdpClient()`, `UdpClient_Create()` | An IPv4 datagram socket |
| `bind(host, port)` | Receive on a fixed address; port `0` picks a free one. `null` or an error |
| `localPort()` | The bound port (or the ephemeral one after the first `sendTo`) |
| `sendTo(host, port, buffer, offset, count)` | Bytes sent, or an error |
| `receiveFrom(buffer, offset, count)` | `{ nbytes, host, port }`, or an error |
| `close()`, `dispose()` | `null` |

### TLS (`@std/net/tls_stream`)

| Name | Description |
|------|-------------|
| `TlsStream_IsAvailable()` | `true` when the runtime was built with `DRYAD_ENABLE_TLS=ON` |
| `TlsStream_Connect(fd, host)` | A `TlsStream` after a client handshake on a connected descriptor, or an error (`"TLS is not available in this build"` without TLS) |
| `TlsStream` | A `Stream` over the TLS session, with the same members as `NetworkStream`: `canRead`, `canWrite`, `canSeek` (`false`), `read`, `write`, `flush`, and `length` / `position` / `seek` returning a "not seekable" error; `close()` ends the TLS session |

### HTTP (`@std/net/http/*`)

| Name | Description |
|------|-------------|
| `HttpClient_Create()`, `new HttpClient()` | Client with `get(url)`, `post(url, body)`, `send(request)`, `getAsync(url)`, `postAsync(url, body)`. Returns an `HttpResponse` or an error |
| `new HttpRequest(method, url, headers, body)` | `headers` defaults to empty `HttpHeaders`, `body` to `""` |
| `new HttpHeaders()` | `set(name, value)`, `get(name)` (`null` when missing), `has(name)`, `forEach(callback(name, value))`. Names are case-insensitive (`get("content-type")` finds `Content-Type`). `set` returns an error for a name or value that is not a string or contains CR/LF |
| `new HttpResponse(statusCode, statusText, headers, body)` | Plain response record |
| `HttpResponse_Parse(raw)` | An `HttpResponse` from raw response text; an error for empty or malformed input |
| `Http_ParseUrl(url)` | Object with `scheme`, `host`, `port` (default 80 / 443) and `path` (default `/`, query included), or an error |

`https://` URLs need a TLS build. `getAsync` / `postAsync` return an already
resolved promise; the request itself runs synchronously.

`send(request)` writes every header in `request.headers`. A `Host` header
replaces the default one; `Connection` (always `close`: the client reads the
response to EOF) and `Content-Length` (the body's byte length) are set by the
client. Responses with `Transfer-Encoding: chunked` are decoded, so `body`
holds the payload; a truncated or malformed chunked body is an error
(`"Malformed chunked HTTP body"`).

## CLI

```bash
dryad --allow-net examples/06-net/tcp_client.dryad
```

Build with TLS (optional):

```bash
cmake -B build -DDRYAD_ENABLE_TLS=ON
cmake --build build
```

## C++ Intrinsics

| Intrinsic | Description |
|-----------|-------------|
| `__socket` | Create socket |
| `__connect` / `__bind` / `__listen` / `__accept` | TCP lifecycle |
| `__send` / `__recv` | String I/O |
| `__send_buffer` / `__recv_buffer` | Buffer I/O |
| `__sendto_buffer` / `__recvfrom_buffer` | UDP I/O |
| `__resolve_host` | DNS (IPv4 via getaddrinfo) |
| `__shutdown` / `__get_errno` | Socket control |
| `__tls_client_handshake` | TLS client (OpenSSL) |
| `__tls_send_buffer` / `__tls_recv_buffer` | TLS I/O |

## Known limitations

- Blocking I/O only (no epoll/kqueue event loop)
- DNS returns IPv4 addresses only
- TLS is client-only with no rigorous certificate verification
- HTTP client is minimal: one request per connection (`Connection: close`), body read until EOF, no redirects, cookies, or chunked decoding
- Errors returned as strings in most APIs, not thrown
- Calls block. In one thread, `connect` before `accept` works (the listen backlog completes the connection), but `accept` before `connect` waits forever. Serve and connect from different threads (`@std/async/threading`) or processes

## Architecture

See [net architecture plan](../implementation/plans/2026-09-16-net-architecture.md) for syscall mapping, test strategy, and phase roadmap.
