# AGENTS.md

## Repo shape
- Independent Windows Visual Prolog (PDC / BestProlog) projects; no root build, workspace, or package manager.
- `GigaChat-App/` is the active app: `gigaAgent` (32-bit console client) and `mcpServer` (64-bit MCP stdio server with a 1C COM tool).
- `VIP-Ollama/`, `TestCOM/`, and `Python Exercises/` are separate experiments.
- Load the repo-local `visual-prolog` skill (`skills/visual-prolog/SKILL.md`) before editing `.pro`/`.cl`/`.i`/`.pack`.

## Build and run
Run from each project directory; the target comes from the project.
```cmd
cd GigaChat-App\gigaAgent
C:\Git\wwPlatform\Backend\node_modules\@pdc_vip\visual-prolog\bin64\vipBuilder.exe gigaAgent.vipprj /build

cd ..\mcpServer
C:\Git\wwPlatform\Backend\node_modules\@pdc_vip\visual-prolog\bin64\vipBuilder.exe mcpServer.vipprj /build
```
- `gigaAgent` is Win32 → `gigaAgent\exe\gigaAgent.exe`; `mcpServer` is x64 → `mcpServer\exe64\mcpServer.exe`. `gigaAgent\exe64\gigaAgent.exe` is an older x64 build.
- `GIGACODE.md` has this output table backwards (and other stale details); trust the `.vipprj`, `.env`, `main.pack`, and source.
- `gigaAgent.exe` reads `config.json` from the working directory; `-config <path>` overrides. `mcp.json` is a separate client config for the same server.
- No test suite. Verify by building plus the stdio smoke test below.

## Module wiring
- `.vipprj` lists PFC packs and the project's `main.pack`, not individual `.pro` files.
- `main.pack` is the real module list: `#include @"pfc\...\x.ph"` for dependencies, `#include @"x.pro"` for implementations. `mcpServer` includes all its classes there; `gigaAgent` has one `.pack` per subfolder required from `main.pack`.
- Adding a class means creating `.cl` (plus `.i` if public) and `.pro`, then adding the `.pro` to the owning `.pack`; editing only the `.vipprj` does nothing.

## MCP server
- stdio framing is newline-delimited JSON, one message per line — not LSP `Content-Length` headers. Responses must stay on one line.
- Requests are processed serially: the loop blocks on `Future:getResult()`. Every request should produce exactly one response line; on an unhandled failure `main.pro` currently logs to stderr and sends nothing, so the client waits until timeout.
- Smoke test:
```powershell
'{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}' |
  & GigaChat-App\mcpServer\exe64\mcpServer.exe
```
- Tool descriptors and handlers are in `mcpServer\mcpTools.pro`; `onec_query` is in `mcpServer\onecQuery.pro`.
- `onec_query` reads `onec.connection` from the process working directory. `gigaAgent` starts the server with an inherited working directory, so put the file where `gigaAgent.exe` is launched (or run from `exe\`). The format is documented at the top of `onecQuery.pro`.

## COM and 1C
- `console::runUtf8` already initializes COM as STA (`mainExe::run(..., exe_api::ole)`); the extra `coInitializeEx` in `mcpServer\main.pro` is redundant. `async::submit` pool threads also default to `exe_api::ole`, so each request gets COM on its own STA thread.
- Create and use COM objects within one request; never cache them in class facts across requests, because the next request may run on a different pool thread. `onecQuery` opens a new 1C connection per call for this reason.
- `mcpServer` is x64 and uses `V83.COMConnector`; a 32-bit-only 1C install will not register that class for it (`REGDB_E_CLASSNOTREG`).

## Secrets and git
- `GigaChat-App\config.json` and `GigaChat-App\gigaAgent\test.ps1` are tracked and contain OAuth `clientSecret` / `authorizationKey`. Do not print, copy, or commit new credentials; these need rotation.
- `.gitignore` lives only in `GigaChat-App\`, so root-level build output (`VIP-Ollama\exe64`, `TestCOM`, `Python Exercises\__pycache__`) appears untracked.

## Conventions
- `gigaChatAgent` caps tool round-trips at `maxSteps` = 8.
- `GIGACODE.md` and `ProjectReview.md` are partly stale (wrong output dirs; the `MCP:close()` claim is outdated). Prefer source and update the docs when you touch the area.
