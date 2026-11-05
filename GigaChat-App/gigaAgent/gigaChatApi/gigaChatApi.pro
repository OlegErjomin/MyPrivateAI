% Copyright (c) 2026 BestProlog

implement gigaChatApi
    open core, json, http

facts
    oauthUrl : string := erroneous.
    apiUrl : string := erroneous.
    scope : string := erroneous.
    model : string := erroneous.
    authorizationKey : optional{string} := none.
    clientId : optional{string} := none.
    clientSecret : optional{string} := none.

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
            authorizationKey := Auth:get_string_optional("authorizationKey"),
            clientId := Auth:get_string_optional("clientID"),
            clientSecret := Auth:get_string_optional("clientSecret")
        else
            exception::raise_definiteUser("Missing GigaChat configuration")
        end if.

facts
    access_token : (string Token, unsigned64 ExpiresAt) single.

clauses
    access_token("", 0).

predicates
    tryGetAccessToken : () -> string Token.
clauses
    tryGetAccessToken() = Token :-
        access_token(Token, ExpiresAt),
        Now = time::now(),
        UnixNow = toUnixTime(Now),
        UnixNow < ExpiresAt,
        !.
    tryGetAccessToken() = auth().

predicates
    postOAuth : (string AuthKey, string Rquid, string Scope) -> string ResponseText.
    postApi : (string AccessToken, json::jsonValue Request) -> jsonValue Response.

clauses
    postOAuth(AuthKey, Rquid, Scope) = Response :-
        Session = winHttp_api::winHttpOpen("VisualProlog"),
        try
            Connection = winHttp_api::winHttpConnect(Session, ngwHost, ngwPort),
            try
                Request =
                    winHttp_api::winHttpOpenRequest(Connection, "POST", ngwPath, nullString, winHttp_native::winhttp_no_referer,
                        winHttp_native::winhttp_default_accept_types, winHttp_native::winhttp_flag_secure),
                try
                    % Send NO client certificate (must be before SendRequest)
                    R =
                        winHttp_native::winHttpSetOption(Request, winHttp_native::winhttp_option_client_cert_context,
                            winHttp_native::winhttp_no_client_cert_context, 0),
                    if R = b_false then
                        exception::raise_nativeCallExceptionLite()
                    end if,
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

    postApi(Token, JsonRequest) = JsonResponse :-
        Session = winHttp_api::winHttpOpen("GigaChatApi"),
        try
            Connection = winHttp_api::winHttpConnect(Session, apiHost),
            try
                Request =
                    winHttp_api::winHttpOpenRequest(Connection, "POST", apiPath, nullString, winHttp_native::winhttp_no_referer,
                        winHttp_native::winhttp_default_accept_types, winHttp_native::winhttp_flag_secure),
                try
                    % Send NO client certificate (must be before SendRequest)
                    R =
                        winHttp_native::winHttpSetOption(Request, winHttp_native::winhttp_option_client_cert_context,
                            winHttp_native::winhttp_no_client_cert_context, 0),
                    if R = b_false then
                        exception::raise_nativeCallExceptionLite()
                    end if,
                    Headers = string::format("Content-Type: application/json\r\nAccept: application/json\r\nAuthorization: Bearer %\r\n", Token),
                    winHttp_api::winHttpAddRequestHeaders(Request, Headers),
                    % body must be bytes (string8), not a UTF-16 string
                    Body = json::asUtf8(JsonRequest),
                    Len = string8::length(Body),
                    winHttp_api::winHttpSendRequest(Request, "", uncheckedConvert(pointer, Body), Len, Len),
                    winHttp_api::winHttpReceiveResponse(Request),
                    Response = readAll(Request),
                    JsonResponse = json::fromString(Response)
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
    readAll : (winHttp_native::hinternet Request) -> string Text.
clauses
    readAll(Request) = Text :-
        Avail = winHttp_api::winHttpQueryDataAvailable(Request),
        if Avail = 0 then
            Text = ""
        else
            Buf = string8::create(Avail),
            Read = winHttp_api::winHttpReadData(Request, uncheckedConvert(pointer, Buf), Avail),
            Chunk = string8::createBufferCopy(Buf, Read), % adapt to your PFC
            Text = string::concat(string8::fromUtf8(Chunk), readAll(Request)) % adapt UTF-8 -> string
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
                ExpiresAt = AO:get_integer64("expires_at"),
                assert(access_token(AccessToken, uncheckedConvert(unsigned64, ExpiresAt)))
            else
                exception::raise_error("Can't get Access Token")
            end if
        catch TraceId do
            exception::continue_user(TraceId, "Can't get Access Token")
        end try.

% Windows local time is a 64-bit value representing the number of 100-nanosecond intervals since January 1, 1601 (UTC).
% The Unix epoch is January 1, 1970 (UTC).
% The difference between the epochs in 100-nanosecond intervals is 116444736000000000LL.
%UnixTime = (Expires:getTime() - 116444736000000000) div 10000,
predicates
    toUnixTime : (time Time) -> unsigned64.
clauses
    toUnixTime(Time) = (Time:getTime() - 116444736000000000) div 10000.

clauses
    apiCall(Request) :-
        Token = tryGetAccessToken(),
        _Resp = postApi(Token, Request).

end implement gigaChatApi
