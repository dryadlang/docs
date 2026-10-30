---
title: Dryad Language Specification
author: Pedro Kaleb
date: October 2026
lang: en
abstract: |
  This document specifies the Dryad programming language: its lexical
  grammar, type system, expressions, statements, declarations, module
  system, execution model, error model, concurrency primitives, foreign
  function interface, runtime architecture, standard library, bytecode
  instruction set, and ahead-of-time compilation pipeline. It is the
  normative reference for implementors of Dryad and supersedes the
  Dryad Conventions 1.0 draft as the authoritative specification.
---

# Status of This Document {.unlisted}

**Document identifier.** DRYAD-SPEC-1.0-DRAFT.

**Status.** Draft Standard. This edition is complete for review but is not
yet a ratified standard. Implementations claiming conformance to this edition
MUST identify the edition and the conformance class they implement (Clause 2).

**Normative content.** Clauses 1 through 20 and Annexes A through D are
normative. The Introduction, Clause 21, Clause 24, and Annexes E through G are
informative. A clause or annex is normative unless it is explicitly marked
*informative*. Within normative clauses, text marked **NOTE** is informative.

**Relationship to prior documents.** This document consolidates and replaces
the content of *Dryad Conventions 1.0* (the `conventions` publication). It also
supersedes *Dryad Theoretical Foundation v2.0* as the authoritative language
specification; the v2 document is retained as an informative architecture
paper. Where this document and any prior document disagree, this document
prevails.

**Editorial decisions.** The conventions draft contains internal
inconsistencies. Every deliberate resolution is recorded in Annex E. An
implementation that follows Annex E is following this specification, not
deviating from it.

**Change control.** Changes to normative content require a new edition or a
published erratum. Editorial changes that do not alter normative behaviour may
be published as a revision of the same edition.

**Licence.** This specification is published under the MIT Licence.

# Introduction {.unlisted}

*This Introduction is informative.*

Dryad is a multi-paradigm programming language designed for clarity,
portability, and deterministic execution. Its syntax is deliberately close to
JavaScript and TypeScript, while its runtime architecture borrows the
micro-kernel discipline of systems languages: a small native core exposes a
fixed set of intrinsics, and the entire standard library is written in Dryad
itself.

The language is defined by the interaction of four layers:

1. **Source language.** A statically scoped, dynamically typed language with
   optional strict typing.
2. **Execution tiers.** A tree-walking interpreter, a stack-based bytecode
   virtual machine, and an ahead-of-time compiler. The tiers are required to
   be observationally equivalent.
3. **Native boundary.** A minimal, explicitly specified intrinsic interface
   through which all operating-system interaction occurs.
4. **Standard library.** Pure Dryad modules that define the user-visible
   platform, including I/O, networking, collections, concurrency, and
   diagnostics.

This specification is written for implementors. It does not teach the
language, and it does not describe the current implementation. It defines what
a conforming implementation MUST do. Where the current implementation differs,
the implementation is non-conforming; Clause 24 and Annex E identify known
gaps for planning purposes.

## Design goals

| Goal | Normative consequence |
|------|----------------------|
| Syntactic familiarity | The surface grammar follows JavaScript/TypeScript conventions unless this document states otherwise. |
| Paradigm flexibility | Procedural, object-oriented, and functional constructs are first-class and freely composable. |
| Optional typing | Dynamic typing is the default; strict typing is opt-in per module, function, or declaration. |
| Triple execution | The interpreter, bytecode VM, and AOT compiler MUST preserve the same observable semantics. |
| Native concurrency | Threads, mutexes, and asynchronous functions are language primitives, not library add-ons. |
| Self-hosting | The standard library MUST be written in pure Dryad and MUST use only the specified intrinsics. |
| Zero surprises | Every construct in this document has exactly one defined behaviour; undefined behaviour is not permitted. |

## Reading guide

A reader implementing an interpreter SHOULD read Clauses 1–15 in order. A
reader implementing the bytecode VM SHOULD additionally read Clause 19. A
reader implementing the AOT compiler SHOULD read Clauses 19 and 20. A reader
implementing the standard library SHOULD read Clauses 8, 14, 17, and 18.
