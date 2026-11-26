% Copyright (c) 2026 BestProlog

implement gigaChatApi
    open core, json

facts
    oauthUrl : string := erroneous.
    apiUrl : string := erroneous.
    scope : string := erroneous.
    model : string := erroneous.
    authorizationKey : optional{string} := none.
    clientId : optional{string} := none.
    clientSecret : optional{string} := none.
    mcpServer : optional{string} := none.
    stream : optional{boolean} := some(false).

facts
    ngwHost : string := "ngw.devices.sberbank.ru".
    ngwPort : winHttp_native::internet_port := 9443.
    ngwPath : string := "/api/v2/oauth".
    apiHost : string := "api.giga.chat".
    apiPath : string := "/v1/chat/completions".

clauses
    init(Config) :-
        if o(ConfigObj) = Config and GigaChat = ConfigObj:get_object("gigaChat") then
            apiUrl := GigaChat:get_string("apiUrl"),
            Auth = GigaChat:get_object("auth"),
            oauthUrl := Auth:get_string("oauthUrl"),
            httpUtility::uri(_Scheme, AuthServer, AuthPath, _Query) = httpUtility::uriParse(oauthUrl),
            ngwPath := AuthPath,
            if [Host, Port] = string::split_delimiter(AuthServer, ":") then
                ngwHost := Host,
                ngwPort := toTerm(Port)
            else
                ngwHost := AuthServer
            end if,
            httpUtility::uri(_SchemeApi, ApiServer, ApiPath, _QueryApi) = httpUtility::uriParse(apiUrl),
            apiHost := ApiServer,
            apiPath := ApiPath,
            scope := Auth:get_string("scope"),
            model := GigaChat:get_string("model"),
            stream := GigaChat:get_boolean_optional("stream"),
            authorizationKey := Auth:get_string_optional("authorizationKey"),
            clientId := Auth:get_string_optional("clientID"),
            clientSecret := Auth:get_string_optional("clientSecret"),
            mcpServer := GigaChat:get_string_optional("mcpServer")
        else
            exception::raise_definiteUser("Missing GigaChat configuration")
        end if.

facts
    % ExpiresAt is a deadline on the local clock (time::now():getTime() ticks), see tokenDeadline.
    access_token : (string Token, unsigned64 ExpiresAt) single.

clauses
    access_token("", 0).

predicates
    tryGetAccessToken : () -> string Token.
clauses
    tryGetAccessToken() = Token :-
        access_token(Token, Deadline),
        Now = time::now(),
        Now:getTime() < Deadline,
        !.
    tryGetAccessToken() = auth().

predicates
    postOAuth : (string AuthKey, string Rquid, string Scope) -> string ResponseText.
    postApi : (string AccessToken, json::jsonValue Request, unsigned Status [out]) -> string ResponseText.
    % @short POST the request to the chat endpoint. `Status` is the HTTP status code of the reply.
    % @end

clauses
    postOAuth(AuthKey, Rquid, Scope) = Response :-
        Session = winHttp_api::winHttpOpen("VisualProlog"),
        _ = winHttp_native::winHttpSetTimeouts(Session, 10000, 10000, 30000, 120000),
        %                                         resolve connect send  receive
        try
            Connection = winHttp_api::winHttpConnect(Session, ngwHost, ngwPort),
            try
                Request =
                    winHttp_api::winHttpOpenRequest(Connection, "POST", ngwPath, nullString, winHttp_native::winhttp_no_referer,
                        winHttp_native::winhttp_default_accept_types, winHttp_native::winhttp_flag_secure),
                try
                    setNoClientCert(Request),
                    Headers =
                        string::format(
                            "Content-Type: application/x-www-form-urlencoded\r\nAccept: application/json\r\nRqUID: %\r\nAuthorization: Basic %\r\n",
                            Rquid, AuthKey),
                    winHttp_api::winHttpAddRequestHeaders(Request, Headers),
                    % body must be bytes (string8), not a UTF-16 string
                    Body = string8::toUtf8(string::format("scope=%", Scope)), % adapt to your PFC
                    Len = string8::length(Body),
                    winHttp_api::winHttpSendRequest(Request, "", uncheckedConvert(pointer, Body), Len, Len),
                    winHttp_api::winHttpReceiveResponse(Request),
                    Response = readAll(Request)
                finally
                    winHttp_api::winHttpCloseHandle(Request)
                end try
            finally
                winHttp_api::winHttpCloseHandle(Connection)
            end try
        finally
            winHttp_api::winHttpCloseHandle(Session)
        end try.

    postApi(Token, JsonRequest, Status) = ResponseText :-
        Session = winHttp_api::winHttpOpen("GigaChatApi"),
        _ = winHttp_native::winHttpSetTimeouts(Session, 10000, 10000, 30000, 120000),
        %                                         resolve connect send  receive
        try
            Connection = winHttp_api::winHttpConnect(Session, apiHost),
            try
                Request =
                    winHttp_api::winHttpOpenRequest(Connection, "POST", apiPath, nullString, winHttp_native::winhttp_no_referer,
                        winHttp_native::winhttp_default_accept_types, winHttp_native::winhttp_flag_secure),
                try
                    setNoClientCert(Request),
                    Headers = string::format("Content-Type: application/json\r\nAccept: application/json\r\nAuthorization: Bearer %\r\n", Token),
                    winHttp_api::winHttpAddRequestHeaders(Request, Headers),
                    % body must be bytes (string8), not a UTF-16 string
                    Body = json::asUtf8(JsonRequest),
                    Len = string8::length(Body),
                    winHttp_api::winHttpSendRequest(Request, "", uncheckedConvert(pointer, Body), Len, Len),
                    winHttp_api::winHttpReceiveResponse(Request),
                    Status = queryStatus(Request),
                    ResponseText = readAll(Request)
                finally
                    winHttp_api::winHttpCloseHandle(Request)
                end try
            finally
                winHttp_api::winHttpCloseHandle(Connection)
            end try
        finally
            winHttp_api::winHttpCloseHandle(Session)
        end try.

% HTTP status code of the response that was just received (call after winHttpReceiveResponse).
% WinHttpQueryHeaders writes through pointers, so both the value and the in/out buffer length
% (4 bytes for a number, otherwise error 122) live in explicitly allocated memory.
predicates
    queryStatus : (winHttp_native::hinternet Request) -> unsigned Status.
clauses
    queryStatus(Request) = Status :-
        PStatus = memory::mk_pUnsigned(0),
        PLen = memory::mk_pUnsigned(4),
        Ok =
            winHttpStatus_native::winHttpQueryHeaders(Request,
                winHttp_native::winhttp_query_status_code ++ winHttp_native::winhttp_query_flag_number, nullString, PStatus, PLen, null),
        Status = memory::getUnsigned(PStatus),
        memory::releaseHeap(PStatus),
        memory::releaseHeap(PLen),
        if b_false = Ok then
            exception::raise_nativeCallExceptionLite()
        end if.

% Send NO client certificate. Must be called before winHttpSendRequest.
predicates
    setNoClientCert : (winHttp_native::hinternet Request).
clauses
    setNoClientCert(Request) :-
        R =
            winHttp_native::winHttpSetOption(Request, winHttp_native::winhttp_option_client_cert_context,
                winHttp_native::winhttp_no_client_cert_context, 0),
        if R = b_false then
            exception::raise_nativeCallExceptionLite()
        end if.

predicates
    isSuccess : (unsigned Status) determ.
clauses
    isSuccess(Status) :-
        Status >= 200,
        Status < 300.

% Reads the whole body. The raw bytes are collected first and decoded once at the end,
% so a multibyte UTF-8 character that is split across two reads is never broken.
predicates
    readAll : (winHttp_native::hinternet Request) -> string Text.
clauses
    readAll(Request) = string8::fromUtf8(utils::joinAll(list::reverse(readChunks(Request, [])))).

predicates
    readChunks : (winHttp_native::hinternet Request, string8* ReverseAcc) -> string8* ReverseAcc.
clauses
    readChunks(Request, Acc) = Result :-
        Avail = winHttp_api::winHttpQueryDataAvailable(Request),
        if Avail = 0 then
            Result = Acc
        else
            Buf = string8::create(Avail),
            Read = winHttp_api::winHttpReadData(Request, uncheckedConvert(pointer, Buf), Avail),
            Chunk = string8::createBufferCopy(Buf, Read),
            Result = readChunks(Request, [Chunk | Acc])
        end if.

clauses
    auth() = AccessToken :-
        try
            Guid = string::toLowerCase(string::replaceAll(string::replaceAll(guid::fromNativeGuid(guid::create()), "{", ""), "}", "")),
            if some(AuthKey) = authorizationKey then
                Response = postOAuth(AuthKey, Guid, scope)
            else
                exception::raise_error("Wrong Authorization key")
            end if,
            A = json::fromString(Response),
            if json::o(AO) = A then
                AccessToken = AO:get_string("access_token"),
                assert(access_token(AccessToken, tokenDeadline()))
            else
                exception::raise_error("Can't get Access Token")
            end if
        catch TraceId do
            exception::continue_user(TraceId, "Can't get Access Token")
        end try.

% The token is treated as valid for 25 minutes from now (GigaChat tokens live 30 minutes).
% Start and check both use the same clock (time::now), so its time zone does not matter.
% Comparing a local-clock value with the UTC "expires_at" from the server would be off by the zone offset.
% If the server invalidates the token earlier anyway, the 401 handling in postWithRetry / chatStream refreshes it.
% time::now():getTime() counts 100-nanosecond ticks, so 25 minutes = 25 * 60 * 10_000_000 ticks.
predicates
    tokenDeadline : () -> unsigned64.
clauses
    tokenDeadline() = Now:getTime() + 15000000000 :-
        Now = time::now().

/**************************************************************************************
   Chat with status check and one re-authentication on 401
**************************************************************************************/
clauses
    chat(Request) = json::fromString(postWithRetry(Request)).

% A 401 means the access token expired or was revoked: get a new one via auth() and repeat the request once.
% Any other non-2xx status (and a second 401) raises a user exception that carries the status and the body.
predicates
    postWithRetry : (jsonValue Request) -> string ResponseText.
clauses
    postWithRetry(Request) = Text :-
        Text0 = postApi(tryGetAccessToken(), Request, Status0),
        if 401 = Status0 then
            Text1 = postApi(auth(), Request, Status1),
            Text = ensureSuccess(Status1, Text1)
        else
            Text = ensureSuccess(Status0, Text0)
        end if.

predicates
    ensureSuccess : (unsigned Status, string Body) -> string Body.
clauses
    ensureSuccess(Status, Body) = Body :-
        isSuccess(Status),
        !.
    ensureSuccess(Status, Body) = _Body :-
        exception::raise_definiteUser(string::format("GigaChat HTTP %: %", Status, Body)).

/**************************************************************************************
   Streamed chat
**************************************************************************************/
facts
    sawEvent : boolean := false.
    otherText : string := "".

clauses
    chatStream(JsonRequest, OnChunk) :-
        if o(Obj) = JsonRequest then
            Obj:set_boolean("stream", true)
        end if,
        Status0 = streamOnce(tryGetAccessToken(), JsonRequest, OnChunk),
        if 401 = Status0 then
            % nothing was streamed on a 401, so it is safe to repeat the whole request
            Status = streamOnce(auth(), JsonRequest, OnChunk)
        else
            Status = Status0
        end if,
        if not(isSuccess(Status)) then
            exception::raise_definiteUser(string::format("GigaChat HTTP %: %", Status, otherText))
        elseif false = sawEvent then
            % a 2xx reply that is not an event stream
            exception::raise_definiteUser(string::format("GigaChat streaming request failed: %", otherText))
        end if.

% One streaming attempt. On a 2xx status the events are pumped to OnChunk;
% otherwise the error body is left in `otherText` and the status is returned.
predicates
    streamOnce : (string Token, jsonValue Request, chunkHandler OnChunk) -> unsigned Status.
clauses
    streamOnce(Token, JsonRequest, OnChunk) = Status :-
        sawEvent := false,
        otherText := "",
        Session = winHttp_api::winHttpOpen("GigaChatApi"),
        _ = winHttp_native::winHttpSetTimeouts(Session, 10000, 10000, 30000, 120000),
        %                                         resolve connect send  receive
        try
            Connection = winHttp_api::winHttpConnect(Session, apiHost),
            try
                Request =
                    winHttp_api::winHttpOpenRequest(Connection, "POST", apiPath, nullString, winHttp_native::winhttp_no_referer,
                        winHttp_native::winhttp_default_accept_types, winHttp_native::winhttp_flag_secure),
                try
                    setNoClientCert(Request),
                    Headers = string::format("Content-Type: application/json\r\nAccept: text/event-stream\r\nAuthorization: Bearer %\r\n", Token),
                    winHttp_api::winHttpAddRequestHeaders(Request, Headers),
                    Body = json::asUtf8(JsonRequest),
                    Len = string8::length(Body),
                    winHttp_api::winHttpSendRequest(Request, "", uncheckedConvert(pointer, Body), Len, Len),
                    winHttp_api::winHttpReceiveResponse(Request),
                    Status = queryStatus(Request),
                    if isSuccess(Status) then
                        pumpEvents(Request, OnChunk)
                    else
                        otherText := readAll(Request)
                    end if
                finally
                    winHttp_api::winHttpCloseHandle(Request)
                end try
            finally
                winHttp_api::winHttpCloseHandle(Connection)
            end try
        finally
            winHttp_api::winHttpCloseHandle(Session)
        end try.

predicates
    pumpEvents : (winHttp_native::hinternet Request, chunkHandler OnChunk).
clauses
    pumpEvents(Request, OnChunk) :-
        Pieces = readUntilNewline(Request, [], AtEof),
        Line = string::trim(string8::fromUtf8(utils::joinAll(list::reverse(Pieces)))),
        Done = handleLine(Line, OnChunk),
        if false = AtEof and false = Done then
            pumpEvents(Request, OnChunk)
        end if.

predicates
    handleLine : (string Line, chunkHandler OnChunk) -> boolean Done.
clauses
    handleLine(Line, OnChunk) = Done :-
        if string::length(Line) >= 5 and string::front(Line, 5, Front, Rest) and Front = "data:" then
            Data = string::trim(Rest),
            if "[DONE]" = Data then
                Done = true,
                console::nl()
            else
                sawEvent := true,
                if o(Chunk) = json::fromString(Data) then
                    OnChunk(Chunk)
                end if,
                Done = false
            end if
        else
            if "" <> Line then
                otherText := string::concat(otherText, Line)
            end if,
            Done = false
        end if.

predicates
    readUntilNewline : (winHttp_native::hinternet Request, string8* ReverseAcc, boolean AtEof [out]) -> string8* ReverseAcc.
clauses
    readUntilNewline(Request, Acc, AtEof) = Result :-
        Piece = readByte(Request),
        if "" = Piece then
            AtEof = true,
            Result = Acc
        elseif "\n" = Piece then
            AtEof = false,
            Result = Acc
        else
            Result = readUntilNewline(Request, [Piece | Acc], AtEof)
        end if.

predicates
    readByte : (winHttp_native::hinternet Request) -> string8 Piece.
clauses
    readByte(Request) = Piece :-
        Buf = string8::create(1),
        Read = winHttp_api::winHttpReadData(Request, uncheckedConvert(pointer, Buf), 1),
        if 1 = Read then
            Piece = string8::createBufferCopy(Buf, 1)
        else
            Piece =
                "" % end of the body
        end if.

% joinAll / pairUp: the same two predicates you already have in mcpProcessTransport
clauses
    mcpHandShake() :-
        if some(MCPServerCommand) = mcpServer then
            Transport = mcpProcessTransport::new(MCPServerCommand),
            Mcp = mcpClient::new(Transport),
            Mcp:initialize(),
            console::write("handshake ok\n"),
            Mcp:close()
        else
            console::write("No MCP server configured\n")
        end if.

clauses
    mcpGetClient() = MCP :-
        if some(MCPServerCommand) = mcpServer then
            Transport = mcpProcessTransport::new(MCPServerCommand),
            MCP = mcpClient::new(Transport),
            MCP:initialize()
        else
            exception::raise_error("MCP Server is not configured")
        end if.

end implement gigaChatApi
