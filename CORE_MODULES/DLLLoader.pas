unit DLLLoader;

interface
uses
  Classes,windows,
  Headers,networkAPI;
  
type

  TDllType = (dtEvtMsgFile, dtParamMsgFile, dtGUIDMsgFile, dtCatMsgFile);

  TDLLLoader = class(TObject)
  strict private
    m_DllList       : TStringList;
    m_OSCheck      : TOSVerInfo;
  public
      constructor Create(const aEventLogName: string = 'Security'{;
                         const aEventSource: string = 'Security'});
      destructor Destroy; override;
      procedure GetDLList(const EventLogSource: string; const DLLType: TDllType; var aList : THandleDynArray; var aCount: DWORD);
  end;
function OpenRegistry(const ARootKey: HKEY; const AKey: string; const IsVistaAndLater:Boolean = false): Boolean;
function CloseRegistry: Boolean;
function GetListOfSubKeys(var List: TStringList) : Boolean;
function GetListOfStringKeys(const List: TStringList; var ErrorCode: DWORD) : Boolean;

implementation
uses
   sysutils,dialogs,StrRepl;
const
// %0:s - имя журнала
// %1:s - имя источника событий
  sLibraryPath             = 'SYSTEM\CurrentControlSet\Services\EventLog\%0:s\%1:s';
  sEvtMsgFile              = 'EventMessageFile';
  sParamMsgFile            = 'ParameterMessageFile';
  sGUIDMsgFile             = 'GuidMessageFile';
  sCatMsgFile              = 'CategoryMessageFile';

  sLibraryPath1            = 'SYSTEM\CurrentControlSet\Services\EventLog\%0:s';
  MS_Win_sec_auditing_GUID =  '{54849625-5478-4994-a5ba-3e3b0328c30d}';
  MS_Win_sec_auditing      =
                  'SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Publishers\{54849625-5478-4994-a5ba-3e3b0328c30d}';

const
  REG_NONE                       = 0;
  REG_SZ                         = 1;
  REG_EXPAND_SZ                  = 2;
  REG_BINARY                     = 3;
  REG_DWORD                      = 4;
  REG_DWORD_LITTLE_ENDIAN        = 4;
  REG_DWORD_BIG_ENDIAN           = 5;
  REG_LINK                       = 6;
  REG_MULTI_SZ                   = 7;
  REG_RESOURCE_LIST              = 8;
  REG_FULL_RESOURCE_DESCRIPTOR   = 9;
  REG_RESOURCE_REQUIREMENTS_LIST = 10;
  REG_QWORD                      = 11;
  REG_QWORD_LITTLE_ENDIAN        = 11;

type
  TSourceData = record
    _SourceName: String;
      //получение текстового представления события
    _EvtMsgFileCnt: DWORD;
    _EvtMsgFile: THandleDynArray;
     // для параметров типа %%1234
    _ParamMsgFileCnt: DWORD;
    _ParamMsgFile: THandleDynArray;
     // для получения категории события
    _CategoryMsgFileCnt: DWORD;
    _CategoryMsgFile: THandleDynArray;
  end;
  TEventLogSources = record
    _Counter: Integer;
    _Items: array of TSourceData;
  end;

var
  EventLogSources: TEventLogSources;
  REG_SESSION_HANDLE: HKEY;

{==============================================================================}
function OpenRegistry(const ARootKey: HKEY; const AKey: String; const IsVistaAndLater:Boolean = false): Boolean;
var
    flag: DWORD;
begin
  Result := false;
  REG_SESSION_HANDLE := 0;

  if IsVistaAndLater then flag :=  KEY_READ or KEY_WOW64_32KEY
  else flag := KEY_READ;


  SetLastError(ERROR_SUCCESS);

  if RegOpenKeyEx(ARootKey, pwidechar(AKey), 0, flag, REG_SESSION_HANDLE) = ERROR_SUCCESS then
    Result := true
  else
    RaiseLastOSError;
end;

function CloseRegistry: Boolean;
begin
  Result := false;
  if REG_SESSION_HANDLE <> 0 then
    begin
    SetLastError(ERROR_SUCCESS);
    if RegCloseKey(REG_SESSION_HANDLE) = ERROR_SUCCESS then
      begin
      Result := True;
      REG_SESSION_HANDLE := 0;
      end;
    end;
end;

function GetListOfSubKeys(var List: TStringList) : Boolean;
var
  i, MaxSubKeyLen, Size, cSize: DWORD;
  //sBuf, sBuf1: string;
  _Buf: array[0.. MAX_PATH] of WideChar;

begin
  Result:=false;
  List.Clear;
try
    if REG_SESSION_HANDLE = 0 then
        exit;

    SetLastError(ERROR_SUCCESS);
    if RegQueryInfoKey(REG_SESSION_HANDLE, nil, nil, nil, nil, @MaxSubKeyLen, nil, nil, nil, nil,
                      nil, nil) <> ERROR_SUCCESS then
        RaiseLastOSError;

    if MaxSubKeyLen > 0 then
        begin
        cSize := MaxSubKeyLen + 1; // учитываем терминирующий нуль\0
        i := 0;
        SetLastError(ERROR_SUCCESS);
        while RegEnumKeyEx(REG_SESSION_HANDLE, i, @_Buf[0], size, nil,nil,nil,nil) <> ERROR_NO_MORE_ITEMS do
          begin
          List.Add(_Buf);
          Size := cSize;
          inc(i);
          end;

        end;
except
  CloseRegistry
end;

end;

function GetListOfStringKeys(const List: TStringList; var ErrorCode: DWORD) : Boolean;
var
  i, MaxValueNameLen, Size, cSize,KeyType: DWORD;
  sBuf, sBuf1: string;
begin
  Result := false;
  List.Clear;

//try
try
    if REG_SESSION_HANDLE = 0 then
        Exit;

    SetLastError(ERROR_SUCCESS);
    if RegQueryInfoKey(REG_SESSION_HANDLE, nil, nil, nil, nil, nil, nil, nil, @MaxValueNameLen, nil,
                      nil, nil) <> ERROR_SUCCESS then
        RaiseLastOSError;

    if MaxValueNameLen > 0 then
        begin
        cSize := MaxValueNameLen +1; //учитываем терминирующий нуль
        SetLength(sBuf, cSize);
        i := 0;
        while RegEnumValue(REG_SESSION_HANDLE,i, pwidechar(sBuf), Size, nil, @KeyType, nil, nil) <> ERROR_NO_MORE_ITEMS do
          begin
          if (KeyType = REG_EXPAND_SZ) or (KeyType = REG_SZ) then
            begin
            sBuf1 := system.copy(sBuf, 1, Size);
            List.Append(sBuf1); sBuf1 := '';
            end;
          Size := cSize;
          inc(i);
          end;
        end;

except
  CloseRegistry;
end;
//finally
//  sBuf := '';
//  sBuf1 := '';
//end;
end;

function GetRegValue(aValue: string; var aData: string):Boolean;
var
  Res: integer;
  DataType, DataSize: DWORD;
  Buf: string;
  wBuf: array[0..127] of WideChar;
begin
  Result := false;
  if REG_SESSION_HANDLE = 0 then exit;

//try
  try
    { TODO : Протестировать на других ОС!!! }
    StringToWideChar(aValue, wBuf, Length(aValue)+1);

    SetLastError(ERROR_SUCCESS);
    //if RegQueryValueEx(REG_SESSION_HANDLE, PWideChar(aValue), nil, @DataType, nil, @DataSize) <> ERROR_SUCCESS then
    if RegQueryValueEx(REG_SESSION_HANDLE, wBuf, nil, @DataType, nil, @DataSize) <> ERROR_SUCCESS then
        exit;

  {Registry Value Types -
   http://msdn.microsoft.com/en-us/library/ms724884(VS.85).aspx}

  SetLength(Buf, datasize div sizeof(char));

  SetLastError(ERROR_SUCCESS);
  //Res := RegQueryValueEx(REG_SESSION_HANDLE, PWideChar(aValue), nil, @DataType,
  Res := RegQueryValueEx(REG_SESSION_HANDLE, wBuf, nil, @DataType,
                          //PByte(pwidechar(Buf)), @DataSize);
                          PByte(@Buf[1]), @DataSize);

  if Res = ERROR_SUCCESS then
    aData := copy(Buf,1, (DataSize div sizeof(char)) - 1)  // DataSize учитывает терминирующий нуль, переводим в кол-во символов
  else
    RaiseLastOSError;

  Result := true;

  except
    CloseRegistry;
  end;
//finally
//  Buf := '';
//end;
end;

function LoadLibList(const aValue: string; var aList: TStringList): Boolean; //aPath,
var
  StrBuffer: string;
  outputStr : array[0..1023] of WideChar;
  index, len: Integer;
  Buffer: string;
begin
  if not Assigned(aList) then
    begin
    Result := false;
    Exit
    end;

  Result := GetRegValue(aValue, Buffer);
  if Result then
    begin
    aList.Clear;
    len := SizeOf(outputStr);
    FillChar(OutputStr,len,0);
    Win32Check(ExpandEnvironmentStrings(Pwidechar(Buffer), @OutputStr[0], len)<>0);
    StrBuffer := pwidechar(@OutputStr[0]);
    index :=1;
    while index > 0 do
      begin
      aList.Add(ParseString(';', StrBuffer, index));
      end;
    end;
end;

function LoadDLL(const aList: TStringList; const aFlag: DWORD; var aHandle: THandleDynArray): Integer;
var
  i,i_cnt: Integer;
  StrBuffer: string;
begin
  Result := 0;
//try
  i_cnt := aList.Count - 1;
  for I := 0 to i_cnt do
    begin
    StrBuffer := aList.Strings[i];
    SetLastError(ERROR_SUCCESS);
    aHandle[i] := LoadLibraryEx(pwidechar(StrBuffer), 0, aFlag);
    if aHandle[i] = 0 then
        begin
        ShowMessage('LoadLibraryExW Error!' + #13#10+
        StrBuffer +#13#10 + SysErrorMessage(GetLastError));
        RaiseLastOSError;
        end;
    inc(Result);
    end; //for i
//finally
//  StrBuffer := '';
//end;
end;

procedure GetDllHandle(const aSource: string; const Param: TDllType; var aDllList: THandleDynArray; var Count: DWORD);
{
procedure SetDllList(const MsgFileCnt: DWORD; const Source: THandleDynArray; var DllList: THandleDynArray; var Count: DWORD);
var
    j: DWORD;
begin
    if MsgFileCnt <> 0 then
        begin
        SetLength(DllList, MsgFileCnt);
        Count := MsgFileCnt;
        for j := 0 to MsgFileCnt - 1 do
        DllList[j] := Source[j]
        end
    else Count := 0;
end;
}

var
  i,j: integer;
begin
  Count := 0;
  aDllList := nil;

  for I := 0 to EventLogSources._Counter -1 do
    begin
    if EventLogSources._Items[i]._SourceName = AnsiUpperCase(aSource) then
      begin
      case Param of
        dtEvtMsgFile: begin
                      with EventLogSources._Items[i] do
                        begin
                        if _EvtMsgFileCnt <> 0 then
                          begin
                          SetLength(aDllList,_EvtMsgFileCnt);
                          Count := _EvtMsgFileCnt;
                          for j := 0 to _EvtMsgFileCnt- 1 do
                            aDllList[j] := _EvtMsgFile[j]
                          end
                        else Count := 0;
                        end;
                end;
        dtParamMsgFile: begin
                        with EventLogSources._Items[i] do
                          begin
                          if _ParamMsgFileCnt <> 0 then
                            begin
                            SetLength(aDllList,_ParamMsgFileCnt);
                            Count := _ParamMsgFileCnt;
                            for J := 0 to _ParamMsgFileCnt - 1 do
                              aDllList[j] := _ParamMsgFile[j]
                            end
                          else Count := 0;
                          end;
                end;
       dtCatMsgFile: begin
                        with EventLogSources._Items[i] do
                          begin
                          if _CategoryMsgFileCnt <> 0 then
                            begin
                            SetLength(aDllList,_CategoryMsgFileCnt);
                            Count := _CategoryMsgFileCnt;
                            for J := 0 to _CategoryMsgFileCnt - 1 do
                              aDllList[j] := _CategoryMsgFile[j]
                            end
                          else Count := 0;
                          end;
                end;
       else
        begin
        aDllList := nil;
        Count := 0;
        end;
      end; //case
      end; //if
    end; //for
end;

{==============================================================================}
constructor TDllLoader.Create(const aEventLogName: string = 'Security'{;
                              const aEventSource: string = 'Security'});
var
    Flag : DWORD;
{--------------------------------------------------------------------}
  ListOfSources {,
  ListOfStrKeys,
  ListOfValue}  : tstringlist;
  Path1, Path2 : string;
  j            : integer;
  DLLCount     : DWORD;
  pdll_file    : PWideChar;
  _EventLogName : string;


begin
  _EventLogName := aEventLogName;
    with m_OSCheck do
        begin
        case OSCheck of // Local host
            50      : _LocalHost:=osf2000;
            51..52  : _LocalHost:=osfPreVista;
            60..61  : _LocalHost:=osfVistaAndLater
        else _LocalHost:=osfUnknown;
        end;
        end; //with


      case m_OSCheck._LocalHost of
         TOperationSystemFamily.osfNotCheck .. TOperationSystemFamily.osfPreVista, TOperationSystemFamily.osfUnknown :
          begin
          Flag := {DONT_RESOLVE_DLL_REFERENCES or} LOAD_LIBRARY_AS_DATAFILE;
          end;
        TOperationSystemFamily.osfVistaAndLater :
          begin
          Flag := {LOAD_LIBRARY_AS_IMAGE_RESOURCE} $0020 or LOAD_LIBRARY_AS_DATAFILE;
          end;
      else Flag := {DONT_RESOLVE_DLL_REFERENCES or} LOAD_LIBRARY_AS_DATAFILE;
      end;

    //получаем список источников событий для выбранного журнала
    Path1 := format(sLibraryPath1,[_EventLogName]); // <--
    if not OpenRegistry(HKEY_LOCAL_MACHINE, Path1) then exit;

    try //except
    try //finally
      m_DllList := TStringList.Create;
      {-----------------------------------------------------------------------}
      ListOfSources := TStringList.Create;
      GetListOfSubKeys(ListOfSources);
      CloseRegistry;

      SetLength(EventLogSources._Items, ListOfSources.Count);
      EventLogSources._Counter := ListOfSources.Count;

      for J := 0 to EventLogSources._Counter - 1 do
        begin
        //получаем список REG_EXPAND_SZ строк в Path2
        Path2 := '';
        Path2 := Path1 + '\' + ListOfSources.Strings[J]; // <--
        EventLogSources._Items[j]._SourceName := AnsiUpperCase(ListOfSources.Strings[J]);
        if not OpenRegistry(HKEY_LOCAL_MACHINE, Path2) then break;

        if LoadLibList(sCatMsgFile,m_DllList) then
            begin
            SetLength(EventLogSources._Items[j]._CategoryMsgFile,m_DllList.Count);
            DLLCount := LoadDLL(m_DllList,Flag,EventLogSources._Items[j]._CategoryMsgFile);
            EventLogSources._Items[j]._CategoryMsgFileCnt := DLLCount;
            end;
            //===================================
        if LoadLibList(sParamMsgFile,m_DllList) then
            begin
            SetLength(EventLogSources._Items[j]._ParamMsgFile,m_DllList.Count);
            DLLCount := LoadDLL(m_DllList,Flag,EventLogSources._Items[j]._ParamMsgFile);
            EventLogSources._Items[j]._ParamMsgFileCnt := DllCount;
            end;
            //===================================
        if LoadLibList(sEvtMsgFile,m_DllList) then
            begin
            SetLength(EventLogSources._Items[j]._EvtMsgFile, m_DllList.Count);
            DLLCount := LoadDLL(m_DllList,Flag,EventLogSources._Items[j]._EvtMsgFile);
            EventLogSources._Items[j]._EvtMsgFileCnt := DllCount;
            end;
        CloseRegistry;
        end; //for J

      //Win Vista +
      if (m_OSCheck._LocalHost = osfVistaAndLater) and (AnsiUpperCase(_EventLogName) = 'SECURITY') then
        begin //load MS_Win_sec_auditing
        DLLCount := EventLogSources._Counter +1;
        SetLength (EventLogSources._Items,DLLCount);
        ShowMessage('SetLength (EventLogSources._Items,DLLCount)');

        inc(EventLogSources._Counter);
        ShowMessage('EventLogSources._Counter)');

        EventLogSources._Items[EventLogSources._Counter-1]._SourceName := AnsiUpperCase('Microsoft-Windows-Security-Auditing');
        ShowMessage('_SourceName');
        pdll_file := StrAlloc(MAX_PATH-1);
        ShowMessage('pdll_file');
        try
//          DLLCount := 1;
//          SetLength(EventLogSources._Items[EventLogSources._Counter-1]._EvtMsgFile,DLLCount);
//          EventLogSources._Items[EventLogSources._Counter-1]._EvtMsgFile[0] :=
//            LoadLibraryEx('C:\Windows\system32\adtschema.dll',0,Flag);
//          EventLogSources._Items[EventLogSources._Counter]._EvtMsgFileCnt := DLLCount;

          DLLCount := 1;
          SetLength(EventLogSources._Items[EventLogSources._Counter-1]._ParamMsgFile,DLLCount);
          EventLogSources._Items[EventLogSources._Counter-1]._ParamMsgFile[0] :=
            LoadLibraryEx('C:\Windows\system32\msobjs.dll',0,Flag);
          EventLogSources._Items[EventLogSources._Counter-1]._ParamMsgFileCnt := DllCount;
        finally
          StrDispose(pdll_file);
        end;
        end;
      {-----------------------------------------------------------------------}

    finally
      FreeAndNil(ListOfSources);
      FreeAndNil(m_DllList);
      CloseRegistry;
      Path1 := '';
      Path2 := '';
      _EventLogName := '';
    end;
    except
      raise EEventLogErrorCreate.Create('Error create EventLog');
    end;
end;

destructor TDllLoader.Destroy;
var
  i,j : integer;
begin
  for I := 0 to EventLogSources._Counter - 1 do
    begin
    with EventLogSources._Items[i] do
      begin
      _SourceName := '';
      if _EvtMsgFileCnt <> 0 then
        begin
        for J := 0 to _EvtMsgFileCnt - 1 do
          FreeLibrary(_EvtMsgFile[j]);
        Finalize(_EvtMsgFile);
        end;

      if _ParamMsgFileCnt <> 0 then
        begin
        for J := 0 to _ParamMsgFileCnt - 1 do
          FreeLibrary(_ParamMsgFile[j]);
        Finalize(_ParamMsgFile);
        end;

    if _CategoryMsgFileCnt <> 0 then
      begin
      for J := 0 to _CategoryMsgFileCnt - 1 do
        FreeLibrary(_CategoryMsgFile[j]);
      Finalize(_CategoryMsgFile);
      end;

      end;
    end;
  Finalize(EventLogSources._Items);
end;
procedure TDLLLoader.GetDLList(const EventLogSource: string; const DLLType: TDllType; var aList : THandleDynArray; var aCount: DWORD);
begin
  if Assigned(aList) then
    Finalize(aList);
  GetDllHandle(EventLogSource,DLLType,aList,aCount);
end;



end.
