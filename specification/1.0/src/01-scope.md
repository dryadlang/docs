# 1 Scope

**1.1** This document specifies the syntax, static semantics, and runtime
semantics of the Dryad programming language, together with the normative
requirements for its execution engines, native runtime interface, standard
library, bytecode format, and ahead-of-time compilation pipeline.

**1.2** This document specifies the observable behaviour of a conforming
implementation. Observable behaviour comprises:

1. the result of evaluating every well-formed program;
2. the sequence of side effects produced during evaluation;
3. the errors and diagnostics reported for ill-formed programs;
4. the values returned by standard-library functions; and
5. the concurrency guarantees defined in Clause 15.

**1.3** This document does not specify:

1. the hardware, operating system, or host environment on which an
   implementation runs, except where a boundary is explicitly defined;
2. the internal data structures, algorithms, or source-code organisation of an
   implementation;
3. user interfaces, editors, debuggers, package registries, or build tools,
   except where their behaviour is observable through a normative interface;
4. the contents of third-party libraries; or
5. performance, except where a normative requirement is explicitly stated.

**1.4** A program is *well-formed* if it satisfies every early error rule in
this document. A well-formed program has exactly one specified behaviour.
This document does not define undefined behaviour; where a program violates a
precondition, the implementation MUST report a runtime error as specified in
Clause 14.

**1.5** The unit of conformance is a *conforming implementation*, as defined
in Clause 2. Conformance is claimed per conformance class, not per feature.

**1.6** This document is organised as follows:

| Clauses | Subject |
|---------|---------|
| 1–6 | Scope, conformance, references, terminology, notation, overview |
| 7 | Lexical grammar |
| 8 | Types and values |
| 9 | Expressions |
| 10 | Statements |
| 11 | Functions and classes |
| 12 | Modules |
| 13 | Execution model |
| 14 | Error system |
| 15 | Concurrency model |
| 16 | Foreign function interface |
| 17 | Runtime architecture and intrinsics |
| 18 | Standard library |
| 19 | Bytecode and intermediate representation |
| 20 | Ahead-of-time compilation |
| 21–24 | Paradigms, formal grammar, conformance testing, limitations |
| Annexes A–G | Registries, editorial decisions, proposals, bibliography |
