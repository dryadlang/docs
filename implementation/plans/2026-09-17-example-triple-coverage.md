# Phase 6.15 — Example Triple Coverage Gate

> **Status:** Complete  
> **Gate:** Every required example in `docs/examples/manifest.json` runs in all three execution modes.  
> **Result:** 51/54 cells passed (3 skipped: optional `net-tcp-client`)

## Definition of done

| Mode | Command | Success criteria |
|------|---------|------------------|
| **Interpreter** | `dryad script.dryad` | Runs without error |
| **Bytecode VM** | `dryad --vm script.dryad` | Runs without error |
| **AOT** | `dryad compile script.dryad --aot -o out.ll` | Compiles to LLVM IR |

Run the matrix from the source tree:

```bash
cd src
../docs/examples/run_benchmark.sh --triple
```

`net-tcp-client` is `optional` and requests `--allow-net`. The benchmark skips it unless `--include-net` or `--include-optional` is set, because it needs an echo server on port 9090.

## Result

| Example | Interpreter | VM | AOT compile |
|---------|-------------|----|-------------|
| `lang-basics` | ✅ | ✅ | ✅ |
| `lang-control-flow` | ✅ | ✅ | ✅ |
| `lang-functions` | ✅ | ✅ | ✅ |
| `lang-classes` | ✅ | ✅ | ✅ |
| `lang-compile-decorator` | ✅ | ✅ | ✅ |
| `buffers-usage` | ✅ | ✅ | ✅ |
| `collections-usage` | ✅ | ✅ | ✅ |
| `io-vfs` | ✅ | ✅ | ✅ |
| `io-native` | ✅ | ✅ | ✅ |
| `io-streams` | ✅ | ✅ | ✅ |
| `io-paths` | ✅ | ✅ | ✅ |
| `async-promises` | ✅ | ✅ | ✅ |
| `async-await` | ✅ | ✅ | ✅ |
| `async-threading` | ✅ | ✅ | ✅ |
| `net-tcp-client` | skip | skip | skip |
| `net-http-parse` | ✅ | ✅ | ✅ |
| `libraries-usage` | ✅ | ✅ | ✅ |
| `turing-dryadsquare` | ✅ | ✅ | ✅ |

## What the gate required

Two VM cells were still failing after the earlier I/O and AOT gaps had already gone green.

### Closures (`lang-functions`)

`makeMultiplier` returns `function(x) { return x * factor; }`. Compiling that named function to bytecode dropped the captured `factor` and handed back a native function tied to a VM that had already returned.

Named functions that contain a function expression stay on the interpreter. The closure keeps its environment, and `--vm` prints `42`, `42`, and `120`.

`MAKE_FUNCTION` invokes the lambda through the runtime delegate instead of capturing the VM instance.

### Script lambdas (`async-await`)

Bytecode compilation used to move a lambda's parameters and body out of the AST. Programs that also have a named function are then executed by the interpreter, which saw a zero-parameter function and rejected `.then(function(v) { ... })` with "expects between 0 and 0 arguments, got 1".

Compilation now copies the parameter list and borrows the body for the duration of the compile. The source expression is unchanged. `--vm` prints `42`, then microtask order `0` and `1`.

## Follow-up semantics

After the gate, interpreter and VM were aligned on logical and integer arithmetic:

- `&&` / `||` short-circuit and return the deciding operand.
- Integer division truncates. Division or modulo by zero throws.

## Key files

| Area | Path |
|------|------|
| Examples manifest | `docs/examples/manifest.json` |
| Triple benchmark | `docs/examples/run_benchmark.sh --triple` |
| Lambda compilation | `src/src/compiler/bytecode_compiler.cpp` |
| Closure call | `src/src/runtime/vm.cpp` (`MAKE_FUNCTION`) |
| Logical and arithmetic evaluation | `src/src/compiler/evaluator.cpp` |
