% Copyright (c) 2026 BestProlog

class mcpProcessTransport : mcpTransport
    open core

constructors
    new : (string CommandLine).
    % @short Start the MCP server process and connect to its stdin/stdout.
    % `CommandLine` is the full command line, e.g. "\"c:\\path\\mcpServer.exe\" -option".
    % The child's stderr is passed on to this process's stderr.
    % @end

end class mcpProcessTransport
