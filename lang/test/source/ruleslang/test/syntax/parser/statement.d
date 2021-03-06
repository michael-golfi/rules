module ruleslang.test.syntax.parser.statement;

import std.format : format;
import std.stdio : stderr;

import ruleslang.syntax.source;
import ruleslang.syntax.tokenizer;
import ruleslang.syntax.ast.statement;
import ruleslang.syntax.parser.statement;
import ruleslang.util;

import ruleslang.test.assertion;

unittest {
    assertEqual(
        "TypeDefinition(def test: lol)",
        parse("def test: lol")
    );
    assertEqual(
        "TypeDefinition(def Vec2d: {fp64 x, fp64 y})",
        parse("def Vec2d: {fp64 x, fp64 y}")
    );
}

unittest {
    assertEqual(
        "VariableDeclaration(let Test t)",
        parse("let Test t")
    );
    assertEqual(
        "VariableDeclaration(let Test[] t)",
        parse("let Test[] t")
    );
    assertEqual(
        "VariableDeclaration(let Test t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("let Test t = 1 + 1")
    );
    assertEqual(
        "VariableDeclaration(let Test[] t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("let Test[] t = 1 + 1")
    );
    assertEqual(
        "VariableDeclaration(let t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("let t = 1 + 1")
    );
    assertParseFail("let");
    assertParseFail("let t");
    assertParseFail("let Test[]");
    assertEqual(
        "VariableDeclaration(var Test t)",
        parse("var Test t")
    );
    assertEqual(
        "VariableDeclaration(var Test[] t)",
        parse("var Test[] t")
    );
    assertEqual(
        "VariableDeclaration(var Test t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("var Test t = 1 + 1")
    );
    assertEqual(
        "VariableDeclaration(var Test[] t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("var Test[] t = 1 + 1")
    );
    assertEqual(
        "VariableDeclaration(var t = Add(SignedIntegerLiteral(1) + SignedIntegerLiteral(1)))",
        parse("var t = 1 + 1")
    );
    assertParseFail("var");
    assertParseFail("var t");
    assertParseFail("var Test[]");
}

unittest {
    assertEqual(
        "Assignment(a = SignedIntegerLiteral(1))",
        parse("a = 1")
    );
    assertEqual(
        "Assignment(a.b *= v)",
        parse("a.b *= v")
    );
    assertEqual(
        "Assignment(MemberAccess(FunctionCall(a.test()).field) ~= StringLiteral(\"2\"))",
        parse("a.test().field ~= \"2\"")
    );
    assertEqual(
        "Assignment(a = CompositeLiteral({a, b, CompositeLiteral({v})}))",
        parse("a = {a, b, {v}}")
    );
    assertEqual(
        "Assignment(a = Initializer(test[]{SignedIntegerLiteral(1), StringLiteral(\"2\"),"
                ~ " CompositeLiteral({hey: FloatLiteral(2.1)})}))",
        parse("a = test[] {1, \"2\", {hey: 2.1}}")
    );
}

unittest {
    assertEqual(
        "FunctionCall(a())",
        parse("a()")
    );
    assertEqual(
        "FunctionCall(a(SignedIntegerLiteral(1), b))",
        parse("a(1, b)")
    );
    assertEqual(
        "FunctionCall(a.b())",
        parse("a.b()")
    );
    assertEqual(
        "FunctionCall(MemberAccess(StringLiteral(\"test\").length)())",
        parse("\"test\".length()")
    );
    assertEqual(
        "FunctionCall(MemberAccess(Infix(SignedIntegerLiteral(2) log b).test)())",
        parse("(2 log b).test()")
    );
}

unittest {
    assertEqual(
        "FunctionCall(a())\n" ~
            "Assignment(a = SignedIntegerLiteral(1))\n" ~
            "FunctionCall(a.b())\n" ~
            "Assignment(a.b *= v)",
        parse("a()\na = 1; a.b();\n\t\ra.b *= v")
    );
    assertParseFail("a()\na = 1; a.b()\n\ta.b *= v");
    assertParseFail("a()\na = 1; a.b();\n\ta.b *= v");
}

unittest {
    assertEqual(
        "ConditionalStatement(if Compare(a == SignedIntegerLiteral(0)): VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("if a == 0:\n  let b = 12")
    );
    assertEqual(
        "ConditionalStatement(if Compare(a == SignedIntegerLiteral(0)): VariableDeclaration(let b = SignedIntegerLiteral(12));"
             ~ " else: Assignment(d = SignedIntegerLiteral(1)))",
        parse("if a == 0:\n  let b = 12\nelse:\n  d = 1")
    );
    assertEqual(
        "ConditionalStatement(if a: FunctionCall(b()); else if c: FunctionCall(d()))",
        parse("if a:\n b()\nelse if c:\n d()")
    );
    assertEqual(
        "ConditionalStatement(if a: FunctionCall(b()); else if c: FunctionCall(d()); else: FunctionCall(e()))",
        parse("if a:\n b()\nelse if c:\n d()\nelse:\n e()\n")
    );
    assertEqual(
        "ConditionalStatement(if Compare(a == SignedIntegerLiteral(0)): )",
        parse("if a == 0:\n  ;")
    );
    assertEqual(
        "ConditionalStatement(if Compare(a == SignedIntegerLiteral(0)): VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("if a == 0:\n  let b = 12\nelse:\n  ;")
    );
    assertEqual(
        "ConditionalStatement(if Compare(a == SignedIntegerLiteral(0)): ; else: Assignment(d = SignedIntegerLiteral(1)))",
        parse("if a == 0:\n  ;\nelse:\n  d = 1")
    );
    assertEqual(
        "ConditionalStatement(if a: FunctionCall(b()); else if c: )",
        parse("if a:\n b()\nelse if c:\n ;")
    );
    assertEqual(
        "ConditionalStatement(if a: ; else if c: )",
        parse("if a:\n ;\nelse if c:\n ;\nelse:\n ;\n")
    );
    assertParseFail("if a == 0:\nlet b = 12");
    assertParseFail("if a == 0:let b = 12");
    assertParseFail("if a == 0:\n\nlet b = 12");
    assertParseFail("if a == 0:\n  \nlet b = 12");
    assertParseFail("if a == 0:\n  let b = 12\nelse:\nd = 1");
    assertParseFail("if a == 0:\n  let b = 12\nelse:d = 1");
    assertParseFail("if a == 0:\n  let b = 12\nelse:\n\nd = 1");
    assertParseFail("if a == 0:\n  let b = 12\nelse:\n  \nd = 1");
    assertParseFail("if a == 0:\n  let b = 12\nelse if a:\nc()");
    assertParseFail("if a == 0:\n  let b = 12\nelse if a:c()");
    assertParseFail("if a == 0:\n  let b = 12\nelse if a:\n\nc()");
    assertParseFail("if a == 0:\n  let b = 12\nelse:\n  \nc()");
}

unittest {
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("while a == 0:\n  let b = 12")
    );
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): )",
        parse("while a == 0:\n  ;")
    );
    assertParseFail("while a == 0:\nlet b = 12");
    assertParseFail("while a == 0:let b = 12");
    assertParseFail("while a == 0:\n\nlet b = 12");
    assertParseFail("while a == 0:\n  \nlet b = 12");
    assertEqual(
        "FunctionDefinition(func test(): "
            ~ "LoopStatement(while BooleanLiteral(true): VariableDeclaration(let a = SignedIntegerLiteral(1)); "
            ~ "LoopStatement(while BooleanLiteral(false): )); VariableDeclaration(let b = SignedIntegerLiteral(1)))",
        parse("func test():\n while true:\n  let a = 1\n  while false:\n   ;\n let b = 1")
    );
    assertParseFail("func test():\n while true:\n  let a = 1\n  while false:\n let b = 1");
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): BreakStatement(break))",
        parse("while a == 0:\n  break")
    );
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): BreakStatement(break test))",
        parse("while a == 0:\n  break test")
    );
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): ContinueStatement(continue))",
        parse("while a == 0:\n  continue")
    );
    assertEqual(
        "LoopStatement(while Compare(a == SignedIntegerLiteral(0)): ContinueStatement(continue test))",
        parse("while a == 0:\n  continue test")
    );
}

unittest {
    assertEqual(
        "FunctionDefinition(func test(): VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("func test():\n  let b = 12")
    );
    assertEqual(
        "FunctionDefinition(func test() bool: VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("func test() bool:\n  let b = 12")
    );
    assertEqual(
        "FunctionDefinition(func test(uint32 a) bool: VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("func test(uint32 a) bool:\n  let b = 12")
    );
    assertEqual(
        "FunctionDefinition(func test(uint32[] a, fp64 b) bool: VariableDeclaration(let b = SignedIntegerLiteral(12)))",
        parse("func test(uint32[] a, fp64 b) bool:\n  let b = 12")
    );
    assertEqual(
        "FunctionDefinition(func test(): ReturnStatement(return))",
        parse("func test():\n  return")
    );
    assertEqual(
        "FunctionDefinition(func test() bool: ReturnStatement(return BooleanLiteral(false)))",
        parse("func test() bool:\n  return false")
    );
    assertParseFail("func test():\nlet b = 12");
    assertParseFail("func test():let b = 12");
    assertParseFail("func test():\n\nlet b = 12");
    assertParseFail("func test():\n  \nlet b = 12");
}

unittest {
    assertEqual(
        "LoopStatement(while BooleanLiteral(true): VariableDeclaration(let a = SignedIntegerLiteral(1)); BreakStatement(break))",
        parse("while true:\n\t\n  let a = 1\n  break")
    );
    assertParseFail("while true:\n\t\n  let a = 1\n\tbreak");
}

private string parse(string source) {
    try {
        auto statements = new Tokenizer(new DCharReader(source)).parseFlowStatements();
        return statements.join!"\n"();
    } catch (SourceException exception) {
        stderr.writeln(exception.getErrorInformation(source).toString());
        assert (0);
    }
}

private void assertParseFail(string source, string file = __FILE__, size_t line = __LINE__) {
    try {
        auto statements = new Tokenizer(new DCharReader(source)).parseFlowStatements();
        throw new AssertionError(format("Expected a source exception at %s line %d, but got statements:\n%s",
                file, line, statements.join!"\n"()));
    } catch (SourceException exception) {
        debug (verboseTests) {
            stderr.writeln(exception.getErrorInformation(source).toString());
        }
    }
}
