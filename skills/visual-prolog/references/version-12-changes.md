# Visual Prolog 12 (Build 1200): what changed

Contents: how to read version numbers · language changes · breaking changes and migration · PFC additions · IDE and debugger · runtime behaviour changes · how to use this file.

Source: the official Visual Prolog change log supplied by the user, covering Build 1200 up to step 7 (15 May 2026). A change log lists *that* something exists, not its signature or semantics. There is no official Version 12 documentation available to check, so treat the names below as real but verify exact signatures in the IDE's library help (F1 / `vip.chm`) before writing code that depends on them. Never invent parameters for them.

## Reading version numbers

Version 12 is "Build 1200" with steps: step 1 (mid-2024) through step 7 (15 May 2026), plus patches (for example "step 5 patch 1"). Version 11 builds are 11xx (the 1105 build introduced suspending predicates; 1112 and 1113 are later 11 builds). If the person says "VIP 12.7" they mean Build 1200 step 7. Ask which step only if it matters; most items below landed in steps 1 to 4.

## Language changes

- **`match ... case ... end match`**: new language construct, introduced in Build 1200 step 2 patch 1 (15 Nov 2024). See `language-cheatsheet.md` for the example the user supplied. The change log gives no formal syntax, so keep to the shape of that example.
- **`match` and `case` are now keywords.** Existing code that uses `match` or `case` as a predicate, functor or variable-like name may stop compiling. Build 1200 step 3 patch 2 added a **`retiredFunctor/2` attribute** "for dealing with new keywords (like match and case)", used to keep old functors usable. Check the IDE help for its exact form. When a Version 11 program fails to compile on 12 with errors around a name `match`/`case`, suggest renaming first and `retiredFunctor` second.
- **New attributes `traceEllipsis` and `traceEllipsisAllVariables`** for tracing support (the change log mentions them in the context of ellipsis blocks and anonymous predicates). Rarely needed by application code.
- **Fixes worth knowing about** because they affect code generation: tail-call code-generation bugs (steps 4 patch 1 and 3 patch 3), a `foreach` cursor problem (the last unification belongs to the `foreach` body, step 5), backtracking code generation, stack backtrack point in `case` statements inside suspending code, false "unused" warnings in suspending code. If a person reports odd runtime behaviour in tail calls or `foreach`, ask whether they are on the latest build before debugging their logic.
- Suspending predicates themselves came in Version 11 (see `async-suspending.md`).

## Breaking changes and migration (11 to 12)

| Change | Effect on code |
|---|---|
| Namespace `pfc\asynchronous` renamed to **`async`** ("asynchronous" abbreviated to "async") | `#include` paths and qualified names that used `asynchronous` must be updated to `async` |
| New class **`asynch`** with support for suspending/asynchronous code | New entry point for async helpers; check its help page |
| `httpServerApi`: **request queues replaced by request handlers**, so a single queue serves several services | Server code written against the Version 11 request-queue API needs restructuring |
| `binary::data/1->` and `binary::size/1->` **moved to the `core` class** | Calls may need the `core::` qualification or no qualification when `core` is open |
| `match`, `case` reserved | See language changes |
| `requestQueue` and `window` API tweaks (`requestQueue::dispose` now shuts down and closes the queue; `requestQueue::shutdown` un-deprecated; `window::setMinimumSize` now takes DPI scaling into account, with `setMinimumSize_scaled` for scaled values; `helpResponder` generalised onto `window`, replacing the one on `frameDecoration`) | Check callers when upgrading GUI or HTTP code |

When asked to port code, list these categories to the person and only change what their code actually uses.

## PFC additions by area (names only; check help for signatures)

**Async, HTTP, concurrency**
- `queueAsync`: new `loop` and `loop_async` predicates.
- `conditionVariable`: multithread synchronisation object for monitors.
- `std::iterate_nd`: invokes an iterator predicate nondeterministically.
- `httpServerApi`: `request::writeResponse_segmented_utf8_async`, `request::cancelRequest_async` (cancel a request without sending a response; a request whose query string cannot be parsed is cancelled automatically), `requestHandler_sse` (Server-Sent Events), exception `webQueryStringParseError` in `webQueryString`.
- `httpHeaders`: class/interface for HTTP headers with multiplicity (typically cookies).
- `outputStream_console` write predicates are now thread-safe (critical section).

**Text, parsing, streams**
- `segmented_utf8` (and `_utf16`): `toTerm`/`fromTerm`, `mkText`, `tryGetOffset` (line number/position handling).
- `inputStream_utf8` and `outputStream_utf8`: streaming to and from `segmented_utf8`.
- The PFC lexer operates on `segmented::segmented_utf16`; `vipLalr` generates lexing/parsing code for it.
- `string_api`: `urlEscape` and `urlUnescape` for percent-encoding in URLs.

**JSON, serialisation, data**
- `json::serializeSorted` global property; `jsonObject` stores key order for iteration, and `jsonObject::new` with initial members (a tuple list).
- `jsonYamlWriter`: writes JSON values as YAML.
- JSON projecting of integral values now fails (not an exception) if the number is not integral; forward slash escaping in JSON was corrected (steps 5 and 5 patch 1).
- `unixTime`: class for Unix time values.
- New zip support through a `libzip` integration (step 7).
- Cryptography: `nCryptStorageProvider`, `nCryptKey`, `derDecoder` for RSA keys; `jwt` `create_signed_rsa`.
- `odbcStatement` uses `SqlDescribeParam` for prepared statements when inserting a null value.

**Math, exceptions, misc**
- `math`: new predicates converting reals to integral domains.
- `exception::raise_exceptionf`: raise a specific exception with a formatted message.
- `pie\variable` property `nextVarNum`, `log` removes appenders that raise exceptions, `pdh_native` bindings to Windows performance counters, `useExe` explicit handle inheritance.

**GUI**
- New `flowLayoutPanelControl`; MDI GUI applications no longer need a menu; `window::getTopLevelWindow`; `ribbonControl` performance and layout fixes; `sciLexer` improvements (DirectWrite by default, `lowLevelDirectFunction`, `insertCheck` notification); `gui_api` additions for window-station queries; colour helpers `blendColor_vpi`, `darken_vpi`, `lighten_vpi` in `vpiDomains`; `webView2` close fix; `watchDirectory` and `webSocket` updates.

## IDE and tooling

- Run in window uses Windows Terminal when present.
- Editor: indentation guides. Debugger: add tracepoint, many stability and display fixes (long list expansion, fastcall, presenters, disassembly).
- The compiler reads sources in segments to avoid allocating large memory blocks; `vipLalrGen` handles an empty path to the grammar file.
- Auto-format (`vipPP`) comma-and-comment handling fixed.

## Runtime behaviour changes to watch for

- **`readLine` and `\r\n`**: the change log says the position after `readLine` changed slightly for the `\r\n` pair (step 5 patch 1), `readLineCRLF` was fixed to return `\r\n` instead of `\r`, and reading until end of stream now leaves the correct buffer position. Code that parses text files and counts offsets can be affected after upgrading.
- JSON escaping (forward slash) behaviour was changed twice; if output is compared byte-for-byte, retest.

## How to use this file

1. When the person names a version-12-only feature, confirm it appears here before using it, and otherwise say you cannot confirm it exists.
2. Do not use any item here in code for Version 11 or earlier targets; ask the version if unclear.
3. For anything this file lists by name only, say plainly that you know it exists but are not sure of the exact signature, and point to F1 help.
