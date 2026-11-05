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

predicates
    init : (jsonValue Config).
    auth : () -> string AccessToken.
    apiCall : (jsonValue Request).

end interface gigaChatApi
