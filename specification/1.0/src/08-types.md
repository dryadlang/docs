# 8 Types and Values

## 8.1 Type-System Overview

**8.1.1** A *type* is a set of values. The dynamic type of a value determines
which operations are defined on it and what those operations compute. Types are
not values: a type expression denotes a type but is not evaluated, stored,
passed, or compared by a program.

**8.1.2** Dryad is dynamically typed. Every value has exactly one *dynamic
type*, determined by the value's form and, for an Object, by its class or
built-in constructor. Types are associated with values, not with variables. A
variable MAY hold values of different dynamic types at different points in one
execution without a declaration or conversion. For example:

```dryad
let x = 1;
print(x + 1);
x = "one";
print(x + "!");
```

**8.1.3** A *value* is a member of a type. A *variable* is a binding in an
environment record (Clause 4) whose value MAY be replaced. A value's dynamic
type never changes; the dynamic type associated with a variable MAY change when
the binding is assigned. An annotation constrains the values that MAY be stored
through a binding; it does not change the identity or dynamic type of a value.

**8.1.4** Dryad provides *optional strict typing*. Outside a strict region, an
annotation is checked for well-formedness but is not enforced against values
(8.4.16). In a *strict region* (8.6), annotations participate in static checking
and in the boundary checks of 8.6.11 through 8.6.13. Dynamic typing is the
default; strict typing is enabled only by the mechanisms of 8.6.

**8.1.5** The static semantics uses four judgments: `E |- e : T` (expression
`e` has static type `T` in static environment `E`); `E |- S <: T` (subtyping);
`E |- S ~ T` (consistency); and `E |- S => T` (assignability). The environment
maps identifiers to static types and type names to denotations. These judgments
are compile-time relations and are not observable by a program.

**8.1.6** Type information is *erased*. Except for the boundary checks of 8.6,
evaluation does not consult static types. A value produced by an expression is
determined by the rules for that expression and by the dynamic types of its
operands, never by an annotation on a receiving binding. Two programs that
differ only in annotations, in a non-strict region, have identical observable
behaviour.

**8.1.7** The types are partitioned into primitives (`null`, `bool`,
`number`, `string`), Objects (`Object` and its subtypes), native types (8.3.17),
and the special types `any` and `never`. The partition is exhaustive: every
value belongs to exactly one family and to exactly one type within it.

**8.1.8** The specification defines no undefined behaviour for a well-formed
program (Clause 1.4). Every operation either produces its specified result or
throws a `DryadError` (Clause 14). A type error in a strict region is an early
error (8.10); a type error at a runtime boundary is a throw (8.6). An
implementation MUST NOT substitute an implementation-dependent result for
either.

## 8.2 Primitive Types

### Null

**8.2.1** The type `null` has exactly one value, `null`. The value is not an
Object, has no properties, and has no members. `null` is the only nullish value
in Dryad; `undefined` does not exist. `ToBoolean(null)` is `false`;
`ToString(null)` is `"null"`; `ToNumber(null)` throws a Type Error;
`null == null` is `true`; `null == v` for any other value `v` is `false`; and
property or element access on `null` throws a Type Error.

### Boolean

**8.2.2** The type `bool` has exactly two values, `true` and `false`. Booleans
are primitives and are never boxed. `ToBoolean(b)` is `b`; `ToNumber(true)` is
`1` and `ToNumber(false)` is `0`; `ToString(true)` is `"true"` and
`ToString(false)` is `"false"`; `b == c` is true if and only if `b` and `c` are
the same Boolean value.

### Number

**8.2.3** The type `number` is the set of values of the IEEE 754-2019
*binary64* interchange format. A *Number* is a member of that set. Every Number
is exactly one of: a finite number, `+Infinity`, `-Infinity`, or `NaN`. There
is exactly one `NaN` value; its payload and sign are not observable. `+0` and
`-0` are distinct under `SameValue` (8.9.1) and equal under `==` (8.9.3). There
is no separate integer value type at the language level.

**8.2.4** A Number occupies 64 bits: one sign bit, eleven exponent bits, and a
fifty-two-bit trailing significand field, giving fifty-three-bit precision. The
largest finite value is `(2 - 2^-52) * 2^1023`, the smallest positive normal is
`2^-1022`, and the smallest positive subnormal is `2^-1074`. An implementation
MUST NOT retain excess precision between operations; a wider intermediate MUST
be rounded to binary64 before it is used by the next operation.

**8.2.5** A numeric literal denotes the binary64 value obtained by correctly
rounding its mathematical value to nearest, ties to even, as specified in 7.6.11.
Decimal, hexadecimal (`0x`), binary (`0b`), and octal (`0o`) forms are defined in
Clause 7. Overflow denotes the infinity of the literal's sign; underflow denotes
`+0` or the smallest positive subnormal according to 7.6.11. A numeric literal
never denotes `-0`; `-0` is produced only by unary minus applied to `+0`.

**8.2.6** `NaN` is produced by undefined results, including `0 / 0`,
`Infinity - Infinity`, `Infinity / Infinity`, and `0 * Infinity`. It propagates
through arithmetic unless 8.2.12 specifies otherwise. `NaN == NaN` is `false`;
`SameValue(NaN, NaN)` is `true`. A program MUST NOT observe a NaN payload or
sign.

**8.2.7** The zeros are distinct values. `SameValue(+0, -0)` is `false`;
`+0 == -0` is `true`. Under round-to-nearest, `x + (-x)` is `+0` for finite
nonzero `x`, `(-0) + (-0)` is `-0`, `(+0) + (-0)` is `+0`, `-0 * -0` is `+0`,
and `-0 * +0` is `-0`. Unary minus maps `+0` to `-0` and `-0` to `+0`.
`ToString(-0)` is `"0"`. The sign is observable through `SameValue` and through
`1 / x`, not through `==`.

**8.2.8** `+Infinity` and `-Infinity` arise from overflow (8.2.5) and from
arithmetic on infinities. `Infinity + Infinity` is `+Infinity`; `-Infinity +
-Infinity` is `-Infinity`; `Infinity + -Infinity`, `Infinity - Infinity`,
`Infinity * 0`, and `Infinity / Infinity` are `NaN`; `1 / Infinity` is `+0`;
`-1 / Infinity` is `-0`.

**8.2.9** Every arithmetic operation rounds its exact result to the nearest
binary64 value, ties to even. An implementation MUST NOT fuse a multiplication
and an addition into one rounding step, because the fused result can differ
from the specified two-rounding result. Conversions between binary64 and
decimal text are correctly rounded in both directions.

**8.2.10** The operators `+`, `-`, and `*`, when both operands are Numbers,
compute IEEE 754-2019 addition, subtraction, and multiplication with the
rounding of 8.2.9. The sign of a zero result follows 8.2.7. If either operand is
`NaN`, the result is `NaN`. These operators are also defined on Booleans and,
for `+` only, on Strings, as specified in 8.8.

**8.2.11** The operator `/`, when both operands are Numbers, computes IEEE
754-2019 division, except that a divisor of `+0` or `-0` throws a `DryadError`
of category *runtime* (Clause 14), even when the dividend is `NaN`, an infinity,
or a zero. If either operand is `NaN`, or both are infinities, the result is
`NaN`; an infinite dividend and finite divisor yield the infinity of the
quotient sign, and a finite dividend and infinite divisor yield the zero of the
quotient sign. The operator `%` computes the IEEE 754-2019 `fmod` operation,
except that a divisor of `+0` or `-0` throws a `DryadError` of category
*runtime*. Its result has the sign of the dividend and is `NaN` when the
dividend is infinite or either operand is `NaN`; an infinite divisor and finite
dividend yield the dividend; a zero dividend yields that zero.

**8.2.12** The operator `**` computes IEEE 754-2019 `pow` with the special cases
of 9.8.4. The result is `NaN` for a negative base and a finite non-integer
exponent; overflow yields the corresponding infinity and underflow the
corresponding zero. `0 ** -1` is `+Infinity`, not a division-by-zero error.

**8.2.13** `ToInt32(value)` and `ToUint32(value)` produce signed and unsigned
32-bit integers, applying `ToNumeric` first, as specified in 9.11.2 and 9.11.3.
They are total: `NaN`, a zero, or an infinity converts to `0`. Their results are
Numbers, and every zero converts to `+0`.

**8.2.14** `&`, `|`, `^`, and `~` apply `ToInt32` to their operands and yield
signed 32-bit Numbers; `<<`, `>>`, and `>>>` apply the conversions and mask the
shift count modulo 32 as specified in 9.10.3 through 9.10.5. `<<` and `>>` yield
signed 32-bit results; `>>>` yields an unsigned 32-bit result.

**8.2.15** There is no integer type at the language level. A Number whose
mathematical value is an integer is an *integer-valued Number*; `IsInteger(x)`
is true if and only if `x` is finite and `trunc(x) = x`. An Array or Tuple index
MUST be a canonical index (9.4.4) within the length; any other numeric string is
an invalid index (8.3.13). Native integer types (8.3.17) are refinements at
native boundaries, not a second language-level value kind.

### String

**8.2.16** The type `string` is the set of finite sequences of Unicode scalar
values. A *String* is a member of that set. A Unicode scalar value is an
integer in `[0, 0x10FFFF]` outside the surrogate range `[0xD800, 0xDFFF]`. A
String MAY be empty; the empty String is `""`. Strings are immutable: no
operation modifies a String in place, and every modifying operation returns a
new String.

**8.2.17** A String is encoded in UTF-8 (RFC 3629) when stored or exchanged.
The encoding is an implementation detail; the value is the sequence of scalar
values. Two Strings are equal if and only if their sequences are equal. The
encoding is canonical: each scalar value has exactly one UTF-8 encoding, and an
implementation MUST NOT preserve alternative encodings of the same sequence.

**8.2.18** The *length* of a String is its number of Unicode scalar values, not
its number of UTF-8 bytes or UTF-16 code units. `StringLength(s)` returns that
number as a non-negative integer-valued Number; `StringByteLength(s)` returns
the number of UTF-8 bytes. A length exposed by the language or the standard
library is measured in scalar values unless its name explicitly contains
`byte`; a byte length MUST be named accordingly.

**8.2.19** The language provides no surface string indexing: an index or member
access whose base is a String throws a `TypeError` (9.4.6), because primitives
are not boxed. The abstract operation `StringCodePointAt(s, i)` returns the
one-scalar String at zero-based position `i` when `i` is an integer-valued Number
in `[0, StringLength(s))`; a non-integer `i` throws a `TypeError`, and an `i`
outside the interval throws a `RangeError`. Negative indices are outside the
interval. Clause 18 MAY expose this operation as a function; it MUST NOT expose
UTF-16 code-unit indexing.

**8.2.20** Every String is well-formed: it contains no unpaired surrogate and
no ill-formed UTF-8 sequence. When bytes are converted to a String, each
maximal ill-formed subsequence is replaced by one U+FFFD REPLACEMENT CHARACTER,
following the substitution practice of the Unicode Standard. Replacement is the
only permitted repair. An implementation MUST NOT discard bytes silently, MUST
NOT decode with a non-UTF-8 encoding, and MUST NOT produce a String containing a
surrogate. Encoding a String cannot fail.

**8.2.21** String equality is equality of scalar-value sequences (8.9.5). The
relational operators `<`, `<=`, `>`, and `>=` do not accept Strings; a String
operand throws a `TypeError` (9.10.6). There is no locale collation, case
folding, normalization, or UTF-16 code-unit order. Strings that differ only in
Unicode normalization are distinct.

**8.2.22** Primitives are never boxed. A String is not an Object, a Number is
not an Object, and a Boolean is not an Object. Property access on a primitive
throws a `TypeError` (9.4.6); primitives are not indexable. `null`, `bool`,
`number`, and `string` are pairwise disjoint.

## 8.3 Object Types and Values

**8.3.1** An *Object* is a value that groups properties and has an identity
independent of its contents. `Object` is the set of all Objects; every Object
has a dynamic type that is `Object` or one of its subtypes in 8.3.2 through
8.3.11. Two Objects are the same if and only if they have the same identity;
contents do not participate in identity. `Object` is open: a property read on a
value of static type `Object` yields `any` (8.3.12).

**8.3.2** The type `Array<T>` is the set of mutable, ordered, zero-based
sequences whose elements have type `T`. An *Array* is a member of `Array<T>` for
some `T`. Every Array has dynamic type `Array`; the element type is a static
refinement not retained by the value. Arrays are heterogeneous when `T` is
`any` or a union. `Array<T>` is a subtype of `Object`, and each Array has an
identity: two Arrays with equal elements are distinct. Literals, growth, and
access are specified in 8.3.13 and 8.3.18.

**8.3.3** The type `Tuple<T1, ..., Tn>`, for `n >= 1`, is the set of
fixed-length sequences of length `n` whose element at zero-based position `i` has
type `Ti`. A *Tuple* is a member of such a type. Every Tuple has dynamic type
`Tuple`; the element types are a static refinement. A Tuple has identity, is a
subtype of `Object`, and is not a subtype of `Array<T>` for any `T`. Its length
is fixed, but its elements are assignable by valid index (8.3.19). Access is
specified in 8.3.13 and 8.3.19.

**8.3.4** A *Function* is a callable Object with a parameter list, a body, and a
captured lexical environment. The type `fn(P1, ..., Pn) -> R` is the set of
Functions that accept `n` positional parameters of the stated types and, when
they return normally, return a value of type `R`. Optional and rest parameters
are permitted; the function type describes the required positions and the
result. A Function has identity: two closures created by the same expression
are distinct. A class constructor is callable only with `new` and has type
`Class<C>`, not a function type. Asynchronous and threaded functions have result
types `Promise<R>` and `Thread<R>` (Clauses 11 and 15).

**8.3.5** A *class* is an Object that defines a nominal object type, a
constructor, instance members, and static members (Clause 11). The type `C`,
where `C` is a class name, is the set of instances of `C` and its subclasses; it
is a subtype of `Object`. `Class<C>` is the set of class Objects whose instances
have type `C`; it is a subtype of `Object` and is invariant in `C`. A class with
superclass `D` satisfies `C <: D`. An *interface* declares required members and
denotes a type; a class satisfies an interface only by declaring `implements`,
directly or through an ancestor, and providing every required member with a
compatible type (Clause 11). An interface is not a runtime value.

**8.3.6** The type `Buffer` is the set of contiguous, bounds-checked byte
regions with an explicit length and capacity (Clause 17.5). A Buffer has
identity, is a subtype of `Object`, and is mutable: its bytes MAY be changed in
place, while length and capacity change only through the operations of Clause
18. A Buffer is not an Array and does not support Array or Tuple element access.
Its members are the Buffer operations of Clause 18 and Clause 17.5; a missing
member yields `null` (9.4.6). Byte values are integer-valued Numbers in
`[0, 255]`; any other value is a `TypeError`.

**8.3.7** `Ok<T>` and `Err<E>` are the types of the two variants of
`Result<T, E>`. Each is a predeclared class with two read-only members: `tag`,
whose value is `"ok"` for `Ok<T>` and `"err"` for `Err<E>`, and `value`, whose
type is `T` for `Ok<T>` and `E` for `Err<E>`. `Result<T, E>` is the union
`Ok<T> | Err<E>`. Both variants are subtypes of `Object`, have identity, and are
compared by identity. A variant is created by `new Ok(value)` or
`new Err(value)`; the argument becomes the `value` member. `Result` is the type
of recoverable failures (Clause 14). The `tag` member is the discriminant: a
`match` on `r.tag` distinguishes the variants without inspecting `value`. For
example:

```dryad
let pair = ("left", 2);
print(pair.0);
print(new Ok(pair.1).tag);
```

**8.3.8** `Promise<T>` is the set of Objects representing the eventual result of
an asynchronous operation producing a value of type `T` (Clause 15.3). A
Promise has identity and a state that is *pending*, *fulfilled*, or *rejected*;
the state changes at most once, from pending to one of the other two.
`Promise<T>` is a subtype of `Object`, is covariant in `T`, and is compared by
identity. Construction, settlement, and `await` are specified in Clause 15.3;
`await p` for `p: Promise<T>` has type `T`.

**8.3.9** `Thread<T>` is the set of handles to threads producing a value of type
`T` (Clause 15.1). A Thread has identity, is a subtype of `Object`, is covariant
in `T`, and is compared by identity. Invoking a `thread function` yields
`Thread<R>` for its declared result type `R`; `await h` for `h: Thread<T>` has
type `T`. Thread operations are specified in Clause 15.1.

**8.3.10** `Mutex` is the set of mutual-exclusion Objects specified in Clause
15.2. A Mutex has identity, is a subtype of `Object`, and has no type
parameters. Mutexes are compared by identity. The `lock` and `unlock`
operations and their timeouts are specified in Clause 15.2.

**8.3.11** `ModuleNamespace` is the set of module namespace Objects produced by
namespace imports (Clause 12). A namespace Object has one read-only property per
export, is sealed, and is a subtype of `Object`. There is at most one namespace
Object per module per realm, and repeated imports yield the same Object.
Properties are live: a read yields the current value of the exported binding.
Assignment to a namespace property is an early error in a strict region and a
`TypeError` in a dynamic region.

**8.3.12** Property access is written `o.k` or `o[k]`, where `k` is a String.
The key is not converted: a non-String computed key is a Type Error, so `o[1]`
does not denote `"1"`. For an object literal, own properties are consulted and
an absent property yields `null`. For a class instance, fields and methods of
the class and its ancestors are consulted; an undeclared member yields `null`
in a dynamic region and is an early error in a strict region when the receiver's
static type is a class type. A `private` member read from outside its class, or
a `protected` member read from outside the hierarchy, is an early error in a
strict region and a Type Error in a dynamic region (Clause 11). Property access
on `null` or on a Buffer is a Type Error; property access on a primitive follows
8.2.22.

**8.3.13** Element access is written `e[i]`, where `e` is an Array, Tuple, or
String and `i` is a Number. For a read from an Array, `i` MUST be an
integer-valued Number in `[0, ArrayLength(e))`; the result is the element. A read
outside the interval throws a `DryadError` reporting the index and the length; a
non-integer index throws a Type Error. For a read from a Tuple, `i` MUST be in
`[0, TupleArity(e))`, with the same errors; writes to a Tuple are forbidden
(8.3.19). For a String, 8.2.19 applies. A computed access `o[k]` on an Object is
property access under 8.3.12 when `k` is a String; `e[i]` on an Array, Tuple, or
String is element access. Element access on any other value is a Type Error.

**8.3.14** Identity is created at allocation and never changes.
`SameObject(x, y)` is true if and only if `x` and `y` are the same Object. Two
object literals with equal properties, two Arrays with equal elements, and two
Tuples with equal elements are distinct; a closure is distinct from every other
closure. Identity is the only comparison `==` performs on Objects (8.9.6).
Copying a reference copies identity, not contents; there is no implicit deep
copy.

**8.3.15** Objects other than Tuples, namespace Objects, `Ok`/`Err` values,
Promises, Threads, and Mutexes are mutable. A `const` binding prevents
replacement of the binding but not mutation of the referenced Object. Tuple
elements, namespace properties, and the `tag` and `value` members of `Ok` and
`Err` are read-only. A Promise's state changes only through Clause 15.3.
Read-only members are enforced by Clause 11 in a strict region and by a Type
Error in a dynamic region.

**8.3.16** An array literal `[e1, ..., en]` with `n > 0` has static type
`Array<T1 | ... | Tn>`, where `Ti` is the static type of `ei`; an empty literal
has type `Array<any>` unless a contextual type supplies an element type. A
tuple literal `(e1, ..., en)` with `n >= 2` has type `(T1, ..., Tn)`. An object
literal has type `Object`. A function expression has the type formed from its
parameter and result annotations, with `any` for each omitted annotation. A
`new C(...)` expression has type `C`; the identifier `C` in value position has
type `Class<C>`.

**8.3.17** The native types are `f64`, `i8`, `i16`, `i32`, `i64`, `u8`, `u16`,
`u32`, `u64`, `isize`, `usize`, `bool`, `ptr<T>`, and `void`. Their domains and
relations to language types are given in Table 8.1. Native types introduce no
separate dynamic-type family: a native value crossing into language code is a
Number or a Boolean, and a native-only value never crosses. `f64` is `number`,
`bool` is the Boolean type, and `void` is `null`. `i8` through `u32` are
subtypes of `number` because every value in their ranges is exactly
representable in binary64. `i64`, `u64`, `isize`, and `usize` contain values not
exactly representable in binary64; they are native-only and are not subtypes of
`number` or `any`. `ptr<T>` is opaque, invariant in `T`, has no literal, and
supports only storage, passing, identity comparison, and return (8.4.11).

| Native type | Domain | Relation to language types |
|-------------|--------|----------------------------|
| `f64` | IEEE 754-2019 binary64 | Identical to `number`. |
| `i8`-`i32` | Two's-complement integers | Subtypes of `number`. |
| `u8`-`u32` | Unsigned integers | Subtypes of `number`. |
| `i64`, `u64`, `isize`, `usize` | 64-bit or pointer-sized integers | Native-only. |
| `bool` | `true` and `false` | Identical to `bool`. |
| `ptr<T>` | Native addresses of `T` or `void` | Native-only; opaque. |
| `void` | The single value `null` | Identical to `null`. |

**8.3.18** `ArrayLength(a)` returns the number of elements as an integer-valued
Number. `ArrayGet(a, i)` and `ArraySet(a, i, v)` are defined for integer-valued
`i` in `[0, ArrayLength(a))`. `ArraySet` at `i = ArrayLength(a)` appends `v` and
increments the length; at `i > ArrayLength(a)` it throws a `DryadError` reporting
the index and the length. Arrays are dense: no operation creates a hole. Removal,
where provided, is a standard-library operation (Clause 18) that renumbers the
remaining elements.

**8.3.19** `TupleArity(t)` returns the arity as an integer-valued Number. Tuple
elements are read-only; `t[i] = x` is an early error in a strict region and a
Type Error in a dynamic region. A Tuple exposes no properties; its arity is a
property of its type and of `TupleArity`, not of the value. A Tuple is not an
Array and supports no growth, removal, or replacement.

**8.3.20** `FunctionArity(f)` returns the number of required positional
parameters. A Function's `this` binding, defaults, rest parameter, and invocation
rules are specified in Clause 11. A non-constructor cannot be invoked with `new`;
a `Class<C>` cannot be invoked without `new`. Both violations are early errors
in a strict region when the static type is known and Type Errors at runtime
otherwise. Extracting a method does not bind its receiver.

**8.3.21** Inheritance is single: a class has at most one direct superclass and
a finite, acyclic superclass chain (Clause 11). A class that declares
`implements I` MUST provide every member of `I` with an assignable type, and the
declaration is an early error otherwise (Clause 11). Access modifiers do not
participate in subtyping except that `private` is invisible outside its class
and `protected` only within the hierarchy. Class types are nominal: two classes
with identical members are not subtypes of each other.

**8.3.22** Named members of Arrays, Strings, Buffers, Promises, Threads,
Mutexes, and namespaces are specified in Clause 18 and in Clauses 15, 17, and
12. A member declared by Clause 18 has the declared function type, and calls to
it are checked under 8.6.

## 8.4 Type Expressions and Annotations

**8.4.1** A *type expression* denotes a type. A *type annotation* attaches one to a
declaration, parameter, result, or member; it is not evaluated and has no runtime
representation. A type expression that violates 8.4.2, or that denotes no type
under 8.4.4 through 8.4.11, is an early error (8.10).

**8.4.2** Type expressions conform to the following grammar. It is normative for
this clause and MUST agree with Clause 22; if the two differ, Clause 22 prevails
(Clause 6.6.2).

```
<TypeExpression>   ::= <UnionType>
<UnionType>        ::= <SuffixType> { "|" <SuffixType> }
<SuffixType>       ::= <BaseType> { "[" "]" | "?" }
<BaseType>         ::= <NamedType>
                     | <TupleType>
                     | <FunctionType>
                     | "(" <TypeExpression> ")"
<NamedType>        ::= <Identifier> [ "<" <TypeArgumentList> ">" ]
<TupleType>        ::= "(" <TypeExpression> "," <TypeExpression> { "," <TypeExpression> } ")"
<FunctionType>     ::= "fn" "(" [ <ParameterType> { "," <ParameterType> } ] ")" "->" <TypeExpression>
<ParameterType>    ::= <TypeExpression> | "..." <TypeExpression>
<TypeArgumentList> ::= <TypeExpression> { "," <TypeExpression> }
```

**8.4.3** `[]` and `?` are postfix operators applied from left to right, so
`T?[]` is an Array of `T?` and `T[]?` is an optional Array of `T`. `|` binds
less tightly than the postfix operators, so `T | U[]` is the union of `T` and an
Array of `U`. The result of `->` extends as far right as possible, so
`fn(number) -> number | string` returns `number | string`; a union containing a
function type requires parentheses, as in `(fn(number) -> number) | null`.
`?` is idempotent: `T??` is `T?`. For example, the following declarations are
well-formed in a strict region:

```dryad
let id: number | string = 1;
let label: string? = null;
```

**8.4.4** The `<Identifier>` of a `<NamedType>` is resolved in the *type
namespace* of the enclosing lexical scope. That namespace contains the
predeclared names of Table 8.2, class and interface names declared anywhere in
the scope, and type names imported from other modules (Clause 12). A name that
resolves to no type denotation is an early error. Value bindings do not affect
type resolution; the namespaces are separate. A class or interface declaration
MUST NOT use a predeclared type name (8.10.11).

**8.4.5** Table 8.2 lists the predeclared type names, their arities, and their
denotations. An omitted type argument defaults to `any`. Initial capitals in
Clause 5.5 are exposition; the source spellings are those in Table 8.2.

| Source spelling | Denotation | Arity | Notes |
|-----------------|------------|-------|-------|
| `null` | The type `null` | 0 | |
| `bool` | The Boolean type | 0 | |
| `number` | The Number type | 0 | |
| `string` | The String type | 0 | |
| `any` | The universal type | 0 | Top of the lattice. |
| `never` | The empty type | 0 | Bottom of the lattice. |
| `Object` | All Objects | 0 | Open. |
| `Array<T>` | Arrays of `T` | 1 | `T[]` equivalent. |
| `Tuple<T1, ..., Tn>` | Tuples of arity `n` | `n >= 2` | `(T1, ..., Tn)` equivalent. |
| `fn(P...) -> R` | Functions | - | See 8.4.2. |
| `Class<C>` | Class Objects for `C` | 1 | Invariant. |
| `Buffer` | Byte buffers | 0 | |
| `Promise<T>` | Promises of `T` | 1 | Covariant. |
| `Thread<T>` | Thread handles of `T` | 1 | Covariant. |
| `Mutex` | Mutexes | 0 | |
| `ModuleNamespace` | Module namespaces | 0 | |
| `Ok<T>` | Successful variants | 1 | |
| `Err<E>` | Failed variants | 1 | |
| `Result<T, E>` | `Ok<T>` or `Err<E>` | 2 | Union. |
| `f64` | `number` | 0 | Native alias. |
| `i8`, `i16`, `i32` | Native signed integers | 0 | Subtypes of `number`. |
| `u8`, `u16`, `u32` | Native unsigned integers | 0 | Subtypes of `number`. |
| `i64`, `u64`, `isize`, `usize` | Native wide integers | 0 | Native-only. |
| `ptr<T>` | Native pointers | 1 | Native-only. |
| `void` | `null` | 0 | Native alias. |

**8.4.6** A parameterized type name MUST receive its arity, except that trailing
arguments MAY be omitted and default to `any`. `Array` is `Array<any>`,
`Promise` is `Promise<any>`, and `Result` is `Result<any, any>`. A type argument
on an arity-zero name is an early error. `Tuple<T1>` and `Tuple<>` are early
errors; `(T)` is a parenthesized type, not a one-element Tuple. `Class` without
an argument is `Class<any>`.

**8.4.7** An annotation MAY appear only after the name of a `let` or `const`
declarator; after a parameter name in a function, method, constructor, arrow
function, extern declaration, or intrinsic declaration; after a parameter list
as the result type; after a property name in a class or interface, including an
accessor; and in an interface member signature. An annotation elsewhere is a
parse error. There is no cast, type assertion, or `as` expression in Edition
1.0.

**8.4.8** An omitted annotation has static type `any`, except where 8.7 infers a
more specific type for a local binding. An omitted parameter, result, or class
property type is `any`, and an omitted type argument is `any` (8.4.6). The
default is a static type, not a conversion: a value stored through an
unannotated binding is not converted and its dynamic type is unchanged.

**8.4.9** A native type name MAY appear only in an `extern function` declaration
(Clause 16), an `@intrinsic` declaration (Clause 17.2), or any declaration in a
strict region (8.6). A native type in a dynamic region outside those
declarations is an early error (8.10.5). `f64`, `bool`, and `void` are permitted
everywhere because they denote `number`, `bool`, and `null`. The native-only
types `i64`, `u64`, `isize`, `usize`, and `ptr<T>` MUST NOT appear as type
arguments to `Array`, `Tuple`, `Promise`, `Thread`, `Result`, `Ok`, `Err`, or a
function type in language code; they MAY appear in extern and intrinsic
declarations.

**8.4.10** `void` denotes `null`. It is intended for native result positions
that carry no information; a function returning `void` returns `null` when it
returns normally. Because `void` and `null` are the same type, `let x: void` is
well-formed and permits only `null`. The spelling does not create a unit value
distinct from `null`.

**8.4.11** `ptr<T>` denotes the native pointer type whose pointee has native
type `T`. `T` MUST be a native type or `void`; `ptr<Object>`,
`ptr<Array<number>>`, and `ptr<MyClass>` are early errors because language-level
layout is not exposed. A `ptr<T>` value has no literal, cannot be created by a
language-level operation, and cannot be converted to or from a Number, String,
or Object. It MAY be stored, passed to another native declaration, compared by
identity, and returned. Pointer arithmetic is not part of Edition 1.0.

**8.4.12** In a type expression, a `>>` token MAY occur where two `>` tokens
close nested argument lists, as in `Array<Array<number>>`; the parser MUST treat
it as two `>` tokens. The same applies to a `>=` token where `>` closes an
argument list and `=` begins a default value or initializer. No other token
splitting is permitted in a type expression.

**8.4.13** Union normalization flattens nested unions, removes duplicates and
`never`, and yields `any` if any member is `any`; `T | null` MAY be written
`T?`. Normalization does not change denotation, and member order is not
significant. A union with no members after normalization is `never`.

**8.4.14** Two type expressions denote the same type if and only if their
denotations are equal as sets, which is equivalent to mutual subtyping (8.5.2).
Spelling does not affect equality: `number[]`, `Array<number>`, and
`Array<number> | never` denote the same type. Annotations are compared by
denotation, not by text.

**8.4.15** The abbreviations `T[]`, `(T1, ..., Tn)`, and `T?` denote `Array<T>`,
`Tuple<T1, ..., Tn>`, and `T | null` respectively. `Array`, `Promise`, `Thread`,
`Result`, `Ok`, and `Err` without arguments denote their `any`-instantiated
forms under 8.4.6. These abbreviations introduce no new types.

**8.4.16** In a dynamic region, an annotation is checked for well-formedness
(8.10.2 through 8.10.7) and otherwise ignored. A value whose dynamic type does
not satisfy the annotation MAY be stored through the binding, and no error is
reported. In a strict region, the annotation participates in static checking and
in the boundary checks of 8.6. An implementation MUST NOT enforce a
dynamic-region annotation at runtime, because that would make the annotation
observable and contradict 8.1.6.

**8.4.17** Type names and value names occupy separate namespaces. A class
declaration introduces a type name (its instances) and a value name (the class
Object); an interface declaration introduces only a type name. A `let`, `const`,
`function`, or parameter declaration introduces only a value name and never
shadows a type name in type position. Using a value name as a type is an early
error, and a class or interface declared with a predeclared type name is an
early error.

**8.4.18** The grammar of 8.4.2 is the operative grammar of type expressions for
this clause. Clause 22 repeats the productions in the complete grammar. A future
erratum that adds a type form MUST add the corresponding production to Clause 22
and MUST NOT renumber the productions of this clause (Clause 5.8.1).

## 8.5 Type Relations

**8.5.1** `S <: T` (*S is a subtype of T*) means every value of type `S` is also
a value of type `T`. Subtyping is reflexive and transitive and is a semantic
relation on sets of values. If `S <: T` and `T <: S`, then `S` and `T` are the
same type.

**8.5.2** Subtyping is reflexive and transitive, and mutual subtyping implies
type equality. These properties justify 8.4.14 and 8.5.19.

**8.5.3** `never` is the bottom type: `never <: T` for every `T`, and no value
has type `never`. `any` is the top type: `T <: any` for every `T`. `any` is not
a subtype of any other type; in particular `any <: Object`, `any <: number`,
and `any <: T?` are false unless `T` is `any`. An expression of type `never`
does not return normally: it throws or diverges and never yields a value.

**8.5.4** The four primitive types are pairwise disjoint, and `Object` is
disjoint from each of them. Every built-in object type is a subtype of `Object`
and therefore disjoint from the primitives.

**8.5.5** Union subtyping is componentwise: `S <: T | U` if and only if
`S <: T` or `S <: U`, and `S | T <: U` if and only if both `S <: U` and
`T <: U`. Hence `S <: S | T`, `S | never` is `S`, `any | T` is `any`, and
`never | T` is `T`.

**8.5.6** `T?` denotes `T | null`: `null <: T?`, `T <: T?`, `S? <: T?` if and
only if `S <: T`, and `T? <: U` if and only if `T <: U` and `null <: U`.

**8.5.7** Class types are nominal: `C <: D` if and only if `C` is `D` or its
superclass chain reaches `D`, and every class type is a subtype of `Object`.
`Class<C>` is invariant because construction depends on `C`'s constructor
signature; it is a subtype of `Object`.

**8.5.8** `C <: I` if and only if `C` or an ancestor declares `implements I` and
satisfies Clause 11; `I <: J` if and only if they are the same interface or `I`
extends `J` and requires every member of `J`. Interfaces are subtypes of
`Object`, and a class that does not declare `implements I` is not a subtype of
`I`.

**8.5.9** Arrays are invariant because they are mutable: `Array<T> <: Array<U>`
only when `T <: U` and `U <: T`, or `U` is `any`, or `T` is `never`.
`Array<T> <: Object`, and `Array<never> <: Array<U>` for every `U`.

**8.5.10** Tuples are covariant because they are immutable:
`Tuple<T1..Tn> <: Tuple<U1..Un>` if and only if the arities are equal and
`Ti <: Ui` for every `i`. No tuple is a subtype of an Array or of a tuple of a
different arity; every tuple is a subtype of `Object`.

**8.5.11** Function types are contravariant in parameters and covariant in the
result. `fn(P1..Pn) -> R <: fn(Q1..Qm) -> S` if and only if the left type accepts
at least `m` arguments and requires at most `m`, `Qi <: Pi` for every compared
position `i`, and `R <: S`. A rest parameter accepts every position beyond its
fixed prefix with its element type. Functions are subtypes of `Object`, and
parameter names do not participate in the type.

**8.5.12** `Promise<T>` and `Thread<T>` are covariant; `Ok<T>`, `Err<E>`, and
`Result<T, E>` are covariant in their parameters; all are subtypes of `Object`,
and `Ok<T>` and `Err<E>` are subtypes of `Result<T, E>`.

**8.5.13** Native numeric subtyping is width-based: `i8 <: i16 <: i32 <:
number`, `u8 <: u16 <: u32 <: number`, `i8 <: i16 <: i32 <: i64`,
`u8 <: u16 <: u32 <: u64`, and `u32 <: i64`. Signed and unsigned types of the
same width are unrelated. `i64`, `u64`, `isize`, and `usize` are native-only.

**8.5.14** `ptr<T> <: ptr<U>` if and only if `T` and `U` are identical.
`ptr<T>` has no supertype other than itself, and no other type is its subtype.
`i64`, `u64`, `isize`, and `usize` are not subtypes of `any`.

**8.5.15** Table 8.3 summarizes subtyping for the composite types. The rows are
exhaustive for the constructors of Table 8.2.

| `S` | `T` | `S <: T` |
|-----|-----|----------|
| `T` | `T` | Yes. |
| `never` | any `T` | Yes. |
| any `T` | `any` | Yes. |
| `null` | `T?` | Yes. |
| `T` | `T?` | Yes. |
| `S?` | `T?` | If `S <: T`. |
| `S` | `T \| U` | If `S <: T` or `S <: U`. |
| `S \| T` | `U` | If `S <: U` and `T <: U`. |
| `Array<T>` | `Array<U>` | If `T <: U` and `U <: T`, or `U` is `any`, or `T` is `never`. |
| `Array<T>` | `Object` | Yes. |
| `Tuple<T1..Tn>` | `Tuple<U1..Un>` | If `Ti <: Ui` for every `i`. |
| `Tuple<...>` | `Object` | Yes. |
| `fn(P..) -> R` | `fn(Q..) -> S` | Arity compatible, `Qi <: Pi`, `R <: S`. |
| `fn(...) -> R` | `Object` | Yes. |
| `C` | `D` | If `C` is `D` or `C` extends `D`. |
| `C` | `I` | If `C` declares `implements I`. |
| `C` | `Object` | Yes. |
| `Class<C>` | `Class<D>` | If `C` and `D` are the same class type. |
| `Class<C>` | `Object` | Yes. |
| `Buffer` | `Buffer` | Yes. |
| `Buffer` | `Object` | Yes. |
| any object type | `Object` | Yes. |
| `Promise<T>` | `Promise<U>` | If `T <: U`. |
| `Thread<T>` | `Thread<U>` | If `T <: U`. |
| `Mutex` | `Mutex` | Yes. |
| `ModuleNamespace` | `Object` | Yes. |
| `Ok<T>` | `Result<T, E>` | Yes. |
| `Err<E>` | `Result<T, E>` | Yes. |
| `Result<T, E>` | `Result<U, F>` | If `T <: U` and `E <: F`. |
| `i8..i32`, `u8..u32` | `number` | Yes. |
| `ptr<T>` | `ptr<T>` | Yes. |

**8.5.16** `S ~ T` (*S is consistent with T*) is the symmetric, non-transitive
relation that permits a value of one type to flow into the other under a runtime
check. The rules of 8.5.17 define it for the constructors of this clause; it is
sufficient for a checked flow, not necessary.

**8.5.17** If `S <: T` and `S` is not `never`, then `S ~ T`. Also, `T ~ T` for
every `T` other than `never`; `any ~ T` for every `T` other than `never`;
`never ~ T` is false; `null ~ T?` is true. A union is consistent with a type if
one of its members is; an optional type is consistent with another optional type
if their bases are; and a parameterized type is consistent with another instance
of the same constructor if every corresponding type argument is consistent. The
subtyping rule stated first takes precedence over these structural rules. Two
class types are consistent if and only if one is a subtype of the other, and
`Class<C>` is consistent with `Class<D>` only if `C` and `D` are identical. A
class type and an interface type are consistent, with the boundary check
deciding satisfaction. A native numeric type is consistent with `number` and
with every native numeric type whose range overlaps it. `Object` is consistent
with every object type. Disjoint primitives are inconsistent: `number ~ string`,
`bool ~ number`, and `null ~ number` are false.

**8.5.18** Consistency decides only whether a *checked* flow is permitted. A
consistent flow does not assert that the value has the target type; it asserts
that the target type can test the value and reject it. A flow that is neither a
subtype flow nor a consistent flow is an early error in a strict region
(8.6.7) and is not checked at all in a dynamic region.

**8.5.19** In a strict region, `S => T` holds if `S <: T` or `S ~ T`. The first
case is an *unchecked assignment*; the second is a *checked assignment* and
inserts the runtime test of 8.6.13. If neither holds, the assignment is an
early error. In a dynamic region the judgment is not evaluated because
annotations are not enforced (8.4.16); every value is assignable to every
annotated position.

**8.5.20** *Widening* is an assignment or argument pass whose source type is a
subtype of the target. It requires no runtime check and cannot fail for a value
of the source type. Assigning an instance to `Object`, an Array to
`Array<any>`, a Tuple to `Object`, or `T` to `T?` are widenings.

**8.5.21** *Narrowing* is an assignment or argument pass whose source type is
consistent with, but not a subtype of, the target. It requires the check of
8.6.13 and throws a Type Error on failure. Assigning `any` to `number`, `number?`
to `number`, `Object` to a class type, or `number` to `i32` are narrowings.
There is no cast syntax; narrowing occurs only through an annotated binding,
parameter, result, or checked assignment.

**8.5.22** Table 8.4 gives the variance of each parameterized constructor.

| Constructor | Variance | Reason |
|-------------|----------|--------|
| `Array<T>` | Invariant, with `any` and `never` exceptions | Mutable elements. |
| `Tuple<T1..Tn>` | Covariant | Immutable elements. |
| `fn(P..) -> R` | Contravariant in `P..`, covariant in `R` | Call substitutability. |
| `Class<C>` | Invariant | Constructor signature. |
| `Promise<T>` | Covariant | Produces `T`. |
| `Thread<T>` | Covariant | Produces `T`. |
| `Ok<T>`, `Err<E>` | Covariant | Read-only payload. |
| `Result<T, E>` | Covariant | Union of covariant variants. |
| `Mutex`, `Buffer`, `ModuleNamespace` | No parameters | - |

**8.5.23** `any` is the top type, is consistent with every type except `never`,
and is the type of a dynamic fallback binding (8.7.5). `never` is the bottom
type, is a subtype of every type, is consistent with none, and types
non-returning expressions. `null` is a subtype only of optional types and `any`.
`Object` is the top of the object branch, and no primitive is consistent with a
different primitive.

## 8.6 Strict Type Mode

**8.6.1** Strict mode is enabled by the directive `"use strict types"`. The
directive is a String literal expression statement whose value is exactly the
sequence of scalar values `use strict types`. The spelling is case-sensitive and
contains no escapes; whitespace and comments outside the literal do not affect
recognition. The statement MUST be terminated by a semicolon.

**8.6.2** The directive has effect only in the *directive prologue* of a module:
the maximal sequence of String literal expression statements at the beginning of
the module, before any other statement. A directive in the prologue enables
strict mode for the entire module, including all functions, methods, classes,
and nested declarations, subject to the overrides of 8.6.4 and 8.6.5. The same
String outside the prologue is an ordinary expression statement with no effect.
A misspelled directive has no effect.

**8.6.3** The prologue MAY contain other String literal statements; they are
ignored. The directive MAY occur more than once; later occurrences have no
additional effect. Strictness is a property of the source text, determined
statically; an implementation MUST NOT enable or disable it at runtime.

**8.6.4** `@strict`, applied to a function declaration or method definition,
enables strict checking for that function and every function nested in it,
whether or not the module is strict. It takes no arguments and MUST NOT be
applied to any other declaration. It is redundant but not an error in an
already-strict region.

**8.6.5** `@dynamic`, applied to a function declaration or method definition,
disables strict checking for that function and every function nested in it,
whether or not the module is strict. It takes no arguments and MUST NOT be
applied to any other declaration. The function is a dynamic region for 8.4.16
and 8.7. Class field initializers and the constructor body are part of the
constructor method and inherit its strictness.

**8.6.6** A declaration MUST NOT carry both decorators; that is an early error
(8.10.7). Strictness is inherited lexically: a function in a strict region is
strict unless it carries `@dynamic`, and a function in a dynamic region is
dynamic unless it carries `@strict`. A method inherits the strictness at its
class declaration unless it carries an override. Strictness does not propagate
across module imports; each module is classified independently.

**8.6.7** In a strict region, the following static obligations apply, and each
violation is an early error reported before execution (Clause 14.8):

1. every initialization, assignment, argument, `return`, and member store MUST
   satisfy `S => T` for its source type `S` and target type `T`;
2. every call MUST have a callee whose static type is a function type or
   `Class<C>`, MUST supply an accepted argument count, and MUST supply arguments
   assignable to the corresponding parameters;
3. every property read MUST name a member of the receiver's static type, unless
   that type is `any` or `Object`;
4. every operand of a primitive operator MUST be in the operator's domain (8.8)
   unless its static type is `any`;
5. every `new C(...)` MUST supply arguments assignable to `C`'s constructor.

**8.6.8** A call whose callee has static type `any` is a *dynamic call*. It is
permitted in a strict region and yields `any`. A call whose callee has static
type `Object` is an early error unless the callee is narrowed to a function
type. A `Class<C>` callee requires `new`; a call without `new` is an early
error. A call with a known argument count outside the callee's accepted range
is an early error.

**8.6.9** A property read on static type `C` is permitted only for a member
declared in `C` or an ancestor, subject to Clause 11. A read on interface type
`I` is permitted only for a member required by `I`. A read on `any` or `Object`
yields `any`. A read on a parameterized type yields the member type declared in
Clause 18. A read of an unknown member on a class or interface type is an early
error.

**8.6.10** In a strict region, an operator application's static type is
determined by the operator's rule in Clause 9 from its operand types. If an
operand is `any`, the result is `any`. If an operand is outside the operator's
domain and is not `any`, the application is an early error. Conditions of `if`,
`while`, `for`, and `match` are not restricted: every value has a truth value
(8.8.2).

**8.6.11** A *boundary check* is a runtime test when a value crosses into a
statically typed position. A check at entry or exit runs on every invocation,
regardless of the caller's strictness, so a strict function behaves the same for
every caller. Checks occur at these points and no others:

1. entry to a strict function, for each argument against its declared parameter
   type;
2. exit from a strict function, for the returned value against the declared
   result type, unless that type is `any`;
3. a call from a strict region to a dynamic function whose declared result is
   not `any`, for the returned value at the call site;
4. a checked assignment in a strict region, for the value against the target;
5. a store to a class member of declared type other than `any`, performed in a
   strict region, for the value against the member type.

**8.6.12** A check evaluates `TypeTest(v, T)`. If it is `true`, execution
continues; if `false`, a Type Error is thrown before the value is stored,
returned, or bound. The check does not convert, coerce, or copy the value.
Checks at a call run left to right by parameter position after the callee and
all arguments have been evaluated (Clause 9).

**8.6.13** `TypeTest(v, T)` is defined by Table 8.5. The table is exhaustive for
the types of Table 8.2. A type argument not mentioned in the right-hand column
is not tested.

| `T` | `TypeTest(v, T)` |
|-----|------------------|
| `any` | `true`. |
| `never` | `false`. |
| `null`, `void` | `v` is `null`. |
| `bool` | `v` is a Boolean. |
| `number`, `f64` | `v` is a Number. |
| `i8`..`i32`, `u8`..`u32` | `v` is an integer-valued Number in range. |
| `i64`, `u64`, `isize`, `usize` | `v` is a native integer in range. |
| `string` | `v` is a String. |
| `Object` | `IsObject(v)`. |
| `Array<T>` | `v` is an Array; `T` is not tested. |
| `Tuple<T1..Tn>` | `v` is a Tuple of arity `n`; the `Ti` are not tested. |
| `fn(P..) -> R` | `v` is a Function; the signature is not tested. |
| `C` (class) | `v` is an instance of `C` or a subclass. |
| `I` (interface) | `v` is an Object with every member required by `I`; member types are not tested. |
| `Class<C>` | `v` is a class Object whose instance type is exactly `C`. |
| `Buffer` | `v` is a Buffer. |
| `Promise<T>` | `v` is a Promise; `T` is not tested. |
| `Thread<T>` | `v` is a Thread; `T` is not tested. |
| `Mutex` | `v` is a Mutex. |
| `ModuleNamespace` | `v` is a ModuleNamespace. |
| `Ok<T>`, `Err<E>` | `v` is a variant of that kind; the payload is not tested. |
| `Result<T, E>` | `v` is an `Ok` or `Err`; payload types are not tested. |
| `T?` | `v` is `null` or `TypeTest(v, T)`. |
| `T \| U` | `TypeTest(v, T)` or `TypeTest(v, U)`. |
| `ptr<T>` | `v` is a native pointer; `T` is not tested. |

**8.6.14** Type arguments are not tested. A check of `Array<T>`,
`Tuple<...>`, `fn(...)`, `Promise<T>`, `Thread<T>`, `Result<T, E>`, `Ok<T>`, or
`Err<E>` establishes the outer constructor and, for a Tuple, its arity, but not
the element or payload types. Those are enforced only by static checking. A
program that obtains an `Array<number>` from a dynamic region and reads its
elements relies on the static checking of the producing region; the boundary
check does not validate them. This limitation is normative.

**8.6.15** A value of static type `any` MAY be used in every operation. The
operation follows its runtime rules and yields `any` unless its rule determines
a more specific type. `any` is narrowed only by a checked assignment,
parameter, result, or member store. A program MUST NOT rely on an `any` value
having any type without narrowing it.

**8.6.16** Strict mode does not change evaluation order, add conversions, or
change the result of an operation. Its only effects are the early errors of
8.6.7 and the Type Errors of boundary checks. A well-formed program whose
checks all succeed behaves exactly as the same program with all annotations
removed, except that the removed program might not have the same early errors.

**8.6.17** An implementation MAY elide a boundary check when it proves the check
cannot fail. It MUST NOT elide a check that could fail or reorder a check across
a side effect in a way that changes which error is observed. The absence of a
check is not observable except through the error that would have been thrown.

**8.6.18** Strictness is a static property of a declaration, not of a value: a
function value does not carry it, and a call through a function-typed value does
not change the callee's strictness. Boundary checks depend on the callee's
declaration and the call's static context, not the callee's dynamic type.

## 8.7 Type Inference and the Gradient

**8.7.1** Every binding has a *static type*, determined at compile time. It is
its annotation if present, otherwise the type inferred by 8.7.3, otherwise
`any`. The static type is a compile-time property; it does not change any value's
dynamic type and is not stored in a value.

**8.7.2** *Annotation-guided resolution*: an annotation is authoritative.
Inference MUST NOT widen, narrow, or replace it. An annotated binding whose
initializer has a different but consistent type receives a checked assignment;
an initializer that is neither a subtype nor consistent is an early error in a
strict region. In a dynamic region the annotation is not enforced (8.4.16).

**8.7.3** *Static CFG inference*: for an unannotated local binding, the
implementation computes the static type from the control-flow graph of the
enclosing function. The candidates are the static types of the initializer, if
any, and of every reachable assignment to the binding, including assignments in
nested closures that capture it. The inferred type is their join under 8.7.4.

**8.7.4** `Join(S, T)` is defined by the first applicable rule. The join is
commutative and associative and never produces a union other than an optional
type; a union requires an explicit annotation.

1. if `S` and `T` are the same type, the result is that type;
2. if `S` is `never`, the result is `T`; if `T` is `never`, the result is `S`;
3. if `S` or `T` is `any`, the result is `any`;
4. if `S <: T`, the result is `T`; if `T <: S`, the result is `S`;
5. if one of `S` and `T` is `null` and the other is not `any`, the result is
   the other type made optional;
6. otherwise the result is `any`.

**8.7.5** *Dynamic fallback*: if the join is `any`, the binding is a dynamic
fallback. The fallback is scoped to that binding alone: it does not make the
enclosing function dynamic, does not change any other binding's static type, and
does not disable static checking of the function. A function with one fallback
binding MAY still have statically typed parameters, results, and other locals.

**8.7.6** An unannotated parameter, result, or class property has static type
`any` in a strict region. Interprocedural inference is not part of the static
semantics: a parameter's type is not inferred from call sites, and a result's
type is not inferred from `return` statements. An implementation MAY use
interprocedural analysis for optimization but MUST NOT use it to accept a
program that 8.6.7 rejects or reject one that 8.6.7 accepts.

**8.7.7** A binding with an initializer and no annotation has the join of the
initializer type and all reachable assignment types. A binding without an
initializer has type `null` if no assignment reaches the binding, and the join of
its assignment types otherwise. An annotated binding does not participate in
inference, even when its annotation is `any`.

**8.7.8** A class property with an annotation has that type; without one it has
`any`. Stores to a property in a constructor or method are checked against the
property type in a strict region; a consistent but non-subtype store is a
checked store (8.6.11).

**8.7.9** Inference is *per binding*. Bindings with the same name in different
scopes have independent static types. A parameter and a local with the same name
are distinct bindings. A captured binding and its declaration are one binding;
a closure does not create a new static type for it.

**8.7.10** A captured binding has one static type for all closures that capture
it. Its candidates include every reachable assignment in the declaring function
and in every nested closure that captures it. The type is computed once for the
binding, not once per closure. An assignment of an unrelated type makes the
binding a dynamic fallback if the join is `any`.

**8.7.11** *Bind Once*: the static type of every binding is determined once at
compile time from the program text and its annotations, and is final for the
program's lifetime. Execution MUST NOT revise a static type, specialize a binding
to an observed type that differs from its static type, or change the static type
when a function is re-entered. A dynamic fallback remains a fallback for every
execution.

**8.7.12** *No deoptimization*: an implementation MUST NOT begin executing a
binding under one static type and later replace it with another. It MAY choose a
specialized representation for a non-`any` static type and MAY use observations
to select among observationally equivalent representations. It MUST NOT use an
observation to change a result, an error, or evaluation order. Bind Once is a
constraint on observable behaviour, not on a compilation strategy.

**8.7.13** The observations recorded in the metadata header of Clause 19.8 are
optimization information. They MAY select specialized opcodes or native
representations. They MUST NOT be treated as static types, override an
annotation, or be used to accept or reject a program. A slot observed as
`STATIC` or `OBSERVED` remains subject to 8.6.7 and 8.6.11.

**8.7.14** Inference is deterministic: every conforming implementation computes
the same static type for every binding of a given program. The representation,
the number of observations, and the execution tier do not affect the result.
This determinism ensures that the early errors of a strict region are the same
for every implementation and every tier.

## 8.8 Conversion and Coercion

**8.8.1** A *conversion* maps a value of one type to a value of another. A
*coercion* is an implicit conversion performed by an operator or construct.
Dryad defines only the coercions of this subclause. An implementation MUST NOT
introduce an unlisted implicit conversion or make a listed conversion depend on
the execution tier.

**8.8.2** `ToBoolean(v)` is total and is defined by Table 8.6. It is the only
operation used to evaluate a condition. Objects are always truthy, including an
empty Array, an empty object literal, a Function, a class, a Buffer, a Promise,
a Thread, a Mutex, and a namespace.

| Type of `v` | `ToBoolean(v)` |
|-------------|-----------------|
| `null` | `false`. |
| `bool` | `v`. |
| `number` | `false` for `+0`, `-0`, or `NaN`; `true` otherwise, including infinities. |
| `string` | `false` for the empty String; `true` otherwise. |
| `Object` and every object subtype | `true`. |
| Native numeric | `false` for zero; `true` otherwise. |
| `ptr<T>` | `true`. |
| `never` | No value exists. |

**8.8.3** `ToNumber(v)` is partial and is defined by Table 8.7. A String is
never converted to a Number implicitly; `ToNumber` on a String, `null`, an
Object, a Buffer, or a pointer throws a Type Error. The operation is used by the
arithmetic and bitwise operators of 8.8.8 through 8.8.12 and by the unary
operators of 8.8.11.
| Type of `v` | `ToNumber(v)` |
|-------------|----------------|
| `number` | `v`, preserving `NaN` and the sign of zero. |
| `bool` | `1` for `true`; `0` for `false`. |
| `null` | Type Error. |
| `string` | Type Error. |
| `Object` and every object subtype | Type Error. |
| `i8`..`i32`, `u8`..`u32` | The equal Number. |
| `never` | No value exists. |

**8.8.4** `ToString(v)` is partial and is defined by Table 8.8. It is used only
by `+` (8.8.10) and by explicit conversion functions of Clause 18. It is not
used by `print` or any diagnostic facility; the display form of a value is
specified in Clause 18 and is not `ToString`.

| Type of `v` | `ToString(v)` |
|-------------|----------------|
| `string` | `v`. |
| `number` | The String of 8.8.5. |
| `bool` | `"true"` or `"false"`. |
| `null` | `"null"`. |
| `Object` and every object subtype | Type Error. |
| `never` | No value exists. |

**8.8.5** `ToString` on a Number yields the shortest decimal numeral that reads
back as that Number under the correctly rounded conversion of 8.2.9; if two
shortest numerals are equally close, the one with the even final digit is
chosen. `NaN` yields `"NaN"`, the infinities yield `"Infinity"` and
`"-Infinity"`, and both zeros yield `"0"`. A finite nonzero Number uses decimal
notation without an exponent when its magnitude is in `[1e-6, 1e21)`, and
exponential notation otherwise, with a lowercase `e`, an explicit sign, and no
leading zeros in the exponent. A decimal point is omitted when the fractional
part is zero.

**8.8.6** Dryad has no `ToPrimitive`. No user-defined conversion hook exists: a
class cannot declare a method invoked implicitly by `+`, `==`, a condition, or
any other operator. `ToString` and `ToNumber` are not overridable. A class that
needs a textual or numeric projection MUST expose an ordinary method that the
program calls explicitly.

**8.8.7** `ToInt32` and `ToUint32` are defined in 8.2.13. They are used by the
bitwise operators of 8.8.12 and by no other operation. They are total on Numbers
and are applied after `ToNumber` when an operand is a Boolean.

**8.8.8** Table 8.9 lists every context that performs an implicit conversion.
A context not listed performs none.

| Context | Conversion |
|---------|------------|
| Binary `+` with at least one String | `ToString` on the other operand. |
| Binary `+` without a String | `ToNumber` on both operands. |
| `-`, `*`, `/`, `%`, `**` | `ToNumber` on both operands. |
| Unary `+`, unary `-` | `ToNumber` on the operand. |
| `&`, `\|`, `^`, `~`, `<<`, `>>`, `>>>` | `ToInt32` or `ToUint32` per 8.2.14. |
| `!`, conditions of `if`, `while`, `for`, `do`, `match` guards | `ToBoolean`. |
| `&&`, `\|\|` | `ToBoolean` on the left operand; the selected operand is returned unconverted. |
| `==`, `!=` | None. |
| Assignment, argument, `return`, `throw` | None. |
| Property keys | None; a non-String key is a Type Error. |
| Array, Tuple, String indices | None; a non-Number index is a Type Error. |

**8.8.9** Binary `+` is defined by Table 8.10. The row and column are the
operand types after evaluation. A *Type Error* cell throws before producing a
value. The table is symmetric except where noted.

| Left / Right | `number` | `bool` | `string` | `null` | Object/Buffer |
|--------------|----------|--------|----------|--------|---------------|
| `number` | Sum. | Sum after `ToNumber`. | Concatenation after `ToString`. | Type Error. | Type Error. |
| `bool` | Sum after `ToNumber`. | Sum after `ToNumber`. | Concatenation after `ToString`. | Type Error. | Type Error. |
| `string` | Concatenation after `ToString`. | Concatenation after `ToString`. | Concatenation. | Concatenation with `"null"`. | Type Error. |
| `null` | Type Error. | Type Error. | Concatenation with `"null"`. | Type Error. | Type Error. |
| Object/Buffer | Type Error. | Type Error. | Type Error. | Type Error. | Type Error. |

**8.8.10** `+` evaluates its left operand, then its right, then applies Table
8.10. Two Numbers yield their IEEE 754 sum (8.2.10). Two Booleans are converted
to Numbers and yield a Number. If at least one operand is a String and the other
is a String, Number, Boolean, or `null`, the other is converted with `ToString`
and the result is the concatenation, left operand first. Every other combination
throws a Type Error: Arrays, object literals, Functions, Buffers, and Promises
are never concatenated implicitly.

**8.8.11** Unary `+` applies `ToNumber` and returns the result; unary `-`
applies `ToNumber`, negates under IEEE 754, and returns the result; `!` applies
`ToBoolean` and negates; `~` applies `ToInt32`, complements the 32-bit pattern,
and returns the signed result as a Number. `typeof` is not an operator in
Edition 1.0; the dynamic type is available through 5.5.4 and Clause 18.

**8.8.12** Bitwise operators apply 8.2.14 and 8.8.7. A `null`, String, Object,
or Buffer operand throws a Type Error. A Boolean operand becomes `0` or `1`
before the 32-bit conversion. Every bitwise result is a Number in the signed
32-bit range, except `>>>`, whose result is in the unsigned 32-bit range.

**8.8.13** Conditions are converted with `ToBoolean`. `&&` and `||` evaluate
their left operand, convert it with `ToBoolean`, and return either operand
unconverted (Clause 9.12). `match` guards are converted with `ToBoolean`. No other
construct converts its operand.

**8.8.14** Apart from the `+` concatenation of 8.8.10, there is no implicit
conversion between a Number and a String in either direction. A program that
parses a String as a Number, or formats a Number for display, MUST use an
explicit operation of Clause 18. Apart from the same concatenation, there is no
implicit conversion between a Boolean and a String, between a primitive and an
Object, or between two object types. There is no boxing or unboxing.

**8.8.15** A conversion specified to throw throws a `DryadError` of category
*type* (Clause 14) naming the operation, the dynamic type of the offending
value, and the source location. The conversion operations are total where Table
8.6 says so and partial where Tables 8.7 and 8.8 say so; an implementation MUST
NOT substitute a default value for a failed conversion.

## 8.9 Equality

**8.9.1** `SameValue(x, y)` is the specification equality relation used where
exact identity of representation is required. It is defined as follows:

1. If `x` and `y` are both `null`, return `true`.
2. If both are Booleans, return `true` if they are the same Boolean.
3. If both are Numbers, then: if either is `NaN`, return `true` if both are
   `NaN` and `false` otherwise; if one is `+0` and the other `-0`, return
   `false`; otherwise return the IEEE 754 equality of the values.
4. If both are Strings, return `true` if their scalar-value sequences are equal.
5. If both are Objects, return `true` if they are the same Object.
6. If the dynamic types differ, return `false`.

**8.9.2** `SameValueZero(x, y)` is `SameValue` except that it returns `true`
for `+0` and `-0`. It is used by the collection operations of Clause 18 that
identify keys and elements. `SameValueZero(NaN, NaN)` is `true`.

**8.9.3** `==` never coerces. `x == y` is defined as
follows:

1. If the dynamic types differ, return `false`.
2. If both are `null`, return `true`.
3. If both are Booleans, return `true` if they are the same Boolean.
4. If both are Numbers, return IEEE 754 equality: `NaN` is unequal to every
   value including itself, and `+0` equals `-0`.
5. If both are Strings, return `true` if their scalar-value sequences are equal.
6. If both are Objects, return `true` if they are the same Object.

**8.9.4** `x != y` is `!(x == y)`. Edition 1.0 has no `===` or `!==` operator.
Because `==` never coerces, a strict-equality operator would be redundant; an
implementation MUST NOT provide one as an extension that changes the meaning of
`==`.

**8.9.5** String equality is equality of scalar-value sequences. It is not
equality of UTF-8 bytes, although the two coincide for well-formed Strings
because the encoding is canonical (8.2.17). It is unaffected by normalization:
`"\u00E9"` and `"e\u0301"` are different Strings. Ordering comparisons, where
Clause 9 defines them, use lexicographic order of scalar values.

**8.9.6** Equality of Objects is identity and nothing else. Two Arrays with
equal elements are unequal unless they are the same Array; the same holds for
Tuples, object literals, closures, and instances. Two instances of one class
with equal fields are unequal. Structural equality is not provided by `==`; a
structural comparison, if available, is a standard-library operation (Clause
18).

**8.9.7** An Object is never equal to a non-Object, and the comparison is
`false`, not a Type Error. `null == 0`, `false == 0`, `"" == 0`, and
`[] == ""` are all `false`. The absence of coercion is total: no operand type
causes `==` to throw, although evaluating an operand can throw.

**8.9.8** `NaN` is unequal to itself under `==`, so `x == x` is `false` when `x`
is `NaN`, and `==` MUST NOT be used to test for `NaN`. `SameValue(NaN, NaN)` and
`SameValueZero(NaN, NaN)` are `true`; a program recognizes `NaN` through a
standard-library predicate (Clause 18) or a `match` pattern where one is
provided. `+0` and `-0` are equal under `==` and `SameValueZero`, and distinct
under `SameValue`.

**8.9.9** `null` equals only `null`, not `false`, `0`, `""`, or any Object. The
empty Array and object literal are truthy (8.8.2) and unequal to `null` and to
each other.

**8.9.10** A native integer that has crossed into language code is a Number and
compares by 8.9.3. Two `ptr<T>` values compare by address identity; a pointer
never equals a Number, String, or Object. Two `i64`, `u64`, `isize`, or `usize`
values of the same native type compare by integer value; comparing different
native types requires an explicit conversion (Clause 16).

**8.9.11** Equality is used by the collection operations of Clause 18 through
`SameValueZero` and by `==` through 8.9.3. An implementation MUST use the
specified relation: the wrong relation would make the zeros distinguishable or
`NaN` unusable as a key. For example:

```dryad
print(0 == -0);
print(0 / 0 == 0 / 0);
let a = [1, 2];
let b = [1, 2];
print(a == b);
print(a == a);
```

## 8.10 Well-Formedness

**8.10.1** This subclause states the conditions under which the type-related
constructs of a program are well-formed. A violation of 8.10.2 through 8.10.11
is an early error (Clause 14.8) and makes the program ill-formed. The conditions
are checked before execution and are independent of the execution tier.

**8.10.2** A type expression MUST conform to 8.4.2, and an annotation MUST
appear only in a position listed in 8.4.7. An unparsable type expression or an
annotation elsewhere is an early error.

**8.10.3** Every `<NamedType>` MUST resolve to a type denotation under 8.4.4.
An identifier that resolves only to a value binding, or to nothing, is an early
error. This applies in dynamic regions as well as strict regions, because
well-formedness of the annotation is independent of enforcement.

**8.10.4** A parameterized type name MUST receive an arity permitted by 8.4.6.
A type argument on an arity-zero name, too many arguments, or `Tuple<T1>` or
`Tuple<>` is an early error. Omitting trailing arguments is permitted and
defaults them to `any`.

**8.10.5** A native type name MUST appear only in a context permitted by 8.4.9.
A native type in a dynamic region outside an extern or intrinsic declaration is
an early error. A `ptr<T>` whose argument is not a native type or `void` is an
early error. A native-only type used as a type argument to `Array`, `Tuple`,
`Promise`, `Thread`, `Result`, `Ok`, `Err`, or a function type in language code
is an early error.

**8.10.6** A function, method, constructor, arrow function, extern declaration,
or intrinsic declaration MUST NOT declare two parameters with the same name. A
duplicate parameter name is an early error regardless of the parameter types. A
function type has no parameter names and is not subject to this rule.

**8.10.7** A declaration MUST NOT carry both `@strict` and `@dynamic`. Either
decorator on a declaration other than a function or method is an early error. A
duplicate application of the same decorator to one declaration is an early
error.

**8.10.8** In a strict region, an initialization, assignment, argument,
`return`, or member store whose source type is neither a subtype nor consistent
with the target is an early error (8.5.19). In a dynamic region the same
construct is well-formed, because annotations are not enforced (8.4.16).

**8.10.9** In a strict region, a call to a non-callable static type, a call with
an unacceptable argument count, a property read of a member absent from a class
or interface type, an operand outside an operator's domain, and a `new` with
arguments not assignable to the constructor are early errors (8.6.7 through
8.6.10). In a dynamic region they are runtime errors, or ordinary operations
where the operation is defined for the value.

**8.10.10** An annotated declaration without an initializer is well-formed in a
strict region only if `null` is assignable to the annotation; otherwise it is an
early error. `let x: number;` is therefore an early error in a strict region,
while `let x: number?;` and `let y: any;` are well-formed. In a dynamic region
the declaration is well-formed and the binding holds `null` (Clause 10).

**8.10.11** A class or interface declaration MUST NOT use a predeclared type
name of Table 8.2. Such a declaration is an early error. A value declaration MAY
use such a name; it introduces a value binding only and does not affect type
resolution (8.4.17).

**8.10.12** Not early errors: a union with duplicates or `never`, an optional
whose base contains `null`, an annotation of `any`, `f64`/`bool`/`void` outside a
native declaration, and an annotation mismatch in a dynamic region. These are
normalized or ignored under 8.4.

**8.10.13** An implementation SHOULD report every early error it can determine
in one pass but MAY stop at the first. Order is not observable except through the
diagnostic text (Clause 14). An implementation MUST NOT defer an early error to
execution.

## 8.11 Conformance Requirements

**8.11.1** A conforming implementation MUST implement every type, value kind,
relation, conversion, and equality rule of this clause for its claimed class
(Clause 2). It MUST reject every program that 8.10 classifies as ill-formed and
MUST NOT reject a program that 8.10 does not classify as ill-formed, except for
the resource limits permitted by 8.11.8 or a facility rejected as unsupported
under Clause 2.9.

**8.11.2** An implementation MUST preserve every value's dynamic type and MUST
report dynamic types consistently with 8.2 and 8.3. It MUST distinguish `+0` from
`-0` under `SameValue`, treat all `NaN` values as one value, and never expose a
NaN payload or sign.

**8.11.3** An implementation MUST implement `ToBoolean`, `ToNumber`, `ToString`,
`ToInt32`, `ToUint32`, `SameValue`, `SameValueZero`, `==`, and `!=` exactly as
specified. In particular, it MUST NOT coerce in `==`, treat an empty Array or
object literal as falsy, or convert a String to a Number implicitly.

**8.11.4** An implementation MUST implement Strings as sequences of Unicode
scalar values with UTF-8 storage, measure length in scalar values, index by
scalar value, and replace ill-formed input with U+FFFD as specified in 8.2.20.
It MUST NOT measure length in bytes or UTF-16 code units in a language-level
length operation.

**8.11.5** An implementation MUST implement Numbers as IEEE 754-2019 binary64,
round after each operation, avoid extended precision, and implement division and
remainder as specified in 8.2.11. An interpreter, a bytecode VM, and an AOT
binary MUST produce identical Number results for the same program.

**8.11.6** An implementation MUST implement strict mode, the boundary checks of
8.6.11, and `TypeTest` of 8.6.13 for every strict region. It MUST NOT enforce
annotations in a dynamic region, change evaluation order in a strict region, or
omit a boundary check that could fail.

**8.11.7** All execution tiers MUST be observationally equivalent with respect
to this clause (Clause 6.4.2). An implementation MUST NOT use the tier, a
bytecode or AOT pipeline, or collected type observations to change a static
type, an early error, a conversion, an equality result, or a boundary check.

**8.11.8** An implementation MAY impose resource limits on String length, Array
length, Buffer size, Tuple arity, or heap size. Exceeding a limit MUST produce a
`DryadError` (Clause 14), not an undefined result,
truncation, or silent failure. Limits MUST be documented as implementation-
defined (Clause 2.5).

**8.11.9** Implementation-defined behaviours are the limits of 8.11.8, diagnostic
wording, the number of early errors reported per pass, and the display form used
by `print` (Clause 18). No other behaviour in this clause is
implementation-defined or implementation-dependent.

**8.11.10** An implementation SHOULD pass the Clause 23 tests covering this
clause; passing them is evidence of conformance but does not replace 8.1 through
8.10.

## 8.12 Early Errors

**8.12.1** The early errors of this clause are: (1) a type expression that
violates 8.4.2, or an annotation in a position forbidden by 8.4.7; (2) an
unresolved type name (8.4.4); (3) an invalid type-argument arity, including
`Tuple<T1>` and `Tuple<>` (8.4.6); (4) a native type outside a permitted
context, a `ptr<T>` with a non-native argument, or a native-only type argument
in language code (8.4.9, 8.4.11); (5) a duplicate parameter name (8.10.6);
(6) conflicting, misplaced, or duplicate `@strict`/`@dynamic` (8.6.6); (7) a
strict-region flow that is neither a subtype nor consistent (8.5.19, 8.6.7);
(8) a strict-region call, member read, operator, or `new` that violates 8.6.7
through 8.6.10; (9) a strict annotated declaration without an initializer whose
type excludes `null` (8.10.10); and (10) a class or interface declared with a
predeclared type name (8.4.17).

**8.12.2** The errors of 8.10.8 through 8.10.10 depend on the strictness of the
region. In a dynamic region the same source text is well-formed, and the
condition is ignored or reported at runtime by the operation that encounters it.

**8.12.3** Clause 8 introduces no early error for a redundant union, a redundant
optional, an annotation of `any`, or the use of `f64`, `bool`, or `void`. An
implementation MUST NOT reject such a construct under this clause.

**8.12.4** An early error under this clause MUST identify the source location of
the offending annotation or construct and MUST name the clause of the violated
condition. The diagnostic text is otherwise governed by Clause 14. For example,
the following program is ill-formed in a strict region because `count` is
initialized with a String:

```dryad
"use strict types";

let count: number = "zero";
```
