% Copyright (c) 2026 BestProlog

interface mcpSession
    open core, json

domains
    mcpMethod = (mcpSession Context, jsonObject ArgumentMap) -> jsonValue Result.

properties
    initialized : boolean.
    clientInfo : optional{json::jsonValue}.

%predicates
%    sendNotification : (string Method, json::jsonValue Params). % server -> client, writes to stdout
predicates
    log : (string Text). % writes to stderr, never stdout

end interface mcpSession
