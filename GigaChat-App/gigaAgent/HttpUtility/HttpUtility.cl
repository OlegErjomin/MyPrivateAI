% Copyright PDC

class httpUtility

domains
    uri = uri(string Schema, string Server, string Path, string Query).

predicates
    urlEncode : (string) -> string.
    % isWellFormedUriString : (string) determ.
    uriParse : (string) -> uri.

end class httpUtility
