module ruleslang.semantic.opexpand;

import std.conv : to;

import ruleslang.syntax.token;
import ruleslang.syntax.ast.expression;
import ruleslang.syntax.ast.statement;
import ruleslang.syntax.ast.mapper;

public Statement expandOperators(Statement target) {
    return target.accept(new OperatorExpander());
}

private class OperatorExpander : StatementMapper {
    public override Statement mapAssignment(Assignment assignment) {
        switch (assignment.operator.getSource()) {
            case "**=":
                return expandOperator!(Exponent, ExponentOperator, "**")(assignment);
            case "*=":
                return expandOperator!(Multiply, MultiplyOperator, "*")(assignment);
            case "/=":
                return expandOperator!(Multiply, MultiplyOperator, "/")(assignment);
            case "%=":
                return expandOperator!(Multiply, MultiplyOperator, "%")(assignment);
            case "+=":
                return expandOperator!(Add, AddOperator, "+")(assignment);
            case "-=":
                return expandOperator!(Add, AddOperator, "-")(assignment);
            case "<<=":
                return expandOperator!(Shift, ShiftOperator, "<<")(assignment);
            case ">>=":
                return expandOperator!(Shift, ShiftOperator, ">>")(assignment);
            case ">>>=":
                return expandOperator!(Shift, ShiftOperator, ">>>")(assignment);
            case "&=":
                return expandOperator!(BitwiseAnd, BitwiseAndOperator, "&")(assignment);
            case "^=":
                return expandOperator!(BitwiseXor, BitwiseXorOperator, "^")(assignment);
            case "|=":
                return expandOperator!(BitwiseOr, BitwiseOrOperator, "|")(assignment);
            case "&&=":
                return expandOperator!(LogicalAnd, LogicalAndOperator, "&&")(assignment);
            case "^^=":
                return expandOperator!(LogicalXor, LogicalXorOperator, "^^")(assignment);
            case "||=":
                return expandOperator!(LogicalOr, LogicalOrOperator, "||")(assignment);
            case "~=":
                return expandOperator!(Concatenate, ConcatenateOperator, "~")(assignment);
            default:
                return assignment;
        }
    }
}

private Statement expandOperator(Bin, BinOp, string op)(Assignment assignment) {
    auto value = new Bin(assignment.target, assignment.value, new BinOp(op.to!dstring, assignment.operator.start));
    return new Assignment(assignment.target, value, new AssignmentOperator("=", assignment.operator.start));
}