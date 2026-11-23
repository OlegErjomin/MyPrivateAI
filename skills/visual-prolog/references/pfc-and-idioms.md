# PFC library and idioms

Contents: how to read PFC · console I/O · strings · lists · files · time and math · common idioms.

The Prolog Foundation Classes reference ships inside the IDE (`vip.chm`, in the install folder's `appData\doc`) and is deliberately not published on the wiki. The signatures below are the ones to reach for first, but they are written from memory of the library: if the person has the IDE, press F1 on the predicate name to confirm. When unsure whether a name exists, say so and offer the nearest alternative rather than inventing.

## Reading PFC code

A package is a directory under `pfc\` with a `.ph` header (`#include @"pfc\string\string.ph"`). Console projects created from the template already include the common ones. Each package exposes a class: `string`, `list`, `stdio`, `console`, `file`, `time`, `math`, `std`, `exception`, `fileSystem_api`.

## Console I/O (`console`, `stdio`)

```prolog
console::init(),                          % once at start
stdio::write("a", 1, 'c', " ", X),         % variadic, prints values, strings without quotes
stdio::writef("%s has %d items\n", Name, N),   % format string
stdio::nl(),
Line = stdio::readLine(),                 % read a line (string)
S = console::readLine().                  % often used in console projects
```

`write` prints any value; `writef` uses `%s %d %u %f %c` style specifiers. For quoted/debug output use `writeq`-like helpers in `stdio` if present in the version (`stdio::write(toString(X))` is always safe).

## Strings (`string`)

```prolog
string::concat(A, B)                 % -> string
string::format("%s-%d", S, N)        % -> string (like sprintf)
string::length(S)                    % -> unsigned
string::toUpperCase(S), string::toLowerCase(S)
string::subString(S, Start, Len)     % -> string
string::search(Haystack, Needle, Pos)    % determ, Pos is 1-based on some versions: check help
string::split(S, Delimiters)         % -> string* (names vary: check help)
toString(X)                          % any value -> string (from core)
toTerm(Str)                          % parse string to a term of the expected domain
```

Concatenate several pieces cleanly with `string::format` or `string::concatList([A, B, C])` if available.

## Lists (`list`)

```prolog
list::length(L)                      % -> unsigned
list::append(A, B)                   % -> list
list::reverse(L)
list::isMember(X, L)                 % determ test
list::getMember_nd(L)                % nondeterm enumerator, use with foreach
list::map(L, { (X) = F(X) })
list::filter(L, { (X) :- Test(X) })
list::fold(L, { (X, A) = A + X }, Initial)
list::sort(L)
list::tryGetNth(N, L, Elem)          % determ
list::remove(L, X)                   % first occurrence
list::removeAll(L, X)
list::removeDuplicates(L)
```

`std::fromTo(1, 10)` enumerates integers in `foreach`.

## Files (`file`, `fileSystem_api`)

```prolog
Text = file::readString("data.txt", _IsUnicode),  % check the exact overload in your version
file::writeString("out.txt", Text),
file::existFile("data.txt"),                      % determ
```

Process a file line by line with `inputStream_file::openFile(...)` and `readLine`, closing in a `finally`.

## Time and math

`time::new()` creates a timestamp object; `math::sqrt`, `math::sin`, `math::pi`, `math::random`. Use `convert(real, N)` when feeding integers to real functions.

## Idioms

**Loop over all solutions, side effects only**

```prolog
foreach parent(Child, Parent) do
    stdio::writef("%s -> %s\n", Child, Parent)
end foreach.
```

**Collect solutions into a list** (the replacement for `findall/3`)

```prolog
Names = [ Name || person(Name, Age), Age > 30 ].
Doubled = [ X * 2 || X = list::getMember_nd(Numbers) ].
```

Form: `L = [ Expression || Goal1, Goal2, ... ]`. The result type is a list of the expression's type. Sort or deduplicate afterwards with `list::sort` / `list::removeDuplicates` if you need `setof`-like behaviour.

**Fail-safe lookup in a procedure**

```prolog
ageOf(Name) = Age :- if person(Name, A) then Age = A else Age = 0 end if.
```

**Accumulator recursion**

```prolog
sumTo(N) = sumTo(N, 0).
sumTo(0, Acc) = Acc :- !.
sumTo(N, Acc) = sumTo(N - 1, Acc + N).
```

**Run a goal once and keep going**

Wrap a `nondeterm` call in `if` (takes the first solution) instead of using a cut at the call site.

**Menu/loop in a console app**

```prolog
loop() :-
    stdio::write("> "),
    Cmd = stdio::readLine(),
    if Cmd = "quit" then
        succeed
    else
        handle(Cmd),
        loop()
    end if.
```
