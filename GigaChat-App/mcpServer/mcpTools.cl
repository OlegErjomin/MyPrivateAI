% Copyright (c) 2026 BestProlog

class mcpTools
    open core, json

predicates
    register : (jsonRpcApiMap{mcpSession} Api).
    % @short Register ping, tools/list, tools/call and the notifications this server handles.
    % @end

end class mcpTools
