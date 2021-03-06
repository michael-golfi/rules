module ruleslang.util;

import std.conv : to;
import std.range.primitives : isInputRange;
import std.algorithm.searching : canFind, findAmong, countUntil;
import std.algorithm.iteration : map, reduce;
import std.range : zip;
import std.ascii : isDigit, isAlphaNum, toLower, toUpper;
import std.traits : ReturnType;

public T castOrFail(T, S)(S s) {
    T t = cast(T) s;
    if (t is null) {
        throw new Error("Cannot cast " ~ __traits(identifier, S) ~ " to " ~ __traits(identifier, T));
    }
    return t;
}

public immutable(T) exactCastImmutable(T, S)(S s) if (!is(T == interface)) {
    auto t = cast(immutable T) s;
    if (t is null || typeid(t) != typeid(T)) {
        return null;
    }
    return t;
}

public T collectExceptionMessage(T, E = Exception)(lazy T expression, out string message) {
    try {
        return expression();
    } catch (E exception) {
        message = exception.msg;
        return null;
    }
}

public T[][T] transitiveClosure(T)(T[][T] adjacencies) {
    T[][T] result;
    bool wasReduced = void;
    do {
        wasReduced = false;
        foreach (node; adjacencies.byKey()) {
            auto adjacents = adjacencies[node];
            if (adjacents.findAmong(adjacencies.keys).length <= 0) {
                adjacencies.reduceGraph(result, node, adjacents);
                wasReduced = true;
                break;
            }
        }
    } while (wasReduced && adjacencies.length > 0);
    foreach (node; result.byKey()) {
        result[node] ~= node;
    }
    return result;
}

private void reduceGraph(T)(ref T[][T] adjacencies, ref T[][T] result, T independent, T[] adjacents) {
    adjacencies.remove(independent);
    foreach (node; adjacencies.byKey()) {
        if (adjacencies[node].canFind(independent)) {
            adjacencies[node].addMissing(adjacents);
        }
    }
    result[independent] = adjacents;
}

public T[] resolveDependencyOrder(alias getDependencies, T, S)(T[S] resourceToObject)
        if (is(ReturnType!getDependencies == S[])) {
    // A helper function to remove resources from a list
    S[] remove(S[] resources, S resource) {
        ptrdiff_t index;
        while ((index = resources.countUntil(resource)) >= 0) {
            resources = resources[0 .. index] ~ resources[index + 1 .. $];
        }
        return resources;
    }
    // First we create a graph of the objects to their resources
    S[][S] resourceToDependencies;
    foreach (resource, object; resourceToObject) {
        auto dependencies = getDependencies(object);
        // Remove any dependencies not in the resources, since they might already exist
        for (size_t i = 0; i < dependencies.length; i++) {
            if (dependencies[i] !in resourceToObject) {
                dependencies = dependencies[0 .. i] ~ dependencies[i + 1 .. $];
                i -= 1;
            }
        }
        resourceToDependencies[resource] = dependencies;
    }
    // Then we find a topological ordering of the graph
    T[] order;
    bool changed;
    do {
        changed = false;
        // For every node in the graph
        foreach (resource, object; resourceToObject) {
            auto optDeps = resource in resourceToDependencies;
            if (optDeps is null) {
                continue;
            }
            auto deps = *optDeps;
            // Check if its dependencies have been resolved
            if (deps.length <= 0) {
                // If so, then it is the next in the order
                order ~= object;
                resourceToDependencies.remove(resource);
                // Remove it as a dependency in the other nodes
                foreach (otherResource; resourceToDependencies.keys()) {
                    resourceToDependencies[otherResource] = remove(resourceToDependencies[otherResource], resource);
                }
                changed = true;
            }
        }
        // Repeat as long as we are not stuck in a cycle
    } while (changed);
    return order;
}

public void addMissing(T)(ref T[] to, T[] elements) {
    foreach (element; elements) {
        if (!to.canFind(element)) {
            to ~= element;
        }
    }
}

public K[V] inverse(K, V)(V[K] array) {
    K[V] inv;
    foreach (k, v; array) {
        inv[v] = k;
    }
    return inv;
}

public V[][K] associateArrays(alias makeKey, K = ReturnType!makeKey, V)(V[] array) {
    V[][K] assoc;
    foreach (v; array) {
        K k = makeKey(v);
        assoc[k] ~= v;
    }
    return assoc;
}

public V[Kb] mapKeys(alias mapKey, Ka, Kb = ReturnType!mapKey, V)(V[Ka] array) {
    V[Kb] mapped;
    foreach (k, v; array) {
        mapped[mapKey(k)] = v;
    }
    return mapped;
}

public auto stringZip(string joiner, string stringerA = ".to!string()", string stringerB = ".to!string()", RangeA, RangeB)
        (RangeA a, RangeB b) if (isInputRange!RangeA && isInputRange!RangeB) {
    enum mapper = "a[0]" ~ stringerA ~ " ~ \"" ~ joiner ~ "\" ~ a[1]" ~ stringerB;
    return zip(a, b).map!mapper();
}

public string join(string joiner, string stringer = "a.to!string()", Range)(Range things)
        if (isInputRange!Range) {
    if (things.length <= 0) {
        return "";
    }
    return things.map!stringer().reduce!("a ~ \"" ~ joiner ~ "\" ~ b")();
}

public string asciiSnakeToCamelCase(string snake, bool upperFirst = false) {
    auto camel = new char[snake.length];
    bool firstWordLetter = upperFirst;
    size_t i = 0;
    foreach (char s; snake) {
        if (s == '_') {
            firstWordLetter = true;
            continue;
        }
        if (!s.isAlphaNum()) {
            throw new Error("Expected only ASCII alphanumeric characters and underscores");
        }
        if (firstWordLetter) {
            s = s.toUpper();
            firstWordLetter = false;
        } else {
            s = s.toLower();
        }
        camel[i++] = s;
    }
    return camel[0 .. i].idup;
}

public string positionalReplace(string source, string[] items...) {
    auto length = items.length;
    if (length > 10) {
        throw new Error("A max of 10 items is supported");
    }
    char[] buffer = [];
    if (!__ctfe) {
        buffer.reserve(source.length);
    }
    auto marker = false;
    foreach (c; source) {
        if (marker) {
            if (c == '$') {
                buffer ~= '$';
            } else if (c.isDigit()) {
                size_t index = c - '0';
                if (index >= length) {
                    throw new Error("No item for index " ~ index.to!string);
                }
                buffer ~= items[index];
            }
            marker = false;
        } else if (c == '$') {
            marker = true;
        } else {
            buffer ~= c;
        }
    }
    return buffer.idup;
}
