# Worked examples

Contents: 1 hello console · 2 facts and rules · 3 recursion (Hanoi) · 4 list processing · 5 classes and interfaces.

These are hand-checked, not compiled (no Visual Prolog compiler is available in the sandbox). Each is a complete `main.pro` for a Console project unless noted; the matching `main.cl` is always:

```prolog
class main
    open core
predicates
    run : core::runnable.
end class main
```

## 1. Hello console

```prolog
implement main
    open core

clauses
    run() :-
        console::init(),
        stdio::write("Hello, Visual Prolog!\n"),
        succeed.

end implement main

goal
    console::runUtf8(main::run).
```

## 2. Facts and rules (family tree)

```prolog
implement main
    open core

class facts - familyDB
    parent : (string Child, string Parent).

class predicates
    grandparent : (string Grandchild, string Grandparent) nondeterm anyflow.
clauses
    grandparent(GC, GP) :-
        parent(GC, P),
        parent(P, GP).

clauses
    run() :-
        console::init(),
        assert(parent("ann", "bob")),
        assert(parent("bob", "carl")),
        assert(parent("bob", "dora")),
        foreach grandparent(GC, GP) do
            stdio::writef("%s has grandparent %s\n", GC, GP)
        end foreach,
        succeed.

end implement main

goal
    console::runUtf8(main::run).
```

Points: facts are typed and declared; `anyflow` allows calling with either argument bound; `foreach` runs all solutions inside a `procedure`.

## 3. Recursion: Towers of Hanoi

```prolog
implement main
    open core

domains
    pole = left; center; right.

class predicates
    move : (unsigned N, pole From, pole To, pole Via) procedure.
clauses
    move(0, _, _, _) :- !.
    move(N, From, To, Via) :-
        move(N - 1, From, Via, To),
        stdio::write("Move disk ", N, " from ", From, " to ", To, "\n"),
        move(N - 1, Via, To, From).

clauses
    run() :-
        console::init(),
        move(3, left, right, center),
        succeed.

end implement main

goal
    console::runUtf8(main::run).
```

## 4. List processing

```prolog
implement main
    open core

class predicates
    sumList : (integer* L) -> integer procedure.
    evens : (integer* L) -> integer* procedure.
clauses
    sumList([]) = 0.
    sumList([H|T]) = H + sumList(T).

    evens(L) = list::filter(L, { (X) :- X mod 2 = 0 }).

clauses
    run() :-
        console::init(),
        Numbers = [1, 2, 3, 4, 5, 6],
        stdio::write("Sum: ", sumList(Numbers), "\n"),
        stdio::write("Evens: ", evens(Numbers), "\n"),
        stdio::write("Doubled: ", list::map(Numbers, { (X) = X * 2 }), "\n"),
        succeed.

end implement main

goal
    console::runUtf8(main::run).
```

Note: `list::filter`'s test lambda is a `determ` predicate body (`:-`), while `list::map`'s lambda is a function (`=`).

## 5. Classes and interfaces

Files: `shape.i`, `circle.cl`, `circle.pro`, plus a `main.pro` that uses them. The project must include the new files in its project tree (IDE: New in Existing Package).

```prolog
% shape.i
interface shape
predicates
    area : () -> real.
    name : () -> string.
end interface shape
```

```prolog
% circle.cl
class circle : shape
constructors
    new : (real Radius).
end class circle
```

```prolog
% circle.pro
implement circle
    open core

facts
    radius : real := 0.0.

clauses
    new(R) :- radius := R.

clauses
    area() = math::pi * radius * radius.
    name() = "circle".

end implement circle
```

```prolog
% in main.pro run/0
S = circle::new(2.0),
stdio::writef("%s area: %f\n", S:name(), S:area()).
```

Points: object facts (`facts`, not `class facts`) store per-instance state; `Object:method()` calls an object member; the class name appears in `class circle : shape` as the type it constructs.
