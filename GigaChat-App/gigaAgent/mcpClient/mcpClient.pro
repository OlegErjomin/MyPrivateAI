% Copyright (c) 2026 BestProlog

implement mcpClient
    open core, json

facts
    transport : mcpTransport := erroneous.
    lastId : integer := 0.

clauses
    new(Transport) :-
        transport := Transport.

clauses
    initialize() :-
        Params = jsonObject::new(),
        Params:set_string("protocolVersion", "2024-11-05"),
        Params:set_object("capabilities", jsonObject::new()),
        Info = jsonObject::new(),
        Info:set_string("name", "gigaChatAgent"),
        Info:set_string("version", "0.1"),
        Params:set_object("clientInfo", Info),
        _Result = request("initialize", o(Params)),
        notify("notifications/initialized", o(jsonObject::new())).

clauses
    request(Method, Params) = Result :-
        lastId := lastId + 1,
        Id = lastId,
        Req = jsonObject::new(),
        Req:set_string("jsonrpc", "2.0"),
        Req:set_integer("id", Id),
        Req:set_string("method", Method),
        Req:set("params", Params),
        transport:writeLine(json::asString(o(Req))),
        Result = readResponse(Id).

clauses
    notify(Method, Params) :-
        Req = jsonObject::new(),
        Req:set_string("jsonrpc", "2.0"),
        Req:set_string("method", Method),
        Req:set("params", Params),
        transport:writeLine(json::asString(o(Req))).

predicates
    readResponse : (integer Id) -> jsonValue Result.
clauses
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

predicates
    handleMessage : (integer Id, jsonObject Msg) -> jsonValue Result.
clauses
    % response to our request
    handleMessage(Id, Msg) = Result :-
        Id = Msg:tryGet_integer("id"),
        none = Msg:get_optional("method"),
        !,
        if some(Err) = Msg:get_object_optional("error") then
            exception::raise_definiteUser(string::format("MCP error %: %", Err:get_integer("code"), Err:get_string("message")))
        else
            Result = Msg:get("result")
        end if.

    % request from the server
    handleMessage(Id, Msg) = Result :-
        some(M) = Msg:get_optional("method"),
        s(Method) = M,
        some(ServerId) = Msg:get_optional("id"),
        !,
        answerServerRequest(Method, ServerId),
        Result = readResponse(Id).

    % notification, or a response to something else: ignore
    handleMessage(Id, _Msg) = readResponse(Id).

predicates
    answerServerRequest : (string Method, jsonValue ServerId).
clauses
    answerServerRequest(Method, ServerId) :-
        Resp = jsonObject::new(),
        Resp:set_string("jsonrpc", "2.0"),
        Resp:set("id", ServerId),
        if "ping" = Method then
            Resp:set_object("result", jsonObject::new())
        else
            Err = jsonObject::new(),
            Err:set_integer("code", jsonRpcError::methodNotFound),
            Err:set_string("message", "Method not found"),
            Resp:set_object("error", Err)
        end if,
        transport:writeLine(json::asString(o(Resp))).

clauses
    listTools() = Tools :-
        % NOTE: does not follow "nextCursor" pagination
        if o(R) = request("tools/list", o(jsonObject::new())) and a(L) = R:get("tools") then
            Tools = L
        else
            Tools = []
        end if.

clauses
    callTool(Name, Arguments, IsError) = Text :-
        Params = jsonObject::new(),
        Params:set_string("name", Name),
        Params:set_object("arguments", Arguments),
        if o(R) = request("tools/call", o(Params)) then
            if some(t()) = R:get_optional("isError") then
                IsError = true
            else
                IsError = false
            end if,
            if a(Content) = R:get("content") then
                Text = string::concatWithDelimiter(textParts(Content), "\n")
            else
                Text = ""
            end if
        else
            Text = "",
            IsError = false
        end if.

predicates
    textParts : (jsonValue* Content) -> string* Texts.
clauses
    textParts([]) = [].
    textParts([o(Item) | Rest]) = [Item:get_string("text") | textParts(Rest)] :-
        some("text") = Item:get_string_optional("type"),
        !.
    textParts([_ | Rest]) = textParts(Rest).

clauses
    close() :-
        transport:close().

end implement mcpClient
