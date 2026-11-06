% Copyright (c) 2026 BestProlog

implement mcpSession
    open core, json

facts
    initialized : boolean := false.
    clientInfo : optional{jsonValue} := none.

clauses
    new().

clauses
    log(Text) :-
        stdio::errorStream:write(Text),
        stdio::errorStream:nl().

end implement mcpSession
