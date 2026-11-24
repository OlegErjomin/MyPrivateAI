% Copyright (c) 2026 BestProlog

implement main
    open core, json

class facts
    config : string := "config.json".

clauses
    run() :-
        CP = commandLineParser::new(),
        CP:acceptEmpty := true,
        CP:addOption_help("-help"),
        CP:addOption_1("-config", @<Load configuration file. Default "config.json">, "Config", { (ConfigFile) :- config := ConfigFile }),
        % define command line options here
        if ErrorMessage = CP:parse():isSome() then
            stdio::errorStream:write(ErrorMessage),
            programControl::setApplicationExitCode(2)
        else
            % place your own code here
            console::initUtf8(),
            Config = getConfig(),
            GigaChat = gigaChatApi::new(),
            GigaChat:init(Config),
            _Token = GigaChat:auth(),
            % mcpGetClient starts the server and performs the MCP handshake (initialize) itself
            MCP = GigaChat:mcpGetClient(),
            try
                Agent = gigaChatAgent::new(GigaChat, MCP, "Ты помощник. Используй инструменты, когда это нужно."),
                conversationLoop(Agent)
            finally
                % always stop the MCP server process, even if the loop ends with an exception
                MCP:close()
            end try
        end if.

class predicates
    getConfig : () -> jsonValue.
clauses
    getConfig() = ConfigObj :-
        try
            ConfigText = file::readString(config),
            ConfigObj = json::fromString(ConfigText)
        catch _ do
            console::writef("Can't read configuration file %", config),
            ConfigObj = json::n
        end try.

class predicates
    conversationLoop : (gigaChatAgent Agent).
clauses
    conversationLoop(Agent) :-
        console::write(">> "),
        Question = console::readLine(),
        string::toLowerCase(Question) <> "quit",
        !,
        ask(Agent, Question),
        conversationLoop(Agent).
    conversationLoop(_Agent).

% One question. A failure (network error, HTTP error, ...) is reported and the conversation continues.
class predicates
    ask : (gigaChatAgent Agent, string Question).
clauses
    ask(Agent, Question) :-
        try
            Answer = Agent:run(Question),
            if false = Agent:streaming then
                console::write(Answer, "\n")
            end if
        catch TraceId do
            console::write("\nError: ", exceptionDump::dumpToString(TraceId), "\n")
        end try.

end implement main

goal
    console::runUtf8(main::run).
