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
        CP:addOption_1("-config", @<Load configuration file. Delault "config.json">, "Config", { (Config) :- config := Config }),
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
            GigaChat:mcpHandShake(),
            MCP = GigaChat:mcpGetClient(),
            Agent = gigaChatAgent::new(GigaChat, Mcp, "Ты помощник. Используй инструменты, когда это нужно."),
            conversationLoop(Agent),
            MCP:close()
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
        Answer = Agent:run(Question),
        console::write(Answer, "\n"),
        conversationLoop(Agent).
    conversationLoop(_Agent).

end implement main

goal
    console::runUtf8(main::run).
