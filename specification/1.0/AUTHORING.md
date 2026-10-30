# Authoring Guide — Dryad Language Specification, Edition 1.0

This file governs the source under `src/`. It is an internal editorial
document, not part of the specification.

## Source layout

```
1.0/
├── src/                 one Markdown file per clause, concatenated in order
├── assets/              CSS, HTML template, LaTeX preamble
├── build.sh             builds HTML, LaTeX and PDF
├── dryad-specification.{html,tex,pdf}
└── AUTHORING.md
```

File names are zero-padded so that a lexicographic sort produces clause order.
Each file starts with exactly one level-1 heading carrying its fixed clause
number, for example:

```markdown
# 7 Lexical Grammar

## 7.1 Source Text

**7.1.1** ...
```

## Normative style

1. Write in the present tense, third person, imperative for requirements:
   "An implementation MUST...", "The lexer consumes...", never "we" or "you".
2. Use RFC 2119 keywords only in uppercase: MUST, MUST NOT, SHOULD, SHOULD NOT,
   MAY, OPTIONAL, REQUIRED.
3. Number every normative paragraph as `**N.M.K**` at the start. Do not number
   headings below level 3.
4. A clause heading is a bare noun phrase: "Lexical Grammar", not
   "Lexical Grammar (informative)" unless the whole clause is informative.
5. Mark informative subclauses explicitly: `*This subclause is informative.*`
6. Definitions are introduced by a numbered paragraph beginning with the
   defined term in italics: `**8.2.1** A *number* is ...`. Do not use a
   separate "Definition" style unless reproducing a registry entry.
7. Algorithms use numbered lists. Introduce locals with "Let x be ...".
   Transfer control with "Return x", "If ..., then ...", "Otherwise ...".
   Use `Assert:` only for invariants of the specification itself.
8. Grammar uses EBNF per Clause 5.2 in fenced code blocks with no language
   tag. One production per line. Terminals in double quotes, nonterminals in
   angle brackets, `::=` for definition, `|` for alternatives.
9. Tables use pipe tables. Every table gets a sentence introducing it.
10. Examples are informative. Introduce them with "For example:" or
    "The following program is well-formed:". Code fences use `dryad`.
11. Cross-references are plain clause numbers: "(Clause 12.4)", "see 9.3.2".
    Do not invent anchors or links to other files.
12. Use ASCII inside inline code and code blocks. In prose, avoid mathematical
    Unicode; write `R`, `Z`, `B`, `<a1, ..., an>`, `->`.
13. Every technical clause ends with a subclause "N.x Early Errors" listing the
    static restrictions, or states explicitly that it introduces none.
14. Do not describe the current implementation, performance numbers, or
    historical decisions in normative clauses except as a **NOTE**.
15. Do not invent standard-library functions. If the conventions do not define
    a needed operation, specify it as reserved or implementation-defined and
    record the gap in a final "Open Issues" list in your report (not in the
    document, unless it is a normative "reserved" clause).

## Editorial decisions already made

These are binding. Apply them consistently; do not re-open them.

| ID | Decision |
|----|----------|
| D-01 | `+` performs numeric addition and string concatenation. `++` is the increment operator only. Examples from the conventions that use `++` for concatenation are corrected. |
| D-02 | Native modules are loaded with `#<name>` (angle brackets required). Bare `#name` is an early error. |
| D-03 | Standard-library functions use `snake_case`; types use `PascalCase`; constants use `SCREAMING_SNAKE_CASE`; modules use lowercase single words. |
| D-04 | Console output is the built-in `print(...)`. `console.log` is not part of Dryad. |
| D-05 | Semicolons are required statement terminators. There is no automatic semicolon insertion. |
| D-06 | `null` is the only nullish value. `undefined` does not exist. |
| D-07 | `&&` and `||` short-circuit and return one of their operands (Clause 9.12). |
| D-08 | Equality (`==`, `!=`) never coerces. Numbers compare by IEEE 754 value (`NaN != NaN`), strings by code-point sequence, booleans by value, `null` equals only `null`, objects and arrays by identity. |
| D-09 | Error handling is split: recoverable environment failures return `Result<T, E>`; programmer errors throw a `DryadError`. Both are specified in Clauses 8 and 14. |
| D-10 | The specification defines the target language, not the current implementation. Implementation gaps are recorded in Clause 24 and Annex E, never as normative relaxations. |
| D-11 | `@compile` accepts exactly `"interpreter"`, `"bytecode"`, `"AOT"` (case-sensitive). |
| D-12 | Function parameters are positional; named arguments are not part of Edition 1.0. |
| D-13 | `match` is an expression. A `default` arm (`_`) is required. |
| D-14 | Numbers are IEEE 754 binary64. There is no separate integer value type at the language level; native integer types exist only in strict/AOT/FFI contexts. |

## Source hierarchy

When drafting, prefer sources in this order:

1. The normative text of `docs/specification/theory/conventionbook.txt`
   (Dryad Conventions 1.0), excluding its examples where they conflict with
   the editorial decisions above.
2. Clauses 1–6 of this specification (terminology and notation).
3. `docs/specification/theory/docs.txt` for user-facing explanations and
   examples that fill gaps.
4. `docs/specification/theory/dryad_theoretical_foundation_v2.tex` for
   architecture detail: intrinsics, syscalls, FFI, bytecode, AOT, BNF.
5. The implementation (`src/`) only to enumerate existing names, opcodes,
   intrinsics, error codes, or APIs. The implementation never overrides a
   normative decision.

If a required detail is absent from all sources, specify the smallest complete
behaviour consistent with the design, mark it as reserved or
implementation-defined if it is not yet stable, and report the gap.

## File assignments

| File | Clause |
|------|--------|
| `07-lexical.md` | 7 Lexical Grammar |
| `08-types.md` | 8 Types and Values |
| `09-expressions.md` | 9 Expressions |
| `10-statements.md` | 10 Statements |
| `11-functions-classes.md` | 11 Functions and Classes |
| `12-modules.md` | 12 Modules |
| `13-execution.md` | 13 Execution Model |
| `14-errors.md` | 14 Error System |
| `15-concurrency.md` | 15 Concurrency |
| `16-ffi.md` | 16 Foreign Function Interface |
| `17-runtime.md` | 17 Runtime Architecture |
| `18-stdlib.md` | 18 Standard Library |
| `19-bytecode.md` | 19 Bytecode and Intermediate Representation |
| `20-aot.md` | 20 Ahead-of-Time Compilation |
| `21-paradigms.md` | 21 Programming Paradigms (informative) |
| `22-grammar.md` | 22 Formal Grammar |
| `23-conformance-testing.md` | 23 Conformance Testing |
| `24-limitations.md` | 24 Limitations and Performance (informative) |
| `90-annex-a-errors.md` | Annex A Error-Code Registry |
| `91-annex-b-opcodes.md` | Annex B Opcode Registry |
| `92-annex-c-intrinsics.md` | Annex C Intrinsic Registry |
| `93-annex-d-stdlib-index.md` | Annex D Standard-Library Index |
| `94-annex-e-decisions.md` | Annex E Editorial Decisions |
| `95-annex-f-proposals.md` | Annex F Proposed Refinements (informative) |
| `96-annex-g-bibliography.md` | Annex G Bibliography |

## Build

Do not run `build.sh` while other writers are active; it overwrites the shared
outputs. The release editor builds after assembly:

```bash
PATH="$HOME/.local/bin:$PATH" ./build.sh
```

Outputs: `dryad-specification.html`, `dryad-specification.tex`,
`dryad-specification.pdf`.
