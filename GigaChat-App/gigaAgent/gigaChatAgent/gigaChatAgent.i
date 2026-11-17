% Copyright (c) 2026 BestProlog

interface gigaChatAgent
    open core

predicates
    run : (string UserPrompt) -> string Answer.
    % @short Send `UserPrompt` to GigaChat, execute any tool calls it requests through the MCP server
    % (repeating until the model answers with text) and return the final answer.
    % The conversation is remembered between calls.
    % @end

predicates
    reset : ().
    % @short Forget the conversation so far.
    % @end

properties
    maxSteps : unsigned.
    % @short Upper bound on model round trips per `run` (protects against tool-call loops). Default 8.
    % @end

/******************************************************************
    Streaming support
******************************************************************/
domains
    tokenCallback = (string Token).

properties
    streaming : boolean.
    % @short true: use stream mode and report text through `tokenHandler` as it arrives. Default false.
    % @end

properties
    tokenHandler : tokenCallback.
    % @short Called with each fragment of the answer text in streaming mode. Default prints to the console.
    % @end

end interface gigaChatAgent
