# Bitwise Operators Implementation Plan (Wave L)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `&`, `|`, `^`, `~`, `<<` and `>>` to the Dryad language with defined 64-bit integer semantics in the interpreter, bytecode VM and AOT pipeline.

**Architecture:** The operators are language syntax, not intrinsics. They flow through the existing pipeline: lexer tokens → `BinaryExpression`/`UnaryExpression` with C-style precedence → interpreter evaluation → bytecode opcodes → VM dispatch → micro-IR lowering. AOT keeps the existing "slow path" behaviour for generic integer ops, so the new opcodes lower to `IntrinsicSlow` exactly like `MOD`.

**Tech Stack:** C++17, Google Test, CMake, Dryad interpreter/bytecode VM/AOT.

**Spec:** `docs/implementation/plans/2026-11-02-stdlib-expansion-design.md` (sections 6, 8.2, 10/A4, 20)

## Global Constraints

- Operators are 64-bit signed integers (`int64_t`). Floats and strings are rejected with a `DryadException`; no implicit conversion.
- Shift counts are masked with `count & 63`; shifting by 64, 65 or a negative count must never be undefined behaviour.
- `>>` is an arithmetic (sign-propagating) right shift. `<<` wraps modulo 2^64.
- `~` is unary only; there is no compound assignment (`&=`, `|=`, `^=`, `<<=`, `>>=`) in this wave.
- Precedence follows C/JS: `||` < `&&` < `|` < `^` < `&` < `==`/`!=` < relational < `<<`/`>>` < `+`/`-` < `*`/`/`/`%` < unary.
- No new intrinsics and no new opcodes outside `0x21–0x26`.
- Existing `&&`/`||` evaluation behaviour (both operands evaluated) is unchanged.
- Build must stay warning-free (`-Wall -Wextra -Werror`) and `ctest` green.

## Review Focus

- `1 & 3 == 1` — a reader expects `1 & (3 == 1)`, because equality binds tighter than `&`. Pinned by `ParserTest.EqualityBindsTighterThanBitwiseAnd`.
- `1 << 64` — a reader expects a defined result, not UB. Pinned by `LanguageFeaturesTest.ShiftCountsAreMasked` and `VMTest.ShiftCountsAreMasked`.
- `1.5 & 1` — a reader expects a clear error. Pinned by `LanguageFeaturesTest.BitwiseRejectsFloats`.
- `-16 >> 2` — a reader expects `-4`, not `1073741820`. Pinned by `LanguageFeaturesTest.BitwiseOperations`.
- `a &&& b` — a reader expects a syntax error, not a crash or silent misparse. Pinned by `LexerTest.AmpersandRuns`.
- `9223372036854775807 + 1` through `<<` — wraparound must be defined, not UB. Pinned by `VMTest.LeftShiftWraps`.

---

### Task 1: Tokens and lexer

**Files:**
- Modify: `src/include/dryad/compiler/token.h` (enum `TokenType`, after `PipePipe`)
- Modify: `src/src/compiler/token.cpp` (`Token::is_operator`, `token_type_to_string`)
- Modify: `src/src/compiler/lexer.cpp` (`scan_token`, cases for `<`, `>`, `&`, `|`, `^`, `~`)
- Test: `src/tests/unit/lexer_test.cpp`

**Interfaces:**
- Consumes: nothing.
- Produces: `TokenType::Ampersand`, `Pipe`, `Caret`, `Tilde`, `LessLess`, `GreaterGreater`, with lexemes `"&"`, `"|"`, `"^"`, `"~"`, `"<<"`, `">>"`.

- [ ] **Step 1: Write the failing lexer tests**

Append to `src/tests/unit/lexer_test.cpp`:

```cpp
TEST(LexerTest, BitwiseOperators) {
    Lexer lexer("& | ^ ~ << >>");
    auto tokens = lexer.tokenize();
    ASSERT_EQ(tokens.size(), 7);
    EXPECT_EQ(tokens[0].type, TokenType::Ampersand);
    EXPECT_EQ(tokens[1].type, TokenType::Pipe);
    EXPECT_EQ(tokens[2].type, TokenType::Caret);
    EXPECT_EQ(tokens[3].type, TokenType::Tilde);
    EXPECT_EQ(tokens[4].type, TokenType::LessLess);
    EXPECT_EQ(tokens[5].type, TokenType::GreaterGreater);
    EXPECT_EQ(tokens[6].type, TokenType::EndOfFile);
}

TEST(LexerTest, BitwiseDoesNotBreakLogicalOrComparison) {
    Lexer lexer("&& || <= >= < >");
    auto tokens = lexer.tokenize();
    ASSERT_EQ(tokens.size(), 7);
    EXPECT_EQ(tokens[0].type, TokenType::AmpersandAmpersand);
    EXPECT_EQ(tokens[1].type, TokenType::PipePipe);
    EXPECT_EQ(tokens[2].type, TokenType::LessEqual);
    EXPECT_EQ(tokens[3].type, TokenType::GreaterEqual);
    EXPECT_EQ(tokens[4].type, TokenType::Less);
    EXPECT_EQ(tokens[5].type, TokenType::Greater);
}

TEST(LexerTest, AmpersandRuns) {
    Lexer lexer("a &&& b");
    auto tokens = lexer.tokenize();
    ASSERT_EQ(tokens.size(), 4);
    EXPECT_EQ(tokens[0].type, TokenType::Identifier);
    EXPECT_EQ(tokens[1].type, TokenType::AmpersandAmpersand);
    EXPECT_EQ(tokens[2].type, TokenType::Ampersand);
    EXPECT_EQ(tokens[3].type, TokenType::Identifier);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='LexerTest.Bitwise*:LexerTest.AmpersandRuns'`
Expected: FAIL to compile with `TokenType::Ampersand` not declared.

- [ ] **Step 3: Add the tokens and lexer cases**

In `src/include/dryad/compiler/token.h`, add after `PipePipe`:

```cpp
Ampersand,       // &
Pipe,            // |
Caret,           // ^
Tilde,           // ~
LessLess,        // <<
GreaterGreater,  // >>
```

In `src/src/compiler/token.cpp`, change the `is_operator()` upper bound from `TokenType::PipePipe` to `TokenType::GreaterGreater`, and add the six lexeme entries next to `"&&"`/`"||"`.

In `src/src/compiler/lexer.cpp`:

```cpp
case '<':
    if (match('<')) return Token(TokenType::LessLess, "<<", start_loc);
    if (match('=')) return Token(TokenType::LessEqual, "<=", start_loc);
    return Token(TokenType::Less, "<", start_loc);

case '>':
    if (match('>')) return Token(TokenType::GreaterGreater, ">>", start_loc);
    if (match('=')) return Token(TokenType::GreaterEqual, ">=", start_loc);
    return Token(TokenType::Greater, ">", start_loc);

case '&':
    if (match('&')) return Token(TokenType::AmpersandAmpersand, "&&", start_loc);
    return Token(TokenType::Ampersand, "&", start_loc);

case '|':
    if (match('|')) return Token(TokenType::PipePipe, "||", start_loc);
    return Token(TokenType::Pipe, "|", start_loc);

case '^': return Token(TokenType::Caret, "^", start_loc);
case '~': return Token(TokenType::Tilde, "~", start_loc);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='LexerTest.*'`
Expected: PASS, including all pre-existing lexer tests.

- [ ] **Step 5: Commit**

```bash
git add src/include/dryad/compiler/token.h src/src/compiler/token.cpp src/src/compiler/lexer.cpp src/tests/unit/lexer_test.cpp
git commit -m "feat(lexer): add bitwise operators"
```

---

### Task 2: Parser precedence

**Files:**
- Modify: `src/include/dryad/compiler/parser.h` (declare `parse_bitwise_or`, `parse_bitwise_xor`, `parse_bitwise_and`, `parse_shift`)
- Modify: `src/src/compiler/parser.cpp` (precedence chain and unary `~`)
- Test: `src/tests/unit/parser_test.cpp`

**Interfaces:**
- Consumes: `TokenType::Ampersand`, `Pipe`, `Caret`, `Tilde`, `LessLess`, `GreaterGreater`.
- Produces: `BinaryExpression` nodes whose `op` is one of the new token types, with C-style nesting.

- [ ] **Step 1: Write the failing parser tests**

Append to `src/tests/unit/parser_test.cpp`:

```cpp
namespace {

BinaryExpression* parse_binary_root(const std::string& source) {
    auto program = parse(source);
    auto* stmt = dynamic_cast<ExpressionStatement*>(program->statements[0].get());
    return dynamic_cast<BinaryExpression*>(stmt->expression.get());
}

} // namespace

TEST(ParserTest, BitwiseAndBindsTighterThanOr) {
    auto* root = parse_binary_root("1 | 2 & 3;");
    ASSERT_NE(root, nullptr);
    EXPECT_EQ(root->op, TokenType::Pipe);
    auto* right = dynamic_cast<BinaryExpression*>(root->right.get());
    ASSERT_NE(right, nullptr);
    EXPECT_EQ(right->op, TokenType::Ampersand);
}

TEST(ParserTest, EqualityBindsTighterThanBitwiseAnd) {
    auto* root = parse_binary_root("1 & 3 == 1;");
    ASSERT_NE(root, nullptr);
    EXPECT_EQ(root->op, TokenType::Ampersand);
    auto* right = dynamic_cast<BinaryExpression*>(root->right.get());
    ASSERT_NE(right, nullptr);
    EXPECT_EQ(right->op, TokenType::EqualEqual);
}

TEST(ParserTest, ShiftBindsTighterThanComparison) {
    auto* root = parse_binary_root("1 << 2 < 5;");
    ASSERT_NE(root, nullptr);
    EXPECT_EQ(root->op, TokenType::Less);
    auto* left = dynamic_cast<BinaryExpression*>(root->left.get());
    ASSERT_NE(left, nullptr);
    EXPECT_EQ(left->op, TokenType::LessLess);
}

TEST(ParserTest, AdditionBindsTighterThanShift) {
    auto* root = parse_binary_root("1 << 2 + 1;");
    ASSERT_NE(root, nullptr);
    EXPECT_EQ(root->op, TokenType::LessLess);
    auto* right = dynamic_cast<BinaryExpression*>(root->right.get());
    ASSERT_NE(right, nullptr);
    EXPECT_EQ(right->op, TokenType::Plus);
}

TEST(ParserTest, TildeIsUnary) {
    auto program = parse("~value;");
    auto* stmt = dynamic_cast<ExpressionStatement*>(program->statements[0].get());
    auto* unary = dynamic_cast<UnaryExpression*>(stmt->expression.get());
    ASSERT_NE(unary, nullptr);
    EXPECT_EQ(unary->op, TokenType::Tilde);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='ParserTest.Bitwise*:ParserTest.EqualityBindsTighterThanBitwiseAnd:ParserTest.Shift*:ParserTest.AdditionBindsTighterThanShift:ParserTest.TildeIsUnary'`
Expected: FAIL — the parser does not yet produce the expected nodes (`root->op` is `Plus`/`Pipe` in the wrong place, or `~` is a parse error).

- [ ] **Step 3: Implement the precedence chain**

In `src/src/compiler/parser.cpp`, make the call chain:

```text
parse_assignment
  → parse_logical_or
    → parse_logical_and
      → parse_bitwise_or        (loop Pipe)
        → parse_bitwise_xor     (loop Caret)
          → parse_bitwise_and   (loop Ampersand)
            → parse_equality
              → parse_comparison
                → parse_shift   (loop LessLess, GreaterGreater)
                  → parse_addition
                    → parse_multiplication
                      → parse_unary
```

Each new function mirrors the existing `parse_logical_and` shape: `while (match(...)) { TokenType op = previous().type; auto right = parse_<next>(); expr = std::make_unique<BinaryExpression>(op, std::move(expr), std::move(right), previous().location); }`.

In `parse_unary`, add `TokenType::Tilde` to the `match({TokenType::Bang, TokenType::Minus})` list.

Declare the four new methods in `src/include/dryad/compiler/parser.h` next to `parse_logical_and`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='ParserTest.*'`
Expected: PASS, including all pre-existing parser tests.

- [ ] **Step 5: Commit**

```bash
git add src/include/dryad/compiler/parser.h src/src/compiler/parser.cpp src/tests/unit/parser_test.cpp
git commit -m "feat(parser): add bitwise precedence and unary tilde"
```

---

### Task 3: Interpreter evaluation

**Files:**
- Modify: `src/include/dryad/compiler/evaluator.h` (declare `evaluate_bitwise`)
- Modify: `src/src/compiler/evaluator.cpp` (`evaluate_binary`, `evaluate_unary`, new `evaluate_bitwise`)
- Modify: `src/src/compiler/semantic_analyzer.cpp` (`is_arithmetic` or a new bitwise predicate, `infer_binary_type`)
- Test: `src/tests/unit/language_features_test.cpp`

**Interfaces:**
- Consumes: `TokenType` values and `BinaryExpression`/`UnaryExpression` from Tasks 1–2.
- Produces: `Value ExpressionEvaluator::evaluate_bitwise(TokenType op, const Value& left, const Value& right)` with the semantics below; semantic analyzer returns `"number"` for integer bitwise expressions.

- [ ] **Step 1: Write the failing interpreter tests**

Append to `src/tests/unit/language_features_test.cpp` (include `"dryad/common/utils.h"` at the top for `DryadException`):

```cpp
TEST(LanguageFeaturesTest, BitwiseOperations) {
    const std::string source = R"(
        let a = 6 & 3;
        let b = 6 | 3;
        let c = 6 ^ 3;
        let d = ~0;
        let e = 1 << 4;
        let f = -16 >> 2;
        let result = a == 2 && b == 7 && c == 5 && d == -1 && e == 16 && f == -4;
    )";
    EXPECT_TRUE(run_source(source).is_truthy());
}

TEST(LanguageFeaturesTest, BitwisePrecedence) {
    const std::string source = R"(
        let result = (1 | 2 & 3) == 3 && (7 ^ 3 & 1) == 6 && (1 << 2 + 1) == 8;
    )";
    EXPECT_TRUE(run_source(source).is_truthy());
}

TEST(LanguageFeaturesTest, BitwiseRejectsBooleans) {
    // `1 & 3 == 1` parses as `1 & (3 == 1)`; equality yields a boolean, which
    // bitwise operators reject instead of coercing to 0/1.
    EXPECT_THROW(run_source("let result = 1 & 3 == 1;"), DryadException);
}

TEST(LanguageFeaturesTest, ShiftCountsAreMasked) {
    const std::string source = R"(
        let result = (1 << 64) == 1 && (1 << 65) == 2 && (16 >> 64) == 16;
    )";
    EXPECT_TRUE(run_source(source).is_truthy());
}

TEST(LanguageFeaturesTest, BitwiseRejectsFloats) {
    EXPECT_THROW(run_source("let result = 1.5 & 1;"), DryadException);
    EXPECT_THROW(run_source("let result = 1 | 2.5;"), DryadException);
    EXPECT_THROW(run_source("let result = ~1.5;"), DryadException);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='LanguageFeaturesTest.Bitwise*:LanguageFeaturesTest.ShiftCountsAreMasked'`
Expected: FAIL with `Unknown binary operator` / `Unknown unary operator`, or a parse failure before that.

- [ ] **Step 3: Implement evaluation**

In `evaluate_binary`, add the five binary cases and delegate:

```cpp
case TokenType::Ampersand:
case TokenType::Pipe:
case TokenType::Caret:
case TokenType::LessLess:
case TokenType::GreaterGreater:
    return evaluate_bitwise(expr->op, left, right);
```

Implement `evaluate_bitwise` with this contract: both operands must be `is_integer()`, otherwise throw `DryadException("Bitwise operators require integer operands")`. Then:

```cpp
const int64_t l = left.as_integer();
const int64_t r = right.as_integer();
switch (op) {
    case TokenType::Ampersand:      return Value(l & r);
    case TokenType::Pipe:           return Value(l | r);
    case TokenType::Caret:          return Value(l ^ r);
    case TokenType::LessLess:       return Value(static_cast<int64_t>(static_cast<uint64_t>(l) << (r & 63)));
    case TokenType::GreaterGreater: return Value(l >> (r & 63));
    default: throw DryadException("Unknown bitwise operator");
}
```

In `evaluate_unary`, add:

```cpp
case TokenType::Tilde:
    if (!operand.is_integer()) throw DryadException("Bitwise operators require integer operands");
    return Value(~operand.as_integer());
```

In `semantic_analyzer.cpp`, include the bitwise token types in the integer arithmetic classification used by `infer_binary_type` so integer expressions infer `"number"`. Do not classify them as comparison/logical.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='LanguageFeaturesTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/include/dryad/compiler/evaluator.h src/src/compiler/evaluator.cpp src/src/compiler/semantic_analyzer.cpp src/tests/unit/language_features_test.cpp
git commit -m "feat(interpreter): evaluate bitwise operators"
```

---

### Task 4: Bytecode opcodes, compiler and VM

**Files:**
- Modify: `src/include/dryad/runtime/opcode.h` (new block `0x21–0x26`)
- Modify: `src/src/runtime/opcode.cpp` (`opcode_name`)
- Modify: `src/src/compiler/bytecode_compiler.cpp` (`compile_binary`, `compile_unary`)
- Modify: `src/src/runtime/vm.cpp` (`execute` dispatch)
- Test: `src/tests/unit/bytecode_compiler_test.cpp`, `src/tests/unit/vm_test.cpp`

**Interfaces:**
- Consumes: parser/evaluator semantics from Tasks 1–3.
- Produces: `Opcode::BIT_AND = 0x21`, `BIT_OR = 0x22`, `BIT_XOR = 0x23`, `BIT_NOT = 0x24`, `SHL = 0x25`, `SHR = 0x26`; compiled functions emit them.

- [ ] **Step 1: Write the failing bytecode tests**

In `src/tests/unit/bytecode_compiler_test.cpp`:

```cpp
TEST(BytecodeCompilerTest, EmitsBitwiseOpcodes) {
    const std::string source = R"(
        function f(a, b) {
            let x = a & b;
            let y = a | b;
            let z = a ^ b;
            let n = ~a;
            let l = a << b;
            let r = a >> b;
            return x + y + z + n + l + r;
        }
    )";

    auto fn = compile_named_function(source, "f", nullptr);
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::BIT_AND));
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::BIT_OR));
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::BIT_XOR));
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::BIT_NOT));
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::SHL));
    EXPECT_TRUE(code_contains_opcode(fn.module, Opcode::SHR));
}
```

In `src/tests/unit/vm_test.cpp`:

```cpp
TEST_F(VMTest, BitwiseOpcodes) {
    BytecodeBuilder builder;
    builder.emit_push_int(6);
    builder.emit_push_int(3);
    builder.emit(Opcode::BIT_AND);
    builder.emit_halt();
    vm.load(builder.build());
    vm.execute();
    EXPECT_EQ(vm.get_stack_top().as_integer(), 2);
}

TEST_F(VMTest, ShiftCountsAreMasked) {
    BytecodeBuilder builder;
    builder.emit_push_int(1);
    builder.emit_push_int(64);
    builder.emit(Opcode::SHL);
    builder.emit_halt();
    vm.load(builder.build());
    vm.execute();
    EXPECT_EQ(vm.get_stack_top().as_integer(), 1);
}

TEST_F(VMTest, LeftShiftWraps) {
    BytecodeBuilder builder;
    builder.emit_push_int(1);
    builder.emit_push_int(63);
    builder.emit(Opcode::SHL);
    builder.emit_halt();
    vm.load(builder.build());
    vm.execute();
    EXPECT_EQ(vm.get_stack_top().as_integer(), -9223372036854775807LL - 1);
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytecodeCompilerTest.EmitsBitwiseOpcodes:VMTest.BitwiseOpcodes:VMTest.ShiftCountsAreMasked:VMTest.LeftShiftWraps'`
Expected: FAIL to compile with `Opcode::BIT_AND` not declared.

- [ ] **Step 3: Add opcodes, compiler cases and VM dispatch**

In `src/include/dryad/runtime/opcode.h`, add after `NOT`:

```cpp
// Bitwise (0x21–0x26)
BIT_AND     = 0x21,
BIT_OR      = 0x22,
BIT_XOR     = 0x23,
BIT_NOT     = 0x24,
SHL         = 0x25,
SHR         = 0x26,
```

In `src/src/runtime/opcode.cpp`, add all six names.

In `compile_binary`, add cases mapping each token to its opcode. In `compile_unary`, add `case TokenType::Tilde: builder_.emit(Opcode::BIT_NOT); break;`.

In `vm.cpp` dispatch, add integer-only cases mirroring `MOD`'s stack handling. Use the same masking rule as the interpreter (`static_cast<uint64_t>(l) << (r & 63)` for `SHL`, `l >> (r & 63)` for `SHR`). Throw `DryadException("Bitwise operators require integer operands")` for non-integers, and `"BIT_NOT requires integer operand"` for `BIT_NOT`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='BytecodeCompilerTest.*:VMTest.*'`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/include/dryad/runtime/opcode.h src/src/runtime/opcode.cpp src/src/compiler/bytecode_compiler.cpp src/src/runtime/vm.cpp src/tests/unit/bytecode_compiler_test.cpp src/tests/unit/vm_test.cpp
git commit -m "feat(vm): add bitwise opcodes"
```

---

### Task 5: AOT lowering, docs and full verification

**Files:**
- Modify: `src/src/aot/analyze_pass.cpp` (`is_slow_opcode`)
- Modify: `src/src/aot/micro_ir.cpp` (lower the six opcodes to `IntrinsicSlow`)
- Test: `src/tests/unit/aot_test.cpp`
- Modify: `docs/language/syntax.md` (operator table and precedence)

**Interfaces:**
- Consumes: `Opcode::BIT_AND`…`SHR` from Task 4.
- Produces: `bytecode_to_micro_ir` no longer throws `unsupported opcode` for bitwise functions; bitwise ops are reported as slow paths (same as `MOD`).

- [ ] **Step 1: Write the failing AOT test**

Append to `src/tests/unit/aot_test.cpp`:

```cpp
TEST(AotTest, MicroIrLowersBitwiseOpcodes) {
    const std::string source = R"(
        function bits(a, b) {
            return (a & b) | (a ^ b) | (a << b) | (a >> b) | ~a;
        }
        bits(6, 3);
    )";

    const std::string input = "/tmp/dryad_micro_ir_bitwise.dryad";
    {
        std::ofstream file(input);
        file << source;
    }

    CompileOptions options;
    options.run_profiler = true;
    CompiledProgram program = compile_file_to_bytecode(input, options);
    IrModule ir = bytecode_to_micro_ir(program);
    EXPECT_FALSE(ir.functions.empty());

    const IrFunction* bits_fn = nullptr;
    for (const auto& fn : ir.functions) {
        if (fn.name == "bits") {
            bits_fn = &fn;
            break;
        }
    }
    ASSERT_NE(bits_fn, nullptr);

    // `(a & b) | (a ^ b) | (a << b) | (a >> b) | ~a` lowers to nine slow sites:
    // &, ^, <<, >>, the four | and ~.
    int slow_sites = 0;
    for (const auto& inst : bits_fn->instructions) {
        if (inst.op == IrOpcode::IntrinsicSlow) {
            ++slow_sites;
        }
    }
    EXPECT_EQ(slow_sites, 9);

    std::remove(input.c_str());
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cmake --build src/build --target unit_tests -j$(nproc) && src/build/unit_tests --gtest_filter='AotTest.MicroIrLowersBitwiseOpcodes'`
Expected: FAIL with `micro_ir: unsupported opcode BIT_AND`.

- [ ] **Step 3: Lower the opcodes**

In `src/src/aot/analyze_pass.cpp`, add the six opcodes to `is_slow_opcode` with the comment that they are generic integer ops (like `MOD`).

In `src/src/aot/micro_ir.cpp`, add cases in the opcode switch that mirror the existing `MOD` case:

```cpp
case Opcode::BIT_AND:
case Opcode::BIT_OR:
case Opcode::BIT_XOR:
case Opcode::SHL:
case Opcode::SHR: {
    inst.rhs = pop();
    inst.lhs = pop();
    inst.op = IrOpcode::IntrinsicSlow;
    inst.intrinsic_id = static_cast<uint16_t>(0xFF00u | static_cast<uint8_t>(op));
    inst.intrinsic_argc = 2;
    inst.result = fresh_reg(IrType::Variant);
    block.instructions.push_back(inst);
    push(inst.result, IrType::Variant);
    pc += 1;
    break;
}
case Opcode::BIT_NOT: {
    inst.lhs = pop();
    inst.op = IrOpcode::IntrinsicSlow;
    inst.intrinsic_id = static_cast<uint16_t>(0xFF00u | static_cast<uint8_t>(op));
    inst.intrinsic_argc = 1;
    inst.result = fresh_reg(IrType::Variant);
    block.instructions.push_back(inst);
    push(inst.result, IrType::Variant);
    pc += 1;
    break;
}
```

- [ ] **Step 4: Run the test and the full suite**

Run: `cmake --build src/build -j$(nproc) && src/build/unit_tests --gtest_filter='AotTest.MicroIrLowersBitwiseOpcodes' && ctest --test-dir src/build --output-on-failure`
Expected: AOT test PASS; entire suite PASS.

- [ ] **Step 5: Update the language docs**

In `docs/language/syntax.md`, add the six operators to the operator table and document the precedence line and the masking/sign rules. This is a submodule change; commit it inside `docs/`.

- [ ] **Step 6: Commit**

```bash
git add src/src/aot/analyze_pass.cpp src/src/aot/micro_ir.cpp src/tests/unit/aot_test.cpp
git commit -m "feat(aot): lower bitwise opcodes through the slow path"

cd docs && git add language/syntax.md && git commit -m "docs(language): document bitwise operators"
```

## Known limitations and follow-ups

- The AOT slow-path ABI is `(id, argc)` and passes no operands. A working `dryad_intrinsic_slow` must extend the signature to `(id, argc, lhs, rhs)` (plus an `argc=1` variant) before `0xFF21`–`0xFF26` can be dispatched.
- Unknown intrinsic ids should abort rather than return `null`.
- The Task 5 AOT test originally undercounted the slow sites (5 instead of 9). The plan snippet is already corrected.
