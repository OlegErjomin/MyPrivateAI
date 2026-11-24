% Copyright (c) 2026 BestProlog
%
% @short Binding of WinHttpQueryHeaders that returns a numeric header value (e.g. the HTTP status code)
% through an [out] argument. PFC's winHttp_native version needs pointer cells for the value and the length.
% @end

class winHttpStatus_native
    open core

predicates
    winHttpQueryHeaders : (winHttp_native::hinternet Request, unsigned InfoLevel, string Name, memory::pUnsigned Value,
        memory::pUnsigned BufferLength, pointer Index) -> booleanInt Result language apicall as decorated.
    % @short See WinHttpQueryHeaders in MSDN. Call with winhttp_query_status_code ++ winhttp_query_flag_number
    % to get the status code as a number in `Value`.
    % @end

end class winHttpStatus_native
