% Copyright (c) 2026 BestProlog
%
% @short Minimal bindings for the Win32 pipe/file calls needed by mcpProcessTransport.
% Delete the ones that PFC already has (search PFC for createPipe / readFile / writeFile).
% @end

class mcpPipe_native
    open core, windowsAPI

constants
    handle_flag_inherit : unsigned = 0x1.
    std_error_handle : unsigned = 0xFFFF_FFF4. % (DWORD)-12

predicates
    createPipe : (handle ReadPipe [out], handle WritePipe [out], security_attributes Attributes, unsigned Size) -> booleanInt Result
        language apicall [mandatoryOut].
    % @short See CreatePipe in MSDN.
    % @end

predicates
    setHandleInformation : (handle Handle, unsigned Mask, unsigned Flags) -> booleanInt Result language apicall.
    % @short See SetHandleInformation in MSDN.
    % @end

predicates
    getStdHandle : (unsigned StdHandle) -> handle Handle language apicall.
    % @short See GetStdHandle in MSDN.
    % @end

predicates
    readFile : (handle File, pointer Buffer, unsigned BytesToRead, unsigned BytesRead [out], pointer Overlapped = null) -> booleanInt Result
        language apicall [mandatoryOut].
    % @short See ReadFile in MSDN.
    % @end

predicates
    writeFile : (handle File, pointer Buffer, unsigned BytesToWrite, unsigned BytesWritten [out], pointer Overlapped = null) -> booleanInt Result
        language apicall [mandatoryOut].
    % @short See WriteFile in MSDN.
    % @end

predicates
    closeHandle : (handle Handle) -> booleanInt Result language apicall.
    % @short See CloseHandle in MSDN.
    % @end

end class mcpPipe_native
