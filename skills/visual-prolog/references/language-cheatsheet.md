# Language cheatsheet

Contents: lexical rules · literals · operators · predicates and functions · lists · control constructs · facts · classes, interfaces, properties · generics · lambdas · namespaces and scope · conditional compilation · error handling.

Based on the Visual Prolog language reference (wiki.visual-prolog.com, Language Reference). Where behavior changed between versions, check that wiki page for the version in use.

## Lexical rules

- Variables: start with an uppercase letter or `_`. `_` alone is anonymous.
- Predicate, domain, constant, class, interface, functor and atom names: start lowercase.
- Strings `"text"` with escapes `\n \t \" \\`. Verbatim strings `@"C:\path\file"` (backslashes literal). Characters `'a'`.
- Numbers: `42`, `0x2A`, `3.14`, `1.0e5`. Real literals need a decimal point.
- Comments: `% to end of line`, `/* block, may not nest in some versions */`.
- Statement terminator: every clause, declaration and fact ends with `.`.

## Operators

| Group | Operators |
|---|---|
| Arithmetic | `+ - * /` (real division), `div mod quot rem`, unary `-` |
| Comparison | `= <> < > <= >=` |
| Logic | `,` (and), `;` (or), `!` (cut), `not(G)` |
| Assignment to a fact variable | `:=` |
| Strings | build with `string::concat(A, B)` or `string::format(...)`; don't assume `+` concatenates strings |
| Cons / list | `[H|T]`, `[1,2,3]` |

## Predicates and functions

```prolog
predicates
    p : (integer A, string B) procedure.          % predicate, no result
    f : (integer A) -> string procedure.          % function with result
    g : (integer A, integer B [out]) determ.      % output parameter
    h : (integer A, integer B) nondeterm (i,o) (o,i).   % explicit flow patterns
    r : (string A, string B) nondeterm anyflow.   % any binding allowed
clauses
    f(N) = toString(N).                           % function clause
    g(A, B) :- A > 0, B = A * 2.
```

- Calling a function inside an expression is allowed: `X = f(3)`, `write(f(3))`.
- `[out]`, `[in]`, `[inout]` annotate parameters when a flow pattern is not spelled out.
- `procedure` is the default determinism when none is written.
- Predicates with a trailing `-> Type` are functions; `Pred() = X` is the clause form.

## Lists

```prolog
domains  intList = integer*.
clauses
    len([]) = 0.
    len([_|T]) = 1 + len(T).
    sum([], 0).
    sum([H|T], S) :- sum(T, S1), S = S1 + H.
```

Use `list::` for the standard operations. Patterns like `[X, Y | Rest]` work in heads and `=`. List comprehension: `L = [ X*2 || X = list::getMember_nd(Src) ]`.

## Control constructs

```prolog
if Cond then A else B end if
if C1 then A elseif C2 then B else C end if
foreach X = list::getMember_nd(L), X > 0 do ... end foreach
try risky() catch E do stdio::write("error\n") finally cleanup() end try
```

**`match` (Visual Prolog 12 and later only).** Pattern-matching over the alternatives of a domain, closed with `end match`. The official change log confirms the construct (Build 1200 step 2 patch 1, 15 Nov 2024) and that `match` and `case` became keywords, but gives no formal syntax and official version 12 documentation was not available, so treat the exact syntax as provisional and recommend confirming it in the version 12 docs. The example the user supplied, where `R` is a result-like value with alternatives `success_(V)` and `error_(T)`:

```prolog
(R) :-
    match (R)
    case (success_(V)) :-
        OnSuccess(V)
    case (error_(T)) :-
        OnError(T)
    end match.
```

Each `case (Pattern) :-` is followed by the goal to run when the pattern matches. On versions before 12, write the same logic with separate clauses, one per alternative, or with `if ... then ... elseif ... end if`.

- `std::repeat()` + `fail` gives infinite loops; prefer `foreach` and recursion.
- `succeed` and `fail` come from `core` (`open core`).
- `isErroneous`, `errorExit(...)`, `exception::raise_User(...)` for failures.

## Facts

```prolog
class facts - db
    item : (integer Id, string Name).             % relation
    total : integer := 0.                         % single variable fact
    last : string determ.                         % may be unset
```

Operations: `assert`, `assertz`, `asserta`, `retract`, `retractAll(item(_, _))`, read by calling `item(Id, Name)`. Single facts read as variables and update with `:=`. Facts declared in `facts` (not `class facts`) are per object.

## Classes, interfaces, properties

```prolog
interface shape
properties
    area : real (o).                  % read-only property
predicates
    describe : () -> string.
end interface shape

class circle : shape
constructors
    new : (real Radius).
end class circle

implement circle
    facts
        radius : real := 0.
    clauses
        new(R) :- radius := R.
        area() = math::pi * radius * radius.
        describe() = string::format("circle r=%s", toString(radius)).
end implement circle
```

- `class X : I` means class `X` constructs objects of type `I`. `supports J` adds more interfaces. `inherits` exists for implementation inheritance.
- `open Class` in the implementation brings static members into scope; `This` is the object.
- Object-valued variables hold interface types: `S = circle::new(2.0), D = S:describe()`.
- Properties: `properties name : type.` plus optional `(o)` / `(i)` flow, with `setName`/`getName` style accessors generated.

## Generics

```prolog
domains  pair{A, B} = pair(A, B).
interface stack{T}
predicates
    push : (T Item).
    pop : () -> T determ.
end interface stack
```

Generic classes use `class stackImpl{T} : stack{T}`.

## Lambdas and delegates

```prolog
Double = { (X) = X * 2 },
R = Double(21),
L2 = list::map(L, { (X) = X + 1 }),
Pos = list::filter(L, { (X) :- X > 0 }).
```

Delegate (predicate-typed) domains: `domains handler = (string Msg) procedure.` then store and call them like values.

## Namespaces and scope

- `open core`, `open list` in a section make names unqualified; avoid opening many namespaces in one file because of name clashes.
- Qualified calls: `list::length(L)`, `stdio::write(...)`.
- Scope qualifications on constants, domains and predicates: `constants` and `domains` inside an interface are visible to everything that sees the interface.

## Conditional compilation

```prolog
#if "release" <> "release" #then ... #else ... #endif
#bininclude "file.bin"
#include @"pfc\list\list.ph"
```

`#requires`, `#export` and `#message` also exist; consult the Directives page of the language reference.

## Error handling

`try ... catch TraceId do ... end try` catches exceptions raised by `exception::raise*`, library failures, and run-time errors. Use `finally` for cleanup. For failure (not exceptions) use `if`/`not`.
