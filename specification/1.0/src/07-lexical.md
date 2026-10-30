# 7 Lexical Grammar

## 7.1 Source Text

**7.1.1** A *source text* is a finite sequence of Unicode scalar values. Each scalar value in a source text is a *source character*. A Unicode scalar value is any code point in the range U+0000 through U+D7FF or U+E000 through U+10FFFF. Surrogate code points U+D800 through U+DFFF are not Unicode scalar values and MUST NOT occur in a source text.

**7.1.2** Source text is encoded in UTF-8. The encoding MUST be well-formed as defined by Unicode: every sequence MUST be the shortest encoding of its scalar value, MUST NOT encode a surrogate, and MUST NOT encode a value greater than U+10FFFF. An implementation MUST validate the encoding before or during lexing and MUST report an early error of category *encoding* for any ill-formed sequence. An implementation MUST NOT replace an ill-formed sequence with U+FFFD and continue.

**7.1.3** A *source text unit* is the source text of exactly one module (Clause 12) or exactly one complete input accepted by an implementation. Lexing is performed independently for each source text unit. A token, comment, string literal, or template literal MUST NOT begin in one source text unit and end in another. The end of a source text unit is the *end of input*.

**7.1.4** A source text unit MAY begin with a single byte-order mark U+FEFF. The initial byte-order mark is not a source character and is discarded before tokenization. It does not contribute to a token, a comment, a line, or a column. A U+FEFF that is not the first scalar value of the unit is a WhiteSpace character under 7.2.1, and a second U+FEFF at the start of a unit is likewise WhiteSpace. No other byte-order mark handling is defined; U+FFFE and U+FEFF in any other position have no special encoding meaning.

**7.1.5** Source positions are pairs of a *line number* and a *column number*. Both are one-based. The first source character of a source text unit has line 1 and column 1. The column number of a source character is one greater than the column number of the preceding source character on the same line. A LineTerminatorSequence resets the column to 1 and increments the line. A horizontal tab counts as one column. Positions are measured in Unicode scalar values, not bytes and not UTF-16 code units.

**7.1.6** Source text is not normalized. An implementation MUST NOT apply Unicode Normalization Form C, Form D, Form KC, or Form KD to source text, to identifiers, or to the contents of string and template literals. Source text SHOULD be in Normalization Form C. Two identifiers that are canonically equivalent but not identical as code-point sequences are distinct identifiers (7.5.7).

**7.1.7** Every Unicode scalar value is permitted in a source text unit. A scalar value that has no role in any token production is a lexical error only when it occurs outside a comment, string literal, or template literal. Noncharacters and unassigned code points are permitted in comments and literals; they are not permitted in identifiers unless the Unicode property ID_Start or ID_Continue includes them.

**7.1.8** There is no hashbang convention. A source text unit that begins with `#!` is tokenized under 7.9; because the character following `#` is not `<`, the unit is ill-formed. There is no encoding declaration syntax. The encoding of a source text unit is always UTF-8 and is not affected by any comment or directive.

**7.1.9** If a source text unit is empty, its only token is EndOfFile at line 1, column 1. Otherwise, EndOfFile is positioned immediately after the last source character, at the line and column that would follow that character.

## 7.2 Whitespace and Line Terminators

**7.2.1** *WhiteSpace* is any code point in Table 7.2.1-1.

| Code point | Name | General category |
|------------|------|------------------|
| U+0009 | CHARACTER TABULATION | Cc |
| U+000B | LINE TABULATION | Cc |
| U+000C | FORM FEED | Cc |
| U+0020 | SPACE | Zs |
| U+00A0 | NO-BREAK SPACE | Zs |
| U+1680 | OGHAM SPACE MARK | Zs |
| U+2000 | EN QUAD | Zs |
| U+2001 | EM QUAD | Zs |
| U+2002 | EN SPACE | Zs |
| U+2003 | EM SPACE | Zs |
| U+2004 | THREE-PER-EM SPACE | Zs |
| U+2005 | FOUR-PER-EM SPACE | Zs |
| U+2006 | SIX-PER-EM SPACE | Zs |
| U+2007 | FIGURE SPACE | Zs |
| U+2008 | PUNCTUATION SPACE | Zs |
| U+2009 | THIN SPACE | Zs |
| U+200A | HAIR SPACE | Zs |
| U+202F | NARROW NO-BREAK SPACE | Zs |
| U+205F | MEDIUM MATHEMATICAL SPACE | Zs |
| U+3000 | IDEOGRAPHIC SPACE | Zs |
| U+FEFF | ZERO WIDTH NO-BREAK SPACE | Cf |

**7.2.2** *LineTerminator* is one of the following code points: LF U+000A, CR U+000D, LS U+2028, and PS U+2029. A *LineTerminatorSequence* is LF; CR; CR immediately followed by LF; LS; or PS. A CRLF pair is one LineTerminatorSequence, not two. U+2028 and U+2029 are line terminators and are not WhiteSpace.

**7.2.3** *Trivia* is WhiteSpace, a LineTerminatorSequence, or a Comment. Trivia separates tokens and is not part of any token. Trivia MAY be discarded after tokenization. An implementation that retains trivia for tooling MUST preserve source positions and MUST NOT expose trivia as tokens to the syntactic grammar.

**7.2.4** WhiteSpace and LineTerminatorSequence have no syntactic significance other than separating tokens and terminating LineComments. Indentation has no syntactic meaning. The amount and kind of trivia between two tokens never changes the syntactic structure, except where a lexical goal or a separation requirement in 7.4.10 or 7.10.7 applies.

**7.2.5** Trivia MAY occur before the first token, between any two tokens, and after the last token before EndOfFile. Trivia MUST NOT occur inside any token. A StringLiteral and a TemplateContent token can contain source characters that would otherwise be trivia, but those characters are part of the literal and are not trivia. In particular, trivia MUST NOT occur between `#`, `<`, the name, and `>` of a NativeDirective (7.9.4).

**7.2.6** A LineTerminatorSequence inside a StringLiteral is an early error unless it is immediately preceded by a reverse solidus as a line continuation (7.7.8). A LineTerminatorSequence inside TemplateContent is permitted and contributes to the template value under 7.8.12. A LineTerminatorSequence inside a Comment is permitted and advances the line count.

**7.2.7** Line terminators do not terminate statements. Dryad has no automatic semicolon insertion (D-05). A semicolon is required wherever the syntactic grammar requires one. A line terminator between two tokens is trivia, and the token sequence is the same as if a single space had appeared.

**7.2.8** The line number increases by one for each LineTerminatorSequence. A CRLF sequence increases the line number by exactly one. A CR that is not followed by LF increases the line number by one. LS and PS each increase the line number by one. WhiteSpace other than a line terminator never changes the line number.

**7.2.9** An implementation MUST treat a lone CR and a CRLF sequence as line terminators for the purposes of positions and LineComments. An implementation MUST NOT treat a CRLF sequence as two line terminators. An implementation MUST NOT treat FF U+000C as a line terminator; FF is WhiteSpace.

**7.2.10** The following program is well-formed and contains trivia of every kind:

```dryad
// Leading line comment.

/* A block comment
   spanning lines. */

function main() {
    let total = 1 + 2; /* trailing block comment */
    print(total);
}
```

The line terminator after `// Leading line comment.` is trivia. The block comment is trivia. The indentation is trivia. None of these affects the token sequence.

## 7.3 Comments

**7.3.1** A *LineComment* begins with `//` and extends to, but does not include, the next LineTerminatorSequence or the end of input. Every source character between the opening `//` and that terminator is part of the comment. A LineComment MAY contain reverse solidus, quotation marks, backticks, `#`, `/*`, and `*/` without effect.

**7.3.2** A *BlockComment* begins with `/*` and ends with the matching `*/`. BlockComments nest. Each occurrence of `/*` inside a BlockComment increases the nesting depth by one; each occurrence of `*/` decreases the nesting depth by one. The BlockComment ends at the `*/` that reduces the nesting depth to zero. The opening `/*` and closing `*/` are not part of the comment text. A BlockComment MAY contain LineTerminatorSequences and any source character.

**7.3.3** Nesting is determined solely by the characters `/*` and `*/`; string and template delimiters inside a BlockComment have no effect. The sequence `/*/` does not close a BlockComment: after the opening `/*`, the remaining `/` is comment text and the comment is unterminated if no later `*/` occurs. The sequence `/***/` is a complete BlockComment: the opening is `/*`, the next `*` is text, and the final `*/` closes it. An implementation MUST scan a BlockComment in a single left-to-right pass and MUST NOT treat the opening delimiter as also closing the comment.

**7.3.4** A BlockComment that reaches end of input while its nesting depth is greater than zero is an early error of category *comment* with condition name `UnterminatedComment`. The reported position MUST be the position of the opening `/*`; the diagnostic SHOULD also report the position of the end of input. A LineComment that reaches end of input is well-formed.

**7.3.5** A BlockComment that is not nested is the ordinary case; nesting is not optional. An implementation MUST accept `/* outer /* inner */ outer */` as one BlockComment. An implementation MUST reject `/* outer /* inner */` because the nesting depth is one at end of input.

**7.3.6** The sequences `//` and `/*` are recognized before the punctuator `/` is considered. Consequently, trivia is required to divide by a value that begins with `*` or `/`. The source text `a//b` consists of the identifier `a` followed by a LineComment, not of `a`, `/`, `/`, `b`. The source text `a/*b*/c` consists of the identifier `a`, one BlockComment, and the identifier `c`.

**7.3.7** A `*/` that is not inside a BlockComment is not a comment terminator. It is tokenized as the punctuator `*` followed by the punctuator `/` unless a longer token begins at the `*`. The resulting token sequence is normally rejected by the syntactic grammar; it is not a lexical error.

**7.3.8** Comments are trivia under 7.2.3. They do not produce tokens, do not affect the syntactic grammar, and do not affect the value of any literal. An implementation MAY attach comments to tokens or syntax nodes for documentation and tooling, but such attachment is not observable by a Dryad program.

**7.3.9** There is no distinct documentation-comment token. A comment beginning with `///` or `/**` is an ordinary LineComment or BlockComment. A comment beginning with `//#` is an ordinary LineComment; the `#` has no directive meaning inside a comment.

**7.3.10** The following program is well-formed:

```dryad
/* outer /* nested */ still outer */
function main() {
    let value = 10 / 2; // division, not a comment
    // The next line contains a comment delimiter inside a string.
    let marker = "/* not a comment */";
    print(value);
    print(marker);
}
```

The following program is ill-formed because the block comment is unterminated:

```dryad
/* outer /* inner */
function main() {
    print("unreachable");
}
```

## 7.4 Tokens and the Lexical Grammar

**7.4.1** A *lexical token* is an indivisible unit produced by the lexer. A token has a *kind*, a *lexeme*, a *value* where the kind defines one, and a *source range* consisting of a start position and an end position. The end position is exclusive. A token's lexeme is the exact sequence of source characters that forms the token, excluding surrounding trivia.

**7.4.2** Table 7.4.2-1 lists the token kinds of Edition 1.0. The table is exhaustive.

| Kind | Payload | Formed by |
|------|---------|-----------|
| EndOfFile | none | end of input in goal `Input` |
| Identifier | name | 7.5 |
| Keyword | keyword identity | 7.5.10 |
| BooleanLiteral | `true` or `false` | 7.5.11 |
| NullLiteral | `null` | 7.5.11 |
| NumericLiteral | binary64 value | 7.6 |
| StringLiteral | sequence of Unicode scalar values | 7.7 |
| TemplateStart | none | 7.8.2 |
| TemplateContent | cooked sequence of Unicode scalar values | 7.8.11 |
| TemplateInterpolationStart | none | 7.8.2 |
| TemplateInterpolationEnd | none | 7.8.2 |
| TemplateEnd | none | 7.8.2 |
| NativeDirective | module name | 7.9 |
| Punctuator | punctuator identity | 7.10 |

**7.4.3** A *lexical token sequence* is a finite sequence of tokens whose last token is EndOfFile and that contains no other EndOfFile. Trivia is not part of the lexical token sequence. The syntactic grammar of Clause 22 consumes the lexical token sequence with trivia removed; source positions remain available for diagnostics.

**7.4.4** Lexing is governed by a *lexical goal*. The goal determines which token productions are eligible at the current position. There are three goals: `Input`, `TemplateContent`, and `TemplateSubstitution`. The initial goal at the start of a source text unit is `Input`.

**7.4.5** In goal `Input`, the lexer recognizes the productions of `<InputElement>` in 7.11. A TemplateStart token switches the goal to `TemplateContent` and pushes a template context. A NativeDirective, Identifier, Keyword, literal, or Punctuator token leaves the goal unchanged. EndOfFile is produced only in goal `Input` when the input is exhausted; EndOfFile MUST NOT be produced while a template context is open.

**7.4.6** In goal `TemplateContent`, the lexer recognizes `<TemplateContent>`, `<TemplateInterpolationStart>`, and `<TemplateEnd>`. A non-empty run of template characters produces one TemplateContent token. A `${` produces a TemplateInterpolationStart token and switches the goal to `TemplateSubstitution`. A backtick produces a TemplateEnd token, pops the innermost template context, and restores the goal that was active before the corresponding TemplateStart. End of input in this goal is an early error under 7.8.13.

**7.4.7** In goal `TemplateSubstitution`, the lexer recognizes `<InputElement>` and `<TemplateInterpolationEnd>`. The lexer maintains a *brace depth*, initially zero for each interpolation. A `{` punctuator increments the depth. A `}` punctuator at depth greater than zero decrements the depth. A `}` at depth zero produces a TemplateInterpolationEnd token, switches the goal to `TemplateContent`, and does not change the template context stack. A TemplateStart in this goal pushes a new template context and switches to `TemplateContent`; after the corresponding TemplateEnd, the goal returns to `TemplateSubstitution`.

**7.4.8** Template contexts form a stack. Each TemplateStart pushes one context; each TemplateEnd pops one context. The lexer MUST reject a source text unit in which a TemplateEnd would pop a context that was not pushed by a TemplateStart, in which EndOfFile occurs while the stack is non-empty, or in which a TemplateInterpolationStart is not matched by a TemplateInterpolationEnd before the enclosing TemplateEnd. The brace depth of an interpolation is local to that interpolation; braces in a nested template literal do not affect the enclosing interpolation.

**7.4.9** At each position, the lexer MUST select the longest source character sequence that matches an eligible token production. This is the *maximal-munch* rule. The productions of 7.11 are disjoint for sequences of equal length; the ordering of alternatives in 7.11 is therefore not a precedence declaration and does not affect tokenization.

**7.4.10** Two tokens MAY be adjacent without intervening trivia when the maximal munch of the first token ends before the second begins and the concatenation of their lexemes is not itself a longer eligible token. When the concatenation would form a longer token, the source text denotes that longer token, and trivia is REQUIRED to obtain the two shorter tokens. For example, `a+b` denotes `a`, `+`, `b`; `a++b` denotes `a`, `++`, `b`; and `a+ +b` denotes `a`, `+`, `+`, `b`. A token boundary is not inferred from the syntactic grammar.

**7.4.11** Lexing is deterministic and context-free except for the lexical goals of 7.4.4 through 7.4.8. For a fixed source text unit, encoding, and initial goal, there is exactly one lexical token sequence. An implementation MUST NOT choose a tokenization based on semantic analysis, name resolution, or the presence or absence of a declaration.

**7.4.12** EndOfFile is a zero-width token. It is produced exactly once, after all other tokens, when the input is exhausted in goal `Input`. Its source range is empty and is positioned immediately after the last source character. An implementation MUST NOT produce EndOfFile before the input is exhausted, and MUST NOT produce any token after EndOfFile.

**7.4.13** The lexer MUST treat the source text as a sequence of Unicode scalar values after UTF-8 validation and after removal of an initial byte-order mark. Byte offsets MAY be retained for diagnostics, but columns and token boundaries are measured in scalar values.

**7.4.14** A *lexical error* is a condition in 7.12 that prevents the formation of a lexical token sequence. A *syntactic error* is a condition in which a lexical token sequence is well-formed but no parse tree exists under Clause 22, or more than one parse tree exists. A lexical error MUST be reported before any syntactic analysis of the affected token sequence. A lexer MUST NOT convert a lexical error into a token of kind `Error` that the syntactic grammar can accept.

**7.4.15** Dryad has no regular-expression literal. The punctuator `/` is always division, and the sequences `//` and `/*` always begin comments. Consequently, a regular-expression literal cannot be written, and no lexical goal for regular expressions exists.

**7.4.16** Table 7.4.16-1 gives the token sequence for representative source fragments.

| Source | Token kinds | Notes |
|--------|-------------|-------|
| `a+b` | Identifier, Punctuator(+), Identifier | no trivia required |
| `a++b` | Identifier, Punctuator(++), Identifier | maximal munch |
| `a + +b` | Identifier, Punctuator(+), Punctuator(+), Identifier | trivia required |
| `a//b` | Identifier, Identifier | LineComment between |
| `1.5e2` | NumericLiteral | one token |
| `` `x${y}z` `` | TemplateStart, TemplateContent, TemplateInterpolationStart, Identifier, TemplateInterpolationEnd, TemplateContent, TemplateEnd | goal stack |
| `#<io>` | NativeDirective | one token |
| `/*c*/` | none | one BlockComment, then EndOfFile |

## 7.5 Identifiers and Keywords

**7.5.1** An *identifier* is a lexical token that names a binding, property, label, or module. An identifier is formed from an *IdentifierName* that is not a ReservedWord. The name of an identifier is its exact sequence of Unicode scalar values.

**7.5.2** An *IdentifierStart* is `_`, an ASCII letter `a` through `z` or `A` through `Z`, or a code point whose Unicode property is ID_Start. An *IdentifierPart* is an IdentifierStart, a decimal digit `0` through `9`, or a code point whose Unicode property is ID_Continue. An IdentifierName is an IdentifierStart followed by zero or more IdentifierParts.

**7.5.3** The Unicode properties ID_Start and ID_Continue are those of Unicode 16.0.0, including the code points contributed by Other_ID_Start and Other_ID_Continue. An implementation MUST use the same Unicode version for every source text unit it accepts. An implementation MUST NOT accept an identifier that depends on a later version of the Unicode Character Database unless it documents that extension under Clause 2.4.

**7.5.4** An identifier MUST NOT contain a reverse solidus. Unicode escape sequences are not recognized in identifiers, and an implementation MUST NOT decode `\u` sequences in an identifier. A reverse solidus at a position where an identifier is expected is an unexpected character under 7.12.

**7.5.5** The dollar sign `$` is not an IdentifierStart and MUST NOT appear in an identifier. The characters `@`, `#`, backtick, quotation mark, apostrophe, and all punctuation are not IdentifierParts. A source character that is neither an IdentifierPart nor eligible as the start of another token is a lexical error.

**7.5.6** Identifiers are case-sensitive. `value`, `Value`, and `VALUE` are three distinct identifiers. Keywords are recognized only in their exact lowercase spelling; `Let`, `CLASS`, and `True` are identifiers, not keywords.

**7.5.7** Identifiers are compared by exact code-point sequence. No normalization is applied. Two identifiers that consist of canonically equivalent sequences, such as a sequence containing U+00E9 and a sequence containing U+0065 followed by U+0301, are distinct identifiers and denote distinct bindings. Source text SHOULD use Normalization Form C to avoid accidental distinctions.

**7.5.8** The identifier `_` is a valid identifier consisting of one IdentifierStart. It is not a keyword. In pattern contexts, the syntactic grammar interprets the identifier `_` as a wildcard (Clause 9); this interpretation is syntactic and does not change its lexical kind.

**7.5.9** A *ReservedWord* is a sequence of characters that matches an IdentifierName and is listed in Table 7.5.10-1. A ReservedWord is never an Identifier. The lexer MUST classify every ReservedWord as a Keyword, BooleanLiteral, or NullLiteral token, and MUST classify every other IdentifierName as an Identifier token. Classification is performed after maximal munch of the IdentifierName.

**7.5.10** Table 7.5.10-1 lists the reserved words grouped by category. The table is exhaustive. No other word is reserved in Edition 1.0.

| Category | Reserved words | Token kind |
|----------|----------------|------------|
| Declarations | `let`, `const`, `function`, `class`, `interface`, `import`, `export` | Keyword |
| Control flow | `if`, `else`, `for`, `while`, `do`, `break`, `continue`, `return`, `match`, `in` | Keyword |
| Functions and concurrency | `fn`, `async`, `await`, `thread`, `mutex` | Keyword |
| Object orientation | `new`, `extends`, `implements`, `this`, `super`, `static`, `public`, `private`, `protected`, `abstract`, `readonly`, `get`, `set`, `delete` | Keyword |
| Modules and FFI | `use`, `as`, `from`, `extern`, `internal` | Keyword |
| Exception handling | `try`, `catch`, `finally`, `throw` | Keyword |
| Literal words | `true`, `false` | BooleanLiteral |
| Literal words | `null` | NullLiteral |

**7.5.11** `true` and `false` are BooleanLiteral tokens. `null` is a NullLiteral token. These three words are reserved and MUST NOT be used as identifiers, but they are literal tokens rather than Keyword tokens. Every other word in Table 7.5.10-1 is a Keyword token.

**7.5.12** Keyword recognition is not context-sensitive. The lexer MUST classify `class` as a Keyword token whether it occurs at the start of a declaration, after a dot, or in an invalid position. The syntactic grammar MAY accept a Keyword token in a position that denotes a property name, a member name, or a label; such acceptance does not change the token kind. In particular, a reserved word MAY be used as a non-computed property name after `.` or in an object literal, as specified in Clause 9.

**7.5.13** The following words are not reserved words and are classified as Identifiers: `constructor`, `print`, `NaN`, `Infinity`, `undefined`, `main`, `value`, `Type`, and every other IdentifierName not listed in Table 7.5.10-1. `undefined` is not a Dryad value (D-06); its use as an identifier does not create one. `NaN` and `Infinity` are identifiers, not numeric literals; their meanings, if any, are defined by Clause 8 and Clause 18.

**7.5.14** No maximum identifier length is specified. An implementation MUST NOT reject an identifier solely because of its length, except on resource exhaustion reported under 7.13.17.

**7.5.15** The following program is well-formed:

```dryad
let _private = 1;
let camelCase2 = 2;
let snake_case_3 = 3;
let x1 = _private + camelCase2 + snake_case_3;
print(x1);
```

The following program is ill-formed:

```dryad
let class = 1;
```

`class` is a Keyword token and cannot appear where an Identifier is required.

**7.5.16** An identifier that begins with a decimal digit is not an identifier. The source text `1abc` is a NumericLiteral followed immediately by an Identifier; it is a lexical error under 7.6.13, not an identifier whose first character is a digit.

## 7.6 Numeric Literals

**7.6.1** A *NumericLiteral* is a token that denotes a Number value. Every NumericLiteral denotes an IEEE 754 binary64 value (D-14). There is no separate integer literal type at the language level. A NumericLiteral has no sign; the characters `+` and `-` are operators, and a sign is applied by the unary expression grammar of Clause 9.

**7.6.2** A *DecimalLiteral* consists of a decimal integer part, an optional fraction, and an optional exponent. The integer part is `0` or a nonzero decimal digit followed by zero or more decimal digits. A fraction consists of `.` followed by at least one decimal digit. An exponent consists of `e` or `E`, an optional `+` or `-`, and at least one decimal digit.

**7.6.3** A DecimalLiteral MUST NOT contain a leading zero unless the integer part is exactly `0`. The forms `00`, `01`, `0123`, and `00.5` are ill-formed. The form `0.5` is well-formed. This rule removes the legacy-octal interpretation: `0755` is not an octal literal and is not a decimal literal; it is an early error. Octal literals use the `0o` prefix exclusively. A leading-zero condition is reported as `InvalidNumericLiteral` and takes precedence over the numeric-followed-by-digit rule of 7.6.13.

**7.6.4** A decimal fraction MUST contain at least one digit after the `.`. A trailing dot is not part of a NumericLiteral. The source text `1.` consists of the NumericLiteral `1` followed by the punctuator `.`. This rule ensures that tuple and member access such as `pair.0` and `value.toString` are tokenized as a dot followed by a numeric index or an identifier, not as a malformed fraction.

**7.6.5** A leading dot does not begin a NumericLiteral. The source text `.5` consists of the punctuator `.` followed by the NumericLiteral `5`. This rule is required for tuple access such as `pair.0` and is consistent with 7.6.4. An expression that intends the number one half MUST write `0.5`.

**7.6.6** A *HexIntegerLiteral* begins with `0x` or `0X` and is followed by one or more hexadecimal digits. A *BinaryIntegerLiteral* begins with `0b` or `0B` and is followed by one or more binary digits. An *OctalIntegerLiteral* begins with `0o` or `0O` and is followed by one or more octal digits. The prefixes are case-insensitive in the sense that both cases are accepted; the digits of a hexadecimal literal can be in either case. A based literal MUST contain at least one digit after the prefix.

**7.6.7** A *NumericSeparator* is `_`. A NumericSeparator MAY appear between two digits of the same digit sequence, including between two digits of the integer part, the fraction, the exponent, or a based literal. A NumericSeparator MUST NOT appear at the beginning or end of a digit sequence, adjacent to another NumericSeparator, adjacent to the decimal point, adjacent to an exponent marker or its sign, or adjacent to a base prefix. The separator is not part of the numeric value.

**7.6.8** The following numeric literals are well-formed:

```dryad
let decimal = 1_000_000;
let hex = 0xFF_EC;
let binary = 0b1010_0101;
let octal = 0o755;
let fraction = 3.141_592_653_589_793;
let exponent = 6.022e23;
let small = 1.0e-9;
let zero = 0;
```

The following numeric literals are ill-formed:

```dryad
let a = 01;
let b = 0x;
let c = 1__2;
let d = 1e;
let e = 123abc;
let f = 0b102;
```

**7.6.9** The *mathematical value* of a NumericLiteral is the exact real number denoted by its digits and exponent, with separators removed. For a based literal, the mathematical value is the exact non-negative integer denoted by its digits in the given base. The value of the literal is the binary64 value obtained by rounding the mathematical value to nearest, ties to even.

**7.6.10** Rounding MUST be correctly rounded. An implementation MUST NOT use a truncating conversion or a conversion that depends on the host's decimal-to-binary library in a way that produces a different binary64 value from correct rounding. For a decimal literal, the implementation MUST behave as if it computed the exact mathematical value and then applied round-to-nearest, ties-to-even. For a based literal, the integer is exact and is rounded by the same rule.

**7.6.11** The value is the binary64 value nearest to the mathematical value. If two binary64 values are equally near, the one whose significand is even is chosen. Consequently, if the mathematical value is at least the overflow threshold, namely the midpoint between the largest finite binary64 value and 2^1024, the literal denotes positive infinity; a value greater than the largest finite value but below that threshold denotes the largest finite value. If the mathematical value is at most half the smallest positive subnormal value, the literal denotes positive zero; a value above that midpoint but below the smallest positive subnormal denotes the smallest positive subnormal. Underflow and overflow are not errors. A NumericLiteral never denotes negative zero; negative zero is produced only by applying the unary `-` operator to a literal or expression whose value is positive zero.

**7.6.12** The spellings `NaN`, `Infinity`, and `-Infinity` are not NumericLiterals. `NaN` and `Infinity` are Identifier tokens (7.5.13). `-Infinity` is the unary `-` operator applied to the identifier `Infinity`. An implementation MUST NOT recognize these spellings as numeric literals.

**7.6.13** A NumericLiteral MUST NOT be immediately followed by an IdentifierStart other than `_`, or by a decimal digit. The source text `123abc` is not a NumericLiteral followed by an Identifier; it is an early error with condition name `NumericLiteralFollowedByIdentifier`. The same rule applies to `0x1g`, `0b10x`, `1e2x`, and `0o7a`. A following `_` is governed by 7.6.14. Trivia or a punctuator is REQUIRED between a numeric literal and a following identifier or digit.

**7.6.14** A NumericSeparator MUST NOT occur at the end of a NumericLiteral. The source text `1_` is an early error, not the NumericLiteral `1` followed by the Identifier `_`. An implementation MUST detect this condition as part of scanning the numeric literal and MUST report `InvalidNumericLiteral`.

**7.6.15** If a token boundary begins with `0x`, `0X`, `0b`, `0B`, `0o`, or `0O`, the lexer MUST attempt to scan a based literal. If no valid digit follows the prefix, or if the first character after the prefix is not a valid digit for the base, the lexer MUST report `InvalidNumericLiteral`. The lexer MUST NOT fall back to scanning `0` as a DecimalLiteral followed by an identifier.

**7.6.16** If a DecimalLiteral is immediately followed by `e` or `E`, the lexer MUST treat the `e` or `E` as the start of an exponent. If the exponent marker is not followed by an optional sign and at least one decimal digit, the lexer MUST report `InvalidNumericLiteral`. The source texts `1e` and `1e+` are therefore lexical errors, not a NumericLiteral followed by an Identifier or a punctuator.

**7.6.17** Table 7.6.17-1 summarizes invalid numeric forms.

| Form | Reason | Condition |
|------|--------|-----------|
| `00`, `01`, `0755` | leading zero in a decimal literal | `InvalidNumericLiteral` |
| `0x`, `0b`, `0o` | no digit after the base prefix | `InvalidNumericLiteral` |
| `0b2`, `0o8`, `0xG` | invalid digit for the base | `InvalidNumericLiteral` |
| `1__2` | adjacent numeric separators | `InvalidNumericLiteral` |
| `1_`, `0x1_` | separator at the end of a digit sequence | `InvalidNumericLiteral` |
| `1e`, `1e+` | missing exponent digits | `InvalidNumericLiteral` |
| `1_.2` | separator before the decimal point | `InvalidNumericLiteral` |
| `123abc` | numeric literal followed by an identifier | `NumericLiteralFollowedByIdentifier` |
| `0b102` | numeric literal followed by a digit | `NumericLiteralFollowedByIdentifier` |
| `_1` | not a numeric literal; an identifier | none at the lexical level |
| `.5` | dot followed by a numeric literal | none at the lexical level |
| `1.` | numeric literal followed by a dot | none at the lexical level |
| `1._2` | numeric literal, dot, identifier | none at the lexical level |

**7.6.18** The value of a NumericLiteral is a Number value under Clause 8.3. The lexer MUST produce the binary64 value, not a decimal string or an arbitrary-precision integer, as the token value. An implementation MAY retain the source lexeme for diagnostics and tooling.

## 7.7 String Literals

**7.7.1** A *StringLiteral* is a token that denotes a String value. A String value is a finite sequence of Unicode scalar values (Clause 5.5.1 and Clause 8.3). A StringLiteral is delimited by a single quotation mark U+0027 or a double quotation mark U+0022. The two delimiters have identical semantics except for which unescaped delimiter terminates the literal.

**7.7.2** A single-quoted string begins with `'` and ends with the next unescaped `'`. A double-quoted string begins with `"` and ends with the next unescaped `"`. The other quotation mark MAY appear unescaped inside the literal and denotes itself. A reverse solidus begins an escape sequence and does not terminate the literal.

**7.7.3** A *StringCharacter* is any source character other than the closing delimiter, a reverse solidus, or a LineTerminatorSequence, or an EscapeSequence. A LineTerminatorSequence MUST NOT appear raw inside a StringLiteral. A StringLiteral MAY contain any other Unicode scalar value, including U+0000, noncharacters, and the non-delimiting quotation mark.

**7.7.4** An *EscapeSequence* begins with a reverse solidus and is one of the forms in Table 7.7.4-1. The *cooked value* of the escape is the scalar value or empty sequence shown.

| Escape | Cooked value |
|--------|--------------|
| `\'` | U+0027 |
| `\"` | U+0022 |
| `\\` | U+005C |
| `\b` | U+0008 |
| `\f` | U+000C |
| `\n` | U+000A |
| `\r` | U+000D |
| `\t` | U+0009 |
| `\v` | U+000B |
| `\0` | U+0000, only when not followed by a decimal digit |
| `\xHH` | the scalar value denoted by the two hexadecimal digits |
| `\uHHHH` | the scalar value denoted by the four hexadecimal digits |
| `\u{H...}` | the scalar value denoted by one through six hexadecimal digits |
| reverse solidus followed by a backtick | U+0060 |
| reverse solidus followed by `$` | U+0024 |
| reverse solidus followed by a LineTerminatorSequence | the empty sequence |

**7.7.5** A `\x` escape consists of a reverse solidus, `x`, and exactly two hexadecimal digits. The two digits denote a scalar value in U+0000 through U+00FF. A `\x` escape with fewer than two digits or with a non-hexadecimal character is an early error with condition name `InvalidHexEscape`.

**7.7.6** A `\u` escape has two forms. The fixed form consists of a reverse solidus, `u`, and exactly four hexadecimal digits. The braced form consists of a reverse solidus, `u`, `{`, one through six hexadecimal digits, and `}`. The denoted value MUST be a Unicode scalar value. A fixed-form escape whose four digits lie in U+D800 through U+DFFF is ill-formed, because the denoted value would be a surrogate. A braced-form escape whose value is greater than U+10FFFF, whose digit count is zero or greater than six, or whose value is a surrogate is ill-formed. The condition name is `InvalidUnicodeEscape`.

**7.7.7** A `\0` escape denotes U+0000 only when it is not immediately followed by a decimal digit. The source text `"\0"` is well-formed. The source text `"\01"` is ill-formed because it would be an octal escape; Dryad has no octal escapes. The condition name is `InvalidEscapeSequence`.

**7.7.8** A *LineContinuation* consists of a reverse solidus immediately followed by a LineTerminatorSequence. It denotes the empty sequence: it contributes no scalar value to the string. A reverse solidus followed by CRLF consumes both characters as one LineTerminatorSequence. A reverse solidus at end of input, or a reverse solidus followed by a source character that is not listed in Table 7.7.4-1 and is not a LineTerminatorSequence, is an early error.

**7.7.9** Dryad has no identity escapes. A reverse solidus followed by a character that is not a valid escape character, hexadecimal escape, Unicode escape, or line continuation is ill-formed. The source text `"\q"` is an early error with condition `InvalidEscapeSequence`; it does not denote `q`. An implementation MUST NOT silently drop the reverse solidus. This rule applies equally to StringLiterals and to template content.

**7.7.10** A raw LineTerminatorSequence inside a StringLiteral is an early error. The condition name is `UnterminatedString`; the literal is considered unterminated at the line terminator. A string literal that reaches end of input before its closing delimiter is also `UnterminatedString`. The reported position MUST be the position of the opening delimiter; the diagnostic SHOULD report the position of the line terminator or end of input.

**7.7.11** An unescaped closing delimiter ends the literal. The characters following it are tokenized normally. There is no implicit concatenation of adjacent StringLiterals; `"a" "b"` is two tokens and is normally a syntactic error. There is no interpolation in a StringLiteral; the sequence `${` inside a string denotes the characters `$` and `{`, not an interpolation. Interpolation is available only in template literals (7.8).

**7.7.12** The *value* of a StringLiteral is the sequence of scalar values obtained by replacing each EscapeSequence with its cooked value and retaining every StringCharacter as itself. The value contains no quotation marks unless they were escaped or were the non-delimiting quotation mark. The value is not normalized, not case-folded, and not trimmed.

**7.7.13** The *lexeme* of a StringLiteral includes the opening delimiter, the source characters of the body, and the closing delimiter. An implementation MUST retain enough information to report the source range; it MAY retain the full lexeme. The lexeme is not the value.

**7.7.14** The following string literals are well-formed:

```dryad
let single = 'apostrophe: \' and reverse solidus: \\';
let double = "quotation: \" and tab: \t";
let unicode = "\u0041\u{1F642}";
let continued = "first line \
second line";
let empty = "";
```

The value of `empty` is the empty sequence. The value of `continued` contains no line terminator at the continuation point; it contains the characters of `first line ` followed by `second line`. The following literals are ill-formed:

```dryad
let a = "unterminated;
let b = "\q";
let c = "\uD800";
let d = "\01";
```

`a` is unterminated at the line terminator. `b` uses an identity escape. `c` denotes a surrogate. `d` is an octal escape.

**7.7.15** An implementation MUST decode every escape at lexing time. A StringLiteral token MUST NOT carry an unresolved escape sequence. If an implementation defers decoding, it MUST produce the same value and the same errors as an implementation that decodes during lexing.

**7.7.16** The maximum length of a StringLiteral is not specified. An implementation MUST NOT reject a StringLiteral solely because its value is long, except on resource exhaustion reported under 7.13.17.

## 7.8 Template Literals

**7.8.1** A *template literal* is a source construct delimited by backticks that can contain *interpolations*. A template literal is represented by a sequence of lexical tokens: one TemplateStart, zero or more TemplateContent tokens and interpolations, and one TemplateEnd. A template literal is not a single token; the tokens are produced under the lexical goals of 7.4.6 and 7.4.7.

**7.8.2** A *TemplateStart* is a single backtick U+0060 that begins a template literal. A *TemplateEnd* is a single backtick that ends the innermost open template literal. A *TemplateContent* token is a non-empty sequence of template characters between a TemplateStart or TemplateInterpolationEnd and the next TemplateInterpolationStart or TemplateEnd. A *TemplateInterpolationStart* is the two-character sequence `${`. A *TemplateInterpolationEnd* is the `}` that closes an interpolation at brace depth zero.

**7.8.3** Template content characters are any source characters other than an unescaped backtick, an unescaped `${`, or a reverse solidus that begins an escape sequence. A `$` that is not immediately followed by `{` is an ordinary content character. A `}` in template content is an ordinary content character; it does not close anything. A raw LineTerminatorSequence is permitted in template content and does not terminate the template.

**7.8.4** An EscapeSequence in template content has the same forms and cooked values as in a StringLiteral (7.7.4 through 7.7.9). In particular, a reverse solidus followed by a backtick denotes U+0060, and a reverse solidus followed by `$` denotes U+0024. The latter permits a literal `${` in template content: the source text `\${` denotes the two characters `$` and `{`, and the `{` does not start an interpolation. A reverse solidus followed by a character that is not a valid escape is ill-formed under 7.7.9.

**7.8.5** A TemplateInterpolationStart switches the lexical goal to `TemplateSubstitution`. The source text between `${` and the matching TemplateInterpolationEnd is a sequence of InputElements and is parsed as an expression under Clause 9. Trivia, comments, nested template literals, string literals, and all ordinary tokens are permitted inside an interpolation, subject to the syntactic grammar.

**7.8.6** The TemplateInterpolationEnd is the first `}` in the interpolation that occurs at brace depth zero. A `{` punctuator increases the brace depth; a `}` punctuator at depth greater than zero decreases it and is an ordinary RightBrace token. Braces that occur inside StringLiterals, TemplateContent, or Comments do not affect the brace depth. Braces inside a nested template literal are governed by that template's own interpolation contexts and do not affect the enclosing depth.

**7.8.7** Template literals MAY nest. A TemplateStart inside an interpolation pushes a new template context; the matching TemplateEnd pops it and returns the goal to `TemplateSubstitution`. The source text `` `a${`b${c}d`}e` `` is well-formed at the lexical level and contains two template literals, one nested in an interpolation of the other. The number of nested template literals is not limited by this specification; an implementation MAY impose a resource limit reported under 7.13.17.

**7.8.8** A TemplateInterpolationStart MUST be matched by a TemplateInterpolationEnd before the TemplateEnd of the enclosing template. A TemplateInterpolationEnd MUST NOT occur in goal `Input` or `TemplateContent`. A TemplateEnd MUST NOT occur when no template context is open. These conditions are lexical early errors.

**7.8.9** An interpolation MUST contain at least one InputElement. The source text `` `${}` `` is lexically a TemplateStart, TemplateInterpolationStart, TemplateInterpolationEnd, TemplateEnd. It is ill-formed because the syntactic grammar of Clause 9 does not derive an expression from an empty token sequence. The condition is a syntactic early error, not a lexical error. The lexer MUST NOT report `UnterminatedTemplateInterpolation` for this form.

**7.8.10** A template literal is not a tagged template. An Identifier or other expression immediately followed by a TemplateStart is two syntactic constructs, not a tag and a template. The syntactic grammar of Clause 9 defines whether such juxtaposition is permitted; in Edition 1.0 it is not. There is no `raw` property and no raw-string accessor for template literals; only the cooked value is defined.

**7.8.11** The *cooked value* of a TemplateContent token is the sequence of scalar values obtained by replacing each EscapeSequence with its cooked value, retaining each ordinary content character, and replacing each raw LineTerminatorSequence as specified in 7.8.12. The cooked value is not normalized.

**7.8.12** A raw LineTerminatorSequence in template content contributes to the cooked value as follows: LF contributes U+000A; CR contributes U+000A; CRLF contributes one U+000A; LS contributes U+2028; PS contributes U+2029. A LineContinuation (reverse solidus followed by a LineTerminatorSequence) contributes nothing. This normalization applies only to template content; StringLiterals cannot contain raw line terminators, and line continuations in strings contribute nothing.

**7.8.13** A template literal that reaches end of input before its TemplateEnd is an early error with condition `UnterminatedTemplate`. The reported position MUST be the position of the opening TemplateStart. If an interpolation is open at end of input, the condition is `UnterminatedTemplateInterpolation`, and the reported position MUST be the position of the opening `${` of the innermost open interpolation.

**7.8.14** A template literal whose interpolation contains an unclosed brace at end of input is `UnterminatedTemplateInterpolation`. A template literal whose interpolation is closed but whose TemplateEnd is missing is `UnterminatedTemplate`. If both conditions apply, the innermost open construct determines the reported condition.

**7.8.15** The following template literals are well-formed:

```dryad
let name = "Dryad";
let version = 1.0;
let message = `Language: ${name}, version: ${version}`;
let nested = `outer ${`inner ${name}`} end`;
let escaped = `literal \${name} and backtick \``;
print(message);
print(nested);
print(escaped);
```

The value of `message` is `Language: Dryad, version: 1`. The value of `nested` is `outer inner Dryad end`. The value of `escaped` is `literal ${name} and backtick ` followed by U+0060. The following is ill-formed:

```dryad
let a = `unterminated;
let b = `value ${name;
```

`a` has no TemplateEnd. `b` has an interpolation that is not closed before end of input.

**7.8.16** A TemplateContent token MUST NOT be empty. When a TemplateStart or TemplateInterpolationEnd is immediately followed by a TemplateInterpolationStart or TemplateEnd, no TemplateContent token is produced. An implementation MUST NOT produce two adjacent TemplateContent tokens; maximal munch produces one token for the longest content run.

## 7.9 Native Directives

**7.9.1** A *NativeDirective* is a token that names a native module. The token has the exact form `#<name>`, where `name` is an Identifier under 7.5. The characters `#`, `<`, and `>` are part of the token; the token's value is the name.

**7.9.2** The lexical rule is: a `#` begins a NativeDirective only when the immediately following source character is `<`. The `<` MUST be immediately followed by an IdentifierStart. The IdentifierStart and all following IdentifierParts form the name. The character immediately following the name MUST be `>`. The token ends at that `>`. WhiteSpace, LineTerminatorSequence, and Comment are prohibited between `#` and `<`, between `<` and the first character of the name, within the name, and between the last character of the name and `>`. An implementation MUST reject any directive containing such trivia under 7.9.4.

**7.9.3** The name MUST be an Identifier, not a ReservedWord. A name that is a ReservedWord is ill-formed. The name is case-sensitive. The name is not a StringLiteral and does not support escape sequences. The name is not normalized.

**7.9.4** A `#` that is not immediately followed by `<` is an early error with condition `MalformedNativeDirective`. This includes a bare `#name` (D-02), a `#` followed by whitespace, a `#` at end of input, and a `#` followed by a line terminator. A `#<` that is not followed by a valid Identifier and `>` is also `MalformedNativeDirective`.

**7.9.5** Table 7.9.5-1 lists ill-formed directive forms.

| Form | Reason |
|------|--------|
| `#io` | bare form; `<` is required (D-02) |
| `#` | no `<` |
| `#<` | no name |
| `#<>` | empty name |
| `#<io` | no `>` |
| `#< io>` | WhiteSpace after `<` |
| `#<io >` | WhiteSpace before `>` |
| `#<io\n>` | LineTerminatorSequence inside the directive |
| `#<class>` | name is a ReservedWord |
| `#<1io>` | name does not begin with IdentifierStart |
| `#<io/*c*/>` | Comment inside the directive |

**7.9.6** A NativeDirective token is a single token even though it contains three punctuation characters. The `<` and `>` inside the token are not separate Punctuator tokens. After the closing `>`, tokenization resumes in the current lexical goal; no separator is required. The source text `#<io>#<net>` is two NativeDirective tokens.

**7.9.7** A NativeDirective MAY occur only where the syntactic grammar of Clause 12 permits a native-module directive. The lexical grammar recognizes the token in any position in goal `Input` or `TemplateSubstitution`; placement is a syntactic restriction, not a lexical one. A NativeDirective inside a StringLiteral, TemplateContent, or Comment is not a token and has no directive meaning.

**7.9.8** The following program is well-formed:

```dryad
#<io>
#<math>

function main() {
    print("native modules loaded");
}
```

The directives are NativeDirective tokens with names `io` and `math`. The following program is ill-formed under D-02:

```dryad
#io
#math

function main() {
    print("not loaded");
}
```

**7.9.9** A `#` inside a LineComment, BlockComment, StringLiteral, or TemplateContent is an ordinary character. A `#` inside a TemplateSubstitution is the start of a NativeDirective if followed by `<`; otherwise it is malformed. The sequence `#<io>` inside a string is not a directive.

**7.9.10** The native module name space and the resolution of a NativeDirective are defined by Clause 12 and Clause 16. An unknown name is a module-resolution error, not a lexical error. The lexer MUST NOT consult the host filesystem, the module registry, or the standard-library index while forming a NativeDirective token.

## 7.10 Operators and Punctuators

**7.10.1** A *Punctuator* is a token that is not an identifier, keyword, literal, template delimiter, or native directive. Punctuators comprise operators, delimiters, separators, and the decorator marker. The complete inventory is Table 7.10.2-1. The table is exhaustive for Edition 1.0.

**7.10.2** Table 7.10.2-1 lists every punctuator by category.

| Category | Lexemes | Token names |
|----------|---------|-------------|
| Arithmetic | `+`, `-`, `*`, `/`, `%`, `**` | Plus, Minus, Star, Slash, Percent, StarStar |
| Increment and decrement | `++`, `--` | PlusPlus, MinusMinus |
| Assignment | `=`, `+=`, `-=`, `*=`, `/=` | Equal, PlusEqual, MinusEqual, StarEqual, SlashEqual |
| Bitwise | `&`, `\|`, `^`, `~`, `<<`, `>>`, `>>>` | Ampersand, Pipe, Caret, Tilde, LessLess, GreaterGreater, GreaterGreaterGreater |
| Logical | `&&`, `\|\|`, `!` | AmpersandAmpersand, PipePipe, Bang |
| Relational | `==`, `!=`, `<`, `<=`, `>`, `>=` | EqualEqual, BangEqual, Less, LessEqual, Greater, GreaterEqual |
| Member and access | `.`, `?.`, `::`, `...` | Dot, QuestionDot, ColonColon, DotDotDot |
| Grouping and delimiters | `(`, `)`, `[`, `]`, `{`, `}` | LeftParen, RightParen, LeftBracket, RightBracket, LeftBrace, RightBrace |
| Separators | `;`, `,` | Semicolon, Comma |
| Conditional and type | `?`, `:` | Question, Colon |
| Arrows | `=>`, `->` | Arrow, ThinArrow |
| Decorator | `@` | At |

**7.10.3** The token names in Table 7.10.2-1 are diagnostic and grammatical names; they are not identifiers and are not visible to a Dryad program. A program cannot refer to a punctuator by name.

**7.10.4** Punctuators are recognized by maximal munch under 7.4.9. The ordering of rows in Table 7.10.2-1 is not a precedence declaration and does not affect tokenization. Operator precedence and associativity are defined by Clause 9.

**7.10.5** The sequences `//` and `/*` begin comments and are not tokenized as `/` followed by `/` or `*`. A `/` that begins a comment is never a Slash token. To write a division whose right operand begins with `*` or `/`, trivia is required between the operator and the operand.

**7.10.6** Table 7.10.6-1 gives the tokenization of ambiguous sequences.

| Source | Tokens |
|--------|--------|
| `a+++b` | `a`, `++`, `+`, `b` |
| `a+ ++b` | `a`, `+`, `++`, `b` |
| `a---b` | `a`, `--`, `-`, `b` |
| `a-- -b` | `a`, `--`, `-`, `b` |
| `a**b` | `a`, `**`, `b` |
| `a***b` | `a`, `**`, `*`, `b` |
| `a=>b` | `a`, `=>`, `b` |
| `a=>>b` | `a`, `=>`, `>`, `b` |
| `a::b` | `a`, `::`, `b` |
| `a:::b` | `a`, `::`, `:`, `b` |
| `a?.b` | `a`, `?.`, `b` |
| `a??.b` | `a`, `?`, `?.`, `b` |
| `a...b` | `a`, `...`, `b` |
| `a..b` | `a`, `.`, `.`, `b` |
| `a....b` | `a`, `...`, `.`, `b` |
| `a>>>b` | `a`, `>>>`, `b` |
| `a>>>>b` | `a`, `>>>`, `>`, `b` |
| `a>>>=b` | `a`, `>>>=`, `b` |
| `a&&&b` | `a`, `&&`, `&`, `b` |
| `a\|\|\|b` | `a`, `\|\|`, `\|`, `b` |
| `a//b` | `a` and a LineComment |
| `a/*b*/c` | `a`, `c` with one BlockComment between |
| `1.2.3` | `1.2`, `.`, `3` |
| `1..2` | `1`, `.`, `.`, `2` |

**7.10.7** Trivia is REQUIRED between two punctuators when their concatenation would form a longer punctuator and the intended tokenization requires the shorter tokens. Table 7.10.6-1 illustrates the rule. In particular, `+` followed by `+` requires separation to avoid `++`; `-` followed by `-` requires separation to avoid `--`; `*` followed by `*` requires separation to avoid `**`; `=` followed by `=` requires separation to avoid `==`; `=` followed by `>` requires separation to avoid `=>`; `-` followed by `>` requires separation to avoid `->`; `<` followed by `<` requires separation to avoid `<<`; `>` followed by `>` requires separation to avoid `>>`; `&` followed by `&` requires separation to avoid `&&`; `|` followed by `|` requires separation to avoid `||`; `:` followed by `:` requires separation to avoid `::`; and `?` followed by `.` requires separation to avoid `?.`. Three consecutive `.` characters form `...`; separation is required if three separate Dot tokens are intended. This list is illustrative, not exhaustive; maximal munch governs every case.

**7.10.8** The sequences `===` and `!==` are not tokens. `===` is tokenized as `==` followed by `=`; `!==` is tokenized as `!=` followed by `=`. The resulting token sequences are rejected by the syntactic grammar. Dryad has no strict-equality operators because `==` and `!=` never coerce (D-08).

**7.10.9** The characters `$` and reverse solidus are not punctuators. In goals `Input` and `TemplateSubstitution`, `$` is an unexpected character. In goal `TemplateContent`, `$` is ordinary content unless it begins a TemplateInterpolationStart. In a StringLiteral or Comment, `$` is ordinary. A reverse solidus is ordinary in a Comment and is an unexpected character elsewhere except where it begins an EscapeSequence in a StringLiteral or TemplateContent. The character `#` is not a punctuator; it begins a NativeDirective only under 7.9.

**7.10.10** The following program is well-formed:

```dryad
import math;

function main() {
    let a = 2 + 3 * 4;
    let b = 2 ** 3 ** 2;
    let c = "left" + "right";
    let d = 0;
    d++;
    let e = -d;
    let f = (x) => x + 1;
    let g = math::cos(0);
    let h = { field: 1 };
    let i = h?.field;
    print(a);
    print(b);
    print(c);
    print(f(e));
    print(g);
    print(i);
}
```

`2 ** 3 ** 2` is right-associative under Clause 9; the lexical grammar does not decide associativity. `math::cos` uses the namespace punctuator. `h?.field` uses optional chaining. `=>` is the arrow punctuator.

**7.10.11** An implementation MUST NOT recognize any punctuator not listed in Table 7.10.2-1. A sequence of characters that resembles an operator but is not listed, such as `===`, `!==`, `??`, `**=**`, or `<<<`, is tokenized by maximal munch into listed punctuators or produces an unexpected-character error. The syntactic grammar then determines whether the resulting sequence is well-formed.

**7.10.12** Operator precedence, associativity, and semantics are defined by Clause 9 and are not lexical properties. The lexical grammar determines only token boundaries. A token sequence that is lexically well-formed can still be rejected by the syntactic grammar or by an early error in another clause.

## 7.11 Lexical Grammar in EBNF

**7.11.1** This subclause presents the complete lexical grammar in the EBNF of Clause 5.2. The productions are normative. In these productions, a terminal written with a reverse-solidus escape denotes the single code point named by the escape: `"\u000A"` denotes LF, `"\uFEFF"` denotes the byte-order mark, `"\\"` denotes one reverse solidus, and `"\""` denotes one quotation mark. A comment of the form `(* ... *)` is informative and does not constrain the production.

**7.11.2** Source text and trivia are defined by the following productions.

```
<SourceText> ::= [ <ByteOrderMark> ] { <SourceCharacter> }
<SourceCharacter> ::= (* any Unicode scalar value *)
<ByteOrderMark> ::= "\uFEFF"
<TokenSequence> ::= { <Trivia> } [ <Token> { <Trivia> <Token> } ] { <Trivia> } <EndOfFile>
<Trivia> ::= <WhiteSpace> | <LineTerminatorSequence> | <Comment>
```

**7.11.3** WhiteSpace, line terminators, and comments are defined by the following productions.

```
<WhiteSpace> ::= "\u0009" | "\u000B" | "\u000C" | "\u0020" | "\u00A0" | "\uFEFF" | <UnicodeSpaceSeparator>
<UnicodeSpaceSeparator> ::= "\u1680" | "\u2000" | "\u2001" | "\u2002" | "\u2003" | "\u2004" | "\u2005" | "\u2006" | "\u2007" | "\u2008" | "\u2009" | "\u200A" | "\u202F" | "\u205F" | "\u3000"
<LineTerminatorSequence> ::= "\u000A" | "\u000D" [ "\u000A" ] | "\u2028" | "\u2029"
<Comment> ::= <LineComment> | <BlockComment>
<LineComment> ::= "//" { <LineCommentCharacter> }
<LineCommentCharacter> ::= (* any SourceCharacter other than a LineTerminator *)
<BlockComment> ::= "/*" <BlockCommentBody> "*/"
<BlockCommentBody> ::= (* any sequence of SourceCharacters in which every "/*" is matched by a later "*/" before the closing "*/" *)
```

**7.11.4** Identifiers and their character classes are defined by the following productions.

```
<Identifier> ::= <IdentifierName> (* but not a ReservedWord *)
<IdentifierName> ::= <IdentifierStart> { <IdentifierPart> }
<IdentifierStart> ::= "_" | <ASCIILetter> | <UnicodeIDStart>
<IdentifierPart> ::= <IdentifierStart> | <DecimalDigit> | <UnicodeIDContinue>
<ASCIILetter> ::= <LowerCaseLetter> | <UpperCaseLetter>
<LowerCaseLetter> ::= "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h" | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v" | "w" | "x" | "y" | "z"
<UpperCaseLetter> ::= "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H" | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V" | "W" | "X" | "Y" | "Z"
<UnicodeIDStart> ::= (* any code point with Unicode property ID_Start, Unicode 16.0.0 *)
<UnicodeIDContinue> ::= (* any code point with Unicode property ID_Continue, Unicode 16.0.0 *)
```

**7.11.5** Reserved words, keywords, and literal words are defined by the following productions.

```
<ReservedWord> ::= <DeclarationKeyword> | <ControlKeyword> | <FunctionKeyword> | <ObjectKeyword> | <ModuleKeyword> | <ExceptionKeyword> | <BooleanLiteral> | <NullLiteral>
<DeclarationKeyword> ::= "let" | "const" | "function" | "class" | "interface" | "import" | "export"
<ControlKeyword> ::= "if" | "else" | "for" | "while" | "do" | "break" | "continue" | "return" | "match" | "in"
<FunctionKeyword> ::= "fn" | "async" | "await" | "thread" | "mutex"
<ObjectKeyword> ::= "new" | "extends" | "implements" | "this" | "super" | "static" | "public" | "private" | "protected" | "abstract" | "readonly" | "get" | "set" | "delete"
<ModuleKeyword> ::= "use" | "as" | "from" | "extern" | "internal"
<ExceptionKeyword> ::= "try" | "catch" | "finally" | "throw"
<BooleanLiteral> ::= "true" | "false"
<NullLiteral> ::= "null"
<Keyword> ::= <DeclarationKeyword> | <ControlKeyword> | <FunctionKeyword> | <ObjectKeyword> | <ModuleKeyword> | <ExceptionKeyword>
```

**7.11.6** Numeric literals are defined by the following productions.

```
<NumericLiteral> ::= <DecimalLiteral> | <HexIntegerLiteral> | <BinaryIntegerLiteral> | <OctalIntegerLiteral>
<DecimalLiteral> ::= <DecimalIntegerLiteral> [ "." <DecimalDigits> ] [ <ExponentPart> ]
<DecimalIntegerLiteral> ::= "0" | <NonZeroDigit> [ <DecimalDigits> ]
<DecimalDigits> ::= <DecimalDigit> { [ "_" ] <DecimalDigit> }
<DecimalDigit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
<NonZeroDigit> ::= "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
<ExponentPart> ::= ( "e" | "E" ) [ "+" | "-" ] <DecimalDigits>
<HexIntegerLiteral> ::= ( "0x" | "0X" ) <HexDigits>
<HexDigits> ::= <HexDigit> { [ "_" ] <HexDigit> }
<HexDigit> ::= <DecimalDigit> | "a" | "b" | "c" | "d" | "e" | "f" | "A" | "B" | "C" | "D" | "E" | "F"
<BinaryIntegerLiteral> ::= ( "0b" | "0B" ) <BinaryDigits>
<BinaryDigits> ::= <BinaryDigit> { [ "_" ] <BinaryDigit> }
<BinaryDigit> ::= "0" | "1"
<OctalIntegerLiteral> ::= ( "0o" | "0O" ) <OctalDigits>
<OctalDigits> ::= <OctalDigit> { [ "_" ] <OctalDigit> }
<OctalDigit> ::= "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7"
```

**7.11.7** String literals and escape sequences are defined by the following productions.

```
<StringLiteral> ::= <SingleQuotedString> | <DoubleQuotedString>
<SingleQuotedString> ::= <Apostrophe> { <SingleStringCharacter> } <Apostrophe>
<DoubleQuotedString> ::= <QuotationMark> { <DoubleStringCharacter> } <QuotationMark>
<SingleStringCharacter> ::= <SingleStringSourceCharacter> | <EscapeSequence>
<DoubleStringCharacter> ::= <DoubleStringSourceCharacter> | <EscapeSequence>
<SingleStringSourceCharacter> ::= (* any SourceCharacter other than <Apostrophe>, <ReverseSolidus>, or a LineTerminator *)
<DoubleStringSourceCharacter> ::= (* any SourceCharacter other than <QuotationMark>, <ReverseSolidus>, or a LineTerminator *)
<EscapeSequence> ::= <ReverseSolidus> <EscapeCharacter> | <HexEscapeSequence> | <UnicodeEscapeSequence> | <LineContinuation>
<EscapeCharacter> ::= <Apostrophe> | <QuotationMark> | <Backtick> | <DollarSign> | "b" | "f" | "n" | "r" | "t" | "v" | "0"
<HexEscapeSequence> ::= <ReverseSolidus> "x" <HexDigit> <HexDigit>
<UnicodeEscapeSequence> ::= <ReverseSolidus> "u" <HexDigit> <HexDigit> <HexDigit> <HexDigit> | <ReverseSolidus> "u" "{" <CodePointDigits> "}"
<CodePointDigits> ::= <HexDigit> [ <HexDigit> [ <HexDigit> [ <HexDigit> [ <HexDigit> [ <HexDigit> ] ] ] ] ]
<LineContinuation> ::= <ReverseSolidus> <LineTerminatorSequence>
<Apostrophe> ::= "'"
<QuotationMark> ::= "\""
<Backtick> ::= "`"
<DollarSign> ::= "$"
<ReverseSolidus> ::= "\\"
```

**7.11.8** Template literals are defined by the following productions.

```
<TemplateStart> ::= <Backtick>
<TemplateEnd> ::= <Backtick>
<TemplateInterpolationStart> ::= <DollarSign> "{"
<TemplateInterpolationEnd> ::= "}"
<TemplateContent> ::= <TemplateCharacter> { <TemplateCharacter> }
<TemplateCharacter> ::= <TemplateSourceCharacter> | <EscapeSequence> | <LineTerminatorSequence>
<TemplateSourceCharacter> ::= (* any SourceCharacter other than <Backtick>, <ReverseSolidus>, or <DollarSign> immediately followed by "{" *)
```

**7.11.9** Native directives are defined by the following production.

```
<NativeDirective> ::= "#" "<" <Identifier> ">"
```

**7.11.10** Punctuators are defined by the following productions.

```
<Punctuator> ::= <BracketPunctuator> | <SeparatorPunctuator> | <MemberPunctuator> | <ArrowPunctuator> | <DecoratorPunctuator> | <ConditionalPunctuator> | <ArithmeticOperator> | <IncDecOperator> | <AssignmentOperator> | <BitwiseOperator> | <LogicalOperator> | <RelationalOperator>
<BracketPunctuator> ::= "(" | ")" | "[" | "]" | "{" | "}"
<SeparatorPunctuator> ::= ";" | ","
<MemberPunctuator> ::= "." | "?." | "::" | "..."
<ArrowPunctuator> ::= "=>" | "->"
<DecoratorPunctuator> ::= "@"
<ConditionalPunctuator> ::= "?" | ":"
<ArithmeticOperator> ::= "+" | "-" | "*" | "/" | "%" | "**"
<IncDecOperator> ::= "++" | "--"
<AssignmentOperator> ::= "=" | "+=" | "-=" | "*=" | "/="
<BitwiseOperator> ::= "&" | "|" | "^" | "~" | "<<" | ">>" | ">>>"
<LogicalOperator> ::= "&&" | "||" | "!"
<RelationalOperator> ::= "==" | "!=" | "<" | "<=" | ">" | ">="
```

**7.11.11** Tokens, input elements, template elements, and end of file are defined by the following productions.

```
<Token> ::= <Identifier> | <Keyword> | <BooleanLiteral> | <NullLiteral> | <NumericLiteral> | <StringLiteral> | <TemplateStart> | <TemplateContent> | <TemplateInterpolationStart> | <TemplateInterpolationEnd> | <TemplateEnd> | <NativeDirective> | <Punctuator>
<InputElement> ::= <Identifier> | <Keyword> | <BooleanLiteral> | <NullLiteral> | <NumericLiteral> | <StringLiteral> | <TemplateStart> | <NativeDirective> | <Punctuator>
<TemplateElement> ::= <TemplateContent> | <TemplateInterpolationStart> | <TemplateEnd>
<TemplateSubstitutionElement> ::= <InputElement> | <TemplateInterpolationEnd>
<EndOfFile> ::= ε
```

**7.11.12** The productions of 7.11.11 define the token kinds and the elements eligible in each lexical goal. `<TemplateContent>`, `<TemplateInterpolationStart>`, `<TemplateInterpolationEnd>`, and `<TemplateEnd>` are eligible only in the goals of 7.4.6 and 7.4.7. The production `<Token>` is the union used for the token-kind inventory; it does not override the goal restrictions of 7.4.4 through 7.4.8.

## 7.12 Early Errors

**7.12.1** A *lexical early error* is a condition that prevents the formation of a lexical token sequence. Every condition in Table 7.12.4-1 is an early error. An implementation MUST detect and report each such condition before execution. A conforming implementation MUST reject a source text unit that contains any lexical early error.

**7.12.2** Each lexical early error has a *category* and a *condition name*. The categories are *encoding*, *character*, *comment*, *number*, *literal*, *template*, *directive*, and *separator*. Condition names are diagnostic identifiers; Annex A assigns numeric error codes. The categories and names in this clause are normative; the numeric codes are registry data.

**7.12.3** An implementation MUST report the source position of the error. For an error associated with a delimited construct, the position MUST be the position of the opening delimiter unless otherwise stated. For an error associated with a character, the position MUST be the position of that character. For an encoding error, the position MUST identify the byte offset of the first invalid byte and, where determinable, the line and column of the last successfully decoded source character.

**7.12.4** Table 7.12.4-1 lists every lexical early error.

| Condition | Category | Description | Reported position |
|-----------|----------|-------------|-------------------|
| `InvalidSourceEncoding` | encoding | The source text is not well-formed UTF-8, contains an overlong form, encodes a surrogate, or encodes a value greater than U+10FFFF. | First invalid byte. |
| `UnexpectedCharacter` | character | A source character cannot begin any token eligible in the current goal, including `$` in goals `Input` and `TemplateSubstitution`, a reverse solidus outside a literal, an unescaped control character, and punctuation not listed in 7.10.2. | The character. |
| `UnterminatedComment` | comment | A BlockComment reaches end of input while its nesting depth is greater than zero. | The opening `/*`. |
| `InvalidNumericLiteral` | number | A decimal literal has a leading zero, a based literal has no valid first digit, a numeric separator is misplaced, or an exponent marker has no digits. | The first character of the literal. |
| `NumericLiteralFollowedByIdentifier` | separator | A NumericLiteral is immediately followed by an IdentifierStart other than `_`, or by a decimal digit. | The first character after the literal. |
| `UnterminatedString` | literal | A StringLiteral reaches a raw LineTerminatorSequence or end of input before its closing delimiter, including a reverse solidus at end of input. | The opening delimiter. |
| `InvalidEscapeSequence` | literal | A reverse solidus is followed by a character that is not a valid escape, or `\0` is followed by a decimal digit. | The reverse solidus. |
| `InvalidHexEscape` | literal | A `\x` escape is not followed by exactly two hexadecimal digits. | The reverse solidus. |
| `InvalidUnicodeEscape` | literal | A `\u` escape is malformed, denotes a surrogate, denotes a value greater than U+10FFFF, or has zero or more than six braced digits. | The reverse solidus. |
| `UnterminatedTemplate` | template | A template literal reaches end of input before its TemplateEnd and no interpolation is open. | The opening TemplateStart. |
| `UnterminatedTemplateInterpolation` | template | End of input occurs before the TemplateInterpolationEnd that closes an open interpolation at brace depth zero. | The opening `${`. |
| `MalformedNativeDirective` | directive | `#` is not immediately followed by `<`; the name is missing, empty, or not an Identifier; `>` is missing; trivia occurs inside the directive; or the name is a ReservedWord. | The `#`. |

**7.12.5** Table 7.12.5-1 lists conditions that are not lexical early errors. They do not change the lexical token sequence and are detected by another clause.

| Condition | Detected by |
|-----------|-------------|
| A ReservedWord occurs where an Identifier is required. | Clause 22, syntactic grammar. |
| A template interpolation contains no expression, as in `${}`. | Clause 9, syntactic grammar. |
| The sequences `===` and `!==` occur. | Clause 9 and Clause 22. |
| Adjacent StringLiterals occur without a punctuator. | Clause 9 and Clause 22. |
| A template literal is used as a tag. | Clause 9. |
| A NativeDirective occurs outside a permitted module position. | Clause 12. |
| A native module name is unknown. | Clause 12 and Clause 16. |
| An identifier has no binding. | Clause 13 and Clause 14. |
| A required semicolon is missing. | Clause 10 and Clause 22. |

**7.12.6** If a source text unit contains more than one lexical error, an implementation MUST report at least the first error in source order. It MAY report additional errors. It MUST NOT report a successful tokenization. Error recovery is permitted only for diagnostic purposes and MUST NOT cause the unit to be accepted.

**7.12.7** A lexical error MUST be distinguishable from a syntactic error in the diagnostic. The diagnostic MUST include the condition name or an equivalent stable identifier and the source position. The diagnostic text is not normative (Clause 2.8).

**7.12.8** The source text `letin` is one Identifier token, not `let` followed by `in`; maximal munch of the IdentifierName applies before keyword classification. Such a spelling is not a lexical error. An implementation that tokenizes `letin` as two keywords is non-conforming.

**7.12.9** A syntactically well-formed token sequence MAY still be ill-formed because of an early error in Clause 8, 9, 10, 11, 12, or 22. Such an error is not a lexical error and does not change the token sequence.

## 7.13 Conformance Requirements for a Lexer

**7.13.1** A *conforming lexer* is a component of a conforming implementation that satisfies every requirement of this clause. Clause 7 is required by every conformance class of Clause 2.

**7.13.2** A conforming lexer MUST accept every source text unit that satisfies 7.1 through 7.11 and MUST produce the unique lexical token sequence defined by this clause, with EndOfFile as the final token.

**7.13.3** A conforming lexer MUST reject every source text unit that contains a lexical early error in 7.12 and MUST report the error as specified in 7.12.3 and Clause 14.

**7.13.4** A conforming lexer MUST validate UTF-8 as specified in 7.1.2. It MUST NOT replace invalid sequences with U+FFFD, MUST NOT ignore invalid bytes, and MUST NOT apply a locale-dependent decoding.

**7.13.5** A conforming lexer MUST discard a single initial U+FEFF and MUST treat every other U+FEFF as WhiteSpace. It MUST NOT treat U+FEFF as an identifier character, a punctuator, or a token separator distinct from WhiteSpace.

**7.13.6** A conforming lexer MUST implement the lexical goals of 7.4.4 through 7.4.8, including the template context stack and the brace-depth rule. It MUST produce TemplateStart, TemplateContent, TemplateInterpolationStart, TemplateInterpolationEnd, and TemplateEnd tokens exactly as specified.

**7.13.7** A conforming lexer MUST apply maximal munch under 7.4.9. It MUST NOT use the syntactic grammar to choose a shorter token. It MUST NOT use semantic information to disambiguate a token.

**7.13.8** A conforming lexer MUST classify reserved words exactly as specified in Table 7.5.10-1. It MUST NOT add or remove reserved words, and it MUST NOT classify a reserved word as an Identifier. It MUST classify every other IdentifierName as an Identifier.

**7.13.9** A conforming lexer MUST compute the binary64 value of every NumericLiteral by correct rounding as specified in 7.6.9 through 7.6.11. It MUST reject every numeric form identified as a lexical error in 7.6.13 through 7.6.16.

**7.13.10** A conforming lexer MUST decode every EscapeSequence in a StringLiteral or TemplateContent and MUST produce the scalar-value sequence specified in 7.7.12 and 7.8.11. It MUST reject every ill-formed escape in 7.7.5 through 7.7.9.

**7.13.11** A conforming lexer MUST form NativeDirective tokens exactly as specified in 7.9.2. It MUST reject every malformed directive in 7.9.5, including every bare `#name` form (D-02).

**7.13.12** A conforming lexer MUST recognize comments as specified in 7.3, including nested BlockComments. It MUST NOT treat `//` or `/*` as operators. It MUST discard comments from the lexical token sequence or retain them only as trivia.

**7.13.13** A conforming lexer MUST report source positions as specified in 7.1.5 and 7.2.8. It MUST count columns in Unicode scalar values, MUST treat CRLF as one LineTerminatorSequence, and MUST report the position of the opening delimiter for unterminated constructs.

**7.13.14** A conforming lexer MUST NOT apply Unicode normalization to identifiers, string values, or template values. It MUST compare identifiers by exact code-point sequence.

**7.13.15** A conforming lexer MUST NOT recognize any token kind, operator, punctuator, escape sequence, numeric form, or directive form not specified in this clause. An implementation extension that adds such a form is permitted only under Clause 2.4 and MUST be disabled for conformance testing.

**7.13.16** A conforming lexer MAY process a source text unit incrementally. If it does, it MUST produce the same token sequence and the same errors as a lexer that processes the entire unit before producing tokens. A lexer MUST NOT emit a token whose formation depends on source characters that have not yet been read, except for the lookahead required by maximal munch.

**7.13.17** Resource exhaustion is not a lexical early error. If an implementation cannot complete lexing because of a host resource limit, it MUST report an error of category *resource* under Clause 14 and MUST NOT silently truncate the token sequence or accept a prefix of the unit. An implementation SHOULD impose no artificial limit on token length, comment nesting, or template nesting.

**7.13.18** A conforming lexer SHOULD pass the lexical conformance tests maintained for Edition 1.0. The tests are evidence of conformance and do not replace the normative requirements of this clause.

**7.13.19** The following checklist is informative and summarizes the mandatory behaviour of a conforming lexer.

1. Validate UTF-8 and discard one initial U+FEFF.
2. Treat WhiteSpace, LineTerminatorSequence, and Comments as trivia; nest BlockComments.
3. Apply maximal munch and the lexical goals of 7.4.4 through 7.4.8.
4. Classify identifiers and the reserved words of Table 7.5.10-1.
5. Decode NumericLiterals to binary64 with correct rounding.
6. Decode string and template escapes to Unicode scalar values.
7. Form `#<name>` NativeDirectives and reject every bare `#name`.
8. Detect every condition in Table 7.12.4-1 and report its position.
9. Emit exactly one EndOfFile, after every other token.

**7.13.20** A lexer that satisfies 7.13.1 through 7.13.17 is conforming for Clause 7. No additional lexical behaviour is required, and Clause 7 introduces no lexical early error other than those in Table 7.12.4-1.
