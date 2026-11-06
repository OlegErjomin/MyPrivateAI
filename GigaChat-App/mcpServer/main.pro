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
            console::write("Stdio MCP server\n"),
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
%         Api:setProc_name("tools/list", onToolsList),
%         Api:setProc_name("tools/call", onToolsCall),
%         Api:setProc_name("ping", onPing),
%         Api:setListener_name("notifications/initialized", onInitialized),
%         Api:setListener_name("notifications/cancelled", onCancelled),
        api := Api.
% Framing: MCP stdio uses newline-delimited JSON, one message per line, UTF-8.
% It does not use Content-Length headers like LSP does.
% Messages must not contain raw newlines, so serialize compactly.

class predicates
    runStdio : ().
clauses
    runStdio() :-
        Stream = stdio::inputStream,
        Stream:setMode(stream::utf8_mode), % once, not per line
        loop(Stream).

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
            Future = submit({  = api:callApi_async(session, Value) }),
            Result = Future:getResult(),
            if async\futureDomains::success_(RetVal) = Result then
                console::write("\nA: ", RetVal)
            else
                session:log("Result is unknown")
            end if
        catch _ do
            session:log("Parse error")
        end try.

class predicates
    onInitialize : mcpSession::mcpMethod.
clauses
    onInitialize(Session, ArgumentMap) = Result :-
        Session:initialized := true,
        console::write(json::asString(o(ArgumentMap))),
        Result = json::n().

end implement main

goal
    console::runUtf8(main::run).
