% Copyright PDC

implement httpUtility

clauses
    urlEncode(Input) = Output :-
        Scan = scannerSupport_string::new_string(Input),
        accumulate(Scan, Scan:accumulator),
        Output = Scan:getAccumulated().

class predicates
    accumulate : (scannerSupport Scan, outputStream Acc).
clauses
    accumulate(Scan, Acc) :-
        Current = Scan:current,
        if '\u0000' <> Current then
            if Translated = tryTranslate(Current) then
                Acc:write(Translated)
            else
                Acc:write(Current)
            end if,
            Scan:advance(),
            accumulate(Scan, Acc)
        end if.

%  RFC-3986
% reserved    = gen-delims / sub-delims
% gen-delims  = ":" / "/" / "?" / "#" / "[" / "]" / "@"
% sub-delims  = "!" / "$" / "&" / "'" / "(" / ")" / "*" / "+" / "," / ";" / "="
class predicates
    tryTranslate : (char Current) -> string Next determ.
clauses
    tryTranslate(':') = "%3A".
    tryTranslate('/') = "%2F".
    tryTranslate('?') = "%3F".
    tryTranslate('#') = "%23".
    tryTranslate('[') = "%5B".
    tryTranslate(']') = "%5D".
    tryTranslate('!') = "%21".
    tryTranslate('$') = "%24".
    tryTranslate('&') = "%26".
    tryTranslate('\'') = "%27".
    tryTranslate('(') = "%28".
    tryTranslate(')') = "%29".
    tryTranslate('*') = "%2A".
    tryTranslate('+') = "%2B".
    tryTranslate(',') = "%2C".
    tryTranslate(';') = "%3B".
    tryTranslate('=') = "%3D".
    tryTranslate('%') = "%25".
    tryTranslate(' ') = "%20".

% Well Formed Uri strings
% The string is not correctly escaped. (http://www.contoso.com/path???/file name)
% The string is an absolute Uri that represents an implicit file Uri.   (c:\\directory\filename)
% The string is an absolute URI that is missing a slash before the path.   (file://c:/directory/filename)
% The string contains unescaped backslashes even if they will be treated as forward slashes (http:\\host/path/file)
% The string represents a hierarchical absolute Uri and does not contain "://" (www.contoso.com/path/file)
%   isWellFormedUriString(_Val).
clauses
    uriParse(RawURL) = uri(Schema, Server, Path, Query) :-
        if P1 = string::search(RawUrl, "://") then
            string::front(RawURL, P1 + 3, Schema, R1),
            if P2 = string::search(R1, "/") then
                string::front(R1, P2, Server, R2_0),
                if string::frontChar(R2_0, _C, R2) then
                    PQ = R2
                else
                    PQ = R1
                end if
            else
                Server = R1,
                PQ = ""
            end if
        else
            Schema = "",
            Server = "",
            PQ = RawUrl
        end if,
        PQL = string::split(PQ, "?"),
        if [Path, Query] = PQL then
            succeed
        else
            Path = PQ,
            Query = ""
        end if.

end implement httpUtility
