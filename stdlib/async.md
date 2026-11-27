# @std/async

Async runtime for Dryad: microtask-driven Promises, `async`/`await`, threading bridge, and epoll I/O polling (Linux).

## Status (Phase 5 complete)

| Feature | Status |
|---------|--------|
| Microtask-driven `Promise` settlement | ✅ |
| `async function` / `await` syntax | ✅ |
| `EventLoop` pump at end of script | ✅ |
| epoll I/O poller (`__runtime_io_*`) | ✅ Linux |
| `Thread_StartAsync` / `ThreadPool.submitAsync` | ✅ |
| `Promise_Await` / `__runtime_await_promise` | ✅ |

## Quick start

```dryad
import { Promise_Resolve, Promise_Await } from "@std/async/promise";
import { Thread_StartAsync } from "@std/async/threading/threading";

async function main() {
    let x = await Promise_Resolve(40);
    let y = await Thread_StartAsync(function() { return 2; }, []);
    return x + y;
}

let result = main();
Promise_Await(result); // or rely on CLI pump at script end
```

## Modules

| Module | Key API |
|--------|---------|
| `promise` | `Promise`, `Promise_Flush`, `Promise_Await`, `Promise_All` |
| `event_loop` | `EventLoop_Schedule`, `EventLoop_Pump` |
| `threading/thread` | `Thread`, `Thread_StartAsync`, `Thread_Parallel` |
| `threading/thread_pool` | `ThreadPool`, `submitAsync`, `run` |
| `async` | Barrel re-export |

## API reference

Every name below is exported by the `@std/async` barrel. The threading names
are documented in [@std/async/threading](async-threading.md).

### Promises (`@std/async/promise`)

`new Promise(function(resolve, reject) { ... })` runs the executor at once.
Methods: `then(onFulfilled, onRejected = null)`, `catch(onRejected)`,
`finally(onFinally)`. In statement position `catch` and `finally` are
keywords; `catchError` and `finallyDo` are the same methods under names that
parse anywhere. `finally(onFinally)` calls `onFinally()` once the promise
settles and returns a promise that keeps the original outcome: the same value,
or a rejection with the same error.

| Function | Returns |
|----------|---------|
| `Promise_Resolve(value)` | A promise fulfilled with `value`. When `value` is a promise, a new promise that settles like it |
| `Promise_Reject(error)` | A rejected promise |
| `Promise_All(promises)` | Fulfills with the array of values in order; rejects with the first rejection |
| `Promise_Race(promises)` | Settles like the first promise to settle; rejects with `"Promise.race: no promises"` for an empty array |
| `Promise_Wrap(promise)` | A new promise that settles like `promise`, whether it is already settled or still pending |
| `Promise_Await(promise)` | Blocks, pumping the event loop, until `promise` settles; returns its value. Same as `await` |
| `Promise_Flush()` | Runs queued callbacks until the event loop is idle |

### Event loop (`@std/async/event_loop`)

| Function | Returns |
|----------|---------|
| `EventLoop_Schedule(callback)` | `null`. Queues `callback()` as a microtask |
| `EventLoop_RunTurn()` | `1` if it ran a task, `0` when there was nothing to run. Runs one task |
| `EventLoop_Pump()` | Runs tasks until the loop is idle |
| `EventLoop_PendingCount()` | Number of queued tasks |

## C++ intrinsics

| Intrinsic | Purpose |
|-----------|---------|
| `__runtime_schedule_microtask` | Queue microtask |
| `__runtime_event_loop_pump_all` | Drain microtasks + thread completions + I/O |
| `__runtime_await_promise` | Block until promise settles (pumps event loop) |
| `__runtime_io_register_fd` | epoll watch (Linux) |
| `__thread_spawn_async` | Worker thread → resolve/reject on main loop |
| `__set_nonblocking` | Set O_NONBLOCK on socket fd |

## Remaining limitations

- `await` blocks the interpreter while pumping (cooperative, not preemptive)
- epoll integration is foundation-level; socket async still uses microtask deferral for connect/send
- Worker threads use isolated interpreters — no shared mutable Dryad state
- `catch`/`finally` reserved in statement position — use `.catch()` / `.finally()` on promises

See [Phase 5 plan](../implementation/plans/2026-09-16-async-runtime.md).
