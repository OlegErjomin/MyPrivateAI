% Copyright (c) 2026 BestProlog

implement gigaChatApi
    open core, json

facts
    oauthUrl : string := erroneous.
    apiUrl : string := erroneous.
    scope : string := erroneous.
    authorizationKey : optional{string} := none.
    clientId : optional{string} := none.
    clientSecret : optional{string} := none.

clauses
    init(Config) :-
        if o(ConfigObj) = Config and GigaChat = ConfigObj:get_object("gigaChat") then
            apiUrl := GigaChat:get_string("apiUrl"),
            Auth = GigaChat:get_object("auth"),
            oauthUrl := Auth:get_string("oauthUrl"),
            scope := Auth:get_string("scope"),
            authorizationKey := Auth:get_string_optional("authorizationKey"),
            clientId := Auth:get_string_optional("clientID"),
            clientSecret := Auth:get_string_optional("clientSecret")
        else
            exception::raise_definiteUser("Missing GigaChat configuration")
        end if.

end implement gigaChatApi
