# 4 Terms and Definitions

For the purposes of this document, the following terms and definitions apply.
Terms are listed alphabetically. Cross-references use clause numbers.

**Abstract operation.** A named algorithm defined by this document. Abstract
operations are not callable from Dryad source text; they define semantics.

**Agent.** An independent unit of execution with its own execution context and
job queue. A Dryad program executes in at least one agent. Threads created by
`thread function` execute in separate agents (Clause 15).

**AOT compilation.** Ahead-of-time compilation: translation of a Dryad program
to native code before execution, as specified in Clause 20.

**Binding.** The association between an identifier and a value within an
environment record.

**Buffer.** A contiguous, bounds-checked byte region with an explicit length
and capacity (Clause 17.5).

**Bytecode.** The stack-based instruction format defined in Clause 19.

**Call frame.** The runtime record that stores the state of an active function
invocation.

**Class.** A value that defines a nominal object type, its constructor, its
instance members, and its static members (Clause 11).

**Completion record.** A specification value that records how evaluation of a
statement or expression terminated. A completion record is one of *normal*,
*break*, *continue*, *return*, or *throw* (Clause 10.2).

**Conforming implementation.** An implementation that satisfies Clause 2.

**Directive.** A syntactic construct beginning with `#` that instructs the
implementation, such as a native-module directive `#<io>` (Clause 7.10), or a
string-literal directive such as `"use strict types"` (Clause 8.6).

**Dynamic type.** The type of a value at runtime. Every value has exactly one
dynamic type (Clause 8).

**Early error.** A condition that makes a program ill-formed and that MUST be
detected before execution, during parsing or static analysis (Clause 14.8).

**Environment record.** A specification data structure that maps identifiers
to bindings and that may have an outer environment reference (Clause 13.2).

**Execution context.** The specification state associated with the evaluation
of a program, module, function, or block. An execution context includes a
lexical environment, a variable environment, and a `this` binding (Clause 13.2).

**Export.** A binding made available by a module to importing modules
(Clause 12.3).

**Expression.** A syntactic construct that evaluates to a value (Clause 9).

**FFI.** Foreign function interface: the boundary between Dryad and code
implemented in another language (Clause 16).

**Function.** A callable value with a parameter list, a body, and a captured
lexical environment (Clause 11).

**HAL.** Hardware abstraction layer: the small set of platform-specific
operations beneath the intrinsic layer (Clause 17.4).

**Host.** The environment in which a conforming implementation executes,
including its operating system, filesystem, network stack, and clock.

**Identifier.** A lexical token that names a binding, property, label, or
module (Clause 7.5).

**Implementation-defined.** A behaviour for which a conforming implementation
MUST document its choice (Clause 2.5).

**Implementation-dependent.** A behaviour for which a conforming
implementation may choose freely without documentation (Clause 2.5).

**Intrinsic.** A primitive operation exposed by the runtime and declared in
Dryad with `@intrinsic` (Clause 17.2).

**Job.** A unit of work scheduled on an agent's job queue, used to implement
promises and asynchronous functions (Clause 15.4).

**Lexical grammar.** The grammar that defines how source text is divided into
tokens (Clause 7).

**Lexical token.** An indivisible lexical unit produced by the lexer
(Clause 7.4).

**Module.** A source-text unit with its own scope, exports, and module record
(Clause 12).

**Module record.** The specification data structure that records a module's
exports, imports, and evaluation state (Clause 12.1).

**Module specifier.** The string or identifier that names a module in an
import declaration (Clause 12.4).

**Native directive.** The token `#<identifier>` that loads a native module
(Clause 7.10).

**Native module.** A host-implemented module exposed through the FFI or the
intrinsic layer (Clauses 16, 17).

**Native type.** A machine-level type used by the runtime, AOT compiler, and
FFI, such as `f64`, `i32`, or `usize` (Clause 8.3).

**Normal completion.** A completion record indicating that evaluation
continued to the next construct without an abrupt transfer of control
(Clause 10.2).

**Object.** A value that groups properties and has an identity independent of
its contents (Clause 8.3).

**Observable behaviour.** The behaviour listed in Clause 1.2.

**Program.** A collection of one or more modules, one of which is the entry
module. Execution begins at the entry module (Clause 13.7).

**Promise.** A value representing the eventual result of an asynchronous
operation (Clause 15.3).

**Property.** A named or indexed member of an object.

**Realm.** The set of intrinsic objects and global bindings associated with an
agent. A realm is created when an agent is created (Clause 13.1).

**Scope.** The region of source text in which a binding is visible, together
with the rules that determine visibility (Clause 13.3).

**Shape.** A compiler-internal description of an object's property layout, used
by the AOT compiler (Clause 20.4).

**Source text.** A sequence of Unicode code points encoded in UTF-8
(Clause 7.1).

**Standard library (STDLIB).** The collection of modules specified in
Clause 18 and implemented in pure Dryad.

**Statement.** A syntactic construct that performs an action and produces a
completion record rather than a value (Clause 10).

**Static semantics.** Rules that constrain well-formed programs and that are
enforced before execution, including early errors and type checking
(Clauses 8, 22).

**Strict mode.** The optional static typing mode enabled by
`"use strict types"` (Clause 8.6).

**Syscall.** A primitive operation in the intrinsic set that corresponds to an
operating-system service (Clause 17.3).

**Thread.** An independent agent created by a `thread function` declaration or
a thread-creation operation (Clause 15.1).

**Type.** A set of values. The dynamic type of a value determines the
operations that are defined on it (Clause 8).

**Type annotation.** A syntactic type expression attached to a declaration,
parameter, return position, or expression (Clause 8.4).

**Value.** A member of a Dryad type. Values are the results of expressions and
the contents of bindings (Clause 8).

**Variable.** A binding whose value may be changed after declaration.

**Well-formed program.** A program that satisfies every early error rule of
this document (Clause 1.4).
