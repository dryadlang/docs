# Library examples

Demonstrates the Dryad library system (`.dyd` source + `.dyl` binary).

## Prerequisites

```bash
export DRYAD_LIBRARY_PATH=src/tests/fixtures/libs
```

## Run

```bash
src/build/bin/dryad docs/examples/08-libraries/library_usage.dyd
```

## Compile library

```bash
src/build/bin/dryad compile src/tests/fixtures/libs/@test/geom.dyd --lib -o /tmp/geom.dyl
src/build/bin/dryad link /tmp/geom.dyl -o /tmp/geom.ll
src/build/bin/dryad compile src/tests/fixtures/libs/@test/geom.dyd --lib --native -o /tmp/geom.dyl
```

## Package install

```bash
src/build/bin/dryad install src/tests/fixtures/packages/sample/dryad.toml --modules /tmp/dryad_modules
```

See [docs/implementation/tooling/DRYAD_TOML.md](../../implementation/tooling/DRYAD_TOML.md).
