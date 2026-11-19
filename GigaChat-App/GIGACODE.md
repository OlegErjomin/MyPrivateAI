# GigaChat-App

## Overview

**GigaChat-App** is a desktop client application built in **Visual Prolog** (BestProlog/PDC) that acts as an AI agent connecting to the **GigaChat** LLM service via REST API and supporting **MCP (Model Context Protocol)** for external tool invocation.

The project consists of two separate Visual Prolog projects:

| Component | Architecture | Purpose |
|-----------|-------------|---------|
| `gigaAgent/` | 32-bit (Win32) | Client agent: OAuth2 authentication, GigaChat API interaction, JSON-RPC MCP client |
| `mcpServer/` | 64-bit (x64) | MCP server: STDIO JSON-RPC server implementing tools (`echo`, `get_time`) |

## Technologies

- **Language:** Visual Prolog (BestProlog / PDC)
- **Platform:** Windows (WinHTTP API, Win32 named pipes, CreateProcess)
- **Protocol:** MCP (Model Context Protocol `2024-11-05`), JSON-RPC 2.0
- **LLM API:** GigaChat REST API (`https://api.giga.chat/v1/chat/completions`)
- **Authentication:** OAuth2 via Sberbank NGW (`https://ngw.devices.sberbank.ru:9443/api/v2/oauth`)
- **Streaming:** SSE (Server-Sent Events)
- **Model:** GigaChat-3-Ultra

## Project Structure

```
GigaChat-App/
+-- config.json              # Configuration: OAuth, API URL, model, MCP server path
+-- init.json                # Example JSON-RPC initialize request for MCP
+-- mcp.json                 # MCP server config (filesystem)
+-- .gitignore
|
+-- gigaAgent/               # AI Agent (32-bit)
|   +-- main.pro             # Entry point: args parsing, config reading, dialog loop
|   +-- gigaChatApi/         # GigaChat REST API wrapper
|   |   +-- gigaChatApi.i    # Interface: init, auth, chat, chatStream, mcpHandShake
|   |   +-- gigaChatApi.pro  # Implementation: OAuth2, winHttp, SSE streaming
|   +-- gigaChatAgent/       # AI agent logic
|   |   +-- gigaChatAgent.i  # Interface: run, reset, maxSteps, streaming, tokenHandler
|   |   +-- gigaChatAgent.pro # Dialog loop: send prompt, handle function_call, MCP calls
|   +-- mcpClient/           # MCP protocol client
|   |   +-- mcpClient.i/pro  # JSON-RPC 2.0: request, notify, listTools, callTool
|   |   +-- mcpProcessTransport.cl/pro  # Child process + named pipes (stdin/stdout)
|   |   +-- mcpPipe_native.cl  # Win32 API: CreatePipe, ReadFile, WriteFile
|   +-- HttpUtility/         # URL encoding and URI parsing
|   +-- utils/               # Utilities (joinAll - pairwise merge O(n log n))
|
+-- mcpServer/               # MCP Server (64-bit)
    +-- main.pro             # Entry point: STDIO JSON-RPC loop
    +-- mcpSession.cl/i/pro  # Session state (initialized, clientInfo, log)
    +-- mcpTools.cl/pro      # Tool registration: ping, echo, get_time
```

## Agent Architecture

1. **Launch** - `main.pro` reads `config.json`, acquires OAuth token via NGW.
2. **MCP handshake** - launches `mcpServer.exe`, performs JSON-RPC `initialize`.
3. **Dialog loop** - waits for user input (`>> ` prompt), sends request to GigaChat.
4. **function_call handling** - if the model requests a tool call, the agent:
   - Parses `function_call` from response (supports streaming).
   - Calls the appropriate MCP tool via `mcpClient.callTool`.
   - Substitutes the result back into the GigaChat request.
   - Repeats up to `maxSteps` = 8 or until a final response is received.
5. **Streaming** - in streaming mode, tokens are output as they arrive via `tokenHandler`.

## Configuration

### config.json

```json
{
  "gigaChat": {
    "auth": {
      "oauthUrl": "https://ngw.devices.sberbank.ru:9443/api/v2/oauth",
      "clientID": "01a18d6c-c77a-7027-b50c-89a0c6209ace",
      "scope": "GIGACHAT_API_PERS"
    },
    "apiUrl": "https://api.giga.chat/v1/chat/completions",
    "model": "GigaChat-3-Ultra",
    "stream": true,
    "mcpServer": "c:\\\\GITHUB\\\\MyPrivateAI\\\\GigaChat-App\\\\mcpServer\\\\exe64\\\\mcpServer.exe"
  }
}
```

> **Important:** `clientSecret` and `authorizationKey` are stored in `config.json`. Do not commit this file with secrets to public repositories.

## Build and Run

### vipBuilder path

```
C:\\Git\\wwPlatform\\Backend\\node_modules\\@pdc_vip\\visual-prolog\\bin64\\vipBuilder.exe
```

### Build commands

```cmd
REM Build gigaAgent (32-bit)
cd C:\\GITHUB\\MyPrivateAI\\GigaChat-App\\gigaAgent
C:\\Git\\wwPlatform\\Backend\\node_modules\\@pdc_vip\\visual-prolog\\bin64\\vipBuilder.exe gigaAgent.vipprj /build

REM Build mcpServer (64-bit)
cd C:\\GITHUB\\MyPrivateAI\\GigaChat-App\\mcpServer
C:\\Git\\wwPlatform\\Backend\\node_modules\\@pdc_vip\\visual-prolog\\bin64\\vipBuilder.exe mcpServer.vipprj /build
```

| Project | Configuration | Output |
|---------|-------------|--------|
| `gigaAgent/` | Default | `gigaAgent/exe64/gigaAgent.exe` |
| `mcpServer/` | Default | `mcpServer/exe/mcpServer.exe` |

`.vipprj` files are Visual Prolog XML projects. Git ignores build artifacts (`*.obj`, `*.exe`, `*.dll`, `*.scope`).

### Run

```cmd
REM Run the agent (reads config.json from current directory by default)
cd gigaAgent\\exe64
gigaAgent.exe

REM Run with custom config
gigaAgent.exe -config C:\\path\\to\\config.json
```

The agent will launch the MCP server via `CreateProcess`, perform handshake, and enter interactive dialog mode.

## MCP Server: Available Tools

| Tool | Arguments | Description |
|------|-----------|-------------|
| `echo` | `text: string` | Returns the provided text unchanged |
| `get_time` | none | Returns the current local date and time of the machine |

## Development Conventions

- **Source code:** Visual Prolog (`*.pro`, `*.cl`, `*.i`, `*.ph`, `*.pack`)
- **Architecture:** modular, each subdirectory is a separate package
- **Threading:** `multiThread_native`, `windowsAPI`
- **Build system:** vipBuilder CLI (no CMake/Makefile)
- **Testing:** `test.ps1` - PowerShell script for OAuth authentication testing
- **Logging:** `mcpSession.log` writes to stderr

## Key Files

| File | Description |
|------|-------------|
| `config.json` | OAuth credentials, API URL, MCP server path |
| `init.json` | Example JSON-RPC `initialize` request for MCP debugging |
| `mcp.json` | MCP server configuration (filesystem transport) |
| `test.ps1` | PowerShell script for OAuth verification |
| `.gitignore` | Ignores BestProlog build artifacts |