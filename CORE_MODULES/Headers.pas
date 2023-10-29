unit Headers;

interface

uses
  sysutils, windows, classes;

const
  tReply: word = $100;
  tAnswer: word = $200;
  tError: word = $300; { использует младшие 8 бит для кода ошибки }
  tTimeOut: word = $400;

  ERROR_NULL_PTR = 1;
  ERROR_SID_NOT_VALID = 2;
  ERROR_OUT_OF_MEM = 3;
  ERROR_LOAD_DLL = 4;
  ERROR_UNLOAD_DLL = 5;
  ERROR_PROC_ADDR = 6;

  SIZE_OF_SID: DWORD = 128; { in bytes! }
  SID_LEN = 64; { in characters! same as database }
  MAX_SIZE = 64; { in characters! same as database }

  cDBName: string = 'SIDs.db3';
  cBDB_DllName: string = 'EvtLogBDB.dll';
  cDB_DllName: string = 'EvtLogDB.dll';

type
  EBaseError = class(Exception)
  strict private
    m_ErrorCode: Integer;
    m_SysCode: Cardinal;
    // private
    // procedure _SetErrorCode(const aErrorCode: Integer);
    // procedure _SetSysCode(const aSysCode: Cardinal);
  public
    constructor Create(const aMsg: string); overload;
    constructor Create(const aErrorCode: Integer); overload;
    constructor Create(const aErrorCode: Integer; const aSysCode: Cardinal);
      overload;
    constructor Create(const aErrorCode: Integer; const aSysCode: Cardinal;
      const aMsg: string); overload;
    constructor Create(const aErrorCode: Integer; const aMsg: string); overload;

    function GetErrorCode(): Integer;
    function GetSysCode(): Cardinal;
    function GetErrorMsg(): string;
  end;

  ESIDCacheError = class(EBaseError);
    ESQLiteError = class(EBaseError);
    ESysError = class(EBaseError); // частично заменено на EOSError(ErrorCode, Message)
    EMemError = class(EBaseError);
    EEventLogError = class(EBaseError);

    EEventLogErrorCreate = class(EBaseError); // in DLL loader
    EEventLogCacheAdd = class(EBaseError); // где-то в недрах EventLog (method ReplaceParamStrings)

    { **************************************************************************** }
    TOperationSystemFamily = (osfNotCheck, osf2000, osfPreVista,
      osfVistaAndLater, osfUnknown);
    TFormatMessageMode = (fmDescription, fmEventCategory, fmParseParameters);
    TOSCheckMode = (oscmLocal, oscmRemote);

    Tva_list = array of va_list;
    TCardinalDynArray = array of Cardinal; // взято из Types
    THandleDynArray = array of THandle;
    TLongWordDynArray = array of LongWord; // взято из Types
    size_t = Cardinal; // для совместимости с DLL

    TOSVerInfo = record _LocalHost: TOperationSystemFamily;
    _LocalHostName: string;
    _RemoteHost: TOperationSystemFamily;
  end;
  { **************************************************************************** }

  TVAList = class(TList)
  private

  public
    constructor Create;
    destructor Destroy; override;
    function Add(Item: Pointer): Integer;
    function AddStr(const Source: string): Integer;
    procedure Clear(); override;

  end;

  TAPIHelper = class
  private
    m_handle: THandle;
    m_ErrorCode: DWORD;
    // (*class var*) m_BufSize: DWORD;
    // (*class var*) m_Ptr: Pointer;
  public
    { public declarations }
    procedure GetEventLogInfo(lpBuffer: Pointer; cbBufSize: DWORD;
      var pcbBytesNeeded: DWORD);

    (* class *) function AllocMem(const BufSize: DWORD): Pointer;
    (* class *) procedure FreeMem(const BufSize: DWORD; var Ptr: Pointer);

    procedure OpenEventLog(Host, Name: string);
    function CloseEventLog(): DWORD;
    function ReadEventLog(const dwReadFlags: DWORD; const Buffer: Pointer;
      const BufSize: DWORD; var BytesRead: DWORD;
      var MinNumberOfBytesNeeded: DWORD): Boolean;
    procedure OpenBackupEventLog(const Host, Name: string);
    procedure BackupEventLog(const aBackupName: string);
    procedure ClearEventLog(const Name: string);
    function GetNumberOfEventLogRecords(): DWORD;
    function GetOldestEventLogRecord(): DWORD;
    property Handle: THandle read m_handle write m_handle;
    property GetErrorCode: DWORD Read m_ErrorCode;
  end;

  // Обьявление внешних функций
procedure _ValidateSID(const aSID: PSID); inline;
procedure _ConvertStringSidToSid(const aStringSID: PWideChar; var aSID: PSID);
function _ConvertSidToStringSid(const aSID: PSID): string;
procedure _LookupAccountSid(const SID: PSID;
  var UserName, DomainName: PWideChar; var UserNameLen, DomainNameLen,
  TypeOfSID: DWORD; const SystemName: PWideChar = nil); inline;
function _GetLengthSid(PSID: Pointer): Cardinal; inline;
function _GetLengthValidSid(PSID: Pointer): Cardinal; inline;
function _GetMessage(const MsgFlags: DWORD; const hModule: Pointer;
  const MsgID: DWORD; var MsgLen: integer; const Arguments: Pointer): string;
  inline;
procedure _CopySid(const Length: DWORD; DestinationSid, SourceSid: Pointer);
  inline;
function _EqualSid(const pSid1, pSid2: PSID): Boolean; inline;

function TzSpecificLocalTimeToSystemTime
  (lpTimeZoneInformation: PTimeZoneInformation;
  var lpUniversalTime: _SYSTEMTIME; var lpLocalTime: _SYSTEMTIME): BOOL;
  stdcall; external 'Kernel32.dll' name 'TzSpecificLocalTimeToSystemTime';

implementation

function GetEventLogInformation(hEventLog: THandle; dwInfoLevel: DWORD;
  lpBuffer: Pointer; cbBufSize: DWORD; var pcbBytesNeeded: DWORD)
  : BOOL; stdcall; external 'Advapi32.dll' name 'GetEventLogInformation';

function ConvertStringSidToSidW(StringSid: PWideChar; var SID: PSID): Boolean;
  stdcall; external 'advapi32.dll';

function ConvertSidToStringSidW(SID: PSID; var StringSid: PWideChar): Boolean;
  stdcall; external 'advapi32.dll';
{$REGION 'EEventLogError'}

(* --- EBaseError constructor--- *)
constructor EBaseError.Create(const aMsg: string);
begin
  m_ErrorCode := 0;
  m_SysCode := 0;
  inherited Create(aMsg);
end;

constructor EBaseError.Create(const aErrorCode: Integer);
begin
  m_ErrorCode := aErrorCode;
  m_SysCode := 0;
  // m_Msg       := '';
  inherited Create('');
end;

constructor EBaseError.Create(const aErrorCode: Integer;
  const aSysCode: Cardinal);
begin
  m_ErrorCode := aErrorCode;
  m_SysCode := aSysCode;
  // m_Msg       := '';
  inherited Create('');
end;

constructor EBaseError.Create(const aErrorCode: Integer; const aMsg: string);
begin
  m_ErrorCode := aErrorCode;
  m_SysCode := 0;
  // m_Msg       := aMsg;
  inherited Create(aMsg);
end;

constructor EBaseError.Create(const aErrorCode: Integer;
  const aSysCode: Cardinal; const aMsg: string);
begin
  m_ErrorCode := aErrorCode;
  m_SysCode := aSysCode;
  // m_Msg       := aMsg;
  inherited Create(aMsg);
end;

(* --- EBaseError --- *)
// procedure EBaseError._SetErrorCode(const aErrorCode: Integer);
// begin
// Self.m_ErrorCode := aErrorCode;
// end;
// procedure EBaseError._SetSysCode(const aSysCode: Cardinal);
// begin
// m_SysCode := aSysCode;
// end;

function EBaseError.GetErrorCode(): Integer;
begin
  Result := m_ErrorCode;
end;

function EBaseError.GetSysCode(): Cardinal;
begin
  Result := m_SysCode;
end;

function EBaseError.GetErrorMsg(): string;
begin
  // Result := m_Msg;
  Result := Message;
end;
{$ENDREGION}
(* --- other functions --- *)

procedure _ValidateSID(const aSID: PSID);
begin
  if (not IsValidSid(aSID)) then
    RaiseLastOSError;
end;

procedure _ConvertStringSidToSid(const aStringSID: PWideChar; var aSID: PSID);
begin
  if not ConvertStringSidToSidW(aStringSID, aSID) then
  begin
    RaiseLastOSError;
  end;
end;

function _ConvertSidToStringSid(const aSID: PSID): string;
var
  Buffer: PWideChar;
begin
  {
    //все, что младше Server 2003 должно с осторожностью использовать эту ф-цию
    //http://msdn.microsoft.com/en-us/library/aa376399(VS.85).aspx

    The GetLastError function may return one of the following error codes.
    Return code	                 Description
    --------------------------------------------------------------------------------
    ERROR_NOT_ENOUGH_MEMORY      Insufficient memory (недостаточно памяти)
    ERROR_INVALID_SID            The SID is not valid.
    ERROR_INVALID_PARAMETER      One of the parameters contains a value that is not valid.
    This is most often a pointer that is not valid.
  }

  try
    Buffer := nil;
    // перед этой функцией можно не ставить IsValidSid
    if ConvertSidToStringSidW(aSID, Buffer) then
      Result := Buffer
    else
      RaiseLastOSError; // throw EOsError
  finally
    LocalFree(Cardinal(Buffer));
  end;
end;

procedure _LookupAccountSid(const SID: PSID;
  var UserName, DomainName: PWideChar; var UserNameLen, DomainNameLen,
  TypeOfSID: DWORD; const SystemName: PWideChar = nil);
begin
  // see http://support.microsoft.com/kb/329420
  {
    http://msdn.microsoft.com/en-us/library/windows/desktop/aa379166(v=vs.85).aspx
    1. search in well-known SIDs list
    2. search in built-in and administratively defined local accounts.
    3. checks in primary domain
    4. Other trusted domains
    }

  if (not LookupAccountSidW(SystemName, SID, UserName, UserNameLen, DomainName,
      DomainNameLen, TypeOfSID)) then
  begin
    RaiseLastOSError;
  end;

  // (1332) ERROR_NONE_MAPPED - the function cannot find an account name for the SID
  // ERROR_INSUFFICIENT_BUFFER - маленький буфер
end;

function _GetLengthSid(PSID: Pointer): Cardinal;
var
  len: Cardinal;
begin
  SetLastError(ERROR_SUCCESS);
  len := windows.GetLengthSid(PSID);
  if GetLastError() <> ERROR_SUCCESS then
    RaiseLastOSError;
  Result := len;
end;

function _GetLengthValidSid(PSID: Pointer): Cardinal;
begin
  SetLastError(ERROR_SUCCESS);
  _ValidateSID(PSID);
  Result := _GetLengthSid(PSID);
end;

function _GetMessage(const MsgFlags: DWORD; const hModule: Pointer;
  const MsgID: DWORD; var MsgLen: integer; const Arguments: Pointer): string;
var
  Buf: array [0 .. 1023] of WideChar;
begin
  MsgLen := FormatMessageW(MsgFlags,
                            Pointer(hModule), MsgID,
                            MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                            Buf, 1024, Arguments);
  if MsgLen > 0 then
    Result := trim(Buf)
  else
    RaiseLastOSError;
end;

procedure _CopySid(const Length: DWORD; DestinationSid, SourceSid: Pointer);
begin
  if not windows.CopySid(Length, DestinationSid, SourceSid) then
    RaiseLastOSError;
end;

function _EqualSid(const pSid1, pSid2: PSID): Boolean;
begin
  // _ValidateSID(pSid1);
  // _ValidateSID(pSid2);
  Result := EqualSid(pSid1, pSid2);
  if (not Result) and (GetLastError <> ERROR_SUCCESS) then
    RaiseLastOSError;
end;

procedure TAPIHelper.GetEventLogInfo;
begin
  SetLastError(ERROR_SUCCESS);
  if not GetEventLogInformation(m_handle, $0000, lpBuffer, cbBufSize,
    pcbBytesNeeded) then
  begin
    RaiseLastOSError;
  end;

end;

(* class *) function TAPIHelper.AllocMem(const BufSize: DWORD): Pointer;
begin
  Result := VirtualAlloc(nil, BufSize, MEM_COMMIT, PAGE_READWRITE);
  if not Assigned(Result) then
    RaiseLastOSError;
end;

(* class *)
procedure TAPIHelper.FreeMem(const BufSize: DWORD; var Ptr: Pointer);
begin
  VirtualFree(Ptr, BufSize, MEM_RELEASE);
  Ptr := nil;
end;

procedure TAPIHelper.OpenEventLog(Host, Name: string);
begin
  SetLastError(ERROR_SUCCESS);
  // m_Handle := OpenEventLogW(pwidechar(WideString(Host)), pwidechar(WideString(Name)));
  m_handle := OpenEventLogW(PWideChar(Host), PWideChar(Name));
  if m_handle = 0 then
    RaiseLastOSError;
end;

function TAPIHelper.CloseEventLog(): DWORD;
begin
  if (m_handle = INVALID_HANDLE_VALUE) or (m_handle = 0) then
  begin
    Result := ERROR_SUCCESS;
    Exit;
  end;

  SetLastError(ERROR_SUCCESS);
  if not windows.CloseEventLog(m_handle) then
    Result := GetLastError()
  else
    Result := ERROR_SUCCESS;
  m_handle := 0;
end;

function TAPIHelper.ReadEventLog(const dwReadFlags: DWORD;
  const Buffer: Pointer; const BufSize: DWORD; var BytesRead: DWORD;
  var MinNumberOfBytesNeeded: DWORD): Boolean;
begin
  SetLastError(ERROR_SUCCESS);
  Result := ReadEventLogW(m_handle, dwReadFlags or $0001,
    { EVENTLOG_SEQUENTIAL_READ }
    0, Buffer, BufSize, BytesRead, MinNumberOfBytesNeeded);
  if not Result then
  begin
    m_ErrorCode := GetLastError;
    if m_ErrorCode = ERROR_HANDLE_EOF then
    begin
      m_handle := 0; // достигнут конец файла (EOF), лог был закрыт ф-цией
      m_ErrorCode := 0; // ErrorCode=0 все нормaльно
    end;
    // else
    // if m_ErrorCode <> ERROR_SUCCESS then
    // RaiseLastOSError(m_ErrorCode);
  end;
end;

procedure TAPIHelper.OpenBackupEventLog(const Host, Name: string);
begin
  if m_handle <> 0 then
    Exit;

  if Length(Host) = 0 then
    m_handle := OpenBackupEventLogW(nil, PWideChar(Name))
  else
    m_handle := OpenBackupEventLogW(PWideChar(Host), PWideChar(Name));
  if m_handle <> 0 then
    RaiseLastOSError;
end;

procedure TAPIHelper.BackupEventLog(const aBackupName: string);
begin
  if not windows.BackupEventLog(m_handle, PWideChar(aBackupName)) then
    RaiseLastOSError;
end;

procedure TAPIHelper.ClearEventLog(const Name: string);
begin
  if m_handle = 0 then
    Exit;
  if not ClearEventLogW(m_handle, PWideChar(Name)) then
    RaiseLastOSError;
end;

function TAPIHelper.GetNumberOfEventLogRecords(): DWORD;
begin
  SetLastError(ERROR_SUCCESS);
  if not windows.GetNumberOfEventLogRecords(m_handle, Result) then
    RaiseLastOSError;
end;

function TAPIHelper.GetOldestEventLogRecord(): DWORD;
begin
  SetLastError(ERROR_SUCCESS);
  if not windows.GetOldestEventLogRecord(m_handle, Result) then
    RaiseLastOSError;
end;

constructor TVAList.Create();
begin
  inherited Create;
end;

destructor TVAList.Destroy();
var
  i, cnt: integer;
  Ptr : PWideChar;
begin
  cnt := inherited count;
  for i:= 0 to cnt - 1 do
    begin
    Ptr := inherited Items[i];
    StrDispose(Ptr);
    end;

  //inherited Destroy;
  inherited clear;
end;

function TVAList.Add(Item: Pointer): Integer;
var
  Ptr: PWideChar;
begin
  Ptr := StrAlloc(1024 * SizeOf(WideChar));
  Ptr := StrCopy(Ptr, Item);
  Result := inherited Add(Ptr);
end;

function TVAList.AddStr(const Source: string): Integer;
var
  Ptr: PWideChar;
begin
  Ptr := StrAlloc(1024 * SizeOf(WideChar));
  StrPCopy(Ptr, Source);
  Result := inherited Add(Ptr);
end;

procedure TVAList.Clear();
var
  i, cnt: integer;
  Ptr : PWideChar;
begin
  cnt := inherited count;
  if cnt <> 0 then
    begin
    for i:= 0 to cnt - 1 do
      begin
      Ptr := inherited Items[i];
      StrDispose(Ptr);
      end;
    inherited Clear;
    end;
end;

end.
