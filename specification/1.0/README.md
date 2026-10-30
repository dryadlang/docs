# Dryad Language Specification — Edition 1.0

The normative specification of the Dryad programming language, modelled on the
organisation and rigor of ECMA-262. This edition consolidates and supersedes
*Dryad Conventions 1.0*.

**Status:** Draft Standard (October 2026)
**Document identifier:** DRYAD-SPEC-1.0-DRAFT

## Read the specification

| Format | File |
|--------|------|
| HTML (responsive, with sidebar contents) | [`dryad-specification.html`](dryad-specification.html) |
| PDF (A4, print edition) | [`dryad-specification.pdf`](dryad-specification.pdf) |
| LaTeX source | [`dryad-specification.tex`](dryad-specification.tex) |

The HTML edition is the primary reading format. The PDF edition is generated
from the same source and carries the same clause numbering.

## Structure

| Clauses | Subject |
|---------|---------|
| 1–6 | Scope, conformance, references, terminology, notation, overview |
| 7–12 | Source language: lexical grammar, types, expressions, statements, functions and classes, modules |
| 13–15 | Execution model, error system, concurrency |
| 16–17 | Foreign function interface, runtime architecture and intrinsics |
| 18 | Standard library |
| 19–20 | Bytecode and IR, ahead-of-time compilation |
| 21–24 | Paradigms, formal grammar, conformance testing, limitations |
| Annexes A–D | Normative registries: errors, opcodes, intrinsics, standard library index |
| Annexes E–G | Informative: editorial decisions, proposals, bibliography |

Clauses are normative unless marked informative. Annex E records every
deliberate resolution of a conflict or ambiguity in the conventions draft.

## Building from source

Requirements: [pandoc](https://github.com/jgm/pandoc/releases) 3.1 or later and
[tectonic](https://github.com/tectonic-typesetting/tectonic/releases) (or any
XeLaTeX engine with the packages used by `assets/preamble.tex`).

```bash
export PATH="$HOME/.local/bin:$PATH"
./build.sh
```

The build concatenates `src/*.md` in clause order and produces all three
artifacts. To rebuild only the HTML edition, use the same pandoc command as in
`build.sh` with the HTML output line.

## Editing

Read [`AUTHORING.md`](AUTHORING.md) before changing normative text. Normative
changes require an erratum or a new edition; editorial changes must not alter
observable behaviour.

## Licence

MIT. See the repository `LICENSE`.
