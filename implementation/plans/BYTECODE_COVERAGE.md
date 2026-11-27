# Bytecode Coverage Matrix

> **Status:** Bytecode-eligible subset complete (6.12). Example triple gate complete (6.15).  
> **Tests:** 403+ unit tests (see [6.13 stdlib via intrinsics](2026-09-17-stdlib-via-intrinsics.md))

## Opcode inventory (50 opcodes)

| Opcode | VM | Compiler | AOT fast-path | Notes |
|--------|:--:|:--------:|:-------------:|-------|
| `PUSH_NULL/TRUE/FALSE/INT/FLOAT/CONST` | ✅ | ✅ | ✅ const | |
| `POP`, `DUP`, `SWAP` | ✅ | ✅ partial | — | `SWAP` VM-only |
| `ADD`…`MOD` (generic) | ✅ | ✅ | slow | |
| `ADD/SUB/MUL/DIV_I32` | ✅ | ✅ | ✅ | typed i32 |
| `ADD/SUB/MUL/DIV_F64` | ✅ | ✅ | ✅ | typed f64 |
| `NOT` | ✅ | ✅ | slow | unary `!` |
| `EQ`…`GTE` | ✅ | ✅ | partial | |
| `JUMP`, `JUMP_IF_FALSE` | ✅ | ✅ | — | control flow |
| `JUMP_IF_TRUE` | ✅ | ✅ | — | `\|\|` short-circuit |
| `HALT`, `CALL`, `RET` | ✅ | ✅ | CALL slow | |
| `LOAD_FAST`, `STORE_FAST` | ✅ | ✅ | ✅ | |
| `NEW_ARRAY`…`NEW_INSTANCE` | ✅ | ✅ | slow | arrays + classes |
| `CALL_GLOBAL` | ✅ | ✅ | slow | stdlib / imported functions |
| `GET_ELEMENT`, `GET_ELEMENT_F64` | ✅ | ✅ | slow / f64 | |
| `INTRINSIC_SYSCALL` | ✅ | ✅ | slow | `__syscall`, `__runtime_*` |

## Language constructs

| Construct | Interpreter | Bytecode | Notes |
|-----------|:-----------:|:--------:|-------|
| Literals | ✅ | ✅ | |
| Variables `let`/`const` | ✅ | ✅ | |
| Arithmetic / compare | ✅ | ✅ | specialized when profiled |
| Logical `&&` `\|\|` | ✅ | ✅ | short-circuit |
| Unary `!`, `-` | ✅ | ✅ | |
| `if` / `else` | ✅ | ✅ | |
| `while` | ✅ | ✅ | |
| `for (init; cond; incr)` | ✅ | ✅ | |
| `break` / `continue` | ✅ | ✅ | |
| `return` | ✅ | ✅ | |
| Array `[…]`, `arr[i]` | ✅ | ✅ | |
| `new Class()`, methods | ✅ | ✅ | via `VmRuntimeDelegate` |
| `this` | ✅ | ✅ | requires `this` slot/param |
| Direct `fn()` calls | ✅ | ✅ | |
| Calls through values `f(x)`, `make()(4)` | ✅ | ✅ | `CALL_VALUE`; arguments evaluated before the callee |
| Assignment to a script global | ✅ | ✅ | `STORE_GLOBAL` |
| Function expressions / closures | ✅ | ✅ | `MAKE_FUNCTION`, or `MAKE_CLOSURE` with cells when they capture locals |
| Intrinsic `__read`, `__runtime_*` | ✅ | ✅ | `INTRINSIC_SYSCALL` |
| `@compile` blocks | ✅ | ✅ | inline body |

## Explicitly interpreter-only (by design)

| Construct | Reason |
|-----------|--------|
| `class` / `interface` declarations | Setup phase; not in function bytecode |
| `import` / module loading | Program-level |
| `await` / async | Event loop integration |
| `super` | Constructor dispatch |
| Function expressions in library exports | `compile_function` alone has nowhere to append the lambda; `dryad compile --lib` reports it |
| `this` inside a function expression | Lambdas have no `this` slot |
| Object literals `{a:1}` | No `ObjectExpression` in parser |
| Computed method call `obj[x]()` | Rare; deferred |

## Gate for next phases

Bytecode coverage is **complete** for:

1. Numeric hot paths → AOT/JIT
2. Stdlib syscall surface via `INTRINSIC_SYSCALL`
3. Class instance methods in `@compile("bytecode")` functions
4. Control flow including `break`/`continue`

Stdlib integration via `CALL_GLOBAL` is complete (6.13). The 6.15 example gate is complete. Closures, including mutable captured locals, run on the VM in named functions and at script level. Next: tier-2 JIT.
