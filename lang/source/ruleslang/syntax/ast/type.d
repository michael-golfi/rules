module ruleslang.syntax.ast.type;

import std.algorithm.iteration;

import ruleslang.syntax.dchars;
import ruleslang.syntax.token;
import ruleslang.syntax.ast.expression;

public interface Type {
    public string toString();
}

public class NamedType : Type {
    private Identifier[] name;
    private Expression[] dimensions;

    public this(Identifier[] name, Expression[] dimensions) {
        this.name = name;
        this.dimensions = dimensions;
    }

    public override string toString() {
        auto componentName = name.join!(".", "getSource()")();
        auto dimensionsString = dimensions.length <= 0 ? "" :
            dimensions.map!"a is null ? \"\" : a.toString()"().map!"\"[\" ~ a ~ \"]\""().reduce!"a ~ b"();
        return componentName ~ dimensionsString;
    }
}