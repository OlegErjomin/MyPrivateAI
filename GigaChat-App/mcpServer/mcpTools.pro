% Copyright (c) 2026 BestProlog

implement mcpTools
    open core, json

constants
    defaultMaxRows : integer = 100.
    hardMaxRows : integer = 1000.

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
        Result:set("tools", a([echoTool(), getTimeTool(), onecQueryTool()])).

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

class predicates
    onecQueryTool : () -> jsonValue Tool.
clauses
    onecQueryTool() = o(Tool) :-
        ParametersProp =
            schemaProperty("object",
                "Values of &Name parameters, keyed by name without &. A value is a string, number, boolean,"
                " array (for IN), or an object with fields type and value, for example type Date and value"
                " 2026-01-31T00:00:00, or type CatalogRef.Name and value GUID"),
        ParametersProp:set_object("properties", jsonObject::new()),
        Props = jsonObject::new(),
        Props:set_object("query", schemaProperty("string", "Query text in the 1C query language")),
        Props:set_object("parameters", ParametersProp),
        Props:set_object("max_rows", schemaProperty("integer", "Maximum rows to return, default 100, at most 1000")),
        Schema = jsonObject::new(),
        Schema:set_string("type", "object"),
        Schema:set_object("properties", Props),
        Schema:set("required", a([s("query")])),
        Tool = jsonObject::new(),
        Tool:set_string("name", "onec_query"),
        Tool:set_string("description",
            "Runs a query in the 1C:ERP infobase using the 1C query language (read only)"
            " and returns columns and rows as JSON. Use SELECT TOP N to limit large selections."
            " Parameters are referenced in the query text as &Name."),
        Tool:set_object("inputSchema", Schema).

class predicates
    schemaProperty : (string Type, string Description) -> jsonObject Property.
clauses
    schemaProperty(Type, Description) = Property :-
        Property = jsonObject::new(),
        Property:set_string("type", Type),
        Property:set_string("description", Description).

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

    callTool(Session, "onec_query", Args) = Result :-
        !,
        if some(QueryText) = Args:get_string_optional("query") then
            Parameters = if some(P) = Args:get_object_optional("parameters") then P else jsonObject::new() end if,
            Outcome = onecQuery::execute(QueryText, Parameters, maxRows(Args)),
            Result = onecResult(Session, Outcome)
        else
            Result = textResult("Missing required argument: query", true)
        end if.

    callTool(_Session, Name, _Args) = _Result :-
        % protocol-level failure: becomes a JSON-RPC error response
        jsonRpcApiMap{mcpSession}::raise_callError(jsonRpcError::invalidParams, string::format("Unknown tool: %", Name)).

class predicates
    maxRows : (jsonObject Args) -> integer MaxRows.
clauses
    maxRows(Args) = MaxRows :-
        if some(r(N)) = Args:get_optional("max_rows") and N >= 1 then
            if N > hardMaxRows then
                MaxRows = hardMaxRows
            else
                MaxRows = math::trunc(N)
            end if
        else
            MaxRows = defaultMaxRows
        end if.

class predicates
    onecResult : (mcpSession Session, onecQuery::outcome Outcome) -> jsonValue Result.
clauses
    onecResult(_, onecQuery::ok(Data)) = Result :-
        Result = textResult(json::asString(o(Data)), false),
        if o(Json) = Result then
            Json:set_object("structuredContent", Data)
        end if.
    onecResult(Session, onecQuery::failed(Message, Details)) = textResult(Message, true) :-
        Session:log(string::format("onec_query failed: %", Details)).

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
