# Dryad Documentation

Central documentation for the Dryad programming language and its C++ implementation.

**Full inventory:** [SITEMAP.md](SITEMAP.md)

> **Module repository.** This documentation is a standalone repo (`github.com/dryadlang/docs`), mapped into the source tree as the `docs/` submodule. Links to `../src/` resolve when the module is checked out inside the source repository.

---

## Start here

| Audience | Path |
|----------|------|
| **New to Dryad** | [Quick start](getting-started/quick-start.md) |
| **Writing code** | [Language reference](language/README.md) → [Standard library](stdlib/README.md) |
| **Building libraries** | [User libraries](libraries/README.md) |
| **CLI & tooling** | [Tooling](tooling/README.md) |
| **Language designers** | [Specification](specification/README.md) (canonical PDF) |
| **C++ implementors** | [Implementation docs](implementation/README.md) |
| **Visual overview** | [PlantUML diagrams](language/diagrams.md) |

---

## Documentation map

```
docs/
├── README.md                 ← you are here
├── SITEMAP.md                Complete file inventory
│
├── getting-started/          Install, build, contribute
│   ├── quick-start.md
│   ├── building.md
│   └── contributing.md
│
├── language/                 User-facing language reference
│   ├── syntax.md
│   ├── modules.md
│   ├── execution-modes.md
│   └── diagrams.md
│
├── specification/            Canonical language specification
│   ├── README.md             Spec index
│   └── theory/               PDF, LaTeX source, architecture design docs
│
├── stdlib/                   @std/* API guides
│   ├── core.md, buffers.md
│   ├── collections.md, io.md
│   └── async.md, net.md
│
├── libraries/                User libraries & packages
│   ├── overview.md
│   └── packages.md
│
├── tooling/                  CLI reference
│   └── cli.md
│
├── examples/                 Runnable examples + benchmark manifest
│
├── diagrams/                 PlantUML (core + stdlib)
│   └── dryad-language/
│
└── implementation/           Internal dev docs
    ├── phases/               Completion reports
    ├── architecture/         System design
    ├── plans/                Feature plans
    ├── principles/           SOLID, resource efficiency
    └── tooling/              dryad.toml spec
```

---

## Key resources

### Canonical specification

[dryad_theoretical_foundation_v2.pdf](./specification/theory/dryad_theoretical_foundation_v2.pdf) — formal language definition (v2.0, 34 pages)

### Implementation status

| Area | Status | Report |
|------|--------|--------|
| Lexer & parser | ✅ | [Phase 1](implementation/phases/PHASE_1_COMPLETE.md) |
| Interpreter | ✅ | [Phase 2](implementation/phases/PHASE_2_COMPLETE.md) |
| Intrinsics (~50 syscalls) | ✅ | [Phase 3](implementation/phases/PHASE_3_FINAL.md) |
| Standard library | 🔄 | [Phase 4](implementation/phases/PHASE_4_PROGRESS_REPORT.md) |
| Bytecode VM | ✅ | [Phase 6](implementation/phases/PHASE_6_TRIPLE_MODEL.md) |
| AOT / LLVM | ✅ | [Triple model plan](implementation/plans/2026-09-16-triple-execution-model.md) |
| User libraries | ✅ | [Library system](implementation/architecture/LIBRARY_SYSTEM.md) |

### Standard library modules

| Module | Guide |
|--------|-------|
| `@std/core` | [core.md](stdlib/core.md) |
| `@std/buffers` | [buffers.md](stdlib/buffers.md) |
| `@std/collections` | [collections.md](stdlib/collections.md) |
| `@std/io` | [io.md](stdlib/io.md) |
| `@std/async` | [async.md](stdlib/async.md) |
| `@std/net` | [net.md](stdlib/net.md) |

### Examples & tests

```bash
cd src
../docs/examples/run_benchmark.sh --triple  # all examples × 3 modes
cd build && ctest --output-on-failure       # full test suite
```

Catalog: [examples/README.md](./examples/README.md)

---

## Related repositories

| Path | Role |
|------|------|
| `src/` | C++ compiler, runtime, standard library, tests |
| `docs/` | This module repository — documentation, examples, specification |
| `CHANGELOG` | Notable changes per release |

---

## Contributing to docs

- User docs → `language/`, `stdlib/`, `libraries/`
- Implementation docs → `implementation/`
- Diagrams → `diagrams/dryad-language/parts/`
- Update [SITEMAP.md](SITEMAP.md) when adding new files

See [CONTRIBUTING.md](../CONTRIBUTING.md) for the development workflow.
