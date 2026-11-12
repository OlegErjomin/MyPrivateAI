% Copyright (c) 2026 BestProlog

implement mcpTools
    open core, json

clauses
    register(Api) :-
        Api:setProc_name("ping", onPing),
        Api:setProc_name("tools/list", onToolsList),
        Api:setProc_name("tools/call", onToolsCall),
        Api:setListener_name("notifications/initialized", onInitialized),
        Api:setListener_name("notifications/cancelled", onCancelled).

% ---------------------------------------------------------------- protocol handlers
class predicates
    onPing : mcpSession::mcpMethod.
clauses
    onPing(_Session, _Args) = o(jsonObject::new()).

class predicates
    onInitialized : (mcpSession Session, jsonObject Args).
clauses
    onInitialized(Session, _Args) :-
        Session:log("client initialized").

class predicates
    onCancelled : (mcpSession Session, jsonObject Args).
clauses
    onCancelled(Session, _Args) :-
        Session:log("cancel notification ignored").

class predicates
    onToolsList : mcpSession::mcpMethod.
clauses
    onToolsList(_Session, _Args) = o(Result) :-
        Result = jsonObject::new(),
        Result:set("tools", a([echoTool(), getTimeTool()])).

class predicates
    onToolsCall : mcpSession::mcpMethod.
clauses
    onToolsCall(Session, Args) = Result :-
        Name = Args:get_string("name"),
        ToolArgs = if some(A) = Args:get_object_optional("arguments") then A else jsonObject::new() end if,
        Result = callTool(Session, Name, ToolArgs).

% ---------------------------------------------------------------- tool descriptors
class predicates
    echoTool : () -> jsonValue Tool.
clauses
    echoTool() = o(Tool) :-
        TextProp = jsonObject::new(),
        TextProp:set_string("type", "string"),
        TextProp:set_string("description", "The text to echo back"),
        Props = jsonObject::new(),
        Props:set_object("text", TextProp),
        Schema = jsonObject::new(),
        Schema:set_string("type", "object"),
        Schema:set_object("properties", Props),
        Schema:set("required", a([s("text")])),
        Tool = jsonObject::new(),
        Tool:set_string("name", "echo"),
        Tool:set_string("description", "Returns the given text unchanged"),
        Tool:set_object("inputSchema", Schema).

class predicates
    getTimeTool : () -> jsonValue Tool.
clauses
    getTimeTool() = o(Tool) :-
        Schema = jsonObject::new(),
        Schema:set_string("type", "object"),
        Schema:set_object("properties", jsonObject::new()),
        Tool = jsonObject::new(),
        Tool:set_string("name", "get_time"),
        Tool:set_string("description", "Returns the current local date and time of the machine the server runs on"),
        Tool:set_object("inputSchema", Schema).

% ---------------------------------------------------------------- tool implementations
class predicates
    callTool : (mcpSession Session, string Name, jsonObject Args) -> jsonValue Result.
clauses
    callTool(_Session, "echo", Args) = Result :-
        !,
        if some(Text) = Args:get_string_optional("text") then
            Result = textResult(Text, false)
        else
            % tool-level failure: reported inside the result so the model can see it
            Result = textResult("Missing required argument: text", true)
        end if.

    callTool(_Session, "get_time", _Args) = textResult(string::format("% %", Now:formatLongDate(), Now:formatTime()), false) :-
        Now = time::now(),
        !.

    callTool(_Session, Name, _Args) = _Result :-
        % protocol-level failure: becomes a JSON-RPC error response
        jsonRpcApiMap{mcpSession}::raise_callError(jsonRpcError::invalidParams, string::format("Unknown tool: %", Name)).

class predicates
    textResult : (string Text, boolean IsError) -> jsonValue Result.
clauses
    textResult(Text, IsError) = o(Result) :-
        Item = jsonObject::new(),
        Item:set_string("type", "text"),
        Item:set_string("text", Text),
        Result = jsonObject::new(),
        Result:set("content", a([o(Item)])),
        if true = IsError then
            Result:set("isError", t)
        else
            Result:set("isError", f)
        end if.

end implement mcpTools
