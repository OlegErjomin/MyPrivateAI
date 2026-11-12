% Copyright (c) 2026 BestProlog

implement mcpProcessTransport
    open core, windowsAPI

facts
    childStdin : handle := nullHandle. % we write here
    childStdout : handle := nullHandle. % we read here
    hProcess : processHandle := erroneous.
    hThread : threadHandle := erroneous.

clauses
    new(CommandLine) :-
        % Pipes are created non-inheritable; only the child's ends are marked inheritable.
        % Parent's ends therefore never leak into the child (otherwise it never sees EOF).
        createPipeChecked(ChildInRead, ParentInWrite),
        createPipeChecked(ParentOutRead, ChildOutWrite),
        setInherit(ChildInRead),
        setInherit(ChildOutWrite),
        StdErr = mcpPipe_native::getStdHandle(mcpPipe_native::std_error_handle),
        setInheritIgnoreFailure(StdErr),
        StartupInfo =
            multiThread_native::startupInfoEx(sizeOfDomain(multiThread_native::startupInfoEx), null, nullString, nullString, 0, 0, 0, 0, 0, 0, 0,
                multiThread_native::startf_usestdhandles, windowsAPI::sw_hide, 0, null, ChildInRead, ChildOutWrite, StdErr, null),
        Flags = multiThread_native::create_no_window ++ multiThread_native::extended_startupinfo_present,
        Ok =
            multiThread_native::createProcess(nullString, CommandLine, uncheckedConvert(security_attributes, null),
                uncheckedConvert(security_attributes, null), b_true, Flags, null, nullString, StartupInfo, ProcInfo),
        if b_false = Ok then
            exception::raise_nativeCallExceptionLite()
        end if,
        multiThread_native::processInformation(HProcess, HThread, _Pid, _Tid) = ProcInfo,
        hProcess := HProcess,
        hThread := HThread,
        % the child owns these ends now; if we keep them open we never get EOF/broken pipe
        _ = mcpPipe_native::closeHandle(ChildInRead),
        _ = mcpPipe_native::closeHandle(ChildOutWrite),
        childStdin := ParentInWrite,
        childStdout := ParentOutRead.

class predicates
    createPipeChecked : (handle Read [out], handle Write [out]).
clauses
    createPipeChecked(Read, Write) :-
        Ret = mcpPipe_native::createPipe(Read, Write, uncheckedConvert(security_attributes, null), 0),
        if b_false = Ret then
            exception::raise_nativeCallExceptionLite()
        end if.

class predicates
    setInherit : (handle Handle).
clauses
    setInherit(Handle) :-
        if b_false = mcpPipe_native::setHandleInformation(Handle, mcpPipe_native::handle_flag_inherit, mcpPipe_native::handle_flag_inherit) then
            exception::raise_nativeCallExceptionLite()
        end if.

class predicates
    setInheritIgnoreFailure : (handle Handle).
clauses
    setInheritIgnoreFailure(Handle) :-
        % stderr may be missing (e.g. GUI process); then the child just gets no stderr
        _ = mcpPipe_native::setHandleInformation(Handle, mcpPipe_native::handle_flag_inherit, mcpPipe_native::handle_flag_inherit).

clauses
    writeLine(Line) :-
        Bytes = string8::toUtf8(string::concat(Line, "\n")),
        Len = string8::length(Bytes),
        Ok = mcpPipe_native::writeFile(childStdin, uncheckedConvert(pointer, Bytes), uncheckedConvert(unsigned, Len), Written),
        if b_false = Ok or Written <> Len then
            exception::raise_definiteUser("Can't write to the MCP server (has it exited?)")
        end if.

clauses
    readLine() = Line :-
        Pieces = list::reverse(readUntilNewline([])),
        % decode once, when the whole line is present, so multibyte characters are never split
        Line = string::trim(string8::fromUtf8(joinAll(Pieces))).

predicates
    readUntilNewline : (string8* ReverseAcc) -> string8* ReverseAcc.
clauses
    readUntilNewline(Acc) = Result :-
        Piece = readByte(),
        if "\n" = Piece then
            Result = Acc
        else
            Result = readUntilNewline([Piece | Acc])
        end if.

predicates
    readByte : () -> string8 Piece.
clauses
    readByte() = Piece :-
        Buf = string8::create(1),
        Ok = mcpPipe_native::readFile(childStdout, uncheckedConvert(pointer, Buf), 1, Read),
        if b_true = Ok and Read = 1 then
            Piece = string8::createBufferCopy(Buf, 1)
        else
            exception::raise_definiteUser("The MCP server closed its output")
        end if.

% Pairwise merge: O(n log n) instead of O(n^2) for repeated concatenation.
class predicates
    joinAll : (string8* Parts) -> string8 Result.
clauses
    joinAll([]) = "".
    joinAll([P]) = P.
    joinAll([A, B | Rest]) = joinAll(pairUp([A, B | Rest])).

class predicates
    pairUp : (string8* Parts) -> string8* Merged.
clauses
    pairUp([A, B | Rest]) = [string8::concat(A, B) | pairUp(Rest)] :-
        !.
    pairUp(Parts) = Parts.

clauses
    close() :-
        % closing stdin first lets a well-behaved server see EOF and exit by itself
        _ = mcpPipe_native::closeHandle(childStdin),
        if multiThread_native::wait_timeout = multiThread_native::waitForSingleObject(hProcess, 2000) then
            _ = multiThread_native::terminateProcess(hProcess, 1)
        end if,
        _ = mcpPipe_native::closeHandle(childStdout),
        _ = mcpPipe_native::closeHandle(hThread),
        _ = mcpPipe_native::closeHandle(hProcess).

end implement mcpProcessTransport
