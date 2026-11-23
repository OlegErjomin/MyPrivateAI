---
name: visual-prolog
description: >-
  Write, explain, debug and review Visual Prolog code (PDC Visual Prolog, "VIP", formerly PDC Prolog / Turbo Prolog) — the statically typed, object-oriented Prolog dialect with `implement ... end implement`, `class predicates`, `domains`, `determ`/`procedure`/`nondeterm` modes and the PFC library. Make sure to use this skill whenever the user mentions Visual Prolog, VIP, PDC Prolog, Turbo Prolog, PFC, `.pro`/`.cl`/`.i`/`.ph`/`.vipprj` files, or pastes code containing `implement`, `class facts`, `clauses`, `predicates ... : (...) procedure`, or asks for a Prolog program for a Windows/PDC environment, or mentions suspending predicates / async programming in Visual Prolog — even if they just say "Prolog" and the context (compiler errors like "determ predicate called as procedure", `stdio::write`, `console::init`) shows it is Visual Prolog. Do NOT use for SWI-Prolog, GNU Prolog or other ISO Prolog systems, where the syntax differs substantially.
---

# Visual Prolog

Visual Prolog (by PDC A/S) looks like Prolog but is a different language in the ways that matter for writing code: it is **statically typed**, **object-oriented**, every predicate has a **declared signature and determinism**, and code lives in **classes/interfaces**, not in free-floating clause files. The most common failure when writing it is producing SWI-Prolog-style code (`:- dynamic`, `format/2`, untyped predicates, `assert(foo(1))` with no fact declaration). That code will not compile. Everything below exists to prevent that.

## Before writing code

1. **Find out what the person has**: Visual Prolog version (7.x, 8, 9, 10, 11, 12; version 12 is "Build 1200", currently up to step 7, May 2026). Version 12 adds `match ... case ... end match` and renames some PFC namespaces, so see `references/version-12-changes.md` and never use its features for older versions and project type (Console, GUI/VPI, or PFC GUI). Syntax is mostly stable from 7.x on; if unknown, target 7.5+ and avoid version-specific features. Ask only if it changes the answer.
2. **You cannot compile Visual Prolog here.** The compiler and IDE are proprietary and Windows-only. So never claim the code was compiled or tested. Instead, check it by hand against the checklist at the end of this file and say plainly that it is untested.
3. Prefer small, complete units the person can paste into the IDE: a full `.cl`/`.pro` pair or a full single-file console `main.pro`, not fragments with missing declarations.

## The shape of a program

A program is a **goal** plus **classes** and **interfaces**. A class has a *declaration* (`class X ... end class X`, usually in `x.cl`) and an *implementation* (`implement X ... end implement X`, in `x.pro`). Interfaces (`interface Y ... end interface Y`, in `y.i`) describe object types. `.ph` files are package headers that `#include` the pieces.

Minimal console program (this is what the IDE's Console template produces, give or take the `goal` line, so keep what the template generated if the person already has a project):

```prolog
% main.cl
class main
    open core
predicates
    run : core::runnable.
end class main
```

```prolog
% main.pro
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

Older templates use `mainExe::run(main::run)` in the goal. Do not "fix" the goal line in an existing project; the template's choice matches that project's version.

## Core syntax you must get right

**Declarations come before clauses, in named sections.** The common sections inside `implement` or `class`:

- `open core` / `open list` — bring names into scope (like `using`).
- `constants` — `maxSize = 100.`
- `domains` — type definitions.
- `class facts` / `facts` — mutable databases (class-level / per-object).
- `class predicates` / `predicates` — declarations (class-level / per-object).
- `clauses` — the definitions.

**Domains** (types):

```prolog
domains
    color = red; green; blue.                       % enumeration of atoms
    person = person(string Name, integer Age).      % compound term, named args
    shape = circle(real R); rect(real W, real H).   % alternatives
    names = string*.                                % list of string
    pair{A, B} = pair(A First, B Second).           % generic
```

Built-in value domains: `integer`, `unsigned`, `integer64`, `unsigned64`, `real`, `string`, `char`, `boolean`, `binary`. Alternatives and atoms start lowercase; variables start uppercase or `_`.

**Predicate declarations carry type, determinism and (optionally) flow pattern:**

```prolog
class predicates
    double : (integer X) -> integer procedure.                 % function
    findAge : (string Name, integer Age [out]) determ.         % may fail
    parent : (string Child, string Parent) nondeterm anyflow.  % many solutions
    greet : (string Name) procedure (i).                       % flow: input
```

Determinism modes — this is the concept that trips people most, so get it right:

| Mode | Meaning |
|---|---|
| `procedure` | always succeeds exactly once (the **default** when you write nothing) |
| `determ` | succeeds at most once, may fail |
| `multi` | succeeds at least once, may backtrack |
| `nondeterm` | any number of solutions, including zero |
| `failure` | always fails |
| `erroneous` | never returns (raises an exception) |

The compiler checks that the *body* respects the declared mode. A clause body that can fail inside a `procedure`, or that calls a `determ` predicate without handling failure, is a compile error, not a runtime surprise. When in doubt, declare `determ` or `nondeterm` and, for code that must never fail, wrap risky calls in `if ... then ... else ... end if`.

**Clauses and control flow:**

```prolog
clauses
    double(X) = X * 2.

    describe(N) = "negative" :- N < 0, !.
    describe(0) = "zero" :- !.
    describe(_) = "positive".

    safeDivide(A, B) = R :-
        if B = 0 then
            R = 0
        else
            R = A div B
        end if.

    printAll(L) :-
        foreach X = list::getMember_nd(L) do
            stdio::write(X, "\n")
        end foreach.
```

- `,` is and, `;` is or, `!` is cut, `not(...)` is negation, `:=` assigns to a fact variable, `=` unifies/compares, `<>` is not-equal.
- Use `div` and `mod` for integer division (`/` is real division).
- `if ... then ... elseif ... else ... end if`, `foreach ... do ... end foreach`, and `try ... catch E do ... finally ... end try` all need their `end`.
- Comments: `% line`, `/* block */`.

**Facts (the database)** replace dynamic predicates and must be declared with types:

```prolog
class facts - familyDB
    parent : (string Child, string Parent).
    counter : integer := 0.           % single-value fact (a "variable")

clauses
    init() :-
        assert(parent("tom", "bob")),
        counter := counter + 1.
```

Use `assert`, `assertz`, `asserta`, `retract`, `retractAll`, and `foreach` to enumerate. Facts are `nondeterm` by default.

**Classes and objects:**

```prolog
% counter.i
interface counter
predicates
    increment : ().
    value : () -> integer.
end interface counter

% counterImpl.cl
class counterImpl : counter
constructors
    new : (integer Start).
end class counterImpl

% counterImpl.pro
implement counterImpl
    facts
        count : integer := 0.
    clauses
        new(Start) :- count := Start.
        increment() :- count := count + 1.
        value() = count.
end implement counterImpl

% usage
C = counterImpl::new(0), C:increment(), V = C:value().
```

Object members are called with `Object:method(...)`, class members with `Class::method(...)`. `This` refers to the current object. A class with no declared constructors gets a default `new/0`.

## Library (PFC) in one glance

Everyday packages: `stdio` (`write`, `writef`, `nl`, `readLine`), `console`, `list` (`length`, `append`, `reverse`, `map`, `filter`, `fold`, `isMember`, `getMember_nd`, `sort`), `string` (`concat`, `format`, `length`, `toUpperCase`, `toLowerCase`, `subString`, `search`), `file`, `fileSystem_api`, `time`, `math`, `exception`. The authoritative library reference ships inside the IDE (`vip.chm` under the install's `appData\doc`) and is not on the wiki, so name library predicates you are confident of and tell the person to check F1 help for exact signatures when unsure. Read `references/pfc-and-idioms.md` for a longer list with signatures and common idioms.

## Where to look when you need more

- `references/language-cheatsheet.md` — full syntax tour: literals, operators, lambdas, properties, generics, namespaces, conditional compilation, error handling.
- `references/pfc-and-idioms.md` — library predicates and recurring idioms (file I/O, string building, list processing, reading input).
- `references/version-12-changes.md` — what Version 12 (Build 1200) added or changed, breaking changes when migrating from 11 (`match`/`case` keywords, `async` namespace rename, HTTP request handlers), and new PFC classes by name. Read it when the person is on 12, is upgrading, or asks for something that looks new.
- `references/async-suspending.md` — asynchronous programming with `suspending` predicates, `future`, `waitSet` (Visual Prolog 11+). Read it whenever the task involves async/await-style code, sockets, HTTP, timers, background work or a non-blocking GUI.
- `references/pitfalls-and-errors.md` — compiler messages you will actually see, what they mean, and the fix. Read this first when debugging.
- `references/examples.md` — complete, hand-checked programs (facts and rules, recursion, list processing, classes with interfaces).
- External: the official wiki at wiki.visual-prolog.com (Language Reference, Tutorial, "Lists and Recursion"), the forum at discuss.visual-prolog.com, and the IDE's bundled Examples folder.

## Self-check before you hand code over

Run through this list on every program, because there is no compiler to catch mistakes:

1. Every predicate used is **declared** (right section, right scope: `class predicates` for static, `predicates` for per-object) with types and a determinism mode.
2. Each clause body **matches its declared determinism**. Anything that can fail inside a `procedure` is wrapped or the declaration is loosened.
3. **Flow patterns**: every variable is bound before it is used as an `[in]`/`i` argument; no singleton variables (use `_` or `_Name`).
4. **Types line up** exactly (`integer` vs `unsigned` vs `real`, `string` vs `char`); use `convert/2`, `toString/1`, `toTerm/1` or library conversions where needed.
5. All clauses of one predicate are **contiguous** and in a `clauses` section; every `if`/`foreach`/`try` is closed.
6. `open core` is present if you use `succeed`, `fail`, `isEmpty`, etc. unqualified; other namespaces are qualified (`list::length`) or opened deliberately.
7. The file has matching `end implement Name` / `end class Name`, and the `.cl`, `.pro`, `.i` split is correct for the project.
8. No ISO/SWI-isms: no `:- dynamic`, `format/2`, `atom_codes`, `assert(foo)` without a `facts` declaration, `:- use_module`, or untyped predicates.

End your reply by saying the code is untested and which version you assumed, in one line.
