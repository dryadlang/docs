# Language Specification

The canonical Dryad language specification lives in `specification/theory/`.

## Primary document

| Document | Description |
|----------|-------------|
| [dryad_theoretical_foundation_v2.pdf](./theory/dryad_theoretical_foundation_v2.pdf) | **Canonical spec** (v2.0, 34 pages) |
| [dryad_theoretical_foundation_v2.tex](./theory/dryad_theoretical_foundation_v2.tex) | LaTeX source |

## Supporting documents

| Document | Description |
|----------|-------------|
| [Theory index](./theory/README.md) | Full index with reading guide |
| [REWORK_OVERVIEW.md](./theory/REWORK_OVERVIEW.md) | C++ reimplementation strategy |
| [intrinsics_architecture_summary.md](./theory/intrinsics_architecture_summary.md) | Intrinsics-based runtime design |
| [self_hosted_native_system.md](./theory/self_hosted_native_system.md) | Self-hosting stdlib design |
| [native_functions_alternatives.md](./theory/native_functions_alternatives.md) | 8 native binding proposals |
| [TASK_CHECKLIST.md](./theory/TASK_CHECKLIST.md) | Spec vs implementation checklist |
| [V2_REVISION_SUMMARY.md](./theory/V2_REVISION_SUMMARY.md) | v2.0 changelog |

## Practical reference (implementation-aligned)

These docs describe what is **actually implemented** in `src/` today:

| Guide | Description |
|-------|-------------|
| [Syntax reference](../language/syntax.md) | Surface syntax |
| [Modules](../language/modules.md) | import/export |
| [Execution modes](../language/execution-modes.md) | Triple execution |
| [Diagrams](../language/diagrams.md) | PlantUML visual reference |
| [Standard library](../stdlib/README.md) | @std/* APIs |

## Relationship

```
specification/theory/          Formal specification (what Dryad should be)
docs/language/         Practical reference (what the compiler supports today)
docs/implementation/   How the C++ code implements the spec
```

When the spec and implementation diverge, the implementation docs note the gap (e.g. `try/catch` lexed but not parsed).
