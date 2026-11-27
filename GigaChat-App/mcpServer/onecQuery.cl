% Copyright (c) 2026 BestProlog

class onecQuery
    open core

domains
    outcome =
        ok(jsonObject Data);
        failed(string Message, string Details).
    % Message is safe to show to the model, Details is for the server log

predicates
    execute : (string QueryText, jsonObject Parameters, integer MaxRows) -> outcome Outcome.
    % connects through V83.COMConnector, runs the query and converts the result to JSON

end class onecQuery
