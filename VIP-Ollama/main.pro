% Copyright (c) 2003-2020 Prolog Development Center A/S

implement main
    open core, async\async

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
            console::write("Enter your question to AI\n >>>"),
            Q = console::readLine(),
            F = submit({  = get_Answer_async(Q) }),
            _ = submit_unit({  :- progress_async(2) }),
            Answer = F:getResult(),
            if async\futureDomains::success_(Result) = Answer then
                console::write("\nA: ", Result)
            else
                console::write("\nResult is unknown")
            end if
        end if.

class facts
    stopProgress : boolean := false.

class predicates
    get_Answer_async : (string Question) -> string suspending.
    get_AI_answer_async : (string Question) -> string suspending.
    progress_async : (timeout Timeout) suspending.

constants
    llama_gen_endpoint = "http://localhost:11434/api/generate".

clauses
    get_Answer_async(Q) = Answer :-
        stopProgress := false,
        Future = submit({  = get_AI_answer_async(Q) }),
        Answer = Future:await(),
        stopProgress := true.

    progress_async(Timeout) :-
        if false = stopProgress then
            yield(Timeout),
            console::write("."),
            progress_async(Timeout)
        end if.

    get_AI_answer_async(Q) = Answer :-
        Request = jsonObject::new(),
        Request:set_string("model", "llama3"),
        Request:set_string("prompt", Q),
        Request:set_boolean("stream", false),
        try
            Req = msxml_HTTP_api::newXmlhttp60(),
            Req:open_predicate("POST", llama_gen_endpoint, comDomains::boolean(false), comDomains::string(""), comDomains::string("")),
            Req:setRequestHeader("Content-Type", "application/json; charset=utf-8"),
            Req:send(comDomains::string(Request:asString())),
            A = json::fromString(Req:responseText),
            if json::o(AO) = A then
                Answer = AO:get_string("response")
            else
                Answer = "unknown"
            end if
        catch _ do
            exception::raise_error(string::format("Send Request to %s failed", llama_gen_endpoint))
        end try.

end implement main

goal
    console::runUtf8(main::run).
