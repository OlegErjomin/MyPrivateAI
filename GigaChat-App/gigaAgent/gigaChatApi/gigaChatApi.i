% Copyright (c) 2026 BestProlog

interface gigaChatApi
    open core, json

properties
    oauthUrl : string.
    apiUrl : string.
    scope : string.
    authorizationKey : optional{string}.
    clientId : optional{string}.
    clientSecret : optional{string}.

predicates
    init : (jsonValue Config).

end interface gigaChatApi
