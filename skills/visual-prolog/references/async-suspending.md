# Asynchronous programming: suspending predicates

Contents: what and when · declaring · calling rules · parallelism with futures · waitSet · execution contexts · restrictions · patterns · version notes · what is not documented.

Source: the Language Reference page "Suspending Predicates" and the "Visual Prolog 11 New Features" page on wiki.visual-prolog.com. Suspending predicates were introduced in Visual Prolog 11 (Build 1105), so they do not exist in 10 or earlier. The wiki pages are brief; everything below is what they state, and anything marked *unverified* is inference. Check the wiki and the IDE's library help for exact signatures before relying on them.

## What and when

A suspending predicate can pause while it waits for something asynchronous (socket read, timer, HTTP response, file watcher) and continue later, without holding a thread meanwhile. Use it for I/O-heavy code, servers, GUI code that must not block the UI thread, and coroutine-style flows. It replaces the older continuation-based style (see version notes).

The language adds one keyword: `suspending`. Everything else is library (`future`, `waitSet`, execution contexts).

## Declaring

`suspending` is added to a predicate declaration or to a predicate domain, alongside the usual signature and determinism:

```prolog
domains
    webSocket_asyncOp = (webSocket WebSocket) suspending.

class predicates
    echoLoop_async : (webSocket WebSocket) suspending.
    tryCalculate : () -> integer Result determ suspending.
    fetch_susp : (string Url) -> string Page suspending.
```

- Output arguments are written as usual: `(string Server, string Result [out]) suspending`.
- The only documented determinism combination with `suspending` is `determ`. Do not invent others (`procedure suspending`, `nondeterm suspending`) without the person confirming the compiler accepts them.
- Naming: the wiki says suspending predicates are conventionally named with a `_susp` suffix, while its own examples also use `_async`. Follow the project's existing convention; default to `_susp`. Names ending in an underscore (`task_susp_`, `heapframe_`) are internal translated entities: never write those yourself.

## Writing the body

Suspending code looks like ordinary clauses and runs in order. Each call to another suspending predicate may suspend and later resume, possibly on a different thread or stack.

```prolog
clauses
    echoLoop_async(WebSocket) :-
        Message = WebSocket:readMessage_async(),
        WebSocket:writeMessage_async(Message),
        echoLoop_async(WebSocket).
```

- Sequencing: in `p_susp() :- q_susp(), r_susp().`, `r_susp` starts only after `q_susp` finishes.
- `if ... then ... else ... end if` is allowed in suspending predicates.
- A suspending predicate may call both other suspending predicates and ordinary (non-suspending) predicates.

## Calling rules

| Caller | Callee | Allowed? |
|---|---|---|
| suspending | suspending | yes, direct call |
| suspending | non-suspending, deterministic | yes |
| suspending | non-suspending `nondeterm`/`multi` | generally no (see restrictions) |
| non-suspending | suspending | **no direct call**: submit it through `future` |

To start suspending work from ordinary code (for example `run/0`, a GUI event handler or a `main`), submit it and get a future:

```prolog
Future = future::submit_unit({ :- echoLoop_async(WebSocket) }),
_ = Future:get().      % blocks the calling thread until done: fine in console main, not in a GUI handler
```

`future::submit_unit` is for work with no result; `future::submit` is for work that returns a value:

```prolog
Page1Future = future::submit({ = fetch_susp("https://example.org/a") }),
```

## Parallelism with futures

Start operations first, wait later. Inside a suspending predicate use `await()` (suspends instead of blocking); in ordinary code use `get()` (blocks):

```prolog
Page1Future = future::submit({ = fetch_susp("https://example.org/a") }),
Page2 = fetch_susp("https://example.org/b"),     % runs while the first is in flight
Page1 = Page1Future:await(),
```

## waitSet: waiting for several futures

A `waitSet` is itself a future. It completes when all member futures have succeeded, or when the first one fails; on failure it cancels the rest and propagates the exception.

```prolog
WaitSet = waitSet::new(),
Page1Future = WaitSet:submit({ = fetch_susp("https://example.org/a") }),
Page2Future = WaitSet:submit({ = fetch_susp("https://example.org/b") }),
WaitSet:await_unit(),
Page1 = Page1Future:await(),
Page2 = Page2Future:await().
```

## Execution contexts

Resumed code runs in an *execution context*: a thread pool for background and parallel work, the GUI thread for UI code, or a regular thread. Build 1105 added PFC classes `executionContext_pool` (multi-threaded pool) and `executionContext_single` (single worker thread); a suspended GUI-related operation can be resumed on the GUI thread via `future::submit`. Each suspending task also has a cancellation context. Both are held in thread-local variables that the library manages, so normal application code does not touch them. Which context a submitted task uses and how to choose one explicitly are not detailed on the wiki: consult the PFC help.

## Restrictions to respect

1. A non-suspending predicate cannot call a suspending one directly. Use `future::submit`/`submit_unit`.
2. Non-suspending `nondeterm` or `multi` predicates generally cannot be called from suspending code. It works only if all their backtracking finishes before the next suspending call, as with a list comprehension. The compiler reports violations. Prefer comprehension or `list::` helpers over `foreach` + nondeterministic generators when you need to cross a suspension.
3. Backtracking does not happen while execution is suspended.
4. Exceptions work with `try ... catch ... end try`. A failure inside a `waitSet` member cancels its siblings.
5. The development environment runs on 64-bit Windows only (it can build 32- and 64-bit programs).

## Version 12 notes (from the Build 1200 change log)

- The namespace `pfc\asynchronous` was renamed to **`async`**, so on Version 12 use `async` in includes and qualified names. A new class `asynch` supports suspending/asynchronous code.
- New in 12: `queueAsync::loop` and `loop_async`, `conditionVariable`, `std::iterate_nd`, `requestHandler_sse` (Server-Sent Events), `httpServerApi` request handlers replacing request queues, `request::cancelRequest_async`, `request::writeResponse_segmented_utf8_async`.
- Compiler fixes in 12 touched suspending code (stack backtrack point in `case` statements, false "unused" warnings). Details and the full list of changes are in `version-12-changes.md`.
- Exact signatures are not in the change log: check the help before use.

## Library pieces that are async-aware (Build 1105+)

`asyncSocket`, `asyncSocketListener`, the HTTP server, JSON RPC, `webSocket`, `webView2`, `watchDirectory`, master/slave support, and `future`/`promise`. Their asynchronous operations are suspending predicates conventionally suffixed `_async` (for example `readMessage_async`, `writeMessage_async`), so check the class in F1 help for the exact names. The older `continuation` class and `threadpool` family were removed as redundant, so code that used them must be migrated: see the Visual Prolog 11 Upgrade Notes on the wiki.

## Pattern: parallel fetch then combine

```prolog
class predicates
    fetchBoth_susp : (string UrlA, string UrlB) -> string* Pages suspending.
clauses
    fetchBoth_susp(UrlA, UrlB) = [PageA, PageB] :-
        WaitSet = waitSet::new(),
        FA = WaitSet:submit({ = fetch_susp(UrlA) }),
        FB = WaitSet:submit({ = fetch_susp(UrlB) }),
        WaitSet:await_unit(),
        PageA = FA:await(),
        PageB = FB:await().
```

*Unverified:* this composes only the documented pieces and has not been compiled. State that when giving it to the person, and mention that `fetch_susp` must exist or be replaced by a real library call.

## Pattern: bridge from console main

```prolog
run() :-
    console::init(),
    F = future::submit_unit({ :- main_susp() }),
    _ = F:get(),
    succeed.
```

## Common mistakes

- Calling `foo_susp()` straight from `run/0` instead of through `future::submit`.
- Using `get()` inside a GUI handler or inside a suspending predicate (blocks a thread, defeats the purpose): use `await()` in suspending code.
- Using `foreach` over a nondeterministic predicate across a suspending call.
- Writing the internal `_`-suffixed names the compiler generates.
- Assuming async works in Visual Prolog 10 or earlier.

## What the wiki does not say (do not guess)

Full `future`/`promise` signatures, how errors from a cancelled task surface, thread-affinity rules for GUI resumption, and other determinism modes for suspending predicates. Say these are undocumented in what you could check, and point to the PFC help (`vip.chm`) and the wiki.
