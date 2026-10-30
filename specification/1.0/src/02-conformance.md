# 2 Conformance

**2.1** A *conforming implementation* is a program that implements every
normative requirement of this document for at least one conformance class, and
that does not contradict any other normative requirement.

**2.2** This document defines four conformance classes.

| Class | Identifier | Required clauses | Description |
|-------|-----------|------------------|-------------|
| Core | `core-1.0` | 7–18 | Lexical analysis, parsing, static semantics, interpretation, modules, errors, concurrency, FFI, runtime interface, standard library. |
| Virtual Machine | `vm-1.0` | 7–19 | Core, plus the bytecode compiler, bytecode verifier, and bytecode VM. |
| Ahead-of-Time | `aot-1.0` | 7–20 | Core, plus the bytecode pipeline and the AOT compiler. |
| Full | `full-1.0` | 7–20 | Core, VM, and AOT in a single implementation. |

**2.3** An implementation that claims a conformance class MUST:

1. accept every program that this document classifies as well-formed;
2. reject every program that this document classifies as ill-formed, with a
   diagnostic as specified in Clause 14;
3. produce the specified result for every well-formed program;
4. preserve the concurrency guarantees of Clause 15; and
5. satisfy every MUST or MUST NOT requirement in the clauses required by its
   class.

**2.4** An implementation MAY provide extensions provided that all of the
following hold:

1. the extension is not observable in a program that uses only the constructs
   specified in this document;
2. the extension does not alter the meaning of any specified construct;
3. the implementation documents the extension and the conditions under which
   it is active; and
4. disabling the extension restores a conforming implementation.

An implementation MUST NOT use the availability of an extension to justify a
deviation from a normative requirement.

**2.5** Certain behaviours are designated *implementation-defined* or
*implementation-dependent*. For implementation-defined behaviour, a conforming
implementation MUST document the chosen behaviour. For implementation-dependent
behaviour, the implementation may choose freely and is not required to
document the choice. This document identifies such behaviours explicitly; no
other behaviour is implementation-defined or implementation-dependent.

**2.6** A conforming implementation SHOULD pass the conformance test suite
maintained by the Dryad Language Project for its claimed class. Passing the
test suite is evidence of conformance but is not a substitute for the
normative requirements of this document.

**2.7** An implementation MUST report its edition and conformance class when
invoked with `--version` or an equivalent mechanism. The report MUST identify
this document as `DRYAD-SPEC-1.0-DRAFT`.

**2.8** Conformance is not affected by:

1. the execution tier used to evaluate a program, provided the observable
   behaviour is preserved;
2. the host operating system, provided the specified platform abstractions are
   implemented;
3. the presence or absence of optional optimisations; or
4. the textual form of a diagnostic, provided it contains the information
   required by Clause 14.

**2.9** An implementation that cannot support a required facility on a given
host MUST reject programs that require that facility at the earliest
specified point, with an error of category *unsupported* (Clause 14). Silent
degradation is not conforming.
