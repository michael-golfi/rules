module ruleslang.syntax.token;

import std.format : format;
import std.array : replace;
import std.conv : to, ConvException, ConvOverflowException;
import std.math: isInfinity;
import std.string : indexOf, CaseSensitive;
import std.algorithm.searching : findAmong;

import ruleslang.syntax.dchars;
import ruleslang.syntax.source;
import ruleslang.syntax.ast.expression;
import ruleslang.syntax.ast.mapper;
import ruleslang.semantic.tree;
import ruleslang.semantic.interpret;

public enum Kind {
    INDENTATION,
    TERMINATOR,
    IDENTIFIER,
    KEYWORD,
    LOGICAL_NOT_OPERATOR,
    EXPONENT_OPERATOR,
    MULTIPLY_OPERATOR,
    ADD_OPERATOR,
    SHIFT_OPERATOR,
    VALUE_COMPARE_OPERATOR,
    TYPE_COMPARE_OPERATOR,
    BITWISE_AND_OPERATOR,
    BITWISE_XOR_OPERATOR,
    BITWISE_OR_OPERATOR,
    LOGICAL_AND_OPERATOR,
    LOGICAL_XOR_OPERATOR,
    LOGICAL_OR_OPERATOR,
    CONCATENATE_OPERATOR,
    RANGE_OPERATOR,
    ASSIGNMENT_OPERATOR,
    OTHER_SYMBOL,
    BOOLEAN_LITERAL,
    STRING_LITERAL,
    INTEGER_LITERAL,
    FLOAT_LITERAL,
    EOF
}

public interface Token : SourceIndexed {
    public string getSource();
    public Kind getKind();
    public bool opEquals(const string source);
    public string toString();
}

public class Terminator : Token {
    private size_t _start;

    public this(size_t start) {
        _start = start;
    }

    public override string getSource() {
        return ";";
    }

    public Kind getKind() {
        return Kind.TERMINATOR;
    }

    @property public override size_t start() {
        return _start;
    }

    @property public override size_t end() {
        return _start;
    }

    public override bool opEquals(const string source) {
        return ";" == source;
    }

    public override string toString() {
        return "Terminator(;)";
    }
}

public template SourceToken(Kind kind) {
    public class SourceToken : Token {
        private string source;
        private size_t _start;
        private size_t _end;

        public this(dstring source, size_t start) {
            this(source, start, start + source.length - 1);
        }

        public this(dstring source, size_t start, size_t end) {
            this.source = source.to!string;
            if (end < start) {
                throw new Exception("A token cannot end before it has started");
            }
            _start = start;
            _end = end;
        }

        public override string getSource() {
            return source;
        }

        public override Kind getKind() {
            return kind;
        }

        @property public override size_t start() {
            return _start;
        }

        @property public override size_t end() {
            return _end;
        }

        public override bool opEquals(const string source) {
            return getSource() == source;
        }

        public override string toString() {
            return format("%s(%s)", getKind().toString(), getSource());
        }
    }
}

public alias LogicalNotOperator = SourceToken!(Kind.LOGICAL_NOT_OPERATOR);
public alias ExponentOperator = SourceToken!(Kind.EXPONENT_OPERATOR);
public alias Indentation = SourceToken!(Kind.INDENTATION);
public alias Identifier = SourceToken!(Kind.IDENTIFIER);
public alias Keyword = SourceToken!(Kind.KEYWORD);
public alias MultiplyOperator = SourceToken!(Kind.MULTIPLY_OPERATOR);
public alias AddOperator = SourceToken!(Kind.ADD_OPERATOR);
public alias ShiftOperator = SourceToken!(Kind.SHIFT_OPERATOR);
public alias ValueCompareOperator = SourceToken!(Kind.VALUE_COMPARE_OPERATOR);
public alias TypeCompareOperator = SourceToken!(Kind.TYPE_COMPARE_OPERATOR);
public alias BitwiseAndOperator = SourceToken!(Kind.BITWISE_AND_OPERATOR);
public alias BitwiseXorOperator = SourceToken!(Kind.BITWISE_XOR_OPERATOR);
public alias BitwiseOrOperator = SourceToken!(Kind.BITWISE_OR_OPERATOR);
public alias LogicalAndOperator = SourceToken!(Kind.LOGICAL_AND_OPERATOR);
public alias LogicalXorOperator = SourceToken!(Kind.LOGICAL_XOR_OPERATOR);
public alias LogicalOrOperator = SourceToken!(Kind.LOGICAL_OR_OPERATOR);
public alias ConcatenateOperator = SourceToken!(Kind.CONCATENATE_OPERATOR);
public alias RangOperator = SourceToken!(Kind.RANGE_OPERATOR);
public alias AssignmentOperator = SourceToken!(Kind.ASSIGNMENT_OPERATOR);
public alias OtherSymbol = SourceToken!(Kind.OTHER_SYMBOL);

public class BooleanLiteral : SourceToken!(Kind.BOOLEAN_LITERAL), Expression {
    private bool value;
    private bool evaluated = false;

    public this(dstring source, size_t start) {
        super(source, start);
    }

    public this(dstring source, size_t start, size_t end) {
        super(source, start, end);
    }

    public this(bool value, size_t start, size_t end) {
        super(value.to!dstring, start, end);
        this.value = value;
        evaluated = true;
    }

    @property public override size_t start() {
        return super.start;
    }

    @property public override size_t end() {
        return super.end;
    }

    public override Expression map(ExpressionMapper mapper) {
        return mapper.mapBooleanLiteral(this);
    }

    public override immutable(Node) interpret() {
        return Interpreter.INSTANCE.interpretBooleanLiteral(this);
    }

    public bool getValue() {
        final switch (getSource()) {
            case "true":
                return true;
            case "false":
                return false;
        }
    }

    public override string toString() {
        return super.toString();
    }

    unittest {
        auto a = new BooleanLiteral("true", 0);
        assert(a.getValue());
        auto b = new BooleanLiteral("false", 0);
        assert(!b.getValue());
    }
}

public class StringLiteral : SourceToken!(Kind.STRING_LITERAL), Expression {
    private dstring original;

    public this(dstring source, size_t start) {
        this(source, start, start + source.length - 1);
    }

    public this(dstring source, size_t start, size_t end) {
        super(source, start, end);
        original = source;
    }

    @property public override size_t start() {
        return super.start;
    }

    @property public override size_t end() {
        return super.end;
    }

    public override Expression map(ExpressionMapper mapper) {
        return mapper.mapStringLiteral(this);
    }

    public override immutable(Node) interpret() {
        return Interpreter.INSTANCE.interpretStringLiteral(this);
    }

    public dstring getValue() {
        auto length = original.length;
        if (length < 2) {
            throw new Exception("String is missing enclosing quotes");
        }
        if (original[0] != '"') {
            throw new Exception("String is missing beginning quote");
        }
        dchar[] buffer = [];
        buffer.reserve(64);
        for (size_t i = 1; i < length - 1; ) {
            dchar c = original[i];
            i += 1;
            if (c == '\\') {
                c = original[i];
                i += 1;
                if (c == 'u') {
                    c = original[i - 1 .. $].decodeUnicodeEscape(i);
                } else {
                    c = c.decodeCharEscape();
                }
            }
            buffer ~= c;
        }
        if (original[length - 1] != '"') {
            throw new Exception("String is missing ending quote");
        }
        return buffer.idup;
    }

    public override string toString() {
        return super.toString();
    }

    unittest {
        auto a = new StringLiteral("\"hello\\u0041\\nlol\""d, 0);
        assert(a.getValue() == "helloA\nlol"d);
    }
}

public class IntegerLiteral : SourceToken!(Kind.INTEGER_LITERAL), Expression {
    private uint _radix;

    public this(dstring source, size_t start) {
        this(source, start, start + source.length - 1);
    }

    public this(dstring source, size_t start, size_t end) {
        super(source, start, end);
        if (source.length > 2) {
            switch (source[1]) {
                case 'b':
                case 'B':
                    _radix = 2;
                    break;
                case 'x':
                case 'X':
                    _radix = 16;
                    break;
                default:
                    _radix = 10;
                    break;
            }
        } else {
            _radix = 10;
        }
    }

    @property public uint radix() {
        return _radix;
    }

    @property public override size_t start() {
        return super.start;
    }

    @property public override size_t end() {
        return super.end;
    }

    public override Expression map(ExpressionMapper mapper) {
        return mapper.mapIntegerLiteral(this);
    }

    public override immutable(Node) interpret() {
        return Interpreter.INSTANCE.interpretIntegerLiteral(this);
    }

    public override string getSource() {
        return super.getSource();
    }

    public L getValue(L)(bool sign, ref bool overflow) if (is(L == long) || is(L == ulong)) {
        static if (is(L == ulong)) {
            if (sign) {
                throw new Exception("Can't apply a sign to an unsigned integer");
            }
        }
        auto source = getSource().replace("_", "");
        if (radix != 10) {
            source = source[2 .. $];
        }
        if (sign) {
            if (radix == 10) {
                source = "-" ~ source;
            } else {
                throw new Exception("Can't apply a sign to a non-decimal integer");
            }
        }
        try {
            overflow = false;
            return source.to!L(_radix);
        } catch (ConvOverflowException) {
            overflow = true;
            return -1;
        }
    }

    public override string toString() {
        return super.toString();
    }

    unittest {
        bool overflow;
        auto a = new IntegerLiteral("424_32", 0);
        assert(a.getValue!long(false, overflow) == 42432);
        assert(a.getValue!long(true, overflow) == -42432);
        assert(!overflow);
    	auto b = new IntegerLiteral("0xFFFF", 0);
        assert(b.getValue!long(false, overflow) == 0xFFFF);
    	auto c = new IntegerLiteral("0b1110", 0);
        assert(c.getValue!long(false, overflow) == 0b1110);
        auto d = new IntegerLiteral("9223372036854775808", 0);
        assert(d.getValue!ulong(false, overflow) == 9223372036854775808uL);
        assert(d.getValue!long(true, overflow) == 0x8000000000000000L);
        assert(!overflow);
        d.getValue!long(false, overflow);
        assert(overflow);
        auto e = new IntegerLiteral("9223372036854775809", 0);
        e.getValue!long(true, overflow);
        assert(overflow);
    }
}

public class FloatLiteral : SourceToken!(Kind.FLOAT_LITERAL), Expression {
    public this(dstring source, size_t start) {
        super(source, start);
    }

    public this(dstring source, size_t start, size_t end) {
        super(source, start, end);
    }

    @property public override size_t start() {
        return super.start;
    }

    @property public override size_t end() {
        return super.end;
    }

    public override Expression map(ExpressionMapper mapper) {
        return mapper.mapFloatLiteral(this);
    }

    public override immutable(Node) interpret() {
        return Interpreter.INSTANCE.interpretFloatLiteral(this);
    }

    public double getValue(ref bool overflow) {
        double value = void;
        try {
            value = getSource().to!double;
        } catch (ConvException) {
            overflow = true;
            return -1;
        }
        overflow = isInfinity(value) || value == 0 && !isZero();
        return value;
    }

    private bool isZero() {
        auto source = getSource();
        auto mantissaEnd = source.indexOf('e', CaseSensitive.no);
        if (mantissaEnd < 0) {
            mantissaEnd = source.length;
        }
        return source[0 .. mantissaEnd].findAmong(['1', '2', '3', '4', '5', '6', '7', '8', '9']).length <= 0;
    }

    public override string toString() {
        return super.toString();
    }

    unittest {
        bool overflow;
        auto a = new FloatLiteral("1_10e12", 0);
        assert(a.getValue(overflow) == 1_10e12);
        assert(!overflow);
    	auto b = new FloatLiteral("1.1", 0);
        assert(b.getValue(overflow) == 1.1);
    	auto c = new FloatLiteral(".1", 0);
        assert(c.getValue(overflow) == 0.1);
        auto d = new FloatLiteral("-1e1000", 0);
        d.getValue(overflow);
        assert(overflow);
        auto e = new FloatLiteral("1e-1000", 0);
        e.getValue(overflow);
        assert(overflow);
        auto f = new FloatLiteral("00_0e12", 0);
        assert(f.getValue(overflow) == 0);
        assert(!overflow);
        auto g = new FloatLiteral("0", 0);
        assert(g.getValue(overflow) == 0);
        assert(!overflow);
        auto h = new FloatLiteral("1e-10000000", 0);
        h.getValue(overflow);
        assert(overflow);
    }
}

public class Eof : Token {
    private size_t _start;

    public this(size_t start) {
        _start = start;
    }

    public override string getSource() {
        return "\u0004";
    }

    public Kind getKind() {
        return Kind.EOF;
    }

    @property public override size_t start() {
        return _start;
    }

    @property public override size_t end() {
        return _start;
    }

    public override bool opEquals(const string source) {
        return "\u0004" == source;
    }

    public override string toString() {
        return "EOF()";
    }
}

public string toString(Kind kind) {
    final switch (kind) with (Kind) {
        case INDENTATION:
            return "Indentation";
        case TERMINATOR:
            return "Terminator";
        case IDENTIFIER:
            return "Identifier";
        case KEYWORD:
            return "Keyword";
        case LOGICAL_NOT_OPERATOR:
        case EXPONENT_OPERATOR:
        case MULTIPLY_OPERATOR:
        case ADD_OPERATOR:
        case SHIFT_OPERATOR:
        case VALUE_COMPARE_OPERATOR:
        case TYPE_COMPARE_OPERATOR:
        case BITWISE_AND_OPERATOR:
        case BITWISE_XOR_OPERATOR:
        case BITWISE_OR_OPERATOR:
        case LOGICAL_AND_OPERATOR:
        case LOGICAL_XOR_OPERATOR:
        case LOGICAL_OR_OPERATOR:
        case CONCATENATE_OPERATOR:
        case RANGE_OPERATOR:
        case ASSIGNMENT_OPERATOR:
        case OTHER_SYMBOL:
            return "Symbol";
        case BOOLEAN_LITERAL:
            return "BooleanLiteral";
        case STRING_LITERAL:
            return "StringLiteral";
        case INTEGER_LITERAL:
            return "IntegerLiteral";
        case FLOAT_LITERAL:
            return "FloatLiteral";
        case EOF:
            return "EOF";
    }
}

public Token newSymbol(dstring source, size_t start) {
    auto constructor = source in OPERATOR_SOURCES;
    if (constructor !is null) {
        return (*constructor)(source, start);
    }
    return new OtherSymbol(source, start);
}

private Token function(dstring, size_t)[dstring] OPERATOR_SOURCES;

private void addSourcesForOperator(Op)(dstring[] sources ...) {
    Token function(dstring, size_t) constructor = (dstring source, size_t start) => new Op(source, start);
    foreach (source; sources) {
        if (source in OPERATOR_SOURCES) {
            throw new Exception("Symbol is declared for two different operators: " ~ source.to!string);
        }
        OPERATOR_SOURCES[source] = constructor;
    }
    OPERATOR_SOURCES.rehash;
}

public static this() {
    addSourcesForOperator!LogicalNotOperator("!"d);
    addSourcesForOperator!ExponentOperator("**"d);
    addSourcesForOperator!MultiplyOperator("*"d, "/"d, "%"d);
    addSourcesForOperator!AddOperator("+"d, "-"d);
    addSourcesForOperator!ShiftOperator("<<"d, ">>"d, ">>>"d);
    addSourcesForOperator!ValueCompareOperator("==="d, "!=="d, "=="d, "!="d, "<"d, ">"d, "<="d, ">="d);
    addSourcesForOperator!TypeCompareOperator("::"d, "!:"d, "<:"d, ">:"d, "<<:"d, ">>:"d, "<:>"d);
    addSourcesForOperator!BitwiseAndOperator("&"d);
    addSourcesForOperator!BitwiseXorOperator("^"d);
    addSourcesForOperator!BitwiseOrOperator("|"d);
    addSourcesForOperator!LogicalAndOperator("&&"d);
    addSourcesForOperator!LogicalXorOperator("^^"d);
    addSourcesForOperator!LogicalOrOperator("||"d);
    addSourcesForOperator!ConcatenateOperator("~"d);
    addSourcesForOperator!RangOperator(".."d);
    addSourcesForOperator!AssignmentOperator(
        "**="d, "*="d, "/="d, "%="d, "+="d, "-="d, "<<="d, ">>="d,
        ">>>="d, "&="d, "^="d, "|="d, "&&="d, "^^="d, "||="d, "~="d, "="d
    );
}
