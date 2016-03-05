package lang

import (
    "fmt"
    "reflect"
)

type Type interface {
}

type NamedType struct {
    Name []*Token
    Dimensions []Expression
}

type Expression interface {
    String() string
}

type NameReference struct {
    Name []*Token
}

type LabeledExpression struct {
    Label *Token
    Value Expression
}

type CompositeLiteral struct {
    Values []*LabeledExpression
}

type Initializer struct {
    Type *NamedType
    Value *CompositeLiteral
}

type ContextFieldAccess struct {
    Name *Token
}

type FieldAccess struct {
    Object Expression
    Name *Token
}

type ArrayAccess struct {
    Object Expression
    Index Expression
}

type FunctionCall struct {
    Object Expression
    Arguments []Expression
}

func (this *NamedType) String() string {
    dimensionsString := ""
    for _, dimension := range this.Dimensions {
        if dimension == nil {
            dimensionsString += "[]"
        } else {
            dimensionsString += "[" + dimension.String() + "]"
        }
    }
    return joinSource(this.Name, ".") + dimensionsString
}

func (this *NameReference) String() string {
    return joinSource(this.Name, ".")
}

func (this *LabeledExpression) String() string {
    labelString := ""
    if this.Label != nil {
        labelString = this.Label.Source + ": "
    }
    return labelString + this.Value.String()
}

func (this *CompositeLiteral) String() string {
    return fmt.Sprintf("CompositeLiteral({%s})", joinString(this.Values, ", "))
}

func (this *Initializer) String() string {
    return fmt.Sprintf("Initializer(%s{%s})", this.Type.String(), joinString(this.Value.Values, ", "))
}

func (this *ContextFieldAccess) String() string {
    return fmt.Sprintf("ContextFieldAccess(.%s)", this.Name.Source)
}

func (this *FieldAccess) String() string {
    return fmt.Sprintf("FieldAccess(%s.%s)", this.Object.String(), this.Name.Source)
}

func (this *ArrayAccess) String() string {
    return fmt.Sprintf("ArrayAccess(%s[%s])", this.Object.String(), this.Index.String())
}

func (this *FunctionCall) String() string {
    return fmt.Sprintf("FunctionCall(%s(%s))", this.Object.String(), joinString(this.Arguments, ", "))
}

func joinString(things interface{}, joiner string) string {
    return join(things, joiner, "String", true)
}

func joinSource(things interface{}, joiner string) string {
    return join(things, joiner, "Source", false)
}

func join(things interface{}, joiner string, stringer string, function bool) string {
    values := reflect.ValueOf(things)
    s := ""
    length :=  values.Len() - 1
    if length < 0 {
        return s
    }
    for i := 0; i < length; i++ {
        s += getString(values.Index(i), stringer, function) + joiner
    }
    s += getString(values.Index(length), stringer, function)
    return s
}

func getString(value reflect.Value, stringer string, function bool) string {
    if function {
        return value.MethodByName(stringer).Call(nil)[0].String()
    }
    return reflect.Indirect(value).FieldByName(stringer).String()
}