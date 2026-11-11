% Copyright (c) 2026 BestProlog

interface mcpClient
    open core, json

predicates
    initialize : ().
    % @short Perform the MCP handshake: initialize request + notifications/initialized.
    % @end

predicates
    request : (string Method, jsonValue Params) -> jsonValue Result.
    % @short Send a JSON-RPC request and wait for the response with the same id.
    % Notifications from the server are ignored; requests from the server are answered
    % ("ping" with an empty result, anything else with "method not found").
    % Raises a user exception if the server answers with an error object.
    % @end

predicates
    notify : (string Method, jsonValue Params).
    % @short Send a JSON-RPC notification (no id, no response).
    % @end

predicates
    listTools : () -> jsonValue* Tools.
    % @short The "tools" array of tools/list (each element is an object with name, description, inputSchema).
    % @end

predicates
    callTool : (string Name, jsonObject Arguments, boolean IsError [out]) -> string Text.
    % @short Call a tool. `Text` is all text parts of the result joined with newlines.
    % `IsError` is true when the tool reported isError. Feed such text back to the model, don't abort.
    % @end

predicates
    close : ().
    % @short Close the transport.
    % @end

end interface mcpClient
