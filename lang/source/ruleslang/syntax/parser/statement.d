module ruleslang.syntax.parser.statement;

import std.format;

import ruleslang.syntax.dchars;
import ruleslang.syntax.token;
import ruleslang.syntax.tokenizer;
import ruleslang.syntax.ast.expression;
import ruleslang.syntax.ast.statement;
import ruleslang.syntax.parser.expression;

private struct IndentSpec {
    private dchar w;
    private uint count;
    private bool nextIgnored;

    private this(dchar w, uint count, bool nextIgnored) {
        this.w = w;
        this.count = count;
        this.nextIgnored = nextIgnored;
    }

    private bool validate(Indentation indentation) {
        if (indentation.getSource().length != count) {
            return false;
        }
        foreach (c; indentation.getSource()) {
            if (c != w) {
                return false;
            }
        }
        return true;
    }
}

private IndentSpec* noIndentation() {
    return new IndentSpec(' ', 0, false);
}

private Statement parseAssigmnentOrFunctionCall(Tokenizer tokens) {
    auto access = parseAccess(tokens);
    auto call = cast(FunctionCall) access;
    if (call !is null) {
        return call;
    }
    auto reference = cast(Reference) access;
    if (reference is null) {
        throw new Exception("Not a reference expression");
    }
    if (tokens.head().getKind() != Kind.ASSIGNMENT_OPERATOR) {
        throw new Exception("Expected an assignment operator");
    }
    auto operator = cast(AssignmentOperator) tokens.head();
    tokens.advance();
    if (operator == "=" && tokens.head() == "{") {
        return new InitializerAssignment(access, parseCompositeLiteral(tokens));
    }
    return new Assignment(access, parseExpression(tokens), operator);
}

public Statement parseStatement(Tokenizer tokens) {
    return parseStatement(tokens, new IndentSpec());
}

private Statement parseStatement(Tokenizer tokens, IndentSpec* indentSpec) {
    auto validIndent = indentSpec.nextIgnored;
    indentSpec.nextIgnored = false;
    // Consume indentation preceding the statement
    while (tokens.head().getKind() == Kind.INDENTATION) {
        validIndent = indentSpec.validate(cast(Indentation) tokens.head());
        tokens.advance();
    }
    // Only the last indentation before the statement matters
    if (!validIndent) {
        throw new Exception(format("Expected %d of %s as indentation", indentSpec.count, indentSpec.w.escapeChar()));
    }
    return parseAssigmnentOrFunctionCall(tokens);
}

public Statement[] parseStatements(Tokenizer tokens) {
    return parseStatements(tokens, new IndentSpec());
}

private Statement[] parseStatements(Tokenizer tokens, IndentSpec* indentSpec) {
    Statement[] statements = [];
    while (tokens.has()) {
        statements ~= parseStatement(tokens, indentSpec);
        if (tokens.head().getKind() == Kind.TERMINATOR) {
            tokens.advance();
            // Can ignore indentation for the next statement if on the same line
            indentSpec.nextIgnored = true;
            continue;
        }
        if (tokens.head().getKind() == Kind.INDENTATION) {
            // Indentation marks a new statement, so the end of the current one
            continue;
        }
        if (tokens.head().getKind() == Kind.EOF) {
            // Nothing else to parse
            break;
        }
        throw new Exception("Expected end of statement");
    }
    return statements;
}