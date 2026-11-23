# Pitfalls and compiler errors

Contents: ISO-Prolog habits that break · determinism errors · flow/binding errors · type errors · structure errors · runtime surprises.

Error texts below are paraphrased from memory of the compiler's wording and may differ slightly by version. Match on the idea, not the exact string.

## 1. ISO / SWI-Prolog habits that do not carry over

| Habit | In Visual Prolog |
|---|---|
| `:- dynamic foo/1.` | Declare typed facts: `class facts` / `foo : (integer X).` |
| `format("~w~n", [X])` | `stdio::writef("%d\n", X)` or `stdio::write(X, "\n")` or `string::format(...)` |
| `foo(X) :- ...` with no declaration | Declare `foo : (type X) determ.` in `predicates` first |
| Untyped terms like `likes(mary, wine)` | Define a `domains` entry, or declare `likes : (string, string)` and use strings |
| `atom_codes`, `atom_length`, `sub_atom` | `string::` predicates, plus `toString`/`toTerm` |
| `findall(X, goal, L)` (also `bagof`/`setof`) | List comprehension `L = [ X || goal1, goal2, ... ]`; there is no `findall/3`. Goals after `||` are comma-separated, and `X` can be any expression over their variables. |
| `between(1,10,X)` | `foreach X = std::fromTo(1,10) do ... end foreach` |
| `:- initialization(main).` | `goal console::runUtf8(main::run).` (or the template's goal) |
| `;` / `->` for if-then-else | `if ... then ... else ... end if` |
| Atoms as strings (`mary`) | Strings need quotes: `"mary"`, unless you declared an enumeration domain |

Reason this matters: Visual Prolog is compiled and strongly typed, so the compiler needs every name and type up front. Code that relies on runtime flexibility is rejected, not merely slow.

## 2. Determinism errors (the most frequent)

**"Determ predicate called as procedure"** or a similar message about `determ`/`nondeterm` inside a `procedure`.
The caller is declared (or defaults to) `procedure`, but its body calls something that can fail or have several solutions. Fixes, in order of preference:
1. Handle failure explicitly: `if foo(X) then ... else ... end if`.
2. Loosen the caller to `determ` or `nondeterm` if failure is a legitimate outcome.
3. Use `foreach ... do ... end foreach` to run a nondeterministic goal for all solutions inside a procedure.

Remember that a predicate with **no mode written is `procedure`**. Writing `foo : (integer X).` and then giving it two clauses where one can fail is the classic cause.

**Clause "can fail" / "will never succeed" warnings** after a cut or comparison, for example a final catch-all clause that is unreachable. Usually means a `procedure` has a missing default clause. Add one that always succeeds.

**Cut in a `procedure`:** a `!` followed by a goal that can fail is an error. Put the cut after the risky test, or restructure with `if`.

## 3. Flow pattern and binding errors

**"The variable X is not bound / has no value."** Variable used as input before anything binds it. Common causes: a variable first appears inside only one branch of an `if`, an `or` (`;`) where one side binds it and the other does not, or a head argument declared `[out]` that you read before assigning.

**"This flow pattern is not supported / not declared."** Predicate was called with a mix of bound and unbound arguments that its declaration does not allow. Either add `anyflow` (for `determ`/`nondeterm` relation-style predicates) or declare the extra flow, for example `(i,o)` and `(o,i)`.

**Singleton variable warnings** (named variable used once). Rename to `_` or `_Name`. These are warnings but treat them as bugs: they usually mean a typo in a variable name.

**A variable bound in `if` condition used after `end if`.** Bindings made in the `then` branch are visible only in that branch unless the `else` also binds it. Bind the variable in both branches, or compute it with a function.

## 4. Type errors

Strong typing means these show up as compile errors:

- `integer` vs `unsigned` vs `real`: arithmetic mixes are limited. Convert with `convert(real, X)`, `convert(integer, X)`, `convert(unsigned, X)`. `/` yields real, so use `div` for integers.
- `string` vs `char` vs a one-letter string: `"a"` and `'a'` are different types.
- Passing a `string*` where an `integer*` is expected, or a list of one domain where a differently named but identical domain is declared: domains are compared by definition, but object/interface types are compared nominally.
- **Output arguments printed with the wrong function**: `stdio::write` accepts anything, `writef` with `%d` needs an integer, `%s` a string.
- Equality between different domains: `X = Y` requires compatible types, so convert first.

## 5. Structure and syntax errors

- **Predicate clauses split apart.** All clauses of one predicate must be contiguous. If another predicate's clauses appear in between, the compiler treats the later ones as an error. Reorder, not duplicate.
- **Clauses in the wrong section** (clauses outside a `clauses` section, declarations inside it).
- **Class predicate vs object predicate**: a predicate in `predicates` (no `class`) belongs to objects and cannot be called as `ClassName::pred` and cannot be used from a `class predicates` clause without an object.
- **Missing `end`**: `end if`, `end foreach`, `end try`, `end implement Name`, `end class Name`, `end interface Name`.
- **Wrong name capitalisation**: predicate and domain names start lowercase; variables start uppercase. An accidentally uppercase predicate name is parsed as a variable and gives a confusing error.
- **Using a name before opening its namespace**: either `open list` or write `list::length(L)`.
- **Mismatched `.cl`/`.pro`**: a predicate declared in the `.cl` but not implemented in the `.pro` (or vice versa) is an error ("declared but not defined").
- **Forgot `#include`**: console projects need the relevant `.ph` includes (`pfc\console\console.ph`, `pfc\list\list.ph`, ...). If the IDE created the project, leave them; add only what a new package needs.

## 6. Runtime surprises

- **Backtracking into `assert`/`retract` loops** — use `foreach` or end the loop with `fail` deliberately, and never rely on side-effects in a failed branch being undone: facts are not rolled back.
- **Unhandled exceptions** print and terminate; wrap risky external calls (`file::`, `toTerm`) in `try ... catch ... end try`.
- **String indices are 1-based in some library calls and 0-based in others**: check the library help for the particular predicate rather than assuming.
- **Non-ASCII text in the console** depends on `console::runUtf8` versus older `mainExe::run`; if letters display wrongly, this is the first thing to check.
- **Stack/recursion depth**: deep non-tail recursion on huge lists can overflow; write accumulator (tail-recursive) versions or use `list::fold`.
