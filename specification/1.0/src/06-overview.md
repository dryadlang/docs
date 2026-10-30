# 6 Overview

## 6.1 Language identity

**6.1.1** Dryad is a statically scoped, dynamically typed, multi-paradigm
programming language. It supports procedural, object-oriented, and functional
programming in a single surface syntax.

**6.1.2** Dryad source text is compiled to an internal program representation
and may be executed by three interchangeable tiers: a tree-walking interpreter,
a bytecode virtual machine, or an ahead-of-time compiled native binary.

**6.1.3** The language provides first-class functions, closures, classes with
single inheritance, interfaces, modules, exceptions, asynchronous functions,
operating-system threads, mutexes, a foreign function interface, and a
standard library written entirely in Dryad.

## 6.2 Design axioms

*This subclause is informative. The axioms guide interpretation where this
document leaves room for judgement; they do not override an explicit
requirement.*

**Axiom 1 — Clarity over performance.** Readability and predictable behaviour
take precedence over premature optimisation. An optimisation is conforming
only if it preserves observable behaviour.

**Axiom 2 — Syntactic consistency.** Syntactic constructs follow uniform,
predictable patterns. Similar operations use similar notation.

**Axiom 3 — Informative errors.** Every error reports a category, a numeric
code, a source location, and, where the cause is determinable, a suggested
correction (Clause 14).

**Axiom 4 — Composability.** Language primitives combine without special
cases. A value of a given type may be used wherever that type is accepted.

**Axiom 5 — Zero surprises.** Every construct has exactly one specified
behaviour. The implementation MUST NOT depend on unspecified state, ambient
configuration, or evaluation order that this document leaves undefined.

## 6.3 Surface language

**6.3.1** A minimal Dryad program is a sequence of statements. The following
program is well-formed and prints `42`:

```dryad
function answer() {
    return 42;
}

print(answer());
```

**6.3.2** The principal syntactic categories are:

| Category | Examples | Clause |
|----------|----------|--------|
| Declarations | `let`, `const`, `function`, `class`, `import`, `export` | 10–12 |
| Statements | `if`, `while`, `for`, `try`, `return`, `throw` | 10 |
| Expressions | operators, calls, member access, `match`, arrow functions | 9 |
| Types | primitives, arrays, tuples, functions, classes, native types | 8 |
| Modules | named, namespace, side-effect, and identifier imports | 12 |
| Directives | `#<io>`, `"use strict types"`, `@compile(...)` | 7, 8, 13 |

## 6.4 Execution architecture

**6.4.1** A conforming implementation MUST provide at least one execution tier
and SHOULD provide all three. The tiers are:

| Tier | Input | Requirement |
|------|-------|-------------|
| Interpreter | Abstract syntax tree | Evaluate the tree directly. |
| Bytecode VM | Bytecode module (Clause 19) | Execute verified bytecode. |
| AOT | Native object code (Clause 20) | Execute ahead-of-time compiled code. |

**6.4.2** All tiers MUST be observationally equivalent for every well-formed
program. Tier selection is not observable except through the timing and the
diagnostic facilities explicitly defined in Clause 20.

**6.4.3** The interpreter MUST collect the runtime type observations required
by the metadata header of Clause 19.8 when the implementation also provides a
bytecode or AOT tier. An implementation that provides only the interpreter is
not required to emit metadata.

**6.4.4** The `@compile` decorator (Clause 13.9) selects the execution tier
for a function or block. In the absence of a decorator, the tier is selected
by the implementation or by the implementation's command-line interface.

## 6.5 Native boundary and self-hosting

**6.5.1** A Dryad implementation consists of a native runtime and a standard
library. The native runtime MUST expose only the intrinsics specified in
Clause 17.3 and Annex C. The standard library MUST be implemented in pure
Dryad and MUST obtain all host services through those intrinsics.

**6.5.2** An implementation MAY provide additional host facilities through the
foreign function interface of Clause 16. Such facilities are not part of the
standard library and do not extend the intrinsic set.

**6.5.3** The native runtime MUST NOT contain language-specific standard
library logic beyond the intrinsics. In particular, collection types,
formatting, HTTP, JSON, cryptography, and path handling are implemented in
Dryad.

## 6.6 Document organisation

**6.6.1** The normative clauses are organised by language layer. Clauses 7–12
define the source language: lexical structure, values and types, expressions,
statements, declarations, and modules. Clause 13 defines how those constructs
execute. Clause 14 defines errors. Clause 15 defines concurrency. Clauses 16
and 17 define the native boundary. Clause 18 defines the library. Clauses 19
and 20 define the compiled representations.

**6.6.2** Clause 22 contains the complete grammar. A production in Clause 22 is
normative. Syntax shown in other clauses is explanatory and MUST agree with
Clause 22; if it does not, Clause 22 prevails and the discrepancy is an erratum.

**6.6.3** Annex A is the error-code registry. Annex B is the opcode registry.
Annex C is the intrinsic registry. Annex D is the standard-library index.
Annex E records editorial decisions against the conventions draft. Annex F is
the informative proposals annex. Annex G is the bibliography.
