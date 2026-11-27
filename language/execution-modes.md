# Execution Modes

Dryad supports three execution tiers for the same language semantics. This is the **triple execution model**.

## Modes

| Mode | CLI / Decorator | Artifact | Characteristics |
|------|-----------------|----------|-----------------|
| **Interpreter** | default / `@compile("interpreter")` | — | Fastest startup, tree-walk evaluation |
| **Bytecode VM** | `--vm` / `@compile("bytecode")` | `.dryadc` | Profile-guided opcodes, ~10× interpreter |
| **AOT native** | `compile --aot` / `@compile("AOT")` | `.ll` / `.so` | LLVM IR → native code, lowest runtime overhead |

## Selecting a mode

### Per-function decorator

```dryad
@compile("bytecode")
function hotLoop(n) {
    let sum = 0;
    for (let i = 0; i < n; i = i + 1) {
        sum = sum + i;
    }
    return sum;
}
```

### Compile block

```dryad
@compile("AOT") {
    function entry() { return compute(); }
}
```

### CLI default

```bash
dryad script.dryad          # interpreter
dryad --vm script.dryad     # bytecode VM
```

## How it works

1. **Interpreter** runs first (optionally) to profile types via `TypeProfiler`
2. **BytecodeCompiler** emits specialized opcodes (`ADD_I32`, `GET_ELEMENT_F64`, …)
3. **AOT** lowers bytecode → Micro-IR → LLVM IR → native `.so`

Type observations flow: interpreter → bytecode → AOT.

## Companion artifacts

When you run `script.dryad` with `@compile("AOT")`, the runtime auto-loads:

- `script.dryadc` — bytecode fallback
- `script.so` — native module via `dlopen`

## Async functions

`async function` bodies always execute on the **interpreter** path (event loop integration).

## Closures

Function expressions compile to bytecode in named functions and at script level. A lambda that uses no variable of its enclosing function compiles to `MAKE_FUNCTION`; one that does compiles to `MAKE_CLOSURE`.

Captured variables live in cells shared by the function and its closures, so writes are visible both ways, as on the interpreter (`makeMultiplier` in `examples/01-language/functions.dryad`, a counter returned from a function). Scoping matches the interpreter:

- Each execution of a `let` is a new binding. A closure made in a loop body keeps the value from its own iteration.
- The `for (let i = ...)` initializer runs once, so every closure made in that loop sees the same `i`.
- A lambda assigned with `let f = function(...) { ... f(...) ... }` can call itself.

Calling a function held in a variable or parameter (`f(x)`), or the result of a call (`make()(4)`), uses `CALL_VALUE`. Compiling never removes a lambda's parameters or body from the source tree.

Still interpreter-only: `this` inside a function expression, lambdas inside library exports (`dryad compile --lib` reports them), and async functions.

## Shared semantics

Interpreter and bytecode VM agree on these rules:

| Expression | Result |
|------------|--------|
| `false && boom()` | `false`, and `boom` is not called |
| `true \|\| boom()` | `true`, and `boom` is not called |
| `true && 10` | `10` |
| `10 / 3` | `3` (integer division truncates) |
| `1 / 0`, `1 % 0` | throws `Division by zero` or `Modulo by zero` |

## Script entry quirk (VM)

Scripts with only top-level statements are wrapped as `__dryad_main` for VM execution. Top-level `let` bindings are **not** visible in `global_env` after VM script entry — wrap verification logic in a named function.

## Triple coverage gate

Required manifest examples pass interpreter, `--vm`, and `compile --aot` (51 of 54 cells). `net-tcp-client` is skipped unless you pass `--include-net`.

```bash
cd src
../docs/examples/run_benchmark.sh --triple
```

## See also

- [Phase 6 report](../implementation/phases/PHASE_6_TRIPLE_MODEL.md)
- [Triple execution plan](../implementation/plans/2026-09-16-triple-execution-model.md)
- [CLI compile options](../tooling/cli.md)
