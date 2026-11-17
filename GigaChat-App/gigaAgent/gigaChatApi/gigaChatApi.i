% Copyright (c) 2026 BestProlog

interface gigaChatApi
    open core, json

properties
    oauthUrl : string.
    apiUrl : string.
    scope : string.
    model : string.
    authorizationKey : optional{string}.
    clientId : optional{string}.
    clientSecret : optional{string}.
    stream : optional{boolean}.

predicates
    init : (jsonValue Config).
    auth : () -> string AccessToken.
    chat : (jsonValue Request) -> jsonValue Response.
    mcpHandShake : ().
    mcpGetClient : () -> mcpClient.

domains
    chunkHandler = (jsonObject Chunk).
    % @short Called for every parsed "data:" event of a streaming response.
    % @end

predicates
    chatStream : (jsonValue Request, chunkHandler OnChunk).
    % @short Like `chat`, but sets "stream": true and calls `OnChunk` for each event as it arrives.
    % @end

end interface gigaChatApi
