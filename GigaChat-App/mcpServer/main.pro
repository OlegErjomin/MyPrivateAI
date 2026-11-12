% Copyright (c) 2026 BestProlog

implement main
    open core, json, async\async

class facts
    api : jsonRpcApiMap{mcpSession} := erroneous.
    session : mcpSession := erroneous.

clauses
    run() :-
        CP = commandLineParser::new(),
        CP:acceptEmpty := true,
        CP:addOption_help("-help"),
        % define command line options here
        if ErrorMessage = CP:parse():isSome() then
            stdio::errorStream:write(ErrorMessage),
            programControl::setApplicationExitCode(2)
        else
            % place your own code here
            initApi(),
            runStdio()
        end if.

class predicates
    initApi : ().
clauses
    initApi() :-
        session := mcpSession::new(),
        Api = jsonRpcApiMap{mcpSession}::new(),
        Api:setProc_name("initialize", onInitialize),
        Api:setProc_name("server/discover", onServerDiscover),
        mcpTools::register(Api),
        api := Api.
% Framing: MCP stdio uses newline-delimited JSON, one message per line, UTF-8.
% It does not use Content-Length headers like LSP does.
% Messages must not contain raw newlines, so serialize compactly.

class predicates
    runStdio : ().
clauses
    runStdio() :-
        stdio::inputStream:setMode(stream::utf8_mode),
        stdio::outputStream:setMode(stream::utf8_mode),
        loop(stdio::inputStream).

class predicates
    loop : (inputStream Stream).
    processLine : (string Input).

clauses
    loop(Stream) :-
        if Stream:endOfStream() then
            % stdin closed: the client is gone, exit cleanly
            succeed()
        else
            Line = Stream:readLine(),
            if Line <> "" then
                processLine(Line)
            end if,
            loop(Stream)
        end if.

    processLine(Line) :-
        try
            Value = json::fromString(Line), % placeholder: parse
            %if Value = json::o(Json) then
            %Id = Json:get("id"),
            addMissingParams(Value),
            Future = submit({  = api:callApi_async(session, Value) }),
            Result = Future:getResult(),
            if async\futureDomains::success_(Response) = Result then
                if n <> Response then
                    Output = stdio::outputStream,
                    %Output:setMode(stream::utf8_mode),
                    Output:write(json::asString(Response), "\n"),
                    Output:flush()
                end if
            else
                session:log("Call did not complete")
            end if
            %end if
        catch TraceId do
            session:log(string::format("Error processing line: %", exceptionDump::dumpToString(TraceId)))
        end try.

class predicates
    addMissingParams : (jsonValue Request).
clauses
    addMissingParams(o(Obj)) :-
        none = Obj:get_optional("params"),
        !,
        Obj:set_object("params", jsonObject::new()).
    addMissingParams(_).

class predicates
    onInitialize : mcpSession::mcpMethod.
clauses
    onInitialize(Session, _Args) = o(Result) :-
        Session:initialized := true,
        Result = jsonObject::new(),
        Result:set_string("protocolVersion", "2024-11-05"),
        Caps = jsonObject::new(),
        Caps:set_object("tools", jsonObject::new()),
        Result:set_object("capabilities", Caps),
        Info = jsonObject::new(),
        Info:set_string("name", "mcpServer"),
        Info:set_string("version", "0.1"),
        Result:set_object("serverInfo", Info).

% class predicates
%     onInitialized : (mcpSession Session, jsonObject Args).
% clauses
%     onInitialized(_Session, _Args) :-
%         session:log("client initialized").
class predicates
    onServerDiscover : mcpSession::mcpMethod.
clauses
    onServerDiscover(_Session, _ArgumentMap) = o(Result) :-
        Result = jsonObject::new(),
        Result:set_string("resultType", "complete"),
        Result:set_array("supportedVersions", [s("2026-07-28")]),
        Caps = jsonObject::new(),
        Caps:set_object("tools", jsonObject::new()),
        Result:set_object("capabilities", Caps),
        Meta = jsonObject::new(),
        Info = jsonObject::new(),
        Info:set_string("name", "mcpServer"),
        Info:set_string("version", "0.1"),
        Meta:set_object("io.modelcontextprotocol/serverInfo", Info),
        Result:set_object("_meta", Meta),
        Result:set_string("instructions", "This is sample BestProlog MCP server").

end implement main

goal
    console::runUtf8(main::run).
