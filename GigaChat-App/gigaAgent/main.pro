% Copyright (c) 2026 BestProlog

implement main
    open core, json, async\async

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
            Config = getConfig(),
            GigaChat = gigaChatApi::new(),
            GigaChat:init(Config),
            GigaChat:auth()
            %submitWait({  :- GigaChat:auth() })
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

end implement main

goal
    console::runUtf8(main::run).
