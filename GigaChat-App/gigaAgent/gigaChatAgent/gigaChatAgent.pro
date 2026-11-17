% Copyright (c) 2026 BestProlog

implement gigaChatAgent
    open core, json

facts
    giga : gigaChatApi := erroneous.
    mcp : mcpClient := erroneous.
    systemPrompt : string := "".
    history : jsonValue* := []. % user/assistant text turns of earlier runs
    maxSteps : unsigned := 8.

clauses
    new(Giga, Mcp, SystemPrompt) :-
        giga := Giga,
        mcp := Mcp,
        if some(true) = giga:stream then
            streaming := true
        end if,
        systemPrompt := SystemPrompt.

clauses
    reset() :-
        history := [].

clauses
    run(UserPrompt) = Answer :-
        Functions = toGigaFunctions(mcp:listTools()),
        UserMsg = message("user", UserPrompt),
        Start = list::append(systemMessages(), list::append(history, [UserMsg])),
        Answer = step(Functions, Start, 0),
        history := list::append(history, [UserMsg, message("assistant", Answer)]).

% One model round trip. If the model asks for a function, run it and recurse with the result appended.
predicates
    step : (jsonValue* Functions, jsonValue* Messages, unsigned Depth) -> string Answer.
clauses
    step(_Functions, _Messages, Depth) = "Too many tool calls, giving up." :-
        Depth >= maxSteps,
        !.

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
        !,
        if some(FC) = Msg:get_object_optional("function_call") then
            Name = FC:get_string("name"),
            Args = argumentsOf(FC),
            log(string::format("tool call: % %", Name, json::asString(o(Args)))),
            ToolText = runTool(Name, Args),
            log(string::format("tool result: %", ToolText)),
            % the assistant message is sent back verbatim (it may carry functions_state_id)
            Next = list::append(Messages, [o(Msg), functionMessage(Name, ToolText)]),
            Answer = step(Functions, Next, Depth + 1)
        else
            Answer = Msg:get_string("content")
        end if.

    step(_Functions, _Messages, _Depth) = "Malformed response.".

% Runs the tool; failures are reported to the model as text instead of aborting the whole run.
predicates
    runTool : (string Name, jsonObject Args) -> string Text.
clauses
    runTool(Name, Args) = Text :-
        try
            Text0 = mcp:callTool(Name, Args, IsError),
            Text = if true = IsError then string::concat("Tool error: ", Text0) else Text0 end if
        catch TraceId do
            Text = string::format("Tool call failed: %", exceptionDump::dumpToString(TraceId))
        end try.

% ---------------------------------------------------------------- JSON helpers
class predicates
    toGigaFunctions : (jsonValue* McpTools) -> jsonValue* Functions.
clauses
    toGigaFunctions([]) = [].
    toGigaFunctions([o(T) | Rest]) = [o(F) | toGigaFunctions(Rest)] :-
        !,
        Description = if some(D) = T:get_string_optional("description") then D else "" end if,
        F = jsonObject::new(),
        F:set_string("name", T:get_string("name")),
        F:set_string("description", Description),
        F:set("parameters", T:get("inputSchema")). % MCP inputSchema is already JSON Schema
    toGigaFunctions([_ | Rest]) = toGigaFunctions(Rest).

class predicates
    argumentsOf : (jsonObject FunctionCall) -> jsonObject Args.
clauses
    argumentsOf(FC) = Args :-
        Value = FC:get("arguments"),
        if o(Obj) = Value then
            Args = Obj
        elseif s(Text) = Value and o(Obj2) = json::fromString(Text) then
            Args = Obj2 % some models/versions send the arguments as a JSON string
        else
            Args = jsonObject::new()
        end if.

class predicates
    message : (string Role, string Content) -> jsonValue Message.
clauses
    message(Role, Content) = o(M) :-
        M = jsonObject::new(),
        M:set_string("role", Role),
        M:set_string("content", Content).

% GigaChat expects the content of a function message to be a JSON string.
class predicates
    functionMessage : (string Name, string Text) -> jsonValue Message.
clauses
    functionMessage(Name, Text) = o(M) :-
        Payload = jsonObject::new(),
        Payload:set_string("result", Text),
        M = jsonObject::new(),
        M:set_string("role", "function"),
        M:set_string("name", Name),
        M:set_string("content", json::asString(o(Payload))).

predicates
    systemMessages : () -> jsonValue* Messages.
clauses
    systemMessages() = [] :-
        "" = systemPrompt,
        !.
    systemMessages() = [message("system", systemPrompt)].

/******************************************************************************************
    Streaming support
******************************************************************************************/
facts
    streaming : boolean := false.
    tokenHandler : tokenCallback := writeToken.

facts
    accContent : string := "".
    accFcName : string := "".
    accArgsObj : optional{jsonObject} := none.
    accArgsText : string := "".
    accStateId : optional{string} := none.
    hasFc : boolean := false.

class predicates
    writeToken : tokenCallback.
clauses
    writeToken(Token) :-
        console::write(Token).

predicates
    complete : (jsonObject Req) -> jsonObject Msg determ.
clauses
    complete(Req) = Msg :-
        if true = streaming then
            accContent := "",
            accFcName := "",
            accArgsObj := none,
            accArgsText := "",
            accStateId := none,
            hasFc := false,
            giga:chatStream(o(Req), onChunk),
            Msg = accumulatedMessage()
        else
            o(Resp) = giga:chat(o(Req)),
            a([o(Choice) | _]) = Resp:get("choices"),
            Msg = Choice:get_object("message")
        end if.

predicates
    onChunk : (jsonObject Chunk).
clauses
    onChunk(Chunk) :-
        some(a([o(Choice) | _])) = Chunk:get_optional("choices"),
        some(Delta) = Choice:get_object_optional("delta"),
        !,
        if some(Text) = Delta:get_string_optional("content") and "" <> Text then
            accContent := string::concat(accContent, Text),
            tokenHandler(Text)
        end if,
        if some(FC) = Delta:get_object_optional("function_call") then
            hasFc := true,
            if some(N) = FC:get_string_optional("name") and "" <> N then
                accFcName := N
            end if,
            % arguments: either a complete object or JSON text arriving in pieces
            Args = FC:get_optional("arguments"),
            if some(o(O)) = Args then
                accArgsObj := some(O)
            elseif some(s(T)) = Args then
                accArgsText := string::concat(accArgsText, T)
            end if
        end if,
        if some(Id) = Delta:get_string_optional("functions_state_id") then
            accStateId := some(Id)
        end if.
    onChunk(_Chunk). % usage-only or unknown chunk

predicates
    accumulatedMessage : () -> jsonObject Msg.
clauses
    accumulatedMessage() = Msg :-
        Msg = jsonObject::new(),
        Msg:set_string("role", "assistant"),
        Msg:set_string("content", accContent),
        if true = hasFc then
            FC = jsonObject::new(),
            FC:set_string("name", accFcName),
            FC:set_object("arguments", streamedArgs()),
            Msg:set_object("function_call", FC)
        end if,
        if some(Id) = accStateId then
            Msg:set_string("functions_state_id", Id)
        end if.

predicates
    streamedArgs : () -> jsonObject Args.
clauses
    streamedArgs() = Obj :-
        some(Obj) = accArgsObj,
        !.
    streamedArgs() = Obj :-
        "" <> accArgsText,
        o(Obj) = json::fromString(accArgsText),
        !.
    streamedArgs() = jsonObject::new().

class predicates
    log : (string Text).
clauses
    log(Text) :-
        stdio::errorStream:write(Text),
        stdio::errorStream:nl().

end implement gigaChatAgent
