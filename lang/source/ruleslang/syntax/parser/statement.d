module ruleslang.syntax.parser.statement;

import std.format : format;

import ruleslang.syntax.dchars;
import ruleslang.syntax.source;
import ruleslang.syntax.token;
import ruleslang.syntax.tokenizer;
import ruleslang.syntax.ast.type;
import ruleslang.syntax.ast.expression;
import ruleslang.syntax.ast.statement;
import ruleslang.syntax.parser.type;
import ruleslang.syntax.parser.expression;
import ruleslang.util;

private struct IndentSpec {
    private size_t count;
    private char w;
    private bool nextIndentIgnored = false;

    private this(char w, size_t count) {
        this.w = w;
        this.count = count;
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

    private IndentSpec opBinary(string op)(Indentation indentation) {
        static if (op == "+") {
            void mixedError(char w, char c) {
                throw new SourceException(format("Mixed indentation: should be '%s', but got '%s'",
                        this.w.escapeChar(), c.escapeChar()), indentation);
            }
            auto source = indentation.getSource();
            if (source.length <= 0) {
                throw new SourceException("Expected some indentation", indentation);
            }
            char w = source[0];
            if (count > 0 && this.w != w) {
                mixedError(this.w, w);
            }
            foreach (c; source) {
                if (w != c) {
                    mixedError(w, c);
                }
            }
            return IndentSpec(w, count + source.length);
        } else {
            static assert(0);
        }
    }

    private string toString() {
        if (count == 0) {
            return "no indentation";
        }
        return format("%d of '%s' of indentation", count, w.escapeChar());
    }
}

private IndentSpec noIndent() {
    return IndentSpec(' ', 0);
}

private TypeDefinition parseTypeDefinition(Tokenizer tokens) {
    if (tokens.head() != "def") {
        throw new SourceException("Expected \"def\"", tokens.head());
    }
    auto start = tokens.head().start;
    tokens.advance();
    if (tokens.head().getKind() != Kind.IDENTIFIER) {
        throw new SourceException("Expected an identifier", tokens.head());
    }
    auto name = tokens.head().castOrFail!Identifier();
    tokens.advance();
    if (tokens.head() != ":") {
        throw new SourceException("Expected ':'", tokens.head());
    }
    tokens.advance();
    auto type = parseType(tokens);
    return new TypeDefinition(name, type, start);
}

private VariableDeclaration parseVariableDeclaration(Tokenizer tokens) {
    // Try to parse "let" or "var" first
    VariableDeclaration.Kind kind;
    if (tokens.head() == "let") {
        kind = VariableDeclaration.Kind.LET;
    } else if (tokens.head() == "var") {
        kind = VariableDeclaration.Kind.VAR;
    } else {
        throw new SourceException("Expected \"let\" or \"var\"", tokens.head());
    }
    auto start = tokens.head().start;
    tokens.advance();
    // Now we can parse an optional named type, which starts with an identifier
    tokens.savePosition();
    auto type = parseNamedType(tokens);
    auto furthestPosition = tokens.head().start;
    // We need another identifier for the variable name which comes after
    if (tokens.head().getKind() == Kind.IDENTIFIER) {
        tokens.discardPosition();
    } else {
        // If we don't have one then back off: the identifier we parsed as a type is the name
        type = null;
        tokens.restorePosition();
    }
    // Now parse the identifier for the name
    if (tokens.head().getKind() != Kind.IDENTIFIER) {
        throw new SourceException("Expected an identifier", tokens.head());
    }
    auto name = tokens.head().castOrFail!Identifier();
    tokens.advance();
    // If we don't have an "=" operator then there isn't any value
    if (tokens.head() != "=") {
        // In this case having a named type is mandatory, not having one means the name is missing
        if (type is null) {
            throw new SourceException("Expected an identifier", furthestPosition);
        }
        return new VariableDeclaration(kind, type, name, start);
    }
    tokens.advance();
    // Otherwise parse and expression for the value
    auto value = parseExpression(tokens);
    return new VariableDeclaration(kind, type, name, value, start);
}

private Statement parseAssigmnentOrFunctionCall(Tokenizer tokens) {
    auto access = parseAccess(tokens);
    auto call = cast(FunctionCall) access;
    if (call !is null) {
        return call;
    }
    auto reference = cast(AssignableExpression) access;
    if (reference is null) {
        throw new SourceException("Not an assignable expression", access);
    }
    if (tokens.head().getKind() != Kind.ASSIGNMENT_OPERATOR) {
        throw new SourceException("Expected an assignment operator", tokens.head());
    }
    auto operator = tokens.head().castOrFail!AssignmentOperator();
    tokens.advance();
    return new Assignment(reference, parseExpression(tokens), operator);
}

private ConditionalStatement parseConditionalStatement(Tokenizer tokens, IndentSpec indentSpec = noIndent()) {
    if (tokens.head() != "if") {
        throw new SourceException("Expected \"def\"", tokens.head());
    }
    auto start = tokens.head().start;
    auto end = tokens.head().end;
    tokens.advance();
    // Parse the condition expression
    auto condition = parseExpression(tokens);
    if (tokens.head() != ":") {
        throw new SourceException("Expected ':'", tokens.head());
    }
    tokens.advance();
    // The indentation of the block will be that of the first statement
    if (tokens.head().getKind() != Kind.INDENTATION) {
        throw new SourceException("Expected some indentation", tokens.head());
    }
    auto blockIndentSpec = indentSpec + tokens.head().castOrFail!Indentation();
    auto trueStatements = parseStatements(tokens, blockIndentSpec);
    if (trueStatements.length > 0) {
        end = trueStatements[$ - 1].end;
    }
    // Try to follow it with an else block
    Statement[] falseStatements = null;
    tokens.savePosition();
    if (validateIndentation(tokens, indentSpec) && tokens.head() == "else") {
        tokens.discardPosition();
        end = tokens.head().end;
        tokens.advance();
        if (tokens.head() != ":") {
            throw new SourceException("Expected ':'", tokens.head());
        }
        tokens.advance();
        // Reuse the indentation of the "if" block
        falseStatements = parseStatements(tokens, blockIndentSpec);
        if (falseStatements.length > 0) {
            end = falseStatements[$ - 1].end;
        }
    } else {
        tokens.restorePosition();
        falseStatements = [];
    }
    return new ConditionalStatement(condition, trueStatements, falseStatements, start, end);
}

public Statement parseStatement(Tokenizer tokens, IndentSpec indentSpec = noIndent()) {
    switch (tokens.head().getSource()) {
        case "def":
            return parseTypeDefinition(tokens);
        case "let":
        case "var":
            return parseVariableDeclaration(tokens);
        case "if":
            return parseConditionalStatement(tokens, indentSpec);
        default:
            return parseAssigmnentOrFunctionCall(tokens);
    }
}

public Statement[] parseStatements(Tokenizer tokens, IndentSpec indentSpec = noIndent()) {
    Statement[] statements = [];
    while (tokens.has()) {
        // Check if the indentation is valid for the current spec
        if (!validateIndentation(tokens, indentSpec)) {
            if (indentSpec.count <= 0) {
                // This is a top level statement, the indentation needs to be correct
                throw new SourceException(format("Expected %s", indentSpec.toString()), tokens.head());
            }
            break;
        }
        indentSpec.nextIndentIgnored = false;
        // Check if this isn't an empty statement
        if (tokens.has() && tokens.head().getKind != Kind.TERMINATOR) {
            // Parse the statement
            statements ~= parseStatement(tokens, indentSpec);
        }
        // Check for termination
        if (tokens.head().getKind() == Kind.TERMINATOR) {
            tokens.advance();
            // Can ignore indentation for the next statement if on the same line
            indentSpec.nextIndentIgnored = true;
            continue;
        }
        if (tokens.head().getKind() == Kind.INDENTATION) {
            // Indentation marks a new statement, so the end of the current one
            continue;
        }
        if (!tokens.has()) {
            // Nothing else to parse (EOF is a valid termination)
            break;
        }
        throw new SourceException("Expected end of statement", tokens.head());
    }
    return statements;
}

private bool validateIndentation(Tokenizer tokens, IndentSpec indentSpec) {
    Indentation lastIndent = null;
    // Consume indentation preceding the statement
    while (tokens.head().getKind() == Kind.INDENTATION) {
        indentSpec.nextIndentIgnored = false;
        lastIndent = tokens.head().castOrFail!Indentation();
        tokens.advance();
    }
    // Indentation could precede end of source
    if (!tokens.has()) {
        return true;
    }
    // Only the last indentation before the statement matters
    return indentSpec.nextIndentIgnored || lastIndent !is null && indentSpec.validate(lastIndent);
}
