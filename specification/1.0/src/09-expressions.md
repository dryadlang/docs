# 9 Expressions

## 9.1 Expression Grammar Overview

**9.1.1** This clause defines the syntax and evaluation of Dryad expressions.
An *expression* evaluates to a value or throws a `DryadError` (Clause 14); it
never yields a `Break`, `Continue`, or `Return` completion (Clause 5.4.3).
Every form here is available in every execution tier and conformance class.

**9.1.2** Expression evaluation produces a *value* or a *Reference*. A
*Reference* is a specification record with a *base*, a *name*, and a *kind*.
The name is a String. The kind is *ordinary*, *super*, or *namespace*. For an
ordinary Reference the base is an Environment Record (Clause 13.2) or an
Object (Clause 8.3); for a super Reference the base is the current `this` and
lookup starts at the superclass (9.3.6); for a namespace Reference the base is
a module namespace (Clause 12.4). A Reference is not a Dryad value and cannot
be stored, passed, returned, or compared. `GetValue` (9.3.3) converts one to a
value; `PutValue` (9.3.4) writes through one.

**9.1.3** The constructs that produce References are an Identifier, a member
access (dot, bracket, or `::`), a `super` member access, and a
ParenthesizedExpression whose operand produces a Reference. All other
expressions produce values. Assignment and update targets MUST be References;
this is an early error where it cannot be satisfied (9.21).

**9.1.4** Unless an algorithm states otherwise, subexpressions are evaluated
from left to right and each is evaluated exactly once. The grammar imposes no
evaluation order (Clause 5.2.6); this clause and the summary in 9.20 impose
it. An implementation MUST NOT evaluate a subexpression that the selected
algorithm does not require, and MUST NOT evaluate a required subexpression
more than once.

**9.1.5** The following EBNF grammar defines the expression forms of Edition
1.0. It refines the complete grammar of Clause 22; if a discrepancy exists,
Clause 22 prevails and the discrepancy is an erratum (Clause 6.6.2).

```
<Expression>               ::= <AssignmentExpression>
<AssignmentExpression>     ::= <ArrowFunction>
                             | <LogicalOrExpression> [ <AssignmentOperator> <AssignmentExpression> ]
<AssignmentOperator>       ::= "=" | "+=" | "-=" | "*=" | "/=" | "%=" | "**="
                             | "<<=" | ">>=" | ">>>=" | "&=" | "^=" | "|="
<LogicalOrExpression>      ::= <LogicalAndExpression> { "||" <LogicalAndExpression> }
<LogicalAndExpression>     ::= <BitwiseOrExpression> { "&&" <BitwiseOrExpression> }
<BitwiseOrExpression>      ::= <BitwiseXorExpression> { "|" <BitwiseXorExpression> }
<BitwiseXorExpression>     ::= <BitwiseAndExpression> { "^" <BitwiseAndExpression> }
<BitwiseAndExpression>     ::= <EqualityExpression> { "&" <EqualityExpression> }
<EqualityExpression>       ::= <RelationalExpression> { ( "==" | "!=" ) <RelationalExpression> }
<RelationalExpression>     ::= <ShiftExpression> { ( "<" | "<=" | ">" | ">=" ) <ShiftExpression> }
<ShiftExpression>          ::= <AdditiveExpression> { ( "<<" | ">>" | ">>>" ) <AdditiveExpression> }
<AdditiveExpression>       ::= <MultiplicativeExpression> { ( "+" | "-" ) <MultiplicativeExpression> }
<MultiplicativeExpression> ::= <ExponentiationExpression> { ( "*" | "/" | "%" ) <ExponentiationExpression> }
<ExponentiationExpression> ::= <UnaryExpression> [ "**" <ExponentiationExpression> ]
<UnaryExpression>          ::= ( "!" | "+" | "-" | "~" | "++" | "--" | "await" ) <UnaryExpression>
                             | <UpdateExpression>
<UpdateExpression>         ::= <LeftHandSideExpression> [ "++" | "--" ]
<LeftHandSideExpression>   ::= <PrimaryExpression> { <MemberSuffix> | <Arguments> }
<MemberSuffix>             ::= "." <MemberName>
                             | "[" <Expression> "]"
                             | "::" <Identifier>
<MemberName>               ::= <Identifier> | <NumericLiteral>
<Arguments>                ::= "(" [ <Expression> { "," <Expression> } ] ")"
<PrimaryExpression>        ::= <Literal>
                             | <Identifier>
                             | "this"
                             | "super"
                             | <ArrayLiteral>
                             | <ObjectLiteral>
                             | <TupleLiteral>
                             | <ParenthesizedExpression>
                             | <NewExpression>
                             | <MatchExpression>
                             | <FunctionExpression>
<Literal>                  ::= <NumericLiteral>
                             | <StringLiteral>
                             | <TemplateLiteral>
                             | "true"
                             | "false"
                             | "null"
<ArrayLiteral>             ::= "[" [ <Expression> { "," <Expression> } ] "]"
<ObjectLiteral>            ::= "{" [ <PropertyDefinition> { "," <PropertyDefinition> } ] "}"
<PropertyDefinition>       ::= <PropertyName> ":" <Expression>
                             | "[" <Expression> "]" ":" <Expression>
                             | <Identifier>
<PropertyName>             ::= <Identifier> | <StringLiteral> | <NumericLiteral>
<TupleLiteral>             ::= "(" <Expression> "," ")"
                             | "(" <Expression> "," <Expression> { "," <Expression> } ")"
<ParenthesizedExpression>  ::= "(" <Expression> ")"
<NewExpression>            ::= "new" <ClassReference> <Arguments>
<ClassReference>           ::= <Identifier> { ( "." | "::" ) <Identifier> }
<MatchExpression>          ::= "match" <Expression> "{" <MatchArm> { "," <MatchArm> } "}"
<MatchArm>                 ::= <Pattern> [ "if" <Expression> ] "=>" <Expression>
<Pattern>                  ::= <LiteralPattern> | "_" | <Identifier>
<LiteralPattern>           ::= [ "-" ] <NumericLiteral>
                             | <StringLiteral>
                             | "true"
                             | "false"
                             | "null"
<FunctionExpression>       ::= [ "async" ] "function" <Parameters> [ ":" <Type> ] <Block>
<ArrowFunction>            ::= <Parameters> "=>" ( <Expression> | <Block> )
<Parameters>               ::= "(" [ <Parameter> { "," <Parameter> } ] ")"
<Parameter>                ::= <Identifier> [ ":" <Type> ] [ "=" <Expression> ]
                             | "..." <Identifier> [ ":" <Type> ]
<TemplateLiteral>          ::= "`" { <TemplateCharacter> | "${" <Expression> "}" } "`"
```

**9.1.6** The grammar is unambiguous. Of the three productions beginning with
`"("`, a comma before the matching `")"` selects TupleLiteral, except when the
matching `")"` is followed by `"=>"`, in which case the list is an
ArrowFunction parameter list. Without a comma or `"=>"`, `"(" <Expression>
")"` is a ParenthesizedExpression. The empty sequence `"()"` occurs only in
`<Parameters>`. An implementation MUST derive the unique parse tree required
by these rules.

**9.1.7** Table 9-1 lists the operators from highest to lowest precedence; the
grammar of 9.1.5 is normative.

| Level | Operators and forms | Associativity | Clause |
|-------|--------------------|---------------|--------|
| 1 | literals, identifiers, `this`, `super`, array, object, tuple, parenthesized, `new`, `match`, function expression | none | 9.2, 9.6, 9.16 |
| 2 | `.`, `[]`, `::` | left | 9.4 |
| 3 | `()` call | left | 9.5 |
| 4 | postfix `++`, `--` | none | 9.7 |
| 5 | prefix `!`, `+`, `-`, `~`, `++`, `--`, `await` | right | 9.7, 9.18 |
| 6 | `**` | right | 9.8 |
| 7 | `*`, `/`, `%` | left | 9.9 |
| 8 | `+`, `-` | left | 9.9 |
| 9 | `<<`, `>>`, `>>>` | left | 9.10 |
| 10 | `<`, `<=`, `>`, `>=` | left | 9.10 |
| 11 | `==`, `!=` | left | 9.10 |
| 12 | `&` | left | 9.11 |
| 13 | `^` | left | 9.11 |
| 14 | `|` | left | 9.11 |
| 15 | `&&` | left | 9.12 |
| 16 | `||` | left | 9.12 |
| 17 | assignment operators | right | 9.14 |
| 18 | `=>` arrow | right | 9.19 |
| 19 | `,` sequence | not an operator | 9.15 |

**9.1.8** *TypeError*, *ReferenceError*, and *RangeError* abbreviate a
`DryadError` of the corresponding category, as specified in Clause 14; the
codes are assigned in Annex A. A specified throw MUST occur at the point
stated by its algorithm.

## 9.2 Primary Expressions

**9.2.1** Primary expressions are the operands from which all other
expressions are constructed. They have the highest precedence. Except for the
forms listed in 9.1.3, a primary expression evaluates to a value.

**9.2.2** A NumericLiteral evaluates to the binary64 number nearest to the
mathematical value denoted by the literal, rounded to nearest with ties to
even. Integer-looking literals denote Numbers; Edition 1.0 has no distinct
integer value type (D-14). Hexadecimal, binary, and octal literals are
specified in Clause 7. A literal that exceeds the finite binary64 range
evaluates to `Infinity` or `-Infinity` with the sign of the literal; a nonzero
literal below the smallest subnormal evaluates to a signed zero. Neither is an
error.

**9.2.3** A StringLiteral evaluates to the String of Unicode scalar values
obtained after escape processing (Clause 7). A BooleanLiteral evaluates to
`true` or `false`; a NullLiteral evaluates to `null`; a TemplateLiteral
evaluates as specified in 9.17.

**9.2.4** An Identifier expression evaluates to the Reference obtained by
`ResolveBinding` (9.3.1). When a value is required, `GetValue` is applied. A
reference to an uninitialized binding throws a ReferenceError (9.3.3).

**9.2.5** A ParenthesizedExpression evaluates its operand and returns the
result unchanged. If the operand produces a Reference, the parenthesized
expression produces a Reference with the same base, name, and kind; thus
`(obj.m)()` preserves the receiver `obj` (9.5.3). Parentheses do not create a
tuple; a tuple requires a comma (9.2.10).

**9.2.6** A ThisExpression evaluates to the ThisBinding of the running
execution context (9.3.5). It produces a value, not a Reference.

**9.2.7** A SuperExpression is not a value and does not evaluate on its own.
It MUST occur as the callee of a call, `super(...)`, or as the base of a
member access, `super.name`. Its evaluation is specified in 9.3.6; any other
occurrence is an early error (9.21).

**9.2.8** An ArrayLiteral creates a new Array of length zero, evaluates each
element expression in source order, applies `GetValue`, and appends the result.
The array is new on each evaluation. Elements are heterogeneous; holes and
trailing commas are not permitted.

**9.2.9** An ObjectLiteral evaluates as follows.

1. Let `object` be a new ordinary Object with no own properties.
2. For each PropertyDefinition in source order:
   1. If computed, evaluate the key expression and apply `ToPropertyKey`
      (9.4.3); otherwise the key is the literal property name.
   2. For a shorthand identifier, obtain its current value by `GetValue` of
      `ResolveBinding`.
   3. Otherwise evaluate the value expression and apply `GetValue`.
   4. Create or update the own property named by the key.
3. Return `object`.

Definitions are processed left to right; a computed key precedes the value of
the same definition. A shorthand reads the binding at creation time. If a key
occurs more than once, all values are evaluated in source order and the last
one wins. `__proto__` is an ordinary key. Methods, accessors, and spread
properties are not part of Edition 1.0.

**9.2.10** A TupleLiteral creates a new Tuple of fixed length, evaluates each
element expression in source order, applies `GetValue`, and stores the value at
its zero-based position. `(e)` is a ParenthesizedExpression; `(e,)` is a
one-element tuple; two or more comma-separated elements form a tuple of that
length; `()` is not an expression. The length is fixed and elements are
assignable by valid index (9.4.7). Each evaluation creates a new Tuple, and
tuples compare by identity (9.10.7). An element is accessed as `tuple.0` or
`tuple[0]`; an index outside `[0, length)` throws a RangeError.

**9.2.11** A FunctionExpression evaluates to a new function value that closes
over the current lexical environment. The body is not evaluated at creation
time. Function expressions are not hoisted; the value exists only after the
expression has been evaluated. Function creation and calling conventions are
specified in Clause 11.

**9.2.12** A MatchExpression is a primary expression and evaluates as
specified in 9.16. An ArrowFunction is an AssignmentExpression, not a primary
expression, and evaluates as specified in 9.19.

## 9.3 Identifier Resolution and `this` Binding

**9.3.1** The abstract operation `ResolveBinding(name)` resolves an identifier
to a Reference as follows.

1. Let `env` be the LexicalEnvironment of the running execution context.
2. Repeat:
   1. If `env` has a binding for `name`, return an ordinary Reference whose
      base is `env` and whose name is `name`.
   2. If `env` has an outer environment, set `env` to that environment and
      repeat.
   3. Otherwise, throw a ReferenceError.

Clause 13.3 specifies the environment chain and visibility. `this` and `super`
are keywords and are not resolved by `ResolveBinding`.

**9.3.2** A binding is *mutable* or *immutable* according to its declaration
(Clause 10). A binding is *uninitialized* while its declaration is being
evaluated; this is the temporal dead zone of Clause 13.3. Reading or writing an
uninitialized binding throws a ReferenceError. The temporal dead zone is a
runtime condition, not an early error.

**9.3.3** The abstract operation `GetValue(reference)` produces a value as
follows.

1. If the kind of `reference` is namespace, return the current value of the
   named export of the module namespace object (Clause 12.3). If the export
   does not exist, throw a ReferenceError.
2. If the kind of `reference` is super, return the result of the superclass
   property lookup specified in 9.3.6.
3. If the base of `reference` is an Environment Record:
   1. If the binding is uninitialized, throw a ReferenceError.
   2. Return the value of the binding.
4. If the base of `reference` is an Object, return `GetProperty(base, name)`
   (9.4.6).
5. Assert: this step is unreachable.

**9.3.4** The abstract operation `PutValue(reference, value)` writes a value
as follows.

1. If the kind of `reference` is namespace, throw a TypeError.
2. If the kind of `reference` is super, throw a TypeError.
3. If the base of `reference` is an Environment Record:
   1. If the binding is uninitialized, throw a ReferenceError.
   2. If the binding is immutable, throw a TypeError.
   3. Set the value of the binding to `value`.
   4. Return.
4. If the base of `reference` is an Object, perform `SetProperty(base, name,
   value)` (9.4.7) and return.
5. Assert: this step is unreachable.

**9.3.5** The ThisBinding of an execution context (Clause 13.2) is established
at invocation and captured by arrow functions. It is `null` at module top
level, for an ordinary function or namespace call, and for a native, intrinsic,
or thread function; it is the receiver object for a method, getter, or setter
call; it is the current `this` for `super.m(...)`; it is the new instance for a
constructor invocation; it is the class object for a static method call; and
it is the captured ThisBinding for an arrow function. There is no global-object
substitution; a detached method called as an ordinary function receives
`null`.

**9.3.6** A `super` occurrence uses the *home object* of the running method
(Clause 11.7), the class in whose body the method was declared. An arrow
function captures the home object of its enclosing method.

1. `super(args)` is permitted only in a derived-class constructor. It evaluates
   the arguments, invokes the superclass constructor with the current instance
   as `this`, marks the instance initialized, and evaluates to `null`. A second
   `super(...)` throws a ReferenceError; a throw from the superclass constructor
   propagates.
2. `super.name` is permitted in a derived-class instance method, getter,
   setter, or constructor, and in a static method when the home object has a
   static superclass. It looks up `name` starting at the superclass with the
   current `this` as receiver, ignoring the receiver's own properties, and
   produces a Reference of kind super.
3. `super.name(args)` performs the lookup of item 2, requires a callable
   result, evaluates the arguments left to right, and invokes with the current
   `this`.
4. `super` is not a value. `super[...]`, `super.name = value`, `super` in a
   non-arrow function nested inside a method, and `super` outside a class with
   a superclass are early errors.

## 9.4 Member Access

**9.4.1** Member access has three forms: dot access `object.name`, bracket
access `object[expression]`, and namespace access `namespace::name`. Dot
access requires an Identifier or NumericLiteral; bracket access computes an
arbitrary key; namespace access requires an Identifier and a module namespace
as base. Member access is left-associative and may be followed by further
member accesses or a call.

**9.4.2** Optional chaining is not part of Edition 1.0. The token sequence
`?.` is not a MemberSuffix and does not occur in the grammar. The `?` token is
used only in nullable type annotations (Clause 8). A member access whose base
is `null` throws a TypeError; there is no null-propagation and no boxing.

**9.4.3** The abstract operation `ToPropertyKey(value)` produces a String: if
`value` is a String, return it; if it is a Number, return
`NumberToString(value)` (9.9.7); otherwise throw a TypeError. A Boolean,
`null`, object, array, or tuple is not a property key. `-0` converts to `"0"`,
`NaN` to `"NaN"`, and `Infinity` to `"Infinity"`.

**9.4.4** A String key is a *canonical index* if it is `"0"` or matches
`[1-9][0-9]*` with value at most `2^53 - 1`; its *index value* is the integer
it denotes. `"-0"`, `"-1"`, `"01"`, `"1.0"`, `"1e2"`, and `" 1"` are not
canonical. A key is a *numeric string* if it matches `-?[0-9]+` or
`-?[0-9]+\.[0-9]+`; every canonical index is a numeric string, but not
conversely.

**9.4.5** `EvaluateMemberReference(objectExpression, keyExpression, keyKind)`
produces a Reference as follows.

1. Let `base` be `GetValue` of the result of evaluating `objectExpression`.
2. If `base` is `null`, throw a TypeError.
3. If `keyKind` is dot, let `key` be the literal MemberName: an Identifier
   verbatim, or the canonical decimal String of a NumericLiteral. No key
   expression is evaluated.
4. If `keyKind` is bracket, let `key` be `ToPropertyKey` of `GetValue` of the
   result of evaluating `keyExpression`.
5. If `keyKind` is namespace, require `base` to be a module namespace;
   otherwise throw a TypeError. Let `key` be the Identifier name.
6. Return a Reference with base `base`, name `key`, and kind ordinary for dot
   and bracket, or namespace for `::`.

For `super.name`, the base is the current `this` and the kind is super; the
lookup of 9.3.6 replaces item 6.

**9.4.6** The abstract operation `GetProperty(base, key)` produces a value as
follows. The key is a String.

1. If `base` is `null`, throw a TypeError.
2. If `base` is an ordinary Object, return the own property named `key` if it
   exists; otherwise return `null`.
3. If `base` is an Array or a Tuple:
   1. If `key` is a canonical index within the length, return the element.
   2. If `key` is a canonical index outside the length, throw a RangeError.
   3. If `key` is a numeric string but not a canonical index, throw a
      RangeError.
   4. If `base` is an Array, return the member named `key` from the array
      member table of Clause 18 if it exists; otherwise return `null`. If
      `base` is a Tuple, return `null`.
4. If `base` is a class instance:
   1. If a getter named `key` exists in the class or a superclass, invoke it
      with the instance as receiver and return its result.
   2. If an own field named `key` exists, return its value.
   3. If a method named `key` exists in the class or a superclass, return the
      method value, unbound.
   4. Otherwise, return `null`.
5. If `base` is a Class, look up a static member starting at `base` and
   proceeding through its superclass chain: a static getter is invoked with the
   class as receiver, a static field is returned, and a static method is
   returned unbound. If no member exists, return `null`.
6. If `base` is a Function, return `null`.
7. If `base` is a Buffer, Promise, Thread, Mutex, or Result, return the member
   specified by Clauses 15, 17, or 8; if none exists, return `null`.
8. If `base` is a String, Number, or Boolean, throw a TypeError. Primitives are
   not boxed in Edition 1.0.
9. Assert: this step is unreachable.

A getter may have side effects; it is invoked at the point specified by 9.20. A
missing property is `null`; calling it throws a TypeError. An array or tuple
index at or beyond the length, a negative numeric string, and a fractional
numeric string throw a RangeError; `array[-1]` is not the last element.
Primitives are not indexable in Edition 1.0.

**9.4.7** The abstract operation `SetProperty(base, key, value)` writes a
property as follows.

1. If `base` is `null`, throw a TypeError.
2. If `base` is an ordinary Object, create or update the own property named
   `key` with `value`.
3. If `base` is an Array or a Tuple:
   1. If `key` is a canonical index within the length, update the element.
   2. If `key` is a canonical index outside the length, throw a RangeError.
      Arrays do not grow through assignment.
   3. If `key` is a numeric string, throw a RangeError.
   4. Otherwise, throw a TypeError: arrays and tuples have no writable named
      members, and a tuple length is immutable.
4. If `base` is a class instance:
   1. If a setter named `key` exists in the class or a superclass, invoke it
      with the instance as receiver and `value` as its argument.
   2. Otherwise, if a property named `key` is read-only and the current
      execution context is not the class constructor, throw a TypeError.
   3. Otherwise, if a method named `key` exists and no own field named `key`
      exists, throw a TypeError; methods are not assignable.
   4. Otherwise, create or update the own field named `key`.
5. If `base` is a Class, perform static assignment: invoke a static setter,
   throw a TypeError for a read-only static property or a static method, or
   create or update the static field.
6. If `base` is a Buffer, Promise, Thread, Mutex, or Result, perform the write
   specified by Clauses 15, 17, or 8, or throw a TypeError if the member is not
   writable.
7. If `base` is a String, Number, or Boolean, throw a TypeError.
8. Assert: this step is unreachable.

**9.4.8** Namespace access `namespace::name` is a read-only reference to a
module export. The left operand MUST be a module namespace object
(Clause 12.4); any other value throws a TypeError. The right operand is an
Identifier naming an export; a missing export is a link-time error
(Clause 12.6). `GetValue` returns the current value of the export; exports are
live bindings. Assignment and update through `::` are early errors; computed
access such as `namespace::[expression]` is a syntax error. `::` has the same
precedence and left associativity as `.`: `a::b.c` is `(a::b).c`, and
`a.b::c` is `(a.b)::c`, which requires `a.b` to be a namespace.

## 9.5 Calls

**9.5.1** A CallExpression consists of a LeftHandSideExpression followed by a
parenthesized, comma-separated Arguments list. A trailing comma, a spread
argument, and a named argument are not part of Edition 1.0 (D-12). A call may
be followed by further member accesses or calls.

**9.5.2** A call evaluates as follows.

1. If the callee is `super`, the call is a superclass constructor invocation
   governed by 9.3.6, not an ordinary call.
2. If the callee is a member access or a ParenthesizedExpression that produces
   a Reference, evaluate it to a Reference and let `func` be `GetValue`. Let
   `thisValue` be the base Object of an ordinary Reference, `null` if the base
   is an Environment Record, the current `this` for a super Reference, and
   `null` for a namespace Reference.
3. Otherwise, evaluate the callee expression, apply `GetValue`, and let
   `thisValue` be `null`.
4. If `func` is not callable, throw a TypeError. A Class value is not callable
   by this algorithm.
5. Evaluate the argument expressions from left to right, applying `GetValue`
   to each and appending the value to a new argument list.
6. Invoke `func` with `thisValue` and the argument list as specified in
   Clause 11.
7. Return the result of the invocation.

The callable test in step 4 occurs before argument evaluation, so a
non-callable callee or a throwing callee expression prevents all argument
evaluation. A throwing argument prevents later arguments and the invocation.

**9.5.3** Table 9-2 specifies the receiver for call forms that differ in
syntax.

| Callee form | Receiver |
|-------------|----------|
| `f(...)` | `null` |
| `obj.m(...)` | `obj` |
| `obj[expr](...)` | `obj` |
| `(obj.m)(...)` | `obj` |
| `ns::f(...)` | `null` |
| `super.m(...)` | current `this` |
| `f()(...)` | `null` |
| `let g = obj.m; g(...)` | `null` |

The receiver is determined by the syntax of the callee, not by the value of
the function. A function value does not carry a bound receiver; Clause 18 MAY
provide one.

**9.5.4** Arguments are evaluated left to right, exactly once, and passed by
value. An object argument passes a reference to the same object, so callee
mutations are observable through the caller's binding. No implicit conversion
occurs at the call boundary. There is no spread and no `arguments` object.

**9.5.5** Parameters are partitioned into required parameters, optional
parameters with defaults, and at most one rest parameter. Required parameters
MUST precede optional parameters, and a rest parameter MUST be last; these are
early errors (9.21). Let `n` be the argument count, `r` the required count, and
`p` the non-rest parameter count. Binding proceeds as follows.

1. If `n < r`, throw a TypeError.
2. If there is no rest parameter and `n > p`, throw a TypeError.
3. For each non-rest index `i` from 0 to `p - 1`: if `i < n`, bind the argument
   at index `i`; otherwise evaluate the default expression in the parameter
   environment and bind its value.
4. If there is a rest parameter, bind it to a new Array of the arguments from
   index `p` through `n - 1`, in order; the Array is empty when `n = p`.

Parameter bindings are mutable. Defaults are evaluated at call time, only for
omitted arguments, from left to right. A default may read earlier parameters,
`this`, and outer bindings; reading a later parameter throws a ReferenceError
because it is uninitialized. A default may call functions and may throw.

**9.5.6** Too few required arguments and too many arguments without a rest
parameter are runtime type errors. Argument expressions are evaluated before
the arity check, so their side effects occur even when the call throws. Default
expressions are evaluated only after the arity check succeeds. Missing
arguments are not filled with `null`.

**9.5.7** A method call obtains the function value from the receiver before
evaluating arguments. A getter is invoked at that point; if it returns a
non-callable value, the call throws before any argument is evaluated. The
receiver is the base object even when the method was found on a superclass. A
method value read from an object and called later as an ordinary function
receives `null`.

**9.5.8** A Class value is not callable through the call syntax; `C(...)`
throws a TypeError, and construction requires `new` (9.6). A function value is
not constructible through `new`; `new f(...)` throws a TypeError. Any other
non-callable value throws a TypeError.

**9.5.9** Parameters are positional (D-12). A named argument such as `f(x: 1)`
is not generated by the grammar and is an early error. An implementation MUST
NOT accept a named argument as an extension that changes a positional call.

**9.5.10** A call exceeding the implementation's call-stack limit throws a
`DryadError` of category *runtime* (stack overflow) as specified in Clause 14.
The limit is implementation-defined; the error itself is specified. Tail-call
elimination is permitted only if it preserves observable behaviour, including
the stack trace.

## 9.6 `new` Expressions and Instance Construction

**9.6.1** A NewExpression has the form `new ClassReference Arguments`. The
ClassReference is an Identifier followed by zero or more `.` or `::`
Identifier components. The Arguments list is REQUIRED; `new C` without a
parenthesized argument list is not generated by the grammar and is an early
error. The class reference is resolved as a value; it is not called as a
function.

**9.6.2** A `new` expression evaluates as follows.

1. Resolve the ClassReference to a value `cls` using identifier resolution and
   member access (9.3, 9.4).
2. If `cls` is not a Class value, throw a TypeError.
3. If `cls` is an abstract class or an interface, throw a TypeError.
4. Evaluate the argument expressions from left to right, applying `GetValue`
   to each, and collect the values in a new argument list.
5. Create a new instance of `cls` as specified by Clause 11.4. The instance
   has the fields declared by `cls` and its superclasses, initialized as
   specified in Clause 11.4.
6. If `cls` declares a constructor, invoke it with the instance as `this` and
   the argument list, applying 9.5.5. If it declares no constructor, invoke the
   superclass constructor with no arguments when a superclass exists, and
   otherwise do nothing; a non-empty argument list throws a TypeError.
7. If the constructor throws, the throw propagates and no instance value is
   produced.
8. Return the instance.

Allocation occurs after argument evaluation. The constructor's return value is
discarded; the result of `new` is always the newly created instance, never a
value returned by the constructor.

**9.6.3** Only a Class value is constructible. A function, ordinary object,
array, tuple, primitive, or `null` throws a TypeError as the target of `new`.
An interface is not constructible; an abstract class is not constructible even
if it declares a constructor. A built-in class of Clause 18 is constructible
only if its specification says so.

**9.6.4** The instance is created before the constructor body runs. Field
initializers are evaluated in the order of Clause 11.4 with `this` bound to the
instance; a field without an initializer is `null`. The instance is observable
through `this` during construction.

**9.6.5** A derived-class constructor MUST call `super(...)` before reading or
writing `this`, passing `this`, or returning normally. Returning without
`super(...)`, or calling it twice, throws a ReferenceError. `super(...)` invokes
the superclass constructor on the same instance and evaluates to `null`.
Clause 11.7 specifies derived construction further.

**9.6.6** Table 9-3 distinguishes function calls from constructor calls.

| Operation | Function value | Class value |
|-----------|----------------|-------------|
| `value(...)` | call, `this` is `null` | TypeError |
| `new value(...)` | TypeError | construct, `this` is the new instance |

## 9.7 Unary Operators and Update Expressions

**9.7.1** The unary operators are `!`, `+`, `-`, and `~`; the update operators
are prefix `++`, prefix `--`, postfix `++`, and postfix `--`. `await` is a
unary operator specified in 9.18. Unary operators are right-associative:
`!-x` is `!(-x)`. Updates bind more tightly than every binary operator except
member access and calls (9.1.5).

**9.7.2** The abstract operation `ToNumeric(value)` produces a Number: if
`value` is a Number, return it; if it is `true`, return `1`; if it is `false`,
return `+0`; otherwise throw a TypeError.

`ToNumeric` is the only implicit conversion to Number in Edition 1.0. Strings,
`null`, objects, arrays, tuples, functions, and classes are never converted.
It is used by unary `+` and `-`, by `++` and `--`, by the arithmetic operators
of 9.8 and 9.9, by the relational and shift operators of 9.10, and by the
bitwise operators of 9.11.

**9.7.3** A unary `!` expression evaluates as follows.

1. Evaluate the operand and apply `GetValue`.
2. Let `b` be `ToBoolean` of the value (Clause 8.8).
3. Return the Boolean value `true` if `b` is `false`, and `false` otherwise.

The result is always a Boolean. The operand is evaluated exactly once.

**9.7.4** A unary `+` expression evaluates as follows.

1. Evaluate the operand and apply `GetValue`.
2. Return `ToNumeric` of the value.

The result is a Number. `+true` is `1`, `+false` is `+0`, and `+"1"` throws a
TypeError. Unary `+` performs no string parsing.

**9.7.5** A unary `-` expression evaluates as follows.

1. Evaluate the operand and apply `GetValue`.
2. Let `n` be `ToNumeric` of the value.
3. Return the IEEE 754 negation of `n`: the sign bit is inverted, `NaN`
   remains `NaN`, `+0` becomes `-0`, and `-0` becomes `+0`.

The sign bit of a `NaN` result is not observable through any expression form
of Edition 1.0. `-true` is `-1`; `-null` throws a TypeError.

**9.7.6** A unary `~` expression evaluates as follows.

1. Evaluate the operand and apply `GetValue`.
2. Let `n` be `ToInt32` of the value (9.11.2).
3. Return the Number whose value is the bitwise complement of `n` in 32-bit
   two's-complement representation.

`~0` is `-1`, `~5` is `-6`, `~-1` is `0`, and `~NaN` is `-1`.

**9.7.7** A prefix `++` expression evaluates as follows.

1. Evaluate the operand as a Reference; if it does not produce a Reference,
   the program is ill-formed (9.21).
2. Let `old` be `ToNumeric` of `GetValue` of the Reference.
3. Let `new` be the IEEE 754 binary64 sum of `old` and `1`.
4. Perform `PutValue` of the Reference with `new`, and return `new`.

`++` performs numeric addition only; it never concatenates strings (D-01). The
operand is evaluated as a Reference once, including its base and key
expressions. If the binding is immutable, `PutValue` throws a TypeError after
`new` is computed.

**9.7.8** A prefix `--` expression follows the algorithm of 9.7.7 with
subtraction of `1` in step 3.

**9.7.9** A postfix `++` expression evaluates as follows.

1. Evaluate the operand as a Reference.
2. Let `old` be `ToNumeric` of `GetValue` of the Reference.
3. Let `new` be the sum of `old` and `1`.
4. Perform `PutValue` of the Reference with `new`, and return `old`.

The returned value is the numeric value obtained in step 2, not the original
value before conversion: if `b` is `true`, `b++` writes `2` and returns `1`. A
postfix `--` is identical with subtraction of `1`.

**9.7.10** The operand of an update MUST be a mutable binding or writable
property. A literal, call result, parenthesized expression, `this`, `super`,
and a namespace Reference are early errors. An immutable binding, read-only
property, method without a setter, and out-of-bounds index throw at `PutValue`
(9.4.7). Getters and setters are invoked once each; the postfix conversion
precedes the write.

**9.7.11** The `typeof` operator is not part of Edition 1.0; `typeof x` is a
syntax error. Whether the token is reserved as an identifier is specified by
Clause 7.6. No expression form provides dynamic type inspection; such
inspection, if available, is provided by Clause 17.

**9.7.12** The `delete` operator is not part of Edition 1.0. `delete` is a
contextual keyword accepted only as a class member name (Clause 11.6);
`delete obj.x` is a syntax error, and no expression removes a property.

## 9.8 Exponentiation

**9.8.1** The exponentiation operator is `**`. It is right-associative:
`a ** b ** c` is `a ** (b ** c)`. Both operands are converted with
`ToNumeric`; the result is a Number. Exponentiation is numeric only; a String
operand throws a TypeError.

**9.8.2** Unary operators bind more tightly than `**` in the grammar of 9.1.5.
Consequently, `-2 ** 2` is `(-2) ** 2`, which evaluates to `4`, and
`-(2 ** 2)` evaluates to `-4`. The expression `2 ** -1` is well-formed and
evaluates to `0.5` because the right operand of `**` may be a unary expression.
`await p ** 2` is `(await p) ** 2`.

**9.8.3** An exponentiation expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `base` be `ToNumeric` of the left value.
3. Let `exponent` be `ToNumeric` of the right value.
4. Return the result of the IEEE 754 `pow` operation on `base` and `exponent`,
   with the special cases of 9.8.4.

The left operand is evaluated before the right operand. If either evaluation
throws, the other operand is not evaluated.

**9.8.4** Table 9-4 specifies the special cases of `**`. In the table, *odd
integer* means an integer whose magnitude is odd, and *non-odd* means any
other real exponent.

| Base | Exponent | Result |
|------|----------|--------|
| any value, including `NaN` | `+0` or `-0` | `1` |
| `1` | any value, including `NaN` | `1` |
| `-1` | `+Infinity` or `-Infinity` | `1` |
| `NaN` | any nonzero value | `NaN` |
| `+0` | positive odd integer | `+0` |
| `-0` | positive odd integer | `-0` |
| `+0` | positive non-odd | `+0` |
| `-0` | positive non-odd | `+0` |
| `+0` | negative odd integer | `+Infinity` |
| `-0` | negative odd integer | `-Infinity` |
| `+0` | negative non-odd | `+Infinity` |
| `-0` | negative non-odd | `+Infinity` |
| negative finite | non-integer | `NaN` |
| `abs(base) < 1` | `-Infinity` | `+Infinity` |
| `abs(base) > 1` | `-Infinity` | `+0` |
| `abs(base) < 1` | `+Infinity` | `+0` |
| `abs(base) > 1` | `+Infinity` | `+Infinity` |
| finite nonzero | finite | finite result, `+Infinity` on overflow, `+0` or `-0` on underflow |

**9.8.5** `0 ** -1` evaluates to `+Infinity`; it is not a division-by-zero
error. `(-0) ** -1` evaluates to `-Infinity`. `0 ** 0` and `NaN ** 0` evaluate
to `1`. `(-2) ** 0.5` evaluates to `NaN`. Overflow produces `Infinity` with
the sign determined by the sign of the base and the parity of an integer
exponent. Underflow produces a signed zero. A `NaN` result propagates through
subsequent arithmetic as specified in 9.9.10.

**9.8.6** The compound assignment `**=` applies the algorithm of this
subclause to the old value of the target and the right-hand value, then writes
the result (9.14.4).

## 9.9 Multiplicative and Additive Operators

**9.9.1** The multiplicative operators are `*`, `/`, and `%`, left-associative
and higher than additive. The additive operators are `+` and `-`,
left-associative and higher than shift. All operands are evaluated left to
right.

**9.9.2** The operands of `*`, `/`, `%`, and `-` are converted with
`ToNumeric` (9.7.2); a String, `null`, object, array, tuple, function, or class
throws a TypeError, and Booleans convert to `1` or `+0`. The operand of `+`
follows the string rule of 9.9.8.

**9.9.3** A multiplication expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
3. Return the IEEE 754 binary64 product of `l` and `r`, rounded to nearest
   with ties to even.

The product is `NaN` if either operand is `NaN`. The product of an infinity
and a zero is `NaN`. The sign of a zero or infinite result is negative if and
only if exactly one operand is negative. `-0 * 3` is `-0`; `-0 * -3` is `+0`.

**9.9.4** A division expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
3. If `r` is `+0` or `-0`, throw a `DryadError` of category *runtime* with
   the division-by-zero diagnostic of Clause 14.
4. If `l` or `r` is `NaN`, return `NaN`.
5. If `l` and `r` are both infinite, return `NaN`.
6. If `l` is infinite, return `+Infinity` or `-Infinity` according to the
   sign rule.
7. If `r` is infinite, return `+0` or `-0` according to the sign rule.
8. Return the IEEE 754 binary64 quotient of `l` by `r`, rounded to nearest
   with ties to even.

Division by zero is an error even when the dividend is `NaN`, `Infinity`, or
`-0`; the check in step 3 precedes the `NaN` check in step 4. A finite nonzero
result is negative if and only if exactly one operand is negative; a zero
result follows the same sign rule.

**9.9.5** A modulo expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
3. If `r` is `+0` or `-0`, throw a `DryadError` of category *runtime* with
   the modulo-by-zero diagnostic of Clause 14.
4. If `l` or `r` is `NaN`, return `NaN`.
5. If `l` is infinite, return `NaN`.
6. If `r` is infinite, return `l`.
7. If `l` is `+0` or `-0`, return `l`.
8. Return the exact floating-point remainder `fmod(l, r)`, which has the sign
   of `l` and magnitude less than `abs(r)`; it equals `l - r * trunc(l / r)`
   when the quotient is finite.

The operation is the floating-point remainder with the sign of the dividend:
`-5 % 2` is `-1`, `5 % -2` is `1`, `-0 % 3` is `-0`, and `0 % -3` is `+0`.
Modulo by zero is an error even when the dividend is `NaN` or infinite.

**9.9.6** The abstract operation `ToString(value)` produces a String as
specified in Table 9-5.

| Type of value | Result |
|---------------|--------|
| String | the value itself |
| Number | `NumberToString(value)` (9.9.7) |
| Boolean | `"true"` or `"false"` |
| Null | `"null"` |
| Array | `"[Array]"` |
| Tuple | `"[Tuple]"` |
| Object | `"[Object]"` |
| Function | `"[Function]"` |
| Class | `"[Class "` followed by the class name and `"]"` |
| Instance | `"[Instance of "` followed by the class name and `"]"` |
| Result | `"Ok("` followed by `ToString` of the payload and `")"`, or `"Err("` followed by `ToString` of the error and `")"` |
| Any other object | `"[Object]"` |

`ToString` is total. The bracketed forms are canonical placeholders; structural
formatting is provided by Clause 18. An unavailable class or instance name
uses `"[Class]"` or `"[Instance]"`.

**9.9.7** The abstract operation `NumberToString(x)` produces a String as
follows.

1. If `x` is `NaN`, return `"NaN"`.
2. If `x` is `+0` or `-0`, return `"0"`.
3. If `x` is `+Infinity`, return `"Infinity"`; if `x` is `-Infinity`, return
   `"-Infinity"`.
4. If `x` is negative, return `"-"` concatenated with `NumberToString(-x)`.
5. Let `n`, `k`, and `s` be integers such that `k >= 1`,
   `10^(k-1) <= s < 10^k`, `s * 10^(n-k) = x`, and `k` is as small as
   possible. If more than one `s` satisfies these conditions, choose the one
   for which `s * 10^(n-k)` is closest to `x`; if two are equally close,
   choose the one with an even least significant digit.
6. Let `digits` be the decimal representation of `s`.
7. If `k <= n <= 21`, return `digits` followed by `n - k` zeros.
8. If `0 < n <= 21`, return the first `n` digits of `digits`, followed by
   `"."`, followed by the remaining digits.
9. If `-6 < n <= 0`, return `"0."`, followed by `-n` zeros, followed by
   `digits`.
10. If `k = 1`, return the first digit of `digits`, followed by `"e"`,
    followed by `"+"` if `n - 1` is non-negative and `"-"` otherwise, followed
    by the decimal representation of `abs(n - 1)`.
11. Otherwise, return the first digit of `digits`, followed by `"."`, followed
    by the remaining digits, followed by `"e"`, followed by the sign of
    `n - 1`, followed by the decimal representation of `abs(n - 1)`.

The algorithm produces the shortest decimal representation that round-trips to
the same binary64 value, using fixed notation for exponents in `[-6, 21)` and
exponential notation otherwise, with no leading zeros except one before a
decimal point. `1` produces `"1"`, `1e21` produces `"1e+21"`, and `-0`
produces `"0"`. An implementation MUST NOT use fixed precision or a
locale-dependent decimal separator.

**9.9.8** An addition expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. If either the left value or the right value is a String:
   1. Let `l` be `ToString` of the left value.
   2. Let `r` be `ToString` of the right value.
   3. Return the concatenation of `l` and `r` in that order.
3. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
4. Return the IEEE 754 binary64 sum of `l` and `r`, rounded to nearest with
   ties to even.

The string test precedes numeric conversion: if either operand is a String,
concatenation occurs even if the other is a Number, Boolean, `null`, or object.
Otherwise both MUST be numeric; `null + 1`, `[1] + 1`, and `{} + 1` throw.
`true + 5` is `6`; `1 + "2"` is `"12"`; `null + "x"` is `"nullx"`.

**9.9.9** A subtraction expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
3. Return the IEEE 754 binary64 difference `l - r`, rounded to nearest with
   ties to even.

The result is `NaN` if either operand is `NaN`. `+0 - +0` is `+0`;
`-0 - +0` is `-0`; `+0 - -0` is `+0`; `-0 - -0` is `+0`. Subtraction never
performs string operations.

**9.9.10** The following propagation rules apply to all arithmetic operators of
this subclause.

1. If an operand is `NaN`, the result is `NaN`, except where 9.9.4 or 9.9.5
   specifies an error or a special case.
2. Overflow produces `Infinity` or `-Infinity`; underflow produces `+0` or
   `-0`. Neither is an error.
3. `Infinity + Infinity` is `Infinity`, `Infinity - Infinity` is `NaN`,
   `Infinity * 0` is `NaN`, and `Infinity / Infinity` is `NaN`.
4. Division by zero and modulo by zero are errors and do not produce
   infinities or `NaN`.

## 9.10 Shift, Relational, and Equality Operators

**9.10.1** The shift operators are `<<`, `>>`, and `>>>`, left-associative
and lower than additive. The relational operators are `<`, `<=`, `>`, and
`>=`, left-associative and lower than shift. The equality operators are `==`
and `!=`, left-associative and lower than relational. `<<<`, `===`, and `!==`
are not part of Edition 1.0.

**9.10.2** Shift operands are converted with `ToNumeric`, `ToInt32`, and
`ToUint32` (9.11.2, 9.11.3). A String, `null`, object, array, tuple, function,
or class operand throws a TypeError; Booleans convert to `1` or `+0`.

**9.10.3** A left-shift expression `left << right` evaluates as follows.

1. Evaluate `left`, then `right`, applying `GetValue` to each.
2. Let `l` be `ToInt32` of the left value.
3. Let `r` be `ToUint32` of the right value.
4. Let `shift` be `r mod 32`, the integer in `[0, 31]` congruent to `r` modulo
   `32`.
5. Let `result` be the 32-bit two's-complement value obtained by shifting the
   32-bit representation of `l` left by `shift` bits, discarding bits shifted
   out and filling with zero bits.
6. Return the Number whose value is `result` interpreted as a signed 32-bit
   integer.

The shift count is taken modulo 32. `1 << 32` is `1`; `1 << 31` is
`-2147483648`.

**9.10.4** A right-shift expression `left >> right` evaluates as follows.

1. Evaluate `left`, then `right`, applying `GetValue` to each.
2. Let `l` be `ToInt32` of the left value.
3. Let `r` be `ToUint32` of the right value.
4. Let `shift` be `r mod 32`.
5. Let `result` be the 32-bit two's-complement value obtained by shifting the
   32-bit representation of `l` right by `shift` bits, filling the vacated
   high-order bits with copies of the sign bit.
6. Return the Number whose value is `result` interpreted as a signed 32-bit
   integer.

`-1 >> 1` is `-1`; `-8 >> 1` is `-4`.

**9.10.5** An unsigned right-shift expression `left >>> right` evaluates as
follows.

1. Evaluate `left`, then `right`, applying `GetValue` to each.
2. Let `l` be `ToUint32` of the left value.
3. Let `r` be `ToUint32` of the right value.
4. Let `shift` be `r mod 32`.
5. Let `result` be the 32-bit value obtained by shifting the 32-bit
   representation of `l` right by `shift` bits, filling the vacated high-order
   bits with zero bits.
6. Return the Number whose value is `result` interpreted as an unsigned
   32-bit integer in `[0, 4294967295]`.

`-1 >>> 0` is `4294967295`; `-8 >>> 1` is `2147483644`.

**9.10.6** A relational expression evaluates as follows.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` be `ToNumeric` of the left value and `r` be `ToNumeric` of the
   right value.
3. If `l` or `r` is `NaN`, return `false` for `<`, `<=`, `>`, and `>=`.
4. Return the Boolean result of the corresponding IEEE 754 comparison of `l`
   and `r`.

Relational operands MUST be numeric after `ToNumeric`. A String operand throws
a TypeError; lexicographic comparison is not performed by these operators.
`-0 < +0` is `false`; `-0 <= +0` is `true`; `+Infinity > x` is `true` for every
finite `x`. Relational operators are left-associative, so `a < b < c` is
`(a < b) < c`, which is not mathematical chaining.

**NOTE** The expression `3 > 2 > 1` is `(3 > 2) > 1`, which is `true > 1`,
which is `1 > 1`, and therefore `false`. Parentheses are RECOMMENDED for a
chain of comparisons.

**9.10.7** An equality expression evaluates as follows. The algorithm is the
complete equality algorithm of D-08.

1. Evaluate the left operand, then the right operand, applying `GetValue` to
   each.
2. Let `l` and `r` be the resulting values.
3. If the dynamic type of `l` differs from the dynamic type of `r`, return
   `false`.
4. If `l` is `null`, return `true`.
5. If `l` is a Boolean, return `true` if `l` and `r` are the same Boolean
   value, and `false` otherwise.
6. If `l` is a Number:
   1. If `l` or `r` is `NaN`, return `false`.
   2. Return `true` if the IEEE 754 numeric values of `l` and `r` are equal,
      and `false` otherwise. In particular, `+0` equals `-0`, and each
      infinity equals itself.
7. If `l` is a String, return `true` if `l` and `r` consist of the same
   sequence of Unicode scalar values, and `false` otherwise.
8. Otherwise, `l` and `r` are object values (including arrays, tuples,
   functions, classes, instances, buffers, promises, threads, mutexes, and
   Results). Return `true` if `l` and `r` are the same object, and `false`
   otherwise.
9. Assert: this step is unreachable.

**9.10.8** An inequality expression `left != right` evaluates the operands
once each, applies the equality algorithm of 9.10.7, and returns the Boolean
negation of its result. `NaN != NaN` is `true`.

**9.10.9** Equality never coerces. `0 == false` is `false`; `"0" == 0` is
`false`; `null == 0` is `false`; `null == false` is `false`; `[] == []` is
`false`; `let a = []; a == a` is `true`. Equality never invokes user code. A
`Result` value compares by identity, so `Ok(1) == Ok(1)` is `false` unless the
two expressions denote the same object.

## 9.11 Bitwise Operators

**9.11.1** The bitwise operators are `&` (AND), `|` (OR), `^` (XOR), and `~`
(complement). The shift operators of 9.10 use the conversions of this
subclause. The bitwise binary operators are left-associative, with `&` binding
more tightly than `^`, and `^` binding more tightly than `|`. All bitwise
operands are converted with `ToNumeric` and then to 32-bit integers; the
result is always a Number whose value is an exact 32-bit integer.

**9.11.2** The abstract operation `ToInt32(value)` produces a signed 32-bit
integer as follows.

1. Let `n` be `ToNumeric` of `value`.
2. If `n` is `NaN`, `+0`, `-0`, `+Infinity`, or `-Infinity`, return `0`.
3. Let `t` be `trunc(n)`, the integer part of `n` toward zero.
4. Let `m` be the unique integer in `[0, 2^32)` that is congruent to `t`
   modulo `2^32`.
5. If `m >= 2^31`, return `m - 2^32`; otherwise return `m`.

Step 4 is mathematical modulo, not the C remainder operation. For a negative
`t`, the implementation adds `2^32` until the result is non-negative.

**9.11.3** The abstract operation `ToUint32(value)` produces an unsigned
32-bit integer as follows.

1. Let `n` be `ToNumeric` of `value`.
2. If `n` is `NaN`, `+0`, `-0`, `+Infinity`, or `-Infinity`, return `0`.
3. Let `t` be `trunc(n)`.
4. Return the unique integer in `[0, 2^32)` that is congruent to `t` modulo
   `2^32`.

**9.11.4** A bitwise AND expression evaluates both operands left to right,
applies `ToInt32` to each, and returns the Number whose value is the bitwise
AND of the two 32-bit two's-complement representations, interpreted as a
signed 32-bit integer. `-1 & 0xFF` is `255`; `5 & 3` is `1`; `NaN & 0` is `0`.

**9.11.5** A bitwise OR expression follows 9.11.4 with bitwise OR in place of
AND. `5 | 2` is `7`.

**9.11.6** A bitwise XOR expression follows 9.11.4 with bitwise exclusive OR
in place of AND. `5 ^ 1` is `4`.

**9.11.7** A bitwise complement expression `~value` evaluates the operand,
applies `ToInt32` to the result, and returns the Number whose value is the
bitwise complement of the 32-bit representation, interpreted as a signed
32-bit integer. `~0` is `-1`; `~5` is `-6`; `~-1` is `0`.

**9.11.8** The shift operators `<<`, `>>`, and `>>>` use `ToInt32` and
`ToUint32` as specified in 9.10.3 through 9.10.5. The result of a shift is a
Number whose value is an exact 32-bit integer. The result of `>>>` is always
in `[0, 4294967295]`; the results of `<<` and `>>` are signed.

**9.11.9** Edition 1.0 provides 32-bit bitwise operations only. There is no
64-bit bitwise operation, no arbitrary-precision integer, and no unsigned
arithmetic type at the language level. Bitwise results are Numbers, not a
distinct integer type (D-14). The exactness of a 32-bit result in binary64 is
guaranteed because every integer in `[-2^31, 2^32)` is exactly representable.

## 9.12 Logical Operators

**9.12.1** The logical operators are `&&`, `||`, and `!`. `&&` has higher
precedence than `||`; both are left-associative. `!` is a unary operator with
the precedence specified in 9.7. `&&` and `||` short-circuit and return one of
their operands (D-07). They do not convert their result to a Boolean.

**9.12.2** `ToBoolean` is defined in Clause 8.8. For Edition 1.0, the falsy
values are `false`, `null`, `+0`, `-0`, `NaN`, and the empty String. All other
values are truthy. In particular, an empty Array, an empty ordinary Object, a
function, a class, and an instance are truthy. Truthiness is not affected by
the contents of a collection.

**9.12.3** A logical AND expression `left && right` evaluates as follows.

1. Evaluate `left` and apply `GetValue`.
2. Let `l` be the resulting value.
3. If `ToBoolean(l)` is `false`, return `l` without evaluating `right`.
4. Otherwise evaluate `right`, apply `GetValue`, and return the resulting
   value.

The result is `l` when `l` is falsy, and the value of `right` otherwise. The
result can be of any type.

**9.12.4** A logical OR expression `left || right` evaluates as follows.

1. Evaluate `left` and apply `GetValue`.
2. Let `l` be the resulting value.
3. If `ToBoolean(l)` is `true`, return `l` without evaluating `right`.
4. Otherwise evaluate `right`, apply `GetValue`, and return the resulting
   value.

The result is `l` when `l` is truthy, and the value of `right` otherwise.

**9.12.5** A logical NOT expression `!value` evaluates the operand, applies
`ToBoolean` (Clause 8.8), and returns `true` if the result is `false`, and
`false` otherwise. The result is always a Boolean. The idiom `!!value` applies
`!` twice and produces the Boolean conversion of `value`.

**9.12.6** Because `&&` and `||` return operands, they can propagate non-Boolean
values. `0 || "default"` is `"default"`; `"" && f()` is `""` and does not
invoke `f`; `null || 0` is `0`; `1 && 2` is `2`. A program that requires a
Boolean uses `!` or a comparison.

**9.12.7** The nullish coalescing operator `??` is not part of Edition 1.0. The
compound logical assignments `&&=` and `||=` are not part of Edition 1.0.
Their token sequences do not occur in the grammar. Nullish selection is
expressed with an explicit comparison or a conditional statement, not with
`??`.

## 9.13 Conditional Operator

**9.13.1** The conditional operator `?:` is not part of Edition 1.0. The
grammar and Clause 22 contain no such production. A program that uses it is
not well-formed and the implementation MUST report a syntax error.

**9.13.2** The `?` token is used in Edition 1.0 only in nullable type
annotations, where `T?` denotes `T | Null` (Clause 8). It is not an expression
operator and does not begin a conditional expression.

**9.13.3** A future edition MAY introduce `?:`. Edition 1.0 programs MUST NOT
rely on it, and an implementation MUST NOT accept it as an extension that
changes the meaning of a well-formed program.

## 9.14 Assignment and Compound Assignment

**9.14.1** The assignment operators are `=`, `+=`, `-=`, `*=`, `/=`, `%=`,
`**=`, `<<=`, `>>=`, `>>>=`, `&=`, `^=`, and `|=`. Assignment is
right-associative: `a = b = c` is `a = (b = c)`. An assignment expression
evaluates to a value and can be used wherever a value is required.

**9.14.2** The left operand of an assignment MUST be an Identifier or a member
access. The following are early errors: a literal, a call result, a
ParenthesizedExpression, `this`, `super`, and a namespace Reference. The left
operand is evaluated as a Reference, not as a value. The base and key
expressions of a member access are evaluated exactly once, before the
right-hand side.

**9.14.3** A simple assignment `target = value` evaluates as follows.

1. Evaluate `target` as a Reference.
   - For an Identifier, apply `ResolveBinding`. If the identifier is
     unresolved, throw a ReferenceError.
   - For a member access, apply `EvaluateMemberReference` (9.4.5). If the base
     is `null`, throw a TypeError before evaluating the right-hand side.
2. Evaluate the right-hand side and apply `GetValue`.
3. Perform `PutValue` of the Reference with the value.
4. Return the value obtained in step 2.

The value returned is the right-hand value, not a re-read of the target.

**9.14.4** A compound assignment `target op= value` evaluates as follows.
The operator `op` is the binary operator named by Table 9-6.

1. Evaluate `target` as a Reference, as in 9.14.3 step 1.
2. Let `old` be `GetValue` of the Reference.
3. Evaluate the right-hand side and apply `GetValue`; let `rhs` be the result.
4. Let `result` be the value produced by applying the binary operation `op` to
   `old` and `rhs`, using the algorithm referenced by Table 9-6.
5. Perform `PutValue` of the Reference with `result`.
6. Return `result`.

The old value is read before the right-hand side is evaluated. The base and
key expressions of the target are not re-evaluated for the read or the write.
If the read throws, the right-hand side is not evaluated. If the binary
operation throws, no write occurs.

**9.14.5** Table 9-6 maps each compound assignment operator to its binary
operation.

| Operator | Operation | Clause |
|----------|-----------|--------|
| `+=` | `+` (numeric addition or string concatenation) | 9.9.8 |
| `-=` | `-` | 9.9.9 |
| `*=` | `*` | 9.9.3 |
| `/=` | `/` | 9.9.4 |
| `%=` | `%` | 9.9.5 |
| `**=` | `**` | 9.8.3 |
| `<<=` | `<<` | 9.10.3 |
| `>>=` | `>>` | 9.10.4 |
| `>>>=` | `>>>` | 9.10.5 |
| `&=` | `&` | 9.11.4 |
| `^=` | `^` | 9.11.6 |
| `|=` | `|` | 9.11.5 |

**9.14.6** The order is: target Reference; for a compound, the old value; the
right-hand side; the operation; the write. The target Reference is evaluated
once. In `a[f()] += g()`, `a` and `f` are evaluated once, the element is read
once, `g` once, and the element written once.

**9.14.7** Assignment to an immutable binding throws a TypeError at
`PutValue`; the right-hand side is evaluated first, so its side effects occur.
A `const` binding is immutable, but the contents of an object or array it
references remain mutable. Assignment to an uninitialized binding throws a
ReferenceError. These are runtime errors.

**9.14.8** Assignment to a member follows `SetProperty` (9.4.7). A getter-only
property, a read-only class property outside its constructor, a method without
a setter, an out-of-bounds index, and a primitive write throw. A setter is
invoked once. An ordinary object property is created if absent; an instance
field is created if absent and does not shadow a method. The assignment returns
the value written; a setter's return is ignored.

**9.14.9** The value of an assignment is the value written, not a Reference.
Thus `a = b = c` is well-formed, but `(a = b) = c` is an early error because
the parenthesized assignment produces a value.

**9.14.10** Destructuring assignment and destructuring declarations are not
part of Edition 1.0. An array or tuple literal on the left of `=` is an early
error. Binding patterns, rest properties, and spread elements do not occur in
the grammar of 9.1.5.

## 9.15 Sequence Expression

**9.15.1** The comma operator is not part of Edition 1.0. A comma is a list
separator in arguments, array literals, object literals, tuple literals,
parameter lists, and match arms; it is not an expression operator. The grammar
has no production `<Expression> "," <Expression>`.

**9.15.2** The form `(a, b)` is a TupleLiteral (9.2.10), not a sequence
expression: it evaluates both expressions and produces a Tuple, rather than
discarding the first value. Sequential evaluation uses two statements in a
block (Clause 10).

**9.15.3** The `void` operator is not part of Edition 1.0. No expression form
discards a value and evaluates to `null`.

**9.15.4** A future edition MAY introduce a comma operator. Edition 1.0
programs MUST NOT rely on it, and an implementation MUST NOT accept a comma
expression as an extension.

## 9.16 `match` Expressions

**9.16.1** A `match` expression selects one of several result expressions by
testing patterns against a scrutinee. It is an expression (D-13) and can appear
wherever an expression is permitted. Every match has exactly one default arm.

**9.16.2** The productions for MatchExpression, MatchArm, Pattern, and
LiteralPattern in 9.1.5 define the syntax. Arms are separated by commas; the
empty form `match e { }` and a trailing comma after the final arm are syntax
errors. The result of an arm is an AssignmentExpression, not a Block.

**9.16.3** The scrutinee is evaluated exactly once, before any pattern is
tested, and its value is used for every arm. Its side effects occur once and
before any guard or result expression.

**9.16.4** Edition 1.0 provides literal patterns, the wildcard pattern `_`, and
binding patterns consisting of an Identifier. `_` is a wildcard only in
pattern position; elsewhere it is an ordinary Identifier. There are no object,
array, tuple, constructor, range, or or-patterns. An Identifier in pattern
position is a binding, not a reference to a constant.

**9.16.5** A literal pattern matches by the equality algorithm of 9.10.7. A
numeric pattern matches a Number with the same IEEE 754 value; `-0` matches
`0`, and `NaN` matches no numeric pattern. A String pattern matches the same
code-point sequence, a Boolean pattern the same Boolean, and `null` only
`null`. A literal pattern never invokes user code and never coerces.

**9.16.6** The wildcard pattern `_` matches every value and binds no name. A
wildcard arm without a guard is irrefutable, so every arm after it is
unreachable. A guarded wildcard is refutable by its guard and does not by
itself satisfy the default requirement.

**9.16.7** A binding pattern is an Identifier other than `_`. It matches every
value and binds the scrutinee to that Identifier in the environment of its
arm. The binding is immutable and is visible only in the guard and result of
that arm. Because an unguarded binding pattern is irrefutable and the required
default arm MUST be `_` and MUST be last, a binding pattern MUST have a guard;
a binding pattern without a guard is an early error.

**9.16.8** A guard is introduced by `if`, followed by an expression and then
`=>`. It is evaluated in the arm environment after the pattern matches and its
bindings are created. `ToBoolean` is applied (Clause 8.8). A falsy guard means
the arm does not match and testing continues; a throwing guard propagates. A
guard may read the arm binding, outer bindings, and `this`. The `if` form is
used because a second `=>` would be ambiguous with an arrow function result.

**9.16.9** Arms are tested in source order. The first arm whose pattern matches
and whose guard, if present, is truthy is selected; no later arm is tested.
The result of the selected arm is evaluated exactly once in its arm
environment, and its value is the value of the match. There is no fallthrough.

**9.16.10** A `match` MUST contain a default arm with pattern `_`, no guard,
and last position (D-13). The default matches every value that reaches it, so
every well-formed match is exhaustive and the algorithm never falls off the
end. A match whose last arm is not `_`, whose `_` arm has a guard, or which has
an arm after `_` is an early error.

**9.16.11** Exhaustiveness is structural, not type-based: the required
unguarded default arm covers every value of every type, so no coverage proof or
warning is required for literal patterns. An arm unreachable because an
earlier unguarded irrefutable pattern matches every value is an early error
(9.21).

**9.16.12** A `match` expression evaluates as follows.

1. Evaluate the scrutinee and apply `GetValue`; let `v` be the result.
2. For each arm in source order:
   1. For a literal pattern, compare `v` with the literal using 9.10.7; if
      `false`, continue.
   2. For `_`, the pattern matches.
   3. For a binding Identifier, create an immutable binding of that Identifier
      to `v` in a new arm environment and match.
   4. If the arm has a guard, evaluate it in the arm environment and apply
      `ToBoolean`; if `false`, discard the environment and continue.
   5. Evaluate the result expression in the arm environment and return its
      value.
3. Assert: this step is unreachable for a well-formed match.

**9.16.13** The following program is well-formed and illustrates literal
patterns, binding patterns, and guards:

```dryad
function classify(value: number): string {
    return match value {
        0 => "zero",
        n if n < 0 => "negative",
        n if n < 10 => "small",
        _ => "large"
    };
}

print(classify(0));  // zero
print(classify(-4)); // negative
print(classify(7));  // small
print(classify(42)); // large
```

## 9.17 Template Literals

**9.17.1** A TemplateLiteral is delimited by backticks and may contain
literal text and interpolation substitutions of the form `${ expression }`.
The lexical structure of the template, including its opening and closing
delimiters and its escape sequences, is specified in Clause 7. The production
in 9.1.5 describes the substitution structure and is normative for parsing;
Clause 7 is normative for tokenization.

**9.17.2** A template literal evaluates as follows.

1. Let `parts` be an empty list of Strings.
2. Process the template from left to right:
   1. For a literal segment, append its cooked character sequence to `parts`.
   2. For a substitution `${ expression }`, evaluate the expression, apply
      `GetValue`, apply `ToString` (9.9.6), and append the resulting String to
      `parts`.
3. Return the concatenation of the elements of `parts` in order.

Substitutions are evaluated from left to right, exactly once. If a
substitution throws, later substitutions are not evaluated and the template
expression throws. `ToString` is applied to the substitution value, not to a
Reference; object and array values use the canonical forms of 9.9.6.

**9.17.3** Template escapes include `\\` for a backslash, `` \` `` for a
backtick, `\$` for a dollar sign, `\n` for a line feed, `\r` for a carriage
return, and `\t` for a tab; Clause 7 specifies the complete table. An escape
not defined by Clause 7 is an early error. A dollar sign not followed by `{`
is literal. To include `${` as literal text, the dollar sign is escaped as
`\${`. A `}` outside a substitution is literal.

**9.17.4** A substitution may contain nested expressions, object literals,
calls, and template literals. It ends at the matching `}` for its opening
`${`, accounting for nested braces, parentheses, brackets, strings, templates,
and comments. An empty substitution `${}` is an early error. A template with
no substitutions evaluates to its cooked literal text.

**9.17.5** Tagged templates, raw strings, and custom interpolation hooks are
not part of Edition 1.0. A template literal always evaluates by 9.17.2 and
always produces a String. A backtick preceded by an expression is not a tag;
the grammar has no tag production.

**9.17.6** Line terminators inside a template are preserved in the cooked
text. No indentation trimming or newline normalization is performed beyond the
source-text normalization of Clause 7. A template may span multiple lines.

**9.17.7** The following program is well-formed and illustrates interpolation,
escaping, and `ToString`:

```dryad
#<io>

let name = "Dryad";
let version = 1.0;
let message = `Language: ${name}, version ${version}`;
print(message); // Language: Dryad, version 1

let amount = 12;
print(`price: \$${amount}`); // price: $12

let inner = `x${1}`;
print(`outer ${inner}`); // outer x1
print(`${2 + 3}`);       // 5
```

## 9.18 `await` Expressions

**9.18.1** An `await` expression has the form `await UnaryExpression`. It has
the precedence of a unary operator: `await p + 1` is `(await p) + 1`, and
`await p ** 2` is `(await p) ** 2`.

**9.18.2** An `await` expression is permitted only in the body of an async
function or async function expression (Clause 11.9), and only in the
expression positions of that body. It is an early error in a non-async
function, in a non-async arrow function, in a parameter default expression, in
a class field initializer, and at module top level. An `await` inside a
non-async function nested within an async function is an early error in the
nested function.

**9.18.3** An `await` expression evaluates as follows.

1. Evaluate the operand and apply `GetValue`; let `value` be the result.
2. If `value` is not a Promise or an awaitable handle defined by Clause 15,
   throw a TypeError. A `Thread<T>` is an awaitable handle; it is converted to
   a Promise by Clause 15.1.
3. Let `promise` be `value`, or the promise associated with the awaitable
   handle.
4. Suspend the running async function. Record its execution context, its
   lexical environment, its `this` binding, and the resume point.
5. Register a fulfillment reaction and a rejection reaction on `promise` and
   enqueue the reactions as jobs on the agent's job queue (Clause 15.4).
6. Return control to the caller of the async function. The async function's
   result Promise remains pending.
7. When the fulfillment reaction runs, resume the async function with the
   fulfillment value as the value of the `await` expression.
8. When the rejection reaction runs, resume the async function by throwing the
   rejection reason at the `await` expression.

**9.18.4** An `await` always suspends the async function, even when the
Promise is already settled. The continuation is always scheduled as a job and
never runs synchronously within the current job, so the number of job
boundaries does not depend on settlement timing.

**9.18.5** If operand evaluation throws, the async function does not suspend
and the throw propagates; if uncaught, its result Promise is rejected. A
non-awaitable operand also rejects the returned Promise rather than throwing
synchronously at the call site.

**9.18.6** A rejection of the awaited Promise becomes a throw at the `await`
expression. It may be caught by an enclosing `try` statement inside the async
function (Clause 10); otherwise the function's result Promise is rejected with
the rejection reason, unwrapped.

**9.18.7** Awaiting a Promise that fulfills with another Promise yields the
final fulfillment value, because the resolution procedure of Clause 15.3
adopts the inner Promise. Awaiting a non-Promise fulfillment value yields that
value; awaiting a rejected Promise throws its reason.

**9.18.8** Multiple `await` expressions in one async function are evaluated
sequentially; the function resumes after each fulfillment before evaluating
the next. An async function runs synchronously from invocation until the first
`await`, return, or throw, and only then returns its result Promise.

**9.18.9** The following program is well-formed and illustrates `await` and
rejection handling:

```dryad
async function increment(p) {
    let value = await p;
    return value + 1;
}

async function recover(p) {
    try {
        return await p;
    } catch (error) {
        return null;
    }
}
```

## 9.19 Arrow Functions

**9.19.1** An ArrowFunction has the form `( parameters ) => body`, where the
body is either an expression or a Block. The parameter list is REQUIRED to be
parenthesized, including when it contains a single parameter or no parameters.
The form `x => x` is not generated by the grammar and is a syntax error.
Async arrow functions are not part of Edition 1.0; `async` before an arrow
parameter list is an early error. The parameter syntax, defaults, rest
parameters, and arity rules are the same as for ordinary functions (9.5.5).

**9.19.2** An ArrowFunction evaluates as follows.

1. Create a new function value with the parameter list, the body, the current
   lexical environment as its closure, the current ThisBinding as its
   captured `this`, and the current home object as its captured `super` home
   object.
2. Do not evaluate the body.
3. Return the function value.

The body is evaluated at call time, in a new function environment whose outer
environment is the captured closure. The parameters are bound by the algorithm
of 9.5.5.

**9.19.3** If the body is an expression, the function returns the value of
that expression. The expression is evaluated at call time, not at creation
time. If the body is a Block, the function executes the statements of the
block and returns `null` if no `return` statement transfers control. There is
no implicit return of the last statement of a block.

**9.19.4** An arrow function does not have its own `this` binding. A
ThisExpression inside an arrow function evaluates to the ThisBinding captured
when the arrow function was created. The captured binding is the `this` of the
nearest enclosing non-arrow function or method; at module top level it is
`null`. An arrow function created inside a method therefore observes the
method's receiver, and an arrow function created inside a constructor observes
the new instance.

**9.19.5** An arrow function does not have its own `super` binding. A `super`
occurrence inside an arrow function uses the home object captured when the
arrow function was created. An arrow function created inside a method may
therefore use `super.name` and `super.name(...)`; an arrow function created
outside a method with a home object cannot. `super(...)` inside an arrow
function is permitted only when the arrow is lexically inside a constructor
and the constructor's home object has a superclass.

**9.19.6** Arrow functions are not hoisted. The function value exists only
after the ArrowFunction expression has been evaluated. A `const` or `let`
binding that will hold an arrow function is in the temporal dead zone before
its declaration is evaluated; calling the binding before initialization throws
a ReferenceError. A function declaration, by contrast, is hoisted as specified
in Clause 11.3.

**9.19.7** An arrow function is not a constructor. `new` applied to an arrow
function value throws a TypeError. An arrow function has no `prototype`
property. An arrow function value is callable by the ordinary call syntax of
9.5.2 and receives the captured `this`, not the receiver of the call site.

## 9.20 Evaluation Order and Side Effects

**9.20.1** Evaluation order is normative. An implementation MUST evaluate the
subexpressions of an expression in the order specified by this clause, and
MUST make every side effect observable in that order. An implementation MUST
NOT reorder, duplicate, or omit a required evaluation, even when the final
value would be unchanged. A side effect includes a function call, a property
read through a getter, a property write, an assignment, a `print` call, a
throw, and any operation specified by Clause 15 or Clause 17 as observable.

**9.20.2** Table 9-7 states the evaluation order for each construct.

| Construct | Evaluation order |
|-----------|------------------|
| `a op b` | `a`, then `b`, then the operation |
| `a && b` | `a`; `b` only if `a` is truthy |
| `a || b` | `a`; `b` only if `a` is falsy |
| `a.b` | `a`, then the property lookup (which may invoke a getter) |
| `a[i]` | `a`, then `i`, then the property lookup |
| `a::b` | resolution of the namespace, then the export lookup |
| `f(args)` | the callee reference, then each argument from left to right, then the invocation |
| `new C(args)` | the class reference, then each argument from left to right, then allocation and construction |
| `a = b` | the target Reference, then `b`, then the write |
| `a op= b` | the target Reference, the old value, `b`, the operation, the write |
| `match e { ... }` | `e` once, then each arm in order: pattern test, guard, result |
| `` `${a}${b}` `` | `a`, then its conversion, then `b`, then its conversion, then concatenation |
| `await e` | `e`, then suspension, then resumption |

**9.20.3** For a member callee, the base, the computed key, and the property
lookup precede the arguments; a throwing getter or a non-callable value
prevents argument evaluation (9.5.2). A call evaluates the callee once and the
arguments left to right; a throwing argument prevents the invocation. `new`
resolves the class, then the arguments, then allocates and constructs.
Assignment evaluates the target Reference, the old value for a compound, the
right-hand side, the operation, and the write; a `null` base throws before the
right-hand side. Short-circuit operators evaluate only the selected operand;
`match` evaluates only the selected arm's result; a template evaluates every
substitution in order.

**9.20.4** If an evaluation throws, every later evaluation in the same
expression is abandoned. The throw propagates according to Clause 14. An
implementation MUST NOT continue evaluating operands after a throw to compute a
value that will be discarded.

**9.20.5** An implementation MAY evaluate independent subexpressions in
parallel only if the parallel evaluation has no observable effect on order,
exceptions, or side effects. Because `print`, assignment, mutation, getters,
and throws are observable, such evaluation is permitted only for
subexpressions provably free of these effects. The observable order MUST be
that of Table 9-7.

## 9.21 Early Errors

**9.21.1** A program is ill-formed if an assignment target or update operand
violates the following restrictions. The implementation MUST report an early
error before execution (Clause 14.8).

1. The target of `=`, `+=`, `-=`, `*=`, `/=`, `%=`, `**=`, `<<=`, `>>=`,
   `>>>=`, `&=`, `^=`, or `|=` is not an Identifier or member access.
2. The target is a literal, call result, NewExpression, ArrayLiteral,
   ObjectLiteral, TupleLiteral, FunctionExpression, ArrowFunction,
   MatchExpression, or a ParenthesizedExpression.
3. The target is `this`, `super`, or a namespace Reference from `::`.
4. The operand of prefix or postfix `++` or `--` is not a Reference or is a
   ParenthesizedExpression.
5. The target of an assignment or update is `super.name`.

**9.21.2** A program is ill-formed if a `this` or `super` occurrence violates
the following restrictions.

1. `super` is not followed by `.` or `(`.
2. `super` is followed by `[`.
3. `super` occurs outside a class that has a superclass.
4. `super(...)` occurs outside a constructor or in a class without a
   superclass.
5. `super.name` occurs outside a method, getter, setter, constructor, or arrow
   function lexically enclosed by one of those.
6. `this` is the target of an assignment or update.

**9.21.3** A program is ill-formed if an `await` expression occurs outside the
body of an async function or async function expression, in a parameter
default, in a class field initializer, or at module top level. An `await` in a
non-async function nested inside an async function is ill-formed in the nested
function. Async arrow functions are not part of Edition 1.0, so `async` before
an arrow parameter list is an early error.

**9.21.4** A program is ill-formed if a `new` expression has no Arguments
list, if its class reference is not an Identifier followed by `.` or `::`
components, or if the class reference contains a bracket access, a call, or a
parenthesized expression. A non-class value as the target is a runtime
TypeError, not an early error.

**9.21.5** A program is ill-formed if a call contains a spread argument, a
named argument of the form `name: expression`, or a trailing comma. A rest
parameter that is not last, a parameter after a rest parameter, a rest
parameter with a default, and a required parameter after an optional parameter
are early errors.

**9.21.6** A program is ill-formed if a `match` expression violates any of the
following restrictions.

1. The match has no arms or no default arm.
2. The default arm does not have the pattern `_`, has a guard, or is not last.
3. An arm follows an unguarded irrefutable pattern (`_` or a binding
   Identifier).
4. A binding pattern has no guard.
5. Two literal patterns in the same match have equal values under 9.10.7.
6. A pattern is not a literal pattern, `_`, or an Identifier.

**9.21.7** A program is ill-formed if a literal or collection form violates
the following restrictions.

1. An ArrayLiteral contains a hole, as in `[1, , 2]`.
2. A TupleLiteral is empty (`()`) or has a trailing comma after a multi-element
   list.
3. An ObjectLiteral contains a method definition, a getter, a setter, or a
   spread property.
4. An ArrayLiteral, ObjectLiteral, or TupleLiteral contains a trailing comma.
5. A TemplateLiteral contains an empty substitution `${}` or an escape
   sequence not defined by Clause 7.

**9.21.8** A program is ill-formed if an arrow function omits the parentheses
around its parameter list, is preceded by `async`, or contains a `yield`
expression, which Edition 1.0 does not provide. The parameter-list restrictions
of 9.21.5 apply to arrows.

**9.21.9** The following token sequences are not part of Edition 1.0 and do
not occur in the grammar. A program that contains one is not well-formed and
the implementation MUST report a syntax error at the first offending token.

1. Optional chaining `?.`, the conditional operator `? :`, and the comma
   operator in expression position.
2. The `typeof` and `delete` operators, and `??`, `&&=`, `||=`, `===`,
   `!==`, `<<<`, `void`.
3. Tagged template literals and dynamic `import(...)`.
4. Destructuring assignment or declaration and spread elements in calls,
   arrays, objects, or tuples.

**9.21.10** No other early errors are introduced by this clause. Assignment to
a `const`, an unresolved identifier, a missing property, an out-of-bounds
index, division or modulo by zero, a non-numeric arithmetic operand, a
non-callable callee, and a non-constructible `new` target are runtime errors.
An implementation MUST NOT reject a well-formed program merely because such an
error is statically predictable.

## 9.22 Conformance Requirements

**9.22.1** A conforming implementation MUST implement every expression form
and operator of 9.1.5 with the syntax, precedence, associativity, and
semantics specified here. An implementation MUST NOT omit an operator because
its execution tier does not lower it directly; all tiers MUST be
observationally equivalent (Clause 6.4.2).

**9.22.2** An implementation MUST evaluate expressions in the order specified
by 9.20. It MUST NOT reorder operands, duplicate or omit a required
evaluation, or evaluate an operand that a short-circuit, `match`, or arrow rule
does not require.

**9.22.3** An implementation MUST use IEEE 754 binary64 for every Number
operation (D-14) and MUST round each arithmetic operation to binary64 before
its result is used. It MUST NOT expose extended-precision intermediates, fused
multiply-add results, or a wider exponent range.

**9.22.4** An implementation MUST preserve `NaN`, `Infinity`, `-Infinity`,
`+0`, and `-0`. `NaN` is unequal to every value, including itself. `+0` and
`-0` are equal under `==` but distinct under the sign rules of division,
exponentiation, and unary minus. An implementation MUST NOT canonicalize `-0`
in a way that changes an observable result.

**9.22.5** An implementation MUST NOT coerce values except where this clause
specifies. In particular, a String is never converted to a Number by an
arithmetic, relational, or bitwise operator; a Boolean is never equal to a
Number; `null` is never converted to `0` or an object; and an object is never
converted to a primitive except by `ToString` in `+` and template
interpolation.

**9.22.6** An implementation MUST throw the `DryadError` specified by 9.3.4,
9.4.6, 9.4.7, 9.5.2, 9.5.5, 9.6.2, 9.7, 9.8, 9.9, 9.10, and 9.18 for every
specified error condition. It MUST NOT return `null`, `NaN`, or a default value
in place of a specified throw. Diagnostic text is not specified beyond
Clause 14, but the category and the point of the throw are observable.

**9.22.7** An implementation MUST evaluate the scrutinee of a `match`
expression exactly once, MUST test arms in source order, MUST select the first
matching arm whose guard is truthy, and MUST require the default arm specified
by D-13. An implementation MUST NOT evaluate a later arm after a selection.

**9.22.8** An implementation MUST evaluate every template substitution from
left to right, exactly once, and MUST apply `ToString` as specified in 9.9.6.
It MUST produce the same String for a given sequence of substitution values
regardless of execution tier.

**9.22.9** An implementation MUST suspend an async function at `await` and
MUST resume it through the job queue specified in Clause 15.4, even when the
awaited Promise is already settled. It MUST propagate a rejection as a throw
at the `await` expression.

**9.22.10** An implementation MUST create arrow functions with the lexical
`this` and lexical `super` captured at creation time. It MUST NOT give an
arrow function its own `this`, its own `super`, or a `prototype` property, and
MUST reject `new` applied to an arrow function.

**9.22.11** An implementation MAY perform constant folding, common
subexpression elimination, inlining, or other optimizations only if the
optimized program is observationally equivalent to the unoptimized program.
Constant folding MUST preserve `NaN`, signed zero, infinity, and specified
throws; an expression that would throw MUST NOT be folded to a value, and an
expression skipped by short-circuit evaluation MUST NOT be evaluated during
optimization.

**9.22.12** An implementation MUST reject every program that violates 9.21
before execution and MUST accept every otherwise well-formed program that does
not violate 9.21. It MUST NOT impose additional early errors that reject a
program this clause classifies as well-formed.

**9.22.13** The conformance test suite for Clause 9 SHOULD cover `NaN` in every
arithmetic and comparison position; `+0` and `-0` in arithmetic,
exponentiation, and `ToString`; division and modulo by zero; shift counts from
`0` through `33` and a negative count; `ToInt32` and `ToUint32` on fractional,
negative, and out-of-range values; concatenation versus addition for every
operand-type pair; equality across dynamic types; `null` member access;
out-of-bounds access; parameter binding; constructor arity; `match` arms and
guards; template escaping; `await` on settled and rejected Promises; and
lexical `this` in arrows.

**9.22.14** Except for the call-stack limit of 9.5.10, Clause 9 designates no
implementation-defined or implementation-dependent behaviour. Every result,
error, and evaluation order is determined here. For a value of a type
introduced by another clause, this clause and its defining clause determine the
conversion; absent one, a TypeError is thrown.
