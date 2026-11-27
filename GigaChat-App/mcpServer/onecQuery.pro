% Copyright (c) 2026 BestProlog

implement onecQuery
    open core, json

constants
    connectionFile : string = "onec.connection".
    % One line in the current directory, UTF-8, for example
    %   Srvr="server";Ref="erp";Usr="mcp_reader";Pwd="secret";
    %   File="C:\Bases\ERP";Usr="mcp_reader";Pwd="secret";
    %coinitMultithreaded : unsigned = 0.
    maxMessageLength : charCount = 1500.

clauses
    execute(QueryText, Parameters, MaxRows) = Outcome :-
        try
            Infobase = connect(),
            try
                Outcome = ok(runQuery(Infobase, QueryText, Parameters, MaxRows))
            catch QueryTrace do
                Dump = exceptionDump::dumpToString(QueryTrace),
                Outcome = failed(errorText(Dump), Dump)
            end try
        catch ConnectTrace do
            % the details may describe the server and user: log only
            Outcome = failed("Cannot connect to the 1C infobase, see the server log", exceptionDump::dumpToString(ConnectTrace))
        end try.

class predicates
    errorText : (string Dump) -> string Text.
    % the part of the dump with the 1C error description, so the model can fix its query
clauses
    errorText(Dump) = Text :-
        if Start = string::search(Dump, "ErrorDescription") then
            Tail = string::subString(Dump, Start, string::length(Dump) - Start)
        else
            Tail = Dump
        end if,
        if End = string::search(Tail, "Native Error Code") then
            Description = string::subString(Tail, 0, End)
        else
            Description = Tail
        end if,
        if string::length(Description) > maxMessageLength then
            Text = string::subString(Description, 0, maxMessageLength)
        else
            Text = Description
        end if.

% ---------------------------------------------------------------------------
% 1C connection and query
%
% A new connection is opened for every call, so that all COM objects are used
% on the thread that created them.
class predicates
    connect : () -> comDispInterface Infobase.
clauses
    connect() = objectOf(callMethod(Connector, "Connect", [comDomains::string(ConnectionString)])) :-
        ConnectionString = string::trim(file::readString(connectionFile)),
        %_ = coInitializeEx(null, coinitMultithreaded),
        % CLSID of V83.COMConnector: {181E893D-73A4-4722-B61D-D604B3D67D47}
        ClassId = core::nativeGuid(0x181E893D, 0x73A4, 0x4722, 0xB6, 0x1D, 0xD6, 0x04, 0xB3, 0xD6, 0x7D, 0x47),
        Unknown = comCreation::createInstance(ClassId, iDispatch::iid),
        Connector = comDispInterface::new(uncheckedConvert(iDispatch, Unknown)).

class predicates
    runQuery : (comDispInterface Ib, string QueryText, jsonObject Parameters, integer MaxRows) -> jsonObject Data.
clauses
    runQuery(Ib, QueryText, Parameters, MaxRows) = Data :-
        Query = objectOf(callMethod(Ib, "NewObject", [comDomains::string("Query")])),
        Query:setProperty("Text", comDomains::string(QueryText)),
        foreach tuple(ParameterName, ParameterValue) = Parameters:getAll_nd() do
            runMethod(Query, "SetParameter", [comDomains::string(ParameterName), toVariant(Ib, ParameterValue)])
        end foreach,
        QueryResult = objectOf(callMethod(Query, "Execute", [])),
        Table = objectOf(callMethod(QueryResult, "Unload", [])),
        Columns = objectOf(Table:getProperty("Columns")),
        ColumnCount = integerOf(Ib, callMethod(Columns, "Count", [])),
        Names = [ columnName(Columns, I) || I = std::fromTo(0, ColumnCount - 1) ],
        TotalRows = integerOf(Ib, callMethod(Table, "Count", [])),
        if TotalRows > MaxRows then
            RowCount = MaxRows,
            Truncated = t
        else
            RowCount = TotalRows,
            Truncated = f
        end if,
        Rows = [ rowToJson(Ib, Table, Names, J) || J = std::fromTo(0, RowCount - 1) ],
        ColumnList = [ s(Name) || Name = list::getMember_nd(Names) ],
        Data = jsonObject::new(),
        Data:set_array("columns", ColumnList),
        Data:set_array("rows", Rows),
        Data:set("rowCount", r(RowCount)),
        Data:set("totalRows", r(TotalRows)),
        Data:set("truncated", Truncated).

class predicates
    columnName : (comDispInterface Columns, integer Index) -> string Name.
clauses
    columnName(Columns, Index) = textOf(Column:getProperty("Name")) :-
        Column = objectOf(callMethod(Columns, "Get", [comDomains::integer(Index)])).

class predicates
    rowToJson : (comDispInterface Ib, comDispInterface Table, string* Names, integer Index) -> jsonValue Row.
clauses
    rowToJson(Ib, Table, Names, Index) = o(Json) :-
        Row = objectOf(callMethod(Table, "Get", [comDomains::integer(Index)])),
        Json = jsonObject::new(),
        fillRow(Ib, Row, Names, 0, Json).

class predicates
    fillRow : (comDispInterface Ib, comDispInterface Row, string* Names, integer Column, jsonObject Json).
clauses
    fillRow(_, _, [], _, _).
    fillRow(Ib, Row, [Name | Names], Column, Json) :-
        Value = callMethod(Row, "Get", [comDomains::integer(Column)]),
        Json:set(Name, toJson(Ib, Value)),
        fillRow(Ib, Row, Names, Column + 1, Json).

% ---------------------------------------------------------------------------
% 1C value -> JSON
class predicates
    toJson : (comDispInterface Ib, comDomains::variant Value) -> jsonValue Json.
clauses
    toJson(_, Value) = s(Text) :-
        comDomains::string(Text) = Value,
        !.
    toJson(_, Value) = t :-
        comDomains::boolean(true) = Value,
        !.
    toJson(_, Value) = f :-
        comDomains::boolean(false) = Value,
        !.
    toJson(_, Value) = r(Number) :-
        comDomains::integer(Number) = Value,
        !.
    toJson(Ib, Value) = referenceToJson(Ib, Value) :-
        comDomains::iDispatch(_) = Value,
        !.
    toJson(Ib, Value) = Json :-
        % remaining cases: NULL, Undefined, dates, non-integer numbers
        if "" = textOf(callMethod(Ib, "String", [Value])) then
            % NULL, Undefined and the empty date
            Json = n
        else
            Xml = textOf(callMethod(Ib, "XMLString", [Value])),
            if Number = tryToTerm(real, Xml) then
                Json = r(Number)
            else
                % dates arrive as yyyy-mm-ddThh:mm:ss
                Json = s(Xml)
            end if
        end if.

class predicates
    referenceToJson : (comDispInterface Ib, comDomains::variant Value) -> jsonValue Json.
clauses
    referenceToJson(Ib, Value) = o(Json) :-
        Json = jsonObject::new(),
        Json:set_string("presentation", textOf(callMethod(Ib, "String", [Value]))),
        try
            % references and enumerations: can be passed back as a parameter
            TypeInfo = objectOf(callMethod(Ib, "XMLTypeOf", [Value])),
            TypeName = textOf(TypeInfo:getProperty("TypeName")),
            Id = textOf(callMethod(Ib, "XMLString", [Value])),
            Json:set_string("type", TypeName),
            Json:set_string("value", Id)
        catch _ do
            % other objects (e.g. nested tables) keep the presentation only
            succeed
        end try.

% ---------------------------------------------------------------------------
% JSON -> 1C parameter value
class predicates
    toVariant : (comDispInterface Ib, jsonValue Json) -> comDomains::variant Value.
clauses
    toVariant(_, s(Text)) = comDomains::string(Text) :-
        !.
    toVariant(_, t) = comDomains::boolean(true) :-
        !.
    toVariant(_, f) = comDomains::boolean(false) :-
        !.
    toVariant(Ib, r(Number)) = xmlValue(Ib, "Number", toString(Number)) :-
        !.
    toVariant(Ib, a(Items)) = ArrayValue :-
        !,
        ArrayValue = callMethod(Ib, "NewObject", [comDomains::string("Array")]),
        Array = objectOf(ArrayValue),
        foreach Item = list::getMember_nd(Items) do
            runMethod(Array, "Add", [toVariant(Ib, Item)])
        end foreach.
    toVariant(Ib, o(Json)) = xmlValue(Ib, TypeName, Text) :-
        some(s(TypeName)) = Json:get_optional("type"),
        some(s(Text)) = Json:get_optional("value"),
        !.
    toVariant(_, _) = _ :-
        exception::raise_user("Unsupported query parameter value", []).

class predicates
    xmlValue : (comDispInterface Ib, string TypeName, string Text) -> comDomains::variant Value.
clauses
    xmlValue(Ib, TypeName, Text) = callMethod(Ib, "XMLValue", [Type, comDomains::string(Text)]) :-
        Type = callMethod(Ib, "Type", [comDomains::string(TypeName)]).

% ---------------------------------------------------------------------------
% COM helpers
class predicates
    callMethod : (comDispInterface Object, string Method, comDomains::variant* Args) -> comDomains::variant Result.
clauses
    callMethod(Object, Method, Args) = list::nth(0, Outputs) :-
        Outputs = Object:invokeMethodWithOutput(Method, list::map(Args, { (A) = comDomains::in(A) })).

class predicates
    runMethod : (comDispInterface Object, string Method, comDomains::variant* Args).
clauses
    runMethod(Object, Method, Args) :-
        _ = Object:invokeMethodWithOutput(Method, list::map(Args, { (A) = comDomains::in(A) })).

class predicates
    objectOf : (comDomains::variant Value) -> comDispInterface Object.
clauses
    objectOf(Value) = comDispInterface::new(Dispatch) :-
        comDomains::iDispatch(Dispatch) = Value,
        !.
    objectOf(_) = _ :-
        exception::raise_user("1C returned a value where an object was expected", []).

class predicates
    textOf : (comDomains::variant Value) -> string Text.
clauses
    textOf(Value) = Text :-
        comDomains::string(Text) = Value,
        !.
    textOf(_) = _ :-
        exception::raise_user("1C returned a value where a string was expected", []).

class predicates
    integerOf : (comDispInterface Ib, comDomains::variant Value) -> integer Number.
clauses
    integerOf(_, Value) = Number :-
        comDomains::integer(Number) = Value,
        !.
    integerOf(Ib, Value) = toTerm(integer, textOf(callMethod(Ib, "XMLString", [Value]))).

end implement onecQuery
