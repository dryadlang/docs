# Stdlib dependency graph

Modules are arranged in layers. A module may import only from lower layers.

## Layers

| Layer | Contents |
|-------|----------|
| `L0` | Runtime |
| `L1` | T0 intrinsics |
| `L2` | `buffers` |
| `L3` | `bytes`, `text`, `encoding`, `math`, `time`, `collections` |
| `L4` | contracts |
| `L5` | domains |

## Current edges

| From | To |
|------|----|
| `bytes` | `buffers` |
| `bytes` | `core` |
| `buffers` | `core` |

## Enforced rule

`StdlibLayersTest` (`src/tests/unit/stdlib_layers_test.cpp`) scans `src/stdlib/@std/<module>/**/*.dryad` import lines and enforces:

- `bytes` may import only `core` and `buffers`.
- `buffers` may import only `core`.
- The module import graph has no cycles.

Modules without a rule are not checked yet.
