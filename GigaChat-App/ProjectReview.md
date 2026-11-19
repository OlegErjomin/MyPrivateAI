# Анализ проекта gigaAgent

## 📁 Общая архитектура

**gigaAgent** — консольное CLI-приложение на Visual Prolog (32-bit), которое работает как AI-агент, подключаясь к LLM-сервису GigaChat через REST API и поддерживая вызов внешних инструментов через MCP (Model Context Protocol).

### Модули проекта

| Модуль | Назначение | Файлы |
|--------|------------|-------|
| main.pro | Точка входа, CLI-парсинг, цикл диалога | 1 файл |
| gigaChatApi/ | Обёртка над GigaChat REST API, OAuth2 | 4 файла |
| gigaChatAgent/ | Логика AI-агента, обработка tool calls | 4 файла |
| mcpClient/ | MCP-протокол клиент, JSON-RPC, процесс-транспорт | 8 файлов |
| HttpUtility/ | URL encoding/decoding, URI parsing | 2 файла |
| utils/ | Утилиты (joinAll) | 2 файла |

---

## 🔄 Поток выполнения

`
main.pro
  ├── config.json → OAuth2 токен → gigaChatApi:auth()
  ├── MCP handshake → mcpServer.exe → gigaChatApi:mcpHandShake()
  └── Цикл диалога
        ├── Пользователь вводит текст
        ├── gigaChatAgent:run(prompt) → запрос к GigaChat
        ├── Если function_call → mcpClient:callTool() → результат обратно в LLM
        └── Возврат финального ответа пользователю
`

---

## 🔍 Детальный анализ по модулям

### 1. main.pro — Точка входа

**Функциональность:**
- CLI-парсер с опциями -config и -help
- Загрузка config.json с fallback на json::n
- Инициализация агента и запуск цикла диалога

**Важные замечания:**
`prolog
conversationLoop(Agent) :-
    console::write(">> "),
    Question = console::readLine(),
    string::toLowerCase(Question) <> "quit",  % Exit condition
    !,
    Answer = Agent:run(Question),
    if false = Agent:streaming then
        console::write(Answer, "\n")
    end if,
    conversationLoop(Agent).
`

---

### 2. gigaChatApi/ — GigaChat REST API

**Ключевые особенности:**

- **OAuth2 аутентификация** через Sberbank NGW (
gw.devices.sberbank.ru:9443)
- **Кэширование токена** с проверкой срока действия (	ryGetAccessToken/1)
- **Два режима чата**:
  - chat/1 — синхронный запрос с полным ответом
  - chatStream/2 — SSE-стриминг с callback-обработчиком

**Реализация HTTP-вызовов:**
`prolog
postOAuth(AuthKey, Rquid, Scope) = Response :-
    Session = winHttp_api::winHttpOpen("VisualProlog"),
    Connection = winHttp_api::winHttpConnect(Session, ngwHost, ngwPort),
    Request = winHttp_api::winHttpOpenRequest(Connection, "POST", ngwPath, ...),
    % Отключение клиентского сертификата
    winHttp_native::winHttpSetOption(Request, winHttp_native::winhttp_option_client_cert_context, ...),
    % Отправка заголовков и тела запроса
    winHttp_api::winHttpSendRequest(Request, "", uncheckedConvert(pointer, Body), Len, Len),
    Response = readAll(Request)
`

---

### 3. gigaChatAgent/ — Логика AI-агента

**Основные концепции:**

- **Поддержка функции** — моделирует conversation history как список сообщений
- **Обработка tool calls** — рекурсивный вызов инструментов до получения текстового ответа
- **Стриминг** — accumulation токенов через callback onChunk/1

**Критическая логика step/3:**
`prolog
step(Functions, Messages, Depth) = Answer :-
    Req = jsonObject::new(),
    Req:set_string("model", giga:model),
    Req:set("messages", a(Messages)),
    Req:set_boolean("stream", streaming),
    if [] <> Functions then
        Req:set("functions", a(Functions)),
        Req:set_string("function_call", "auto")
    end if,
    Msg = complete(Req),
    if some(FC) = Msg:get_object_optional("function_call") then
        Name = FC:get_string("name"),
        Args = argumentsOf(FC),
        ToolText = runTool(Name, Args),
        Next = list::append(Messages, [o(Msg), functionMessage(Name, ToolText)]),
        Answer = step(Functions, Next, Depth + 1)  % Рекурсия
    else
        Answer = Msg:get_string("content")
    end if.
`

**Стриминг-логика:**
`prolog
onChunk(Chunk) :-
    some(a([o(Choice) | _])) = Chunk:get_optional("choices"),
    some(Delta) = Choice:get_object_optional("delta"),
    if some(Text) = Delta:get_string_optional("content") and "" <> Text then
        accContent := string::concat(accContent, Text),
        tokenHandler(Text)
    end if,
    if some(FC) = Delta:get_object_optional("function_call") then
        hasFc := true,
        Args = FC:get_optional("arguments"),
        if some(o(O)) = Args then
            accArgsObj := some(O)
        elseif some(s(T)) = Args then
            accArgsText := string::concat(accArgsText, T)
        end if
    end if.
`

---

### 4. mcpClient/ — MCP-протокол клиент

**Компоненты:**

- mcpClient.pro — JSON-RPC 2.0 клиент
- mcpProcessTransport.pro — запуск дочернего процесса через Win32 pipes
- mcpPipe_native.cl — обёртки над Win32 API (CreatePipe, ReadFile, WriteFile)

**JSON-RPC обработка:**
`prolog
readResponse(Id) = Result :-
    Line = transport:readLine(),
    if "" = string::trim(Line) then
        Result = readResponse(Id)
    else
        Value = json::fromString(Line),
        if o(Obj) = Value then
            Result = handleMessage(Id, Obj)
        else
            Result = readResponse(Id)
        end if
    end if.
`

**Обработка входящих запросов от сервера:**
`prolog
handleMessage(Id, Msg) = Result :-
    some(M) = Msg:get_optional("method"),
    answerServerRequest(Method, ServerId),
    Result = readResponse(Id).

answerServerRequest(Method, ServerId) :-
    if "ping" = Method then
        Resp:set_object("result", jsonObject::new())
    else
        Err:set_integer("code", jsonRpcError::methodNotFound),
        Resp:set_object("error", Err)
    end if.
`

---

## ⚠️ Найденные проблемы и замечания

### Критические 🔴

#### 1. **Отсутствие таймаута на HTTP-вызовы OAuth2**

**Файл:** gigaChatApi.pro

**Проблема:** В postApi/2 настроены таймауты:
`prolog
_ = winHttp_native::winHttpSetTimeouts(Session, 10000, 10000, 30000, 120000),
`
Но в postOAuth/3 они **не устанавливаются**. Если сервер NGW не отвечает, OAuth-запрос может зависнуть навсегда.

**Рекомендация:** Добавить winHttpSetTimeouts в postOAuth/3 для консистентности.

---

#### 2. **OAuth2 токен может истечь во время стриминга**

**Файл:** gigaChatAgent.pro

`prolog
chatStream(JsonRequest, OnChunk) :-
    Token = tryGetAccessToken(),  % <- Проверка только в начале
    ...
`

**Проблема:** Если стриминг длится дольше срока жизни токена (обычно ~15 минут), запрос может завершиться с ошибкой 401.

**Рекомендация:** Периодически проверять срок действия токена во время стриминга.

---

#### 3. **Необработанное исключение при парсинге function_call аргументов**

**Файл:** gigaChatAgent.pro

`prolog
argumentsOf(FC) = Args :-
    Value = FC:get("arguments"),
    if o(Obj) = Value then
        Args = Obj
    elseif s(Text) = Value then
        Args = json::fromString(Text)  % <- Может выбросить исключение при невалидном JSON
    else
        Args = jsonObject::new()
    end if.
`

**Риск:** Если модель вернёт невалидный JSON в rguments, исключение поднимется наверх и прервёт step/3.

**Рекомендация:**
`prolog
argumentsOf(FC) = Args :-
    Value = FC:get("arguments"),
    if o(Obj) = Value then
        Args = Obj
    elseif s(Text) = Value then
        Args = try json::fromString(Text) catch _ -> jsonObject::new() end try
    else
        Args = jsonObject::new()
    end if.
`

---

### Предложения 🟡

#### 4. **Нет валидации ответа MCP-сервера**

**Файл:** mcpClient.pro

`prolog
callTool(Name, Arguments, IsError) = Text :-
    if o(R) = request("tools/call", o(Params)) then
        ...
        if a(Content) = R:get("content") then
            Text = string::concatWithDelimiter(textParts(Content), "\n")
        else
            Text = ""  % <- Если content пустой, агента ничего не получает
        end if
    else
        Text = "",  % <- Если request вернул none, также ничего не сообщаем
        IsError = false
    end if.
`

**Риск:** Если MCP-сервер вернёт пустой ответ или equest вернёт 
one, агента получит пустую строку и передаст её в LLM как результат инструмента, что может запутать модель.

**Рекомендация:**
`prolog
callTool(Name, Arguments, IsError) = Text :-
    if o(R) = request("tools/call", o(Params)) then
        ...
        if a(Content) = R:get("content") then
            Text = string::concatWithDelimiter(textParts(Content), "\n")
        else
            Text = "No content returned by tool"  % <- Более информативно
        end if
    else
        Text = string::format("MCP request failed for tool: %", Name),
        IsError = true
    end if.
`

---

#### 5. **Потенциальная утечка ресурсов при ошибке инициализации**

**Файл:** main.pro

`prolog
conversationLoop(Agent),
MCP:close()  % <- Закрывается в конце
`

**Риск:** Если conversationLoop/1 выбросит исключение, MCP:close() не вызовется.

**Рекомендация:**
`prolog
try
    conversationLoop(Agent)
finally
    MCP:close()
end try
`

---

#### 6. **Отсутствие пагинации в listTools/1**

**Файл:** mcpClient.pro

`prolog
listTools() = Tools :-
    % NOTE: does not follow "nextCursor" pagination
    if o(R) = request("tools/list", o(jsonObject::new())) and a(L) = R:get("tools") then
        Tools = L
    else
        Tools = []
    end if.
`

**Замечание:** В комментарии указано, что пагинация не реализована. Это может быть проблемой, если сервер вернёт >100 инструментов.

**Рекомендация:** Реализовать поддержку 
extCursor для серверов с большим количеством инструментов.

---

#### 7. **Нет обработки 401/422 от GigaChat API**

**Файл:** gigaChatAgent.pro

`prolog
step(Functions, Messages, Depth) = Answer :-
    ...
    Msg = complete(Req),
`

Если API вернёт 401 (токен истёк) или 422 (невалидный запрос), ответ будет содержать поле error, но код не проверяет это явно.

**Рекомендация:** Проверять поле error в ответе API и повторять аутентификацию при 401.

---

#### 8. **mcpHandShake/1 закрывает соединение после проверки**

**Файл:** gigaChatApi.pro

`prolog
mcpHandShake() :-
    if some(MCPServerCommand) = mcpServer then
        Transport = mcpProcessTransport::new(MCPServerCommand),
        Mcp = mcpClient::new(Transport),
        Mcp:initialize(),
        console::write("handshake ok\n"),
        Mcp:close()  % <- Закрывает сразу после проверки
    end if.
`

**Замечание:** Это намеренное поведение — проверка работоспособности сервера. Однако если сервер упадёт после handshake, ошибка обнаружится только при первом вызове callTool.

**Рекомендация:** Добавить ping-проверку после handshake:
`prolog
mcpHandShake() :-
    ...
    Mcp:initialize(),
    % Ping для проверки
    Mcp:request("ping", o(jsonObject::new())),
    console::write("handshake ok\n"),
    Mcp:close()
`

---

### Небольшие замечания 🟢

#### 9. **Жёстко закодированные значения**

**Файл:** gigaChatAgent.pro

`prolog
systemPrompt : string := "".  % <- Пустой системный промпт по умолчанию
maxSteps : unsigned := 8.     % <- Хардкод
`

**Рекомендация:** Вынести maxSteps в конфиг или сделать константой с описанием.

---

#### 10. **Console::write без проверки кодировки**

**Файл:** main.pro

`prolog
console::write(">> "),
Question = console::readLine(),
`

**Замечание:** В main.pro вызывается console::initUtf8(), но console::write/1 и console::readLine() могут некорректно работать с русским текстом в некоторых терминалах Windows.

---

## ✅ Сильные стороны

1. **Хорошая модульность** — чёткое разделение ответственности между модулями
2. **Поддержка стриминга** — правильная реализация SSE с callback-обработчиками
3. **Обработка ошибок** — try-catch на всех критических участках
4. **MCP-протокол** — корректная реализация JSON-RPC 2.0 с поддержкой server-initiated запросов
5. **Управление ресурсами** — 	ry...finally для закрытия WinHTTP-соединений
6. **Кэширование токенов** — проверка срока действия перед каждым запросом
7. **Безопасность** — отключение клиентских сертификатов, use of uncheckedConvert только для синхронных операций

---

## 📊 Статистика

| Метрика | Значение |
|---------|----------|
| Исходных файлов (.pro, .cl, .i) | 15 |
| Строк кода (примерно) | ~1500 |
| Модулей | 6 |
| API-вызовов WinHTTP | 3 (postOAuth, postApi, chatStream) |
| MCP-методов | 4 (initialize, 	ools/list, 	ools/call, ping) |
| Инструментов сервера | 2 (echo, get_time) |