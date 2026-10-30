# 5 Notational Conventions

## 5.1 Normative keywords

**5.1.1** The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD,
SHOULD NOT, RECOMMENDED, NOT RECOMMENDED, MAY, and OPTIONAL in this document
are to be interpreted as described in RFC 2119 and RFC 8174.

**5.1.2** These keywords are normative only when they appear in uppercase.
Lowercase uses of the same words are descriptive.

**5.1.3** A requirement stated without a keyword is normative if it appears in
a normative clause and describes observable behaviour, a well-formedness
condition, or a conformance requirement.

**5.1.4** The word *can* describes possibility; the word *cannot* describes
impossibility under this specification. Neither word creates an optional
implementation choice.

## 5.2 Grammar notation

**5.2.1** Grammars in this document use an extended Backus–Naur form (EBNF)
with the following metacharacters.

| Notation | Meaning |
|----------|---------|
| `::=` | Production definition. |
| `<name>` | Nonterminal symbol `name`. |
| `"text"` | Terminal symbol consisting of the exact characters `text`. |
| `A \| B` | Alternative: either `A` or `B`. |
| `[ A ]` | Optional occurrence of `A` (zero or one). |
| `{ A }` | Repetition of `A` (zero or more). |
| `( A )` | Grouping. |
| `ε` | The empty production. |
| `(* text *)` | Informative comment inside a grammar. |

**5.2.2** A production of the form `<A> ::= <B> { "," <B> }` denotes a
possibly empty comma-separated sequence of `<B>`. A trailing comma is
permitted only where a production says so explicitly.

**5.2.3** Lexical grammar productions are identified by the prefix `Lexical`
and are defined in Clause 7. Syntactic grammar productions are defined in
Clause 22 and referenced throughout this document. When a syntactic production
references a token, the token name is written in angle brackets, for example
`<Identifier>`.

**5.2.4** The lexical grammar is applied before the syntactic grammar. The
lexer consumes the longest sequence of input characters that forms a valid
token, subject to the rules of Clause 7.11. Whitespace and comments separate
tokens but are not tokens themselves.

**5.2.5** A syntactic grammar is unambiguous if every well-formed token
sequence has exactly one parse tree. This document defines an unambiguous
grammar. An implementation MUST reject a token sequence for which no parse
tree exists and MUST report an early error if more than one parse tree exists.

**5.2.6** Grammar productions do not by themselves impose evaluation order.
Evaluation order is defined by the algorithms in Clauses 9 through 13.

## 5.3 Algorithm conventions

**5.3.1** Semantic algorithms are written as numbered steps. Steps are
performed in order unless a step transfers control.

**5.3.2** The phrase *Let x be ...* introduces a local specification variable
`x`. Specification variables are distinct from Dryad variables and are not
observable by a program.

**5.3.3** The phrase *If condition, then ...* executes the indented steps when
`condition` is true. *Otherwise* executes them when `condition` is false. *If
condition, then ...; otherwise ...* is equivalent.

**5.3.4** The phrase *Return value* terminates the abstract operation and
yields `value`. The phrase *Return* without a value yields the normal
completion `Normal(empty)`.

**5.3.5** The phrase *Assert: condition* states an invariant that MUST hold
whenever the algorithm reaches that step. A violation indicates an error in
this specification or in a conforming implementation, not in the source
program.

**5.3.6** An abstract operation whose name ends in `?` MAY return an abrupt
completion. In an algorithm, the notation `result = Operation?` means: perform
`Operation`; if it returns an abrupt completion, return that completion
immediately; otherwise, assign its value to `result`.

**5.3.7** Abstract operations named in CamelCase, such as `GetValue` or
`ResolveBinding`, are specification operations. They are not callable from
Dryad source text.

**5.3.8** An algorithm MAY state that behaviour is *implementation-defined* or
*implementation-dependent*. Those terms have the meanings given in Clause 2.5.

## 5.4 Completion records

**5.4.1** A completion record is a specification value of one of the following
forms.

| Form | Payload | Meaning |
|------|---------|---------|
| `Normal(value)` | A value or `empty` | Evaluation continued normally. |
| `Break(label)` | A label or `empty` | Control transfers to the matching labelled statement. |
| `Continue(label)` | A label or `empty` | Control transfers to the next iteration of the matching loop. |
| `Return(value)` | A value | Control returns from the current function. |
| `Throw(value)` | A value | An exception is propagating. |

**5.4.2** A completion record is *abrupt* if it is not `Normal`. A completion
record is *empty* if it carries no value.

**5.4.3** Statement evaluation in Clause 10 yields completion records.
Expression evaluation in Clause 9 yields values or throws; an expression never
yields `Break`, `Continue`, or `Return`.

## 5.5 Type notation

**5.5.1** This document uses the following notation for value types.

| Notation | Meaning |
|----------|---------|
| `Null` | The type whose only value is `null`. |
| `Boolean` | `true` and `false`. |
| `Number` | IEEE 754 binary64 values, including `NaN` and infinities. |
| `String` | Finite sequences of Unicode scalar values. |
| `Object` | Objects with identity, including arrays, tuples, functions, and class instances. |
| `Array<T>` | An ordered, dynamically sized sequence of `T`. |
| `Tuple<T1, ..., Tn>` | A fixed-length sequence with element types `T1` through `Tn`. |
| `Function<P..., R>` | A callable value with parameters `P...` and result `R`. |
| `Class<C>` | The type of instances of class `C`. |
| `Buffer` | The byte-buffer type of Clause 17.5. |
| `Promise<T>` | The asynchronous-result type of Clause 15.3. |
| `Result<T, E>` | A value that is either `Ok(T)` or `Err(E)` (Clause 8.3.7). |
| `Thread<T>` | A handle to a thread producing `T` (Clause 15.1). |
| `Mutex` | A mutual-exclusion primitive (Clause 15.2). |
| `any` | The union of all value types. |
| `never` | The empty type; an expression of type `never` does not return normally. |
| `T?` | Shorthand for `T | Null`. |
| `T | U` | The union of `T` and `U`. |

**5.5.2** This document uses the following notation for native types, which are
visible to the AOT compiler, the FFI, and intrinsic declarations.

| Notation | Meaning |
|----------|---------|
| `f64` | IEEE 754 binary64. |
| `i8`, `i16`, `i32`, `i64` | Signed two's-complement integers. |
| `u8`, `u16`, `u32`, `u64` | Unsigned integers. |
| `usize`, `isize` | Pointer-sized unsigned and signed integers. |
| `bool` | A native boolean. |
| `ptr<T>` | A raw pointer to `T`. |
| `void` | No value. |

**5.5.3** `T <: U` means that `T` is a subtype of `U`; every value of type `T`
is also a value of type `U`. `T ~ U` means that `T` and `U` are consistent:
their intersection is non-empty and values may flow between them under the
rules of Clause 8.5.

**5.5.4** `typeof(v)` denotes the dynamic type of value `v`. `IsCallable(v)`
denotes whether `v` is a function or class constructor. `IsObject(v)` denotes
whether `v` is an object.

## 5.6 Mathematical notation

**5.6.1** `R` denotes the real numbers, `Z` the integers, and `B` the booleans.

**5.6.2** A sequence is written `<a1, ..., an>`; an empty sequence is `<>`.
The length of sequence `s` is `len(s)`. Indexing is zero-based and written
`s[i]`.

**5.6.3** A map is written `{k1 -> v1, ..., kn -> vn}`; `m[k]` denotes lookup
and `m[k -> v]` denotes extension or update.

**5.6.4** The interval `[a, b)` denotes the set of integers `x` such that
`a ≤ x < b`. `[a, b]` includes `b`.

**5.6.5** `floor(x)` denotes the largest integer less than or equal to `x`;
`trunc(x)` denotes the integer part of `x` toward zero.

**5.6.6** `SameValue(x, y)` denotes the specification equality relation of
Clause 8.9. `SameValueZero(x, y)` is `SameValue` except that it treats `+0`
and `-0` as equal.

## 5.7 Normative and informative marking

**5.7.1** A clause is normative unless its heading or introductory paragraph
marks it informative. Annexes A through D are normative; Annexes E through G
are informative.

**5.7.2** Within a normative clause, a paragraph beginning with **NOTE** is
informative and does not create a requirement.

**5.7.3** Examples are informative unless the example is introduced as a
normative test vector.

## 5.8 Document versioning

**5.8.1** This document is Edition 1.0, Draft. Clause numbers are stable
within the edition. An erratum MUST NOT renumber a clause; it MAY add
subclauses with a new final component.

**5.8.2** A future edition MAY renumber clauses only if it publishes a
migration table mapping old clause numbers to new ones.
