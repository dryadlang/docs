# @std/async/threading

OS-level threading sub-library. Each thread runs Dryad code in an isolated `Interpreter` instance.

## When to use

| Use case | API |
|----------|-----|
| Run one function on a background thread | `Thread` |
| Run multiple functions in parallel | `Thread_Parallel` |
| Reuse workers for many short jobs | `ThreadPool` |
| Sleep without blocking the whole process | `Thread_SleepMs` |

## Thread lifecycle

1. `new Thread(fn, args)` — create (does not start)
2. `thread.start()` — spawn OS thread (non-blocking)
3. `thread.join()` — block until complete, return outcome object

`join()` returns a runtime object:

```dryad
let outcome = thread.join();
let ok = __runtime_object_get(outcome, "ok");
let value = __runtime_object_get(outcome, "value");
let error = __runtime_object_get(outcome, "error");
```

## ThreadPool lifecycle

1. `new ThreadPool(workerCount)` — start N worker threads
2. `pool.submit(fn, args)` → job id (non-blocking)
3. `pool.wait(jobId)` → result (blocking)
4. `pool.run(fn, args)` — shorthand for submit + wait
5. `pool.destroy()` — shutdown workers

## API reference

Exported by `@std/async/threading` and by the `@std/async` barrel.

| Name | Description |
|------|-------------|
| `new Thread(fn, args = [])` | A thread that has not started. `start()` spawns it, `join()` blocks and returns `{ ok, value, error }`, `isStarted()` |
| `Thread_StartAsync(fn, args = [])` | Runs `fn(...args)` on a new thread and returns a `Promise` of its result, settled on the main event loop |
| `Thread_Parallel(fns)` | Runs every function on its own thread and joins them all. Returns `{ ok, value, error }` with `value` the array of results |
| `Thread_SleepMs(milliseconds)` | Sleeps the calling thread |
| `Thread_HardwareConcurrency()` | Number of hardware threads (at least `1`) |
| `new ThreadPool(workerCount = 2)` | Pool of worker threads. `submit(fn, args)` returns a job id, `wait(jobId)` blocks and returns the job's value, `run(fn, args)` is submit + wait, `submitAsync(fn, args)` returns a `Promise`, `destroy()` stops the workers |
| `ThreadPool_Map(pool, fns)` | Submits every function (no arguments) and returns the array of their values in order |

## Implementation notes

- Workers call `pthread`-backed `std::thread` via C++ `ThreadManager`
- `stdlib_root` is propagated to worker interpreters via static registry
- `pool_wait` does not hold the global mutex during blocking wait (avoids deadlock with `set_stdlib_root`)
- Jobs are tracked by `shared_ptr<ThreadJob>` in the queue to avoid races between `wait()` and worker completion

## Limitations

- `join` and `wait` block. For non-blocking use, `Thread_StartAsync` and `ThreadPool.submitAsync` return promises
- No thread cancellation or timeout
- GC/thread safety across interpreters not fully validated
- Functions passed to threads must not depend on caller's mutable closure state
