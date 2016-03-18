package syntax

func parseCompositeLiteralPart(tokens *Tokenizer) *LabeledExpression {
    var label Token = nil
    headKind := tokens.Head().Kind()
    if headKind == IDENTIFIER || headKind == INTEGER_LITERAL {
        label = tokens.Head()
        tokens.SavePosition()
        tokens.Advance()
        if tokens.Head().Is(":") {
            tokens.Advance()
            tokens.DiscardPosition()
        } else {
            tokens.RestorePosition()
            label = nil
        }
    }
    var value Expression
    if tokens.Head().Is("{") {
        value = parseCompositeLiteral(tokens)
    } else {
        value = ParseExpression(tokens)
    }
    return &LabeledExpression{label, value}
}

func parseCompositeLiteralBody(tokens *Tokenizer) []*LabeledExpression {
    body := []*LabeledExpression{parseCompositeLiteralPart(tokens)}
    for tokens.Head().Is(",") {
        tokens.Advance()
        body = append(body, parseCompositeLiteralPart(tokens))
    }
    return body
}

func parseCompositeLiteral(tokens *Tokenizer) *CompositeLiteral {
    if !tokens.Head().Is("{") {
        panic("Expected '{'")
    }
    tokens.Advance()
    var body []*LabeledExpression
    if tokens.Head().Is("}") {
        tokens.Advance()
        body = []*LabeledExpression{}
    } else {
        body = parseCompositeLiteralBody(tokens)
        if !tokens.Head().Is("}") {
            panic("Expected '}'")
        }
    }
    return &CompositeLiteral{body}
}

func parseAtom(tokens *Tokenizer) Expression {
    if tokens.Head().Is(".") {
        // Context field access
        tokens.Advance()
        if tokens.Head().Kind() != IDENTIFIER {
            panic("Expected an identifier")
        }
        identifier := tokens.Head().(*Identifier)
        tokens.Advance()
        return &ContextFieldAccess{identifier}
    }
    if tokens.Head().Kind() == IDENTIFIER {
        // Name, or initializer
        tokens.SavePosition()
        namedType := parseNamedType(tokens)
        if !tokens.Head().Is("{") {
            // Name
            tokens.RestorePosition()
            name := parseName(tokens)
            return &NameReference{name}
        }
        tokens.DiscardPosition()
        value := parseCompositeLiteral(tokens)
        return &Initializer{namedType, value}
    }
    if tokens.Head().Is("(") {
        // Parenthesis operator
        tokens.Advance()
        expression := ParseExpression(tokens)
        if !tokens.Head().Is(")") {
            panic("Expected ')'")
        }
        tokens.Advance()
        return expression
    }
    // Check for a literal
    switch literal := tokens.Head().(type) {
    case *BooleanLiteral:
        tokens.Advance()
        return literal
    case *StringLiteral:
        tokens.Advance()
        return literal
    case *IntegerLiteral:
        tokens.Advance()
        return literal
    case *FloatLiteral:
        tokens.Advance()
        return literal
    }
    panic("Expected a literal, a name or '('")
}

func parseAccess(tokens *Tokenizer) Expression {
    return parseAccessOn(tokens, parseAtom(tokens))
}

func parseAccessOn(tokens *Tokenizer, value Expression) Expression {
    if tokens.Head().Is(".") {
        tokens.Advance()
        if tokens.Head().Kind() != IDENTIFIER {
            panic("Expected an identifier")
        }
        name := tokens.Head().(*Identifier)
        tokens.Advance()
        return parseAccessOn(tokens, &FieldAccess{value, name})
    }
    if tokens.Head().Is("[") {
        tokens.Advance()
        index := ParseExpression(tokens)
        if !tokens.Head().Is("]") {
            panic("Expected ']'")
        }
        tokens.Advance()
        return parseAccessOn(tokens, &ArrayAccess{value, index})
    }
    if tokens.Head().Is("(") {
        tokens.Advance()
        var arguments []Expression
        if tokens.Head().Is(")") {
            tokens.Advance()
            arguments = []Expression{}
        } else {
            arguments = parseExpressionList(tokens)
            if !tokens.Head().Is(")") {
                panic("Expected ')'")
            }
            tokens.Advance()
        }
        return parseAccessOn(tokens, &FunctionCall{value, arguments})
    }
    // Disambiguate between a float without decimal digits
    // and an integer with a field access
    token, ok := value.(*FloatLiteral)
    if ok && tokens.Head().Kind() == IDENTIFIER && token.Source()[len(token.Source()) - 1] == '.' {
        name := tokens.Head().(*Identifier)
        tokens.Advance()
        // The form decimalInt.identifier is lexed as float(numberSeq.)identifier
        // We detect it and convert it to first form here
        decimalInt := &IntegerLiteral{TokenSource{token.Source()[:len(token.Source()) - 1]}, nil}
        return parseAccessOn(tokens, &FieldAccess{decimalInt, name})
    }
    return value
}

func parseUnary(tokens *Tokenizer) Expression {
    switch tokens.Head().Source() {
    case "+":
        fallthrough
    case "-":
        operator := tokens.Head().(*Symbol)
        tokens.Advance()
        inner := parseUnary(tokens)
        return &Sign{operator, inner}
    case "!":
        tokens.Advance()
        inner := parseUnary(tokens)
        return &LogicalNot{inner}
    case "~":
        tokens.Advance()
        inner := parseUnary(tokens)
        return &BitwiseNot{inner}
    default:
        return parseAccess(tokens)
    }
}

func parseExponent(tokens *Tokenizer) Expression {
    return parseExponentOn(tokens, parseUnary(tokens))
}

func parseExponentOn(tokens *Tokenizer, value Expression) Expression {
    if tokens.Head().Is("**") {
        tokens.Advance()
        exponent := parseUnary(tokens)
        return parseExponentOn(tokens, &Exponent{value, exponent})
    }
    return value
}

func parseInfix(tokens *Tokenizer) Expression {
    return parseInfixOn(tokens, parseExponent(tokens))
}

func parseInfixOn(tokens *Tokenizer, value Expression) Expression {
    if tokens.Head().Kind() == IDENTIFIER {
        function := tokens.Head().(*Identifier)
        tokens.Advance()
        argument := parseExponent(tokens)
        return parseInfixOn(tokens, &Infix{value, function, argument})
    }
    return value
}

func parseMultiply(tokens *Tokenizer) Expression {
    return parseMultiplyOn(tokens, parseInfix(tokens))
}

func parseMultiplyOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Kind() == MULTIPLY_OPERATOR {
        operator := tokens.Head().(*Symbol)
        tokens.Advance()
        right := parseInfix(tokens)
        return parseMultiplyOn(tokens, &Multiply{left, operator, right})
    }
    return left
}

func parseAdd(tokens *Tokenizer) Expression {
    return parseAddOn(tokens, parseMultiply(tokens))
}

func parseAddOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Kind() == ADD_OPERATOR {
        operator := tokens.Head().(*Symbol)
        tokens.Advance()
        right := parseMultiply(tokens)
        return parseAddOn(tokens, &Add{left, operator, right})
    }
    return left
}

func parseShift(tokens *Tokenizer) Expression {
    return parseShiftOn(tokens, parseAdd(tokens))
}

func parseShiftOn(tokens *Tokenizer, value Expression) Expression {
    if tokens.Head().Kind() == SHIFT_OPERATOR {
        operator := tokens.Head().(*Symbol)
        tokens.Advance()
        amount := parseAdd(tokens)
        return parseShiftOn(tokens, &Shift{value, operator, amount})
    }
    return value
}

func parseCompare(tokens *Tokenizer) Expression {
    value := parseShift(tokens)
    if tokens.Head().Kind() != VALUE_COMPARE_OPERATOR &&
        tokens.Head().Kind() != TYPE_COMPARE_OPERATOR {
        return value
    }
    valueOperators := []*Symbol{}
    values := []Expression{value}
    for tokens.Head().Kind() == VALUE_COMPARE_OPERATOR {
        valueOperators = append(valueOperators, tokens.Head().(*Symbol))
        tokens.Advance()
        values = append(values, parseShift(tokens))
    }
    var typeOperator *Symbol = nil
    var _type Type = nil
    if tokens.Head().Kind() == TYPE_COMPARE_OPERATOR {
        typeOperator = tokens.Head().(*Symbol)
        tokens.Advance()
        _type = parseType(tokens)
    }
    return &Compare{values, valueOperators, _type, typeOperator}
}

func parseBitwiseAnd(tokens *Tokenizer) Expression {
    return parseBitwiseAndOn(tokens, parseCompare(tokens))
}

func parseBitwiseAndOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("&") {
        tokens.Advance()
        right := parseCompare(tokens)
        return parseBitwiseAndOn(tokens, &BitwiseAnd{left, right})
    }
    return left
}

func parseBitwiseXor(tokens *Tokenizer) Expression {
    return parseBitwiseXorOn(tokens, parseBitwiseAnd(tokens))
}

func parseBitwiseXorOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("^") {
        tokens.Advance()
        right := parseBitwiseAnd(tokens)
        return parseBitwiseXorOn(tokens, &BitwiseXor{left, right})
    }
    return left
}

func parseBitwiseOr(tokens *Tokenizer) Expression {
    return parseBitwiseOrOn(tokens, parseBitwiseXor(tokens))
}

func parseBitwiseOrOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("|") {
        tokens.Advance()
        right := parseBitwiseXor(tokens)
        return parseBitwiseOrOn(tokens, &BitwiseOr{left, right})
    }
    return left
}

func parseLogicalAnd(tokens *Tokenizer) Expression {
    return parseLogicalAndOn(tokens, parseBitwiseOr(tokens))
}

func parseLogicalAndOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("&&") {
        tokens.Advance()
        right := parseBitwiseOr(tokens)
        return parseLogicalAndOn(tokens, &LogicalAnd{left, right})
    }
    return left
}

func parseLogicalXor(tokens *Tokenizer) Expression {
    return parseLogicalXorOn(tokens, parseLogicalAnd(tokens))
}

func parseLogicalXorOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("^^") {
        tokens.Advance()
        right := parseLogicalAnd(tokens)
        return parseLogicalXorOn(tokens, &LogicalXor{left, right})
    }
    return left
}

func parseLogicalOr(tokens *Tokenizer) Expression {
    return parseLogicalOrOn(tokens, parseLogicalXor(tokens))
}

func parseLogicalOrOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("||") {
        tokens.Advance()
        right := parseLogicalXor(tokens)
        return parseLogicalOrOn(tokens, &LogicalOr{left, right})
    }
    return left
}

func parseConcatenate(tokens *Tokenizer) Expression {
    return parseConcatenateOn(tokens, parseLogicalOr(tokens))
}

func parseConcatenateOn(tokens *Tokenizer, left Expression) Expression {
    if tokens.Head().Is("~") {
        tokens.Advance()
        right := parseLogicalOr(tokens)
        return parseConcatenateOn(tokens, &Concatenate{left, right})
    }
    return left
}

func parseRange(tokens *Tokenizer) Expression {
    return parseRangeOn(tokens, parseConcatenate(tokens))
}

func parseRangeOn(tokens *Tokenizer, from Expression) Expression {
    if tokens.Head().Is("..") {
        tokens.Advance()
        to := parseConcatenate(tokens)
        return parseRangeOn(tokens, &Range{from, to})
    }
    return from
}

func parseConditional(tokens *Tokenizer) Expression {
    trueValue := parseRange(tokens)
    if !tokens.Head().Is("if") {
        return trueValue
    }
    tokens.Advance()
    condition := parseRange(tokens)
    if !tokens.Head().Is("else") {
        panic("Expected \"else\"")
    }
    tokens.Advance()
    falseValue := parseConditional(tokens)
    return &Conditional{condition, trueValue, falseValue}
}

func ParseExpression(tokens *Tokenizer) Expression {
    return parseConditional(tokens)
}

func parseExpressionList(tokens *Tokenizer) []Expression {
    expressions := []Expression{ParseExpression(tokens)}
    for tokens.Head().Is(",") {
        tokens.Advance()
        expressions = append(expressions, ParseExpression(tokens))
    }
    return expressions
}
