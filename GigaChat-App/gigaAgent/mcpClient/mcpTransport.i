% Copyright (c) 2026 BestProlog

interface mcpTransport
    open core

predicates
    writeLine : (string Line).
    % @short Write one message plus "\n" to the server's stdin and flush.
    % @end

predicates
    readLine : () -> string Line.
    % @short Read one line (UTF-8 decoded, without line terminator) from the server's stdout.
    % Raises an exception when the server has closed its stdout.
    % @end

predicates
    close : ().
    % @short Close the pipes and terminate the child process.
    % @end

end interface mcpTransport
