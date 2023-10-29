unit EventLog;

//����� ����� ���������
{$Define RUS}

interface
uses
    windows, Classes, sysutils, messages,
    RTCache, Headers, DLLLoader;
const
  EVENTLOG_AUDIT_SUCCESS    = $0008;
  EVENTLOG_AUDIT_FAILURE    = $0010;
  EVENTLOG_AUDIT_ANY        = $0020; //����������� ���������-��������
{$region 'Types'}
type

  TDirection = (dForvards, dBackwards); //����������� ������ ����
                //dForvards - old -> new, ��-���������
                //dBackwards - new -> old

  TDateTimeFilter = function(const StartData,EndData: DWORD):integer of object;
    {----------------------------------------------------------
    ������ ��� ������ ��� ���������� ������ �� ���������� SID
    ������������ ��� ��� ��� ����� ������������� SID
    -----------------------------------------------------------}
  TPrevSIDInfo = record
    _SID        : PSID;
    _SidLength  : DWORD;
    _UserName   : string;
    _StringSID  : string;
    _SIDType    : DWORD;
    end;

    {----------------------------------------------------------
    ������ ��� ������ ��� ���������� ������ �� ��������������
    Unix DateTime � Delphi �DateTime
    -----------------------------------------------------------}
  TPrevTime = record
    _UnixDateTime     : DWORD;
    _DelphiDateTime   : TDateTime;
    end;

    {----------------------------------------------------------
    ������ ��� ������ ��� ���������� ������ �� ����������
    ��������� �������
    -----------------------------------------------------------}
  TPrevEventCategory = record
    _EventCategory      : word;
    _StrEventCategory   : string;
    end;

  PEventLogRecord= ^TEventLogRecord;
  TEventLogRecord = record
    Length              : DWORD;    // Length of full record
    Reserved            : DWORD;    // Used by the service = ELF_LOG_SIGNATURE
    RecordNumber        : DWORD;    // Absolute record number
    TimeGenerated       : DWORD;    // Seconds since 1-1-1970, Universal Coordinated Time
    TimeWritten         : DWORD;    // Seconds since 1-1-1970, Universal Coordinated Time
    EventID             : DWORD;
    EventType           : Word;
    NumStrings          : Word;
    EventCategory       : Word;
    ReservedFlags       : Word;     // For use with paired events (auditing)
    ClosingRecordNumber : DWORD;    // For use with paired events (auditing)
    StringOffset        : DWORD;    // Offset from beginning of record
    UserSidLength       : DWORD;
    UserSidOffset       : DWORD;
    DataLength          : DWORD;
    DataOffset          : DWORD;    // Offset from beginning of record
    //
    // Then follow:
    //
    // WCHAR SourceName[]
    // WCHAR Computername[]
    // SID   UserSid
    // WCHAR Strings[]
    // BYTE  Data[]
    // CHAR  Pad[]
    // DWORD Length;
    //
  end;
{==============================================================================}
  TEventLog = class
  strict private
     //Base fields
     m_RecordNumber       : DWord;
     m_TimeGenerated      : DWORD;
     m_TimeWritten        : DWORD;
     m_EventID            : DWORD;
     m_EventType          : word;
     m_NumStrings         : WORD;
     m_EventCategory      : Word;
     m_UserSidLength      : dword;
     m_SourceName         : String; // ��� ��������� ���������, ������� ��������
                                   //(����������� �� ��������)
     m_ComputerName       : String; // ��� �������, ��� ������� ��������
                                   //(����������� �� ��������)
     m_Description        : string;

     m_UserName           : string;
     m_StringSID          : string; {������ ���� S-1-5-2...}
     m_SIDType            : DWORD;
     m_ArgsList           : TVAList;

     m_CurrentArgsCount   : WORD;

     m_EventLogName       : string; //��� �������, ������� ��������
     m_Direction          : TDirection;
     m_DirectionFlag      : Cardinal; //���� ���������� ����� ������ ReadEventLog
     m_src                : PEventLogRecord;
     m_Source             : PEventLogRecord;
     m_EndOfRecords       : PEventLogRecord;

     //�������������� ����
     m_ServerName         : String; // ��� �������, ��� ������� ����� ������
                                   //����������� � ������ Create ������
     m_IsLocalHost        : boolean; //True - ������ ������� ���������� �����
                                    //false - ���������� �����

     m_ErrorCode          : DWORD; //���� ������ ��� ������ ���-�������
     m_ErrorWnd           : HWND;

     m_Param_hModule       : THandleDynArray;
     m_Category_hModule    : THandleDynArray;
     m_Param_Count         : DWORD;
     m_Param_PrevSource    : string;
     m_CategoryCount       : DWORD;
     m_Category_PrevSource : string;

     m_DllList             : TDLLLoader;
     m_dwBufSize           : DWORD;
     m_dwread              : DWORD;
     m_dwneeded            : DWORD;

     m_OSCheck            : TOSVerInfo;
     //���������� ��� ��������� ���������� SID
     m_PrevSIDInfo        : TPrevSIDInfo;    // L1 Cache
     m_IsInternalCashe     : Boolean;         // True - ������� ���,
                                            // False - ������������ ��� ������
     m_SIDCache            : TSIDCache;       // L2 cache

     //���������� ��� ��������� ���������� �������� %%1234
     m_FMCache             : TFMCache;

     //���������� ��� ��������� ���������� ����/������� � ��������� �������
     m_PrevTimeGenerated  : TPrevTime;
     m_PrevTimeWritten    : TPrevTime;
     m_PrevEventCategory  : TPrevEventCategory;

     m_DateTimeFilter     : TDateTimeFilter;
     // �������������� ����������
     m_ByteReadCount      : Int64;
     m_MaxArgumentsCount  : WORD;
     m_EventsReadCount    : Int64;
     m_api                : TAPIHelper;
     dll_parse_init       : Boolean;

    //������ ��� ������ �� ���������� TPrevSIDInfo
    procedure _PrevSIDInfoInit(var aValue: TPrevSIDInfo);// inline;
    {procedure _PrevSIDInfoClear(var aValue: TPrevSIDInfo);// inline; }
    procedure _PrevSIDInfoDeinit(var aValue: TPrevSIDInfo);// inline;
    function _GetPrevSIDInfo(const aSID: PSID; var aSIDLength, aSIDType: DWORD;
                                               var aData, aStrSID: string): boolean;// inline;
    procedure _SetPrevSIDInfo(const aSID: PSID; const aSIDLength, aSIDType: DWORD;
                          const aData, aStringSID: string);// inline;
    //DateTime routing
    function _GetDateTimeStamp(const aUnixDateTime: DWORD):TDateTime; overload; register;
    {function _GetDateTimeStamp(const aDelphiDateTime: TDateTime):dword; overload; register; }
    function _DateTimeFilterForvard(const StartData,EndData: DWORD):integer;
    function _DateTimeFilterBackward(const StartData,EndData: DWORD):integer;
    //End DateTime routing
    function _GetMessage(Mode: TFormatMessageMode; hModule: THandle;
                      var MsgLen: integer; ParametrID: DWORD =0): string; register;
    procedure _ApplyParametersStringsToMessage;
    //������ ��� ������ � SID
    procedure _GetUserInfoFromSID(const aSID: PSID; var aDomainName: string; var aTypeOfSID: DWORD; const aSystemName: PWideChar = nil);
    procedure _GetDataFromSID(const aSID: PSID; var aDecodeData,aStrSID: string;
                        var aSIDType: DWORD; var aIsFindInCache: Boolean);

    function _GetEventID(const aEventID: DWORD): DWORD;

  private
    {---- Getters/Setters ----}
    function GetDirection : TDirection;
    procedure SetDirection(const aDirection: TDirection);
    function GetRecordNumber: DWORD;

    function dwGetTimeGenerated: DWORD;
    function dwGetTimeWritten: DWORD;

    function dtGetTimeGenerated: TDateTime;
    function dtGetTimeWritten: TDateTime;

    function GetEventID: DWord;
    function GetEventType: Word;
    function GetEventCategory: Word;

    function GetSIDLength: dword;
    function GetSourceName: String;
    function GetComputerName: String;
    function GetStringSID:string;

    function GetDescription: string;
    function GetUserName: String;
    function GetErrorCode: DWORD;
    //statistics
    function GetBytesReadCount: int64;
    function GetMaxArgumentsCount: WORD;
    function GetEventsReadCount: Int64;

  public
    constructor Create(const ServerName: string = '';
                       const Cache:TSIDCache = nil; Direction: TDirection = dForvards);
    destructor Destroy; override;

    procedure OpenLog(const aEventLogName: string); overload;
    procedure OpenLog(); overload;
    procedure  CloseLog();
    function  ReadLog: boolean;
      {������ � ��������� ������ �������}
    procedure OpenBackupLog(const aBackupName: string);
    procedure  BackupLog(const aBackupName: string);
    procedure  ClearLog(const aBackupName: string = '' );
      {������� ������ �������. ������ ������ ���� ������. ���� ����� ��������
      BackupName, �� ��������� ��������� ����� �������}

    function  LogIsFull: boolean;
    function NumberOfLogRecords(): DWORD;
    function  NumberOfOldestLogRecord(): DWORD;

    //��� ������ �����������, ���� ������� �������� �������� ��������
    procedure SetPtrToExtSource(aSource: Pointer);
    function GetPtrFromExtSource: pointer;
    procedure SetHandleOfLog(aHandle: THandle);
    function GetHandleOfLog: THandle;

    procedure Next;
    function IsNotDone:Boolean;

    procedure DecodeBase;
    procedure DecodeArg;
    procedure DecodeUserInfo;
//    procedure DecodeMsgDesc;
    procedure Clear; inline;
    procedure ClearMemory;

    function GetFacility: Word;
    function GetStatusCode: Word;
    function GetSeverity: Byte;

    function GetEventTypeAsString: String;
    function GetEventCategoryAsString: string;

    function  GetArgumentsCount: dword;
    function  GetArgumentsAsString: string;
    procedure GetArgumentsAsArray(var Arr:Tva_list);
    function  GetArgumentItem(ItemIndex: Integer): string;
    function  GetSIDTypeAsString: string;

    //function ContentFilter: boolean;
    function ArgumentsFilter(const aValue: PwideChar): boolean;
    function DateTimeFilter(aStartDataTime, aEndDataTime: DWORD): integer;
    function EventIDFilter(const aEventIDArray: TLongWordDynArray;
                           aCount: DWORD; const Include: Boolean = True): boolean;
    function EventTypeFilter(aEventType: word): boolean;

    procedure CallOutput; overload;

    property Direction : TDirection read GetDirection write SetDirection; //fdirection
    property RecordNumber:DWord read GetRecordNumber;                     //fRecordNumber;

    property dwTimeGenerated: DWORD read dwGetTimeGenerated;      //fTimeGenerated;
    property dwTimeWritten: DWORD read dwGetTimeWritten;          //fTimeWritten;
    property dtTimeGenerated: TDateTime read dtGetTimeGenerated;  //fTimeGenerated;
    property dtTimeWritten: TDateTime read dtGetTimeWritten;      //fTimeWritten;

    property EventID: DWord read GetEventID;                      //fEventID;
    property EventType: Word read GetEventType;                   //fEventType;
    property EventCategory: Word read GetEventCategory;           //fEventCategory;

    property SIDLength: dword read GetSIDLength;                  //fUserSidLength;
    property SourceName: String read GetSourceName;               //fSourceName;
    property ComputerName: String read GetComputerName;           //fComputerName;
    property StringSID:string read GetStringSID;                  //fStringSID;

    property Description: string read GetDescription;             //fDescription;
    property UserName: String read GetUserName;                   //fUserName;
    property ErrorCode: DWORD read GetErrorCode;                  //fErrorCode;
    property ErrorWnd: HWND read m_ErrorWnd;
    //statistics
    property BytesReadCount : int64 read GetBytesReadCount;       //fByteReadCount;
    property MaxArgumentsCount  : WORD read GetMaxArgumentsCount; //fMaxArgumentsCount;
    property EventsReadCount : int64 read GetEventsReadCount;     //fEventsReadCount
  end;
{==============================================================================}
{$endregion}
implementation
uses
    StrUtils, DateUtils, dialogs,
    NetworkAPI, StrRepl{, MPUnit};

{$region 'Const'}
const
  // The types of events that can be logged.
  EVENTLOG_SUCCESS          = $0000;
  EVENTLOG_ERROR_TYPE       = $0001;
  EVENTLOG_WARNING_TYPE     = $0002;
  EVENTLOG_INFORMATION_TYPE = $0004;

  FACILITY_NULL             = $0000; //����� ���� ��������� (���� S_OK)
  FACILITY_RPC              = $0001; //������ RPC
  FACILITY_DISPATCH         = $0002; //������ ���������� IDispatch ��� �������� ����������
  FACILITY_STORAGE          = $0003; //������ IStorage � IStream.
                                     //���� �� ��������� �� 256, ����� ��� �� �����, ��� � ���� ������ DOS
  FACILITY_ITF              = $0004; {���� ���������, ������������ ������������ ������� �����������.
                                      �������������� ����� ������ ������������ ������ ����������� �
                                      �����������. �� ����� �������, ��� ��� ���������� ��������,
                                      ������������ ������� ������������, ����� ����� ��������� �����}
  FACILITY_WIN32            = $0007; //���� ������ ������� Win32, ������������ �������� ���� HResult
  FACILITY_WINDOWS          = $0008; //�������������� ���� ������ �����������, ������������ Microsoft
  FACILITY_SECURITY         = $0009;
  FACILITY_CONTROL          = $000A;
  FACILITY_CERT             = $000B;
  FACILITY_INTERNET         = $000C;
  FACILITY_MEDIASERVER      = $000D;
  FACILITY_MSMQ             = $000E;
  FACILITY_SETUPAPI         = $000F;
  FACILITY_SCARD            = $0010;
  FACILITY_COMPLUS          = $0011;

  WM_USER                   = $0400;

  EVENTLOG_FULL_INFO        = $0000;
  EVENTLOG_SEQUENTIAL_READ  = $0001; //���������� ������ � ������� ����� ��������� ����������� ������
  EVENTLOG_SEEK_READ        = $0002; //������ ������ � ������, ������� ������ dwRecordOffset (see KB177199)
  EVENTLOG_FORWARDS_READ    = $0004; //������ ��� �� ����� ������ (������) �� ����� ��������� (old -> new) ���� ��-���������
  EVENTLOG_BACKWARDS_READ   = $0008; //������ ��� �� ����� ��������� � ����� ������ (new -> old)


  SIZE_OF_TEventLogRecord: DWORD = sizeof(TEventLogRecord);

  WM_THREAD_ERROR                = WM_USER + 1;
{$endregion}
{$region 'resourcestring'}
resourcestring
  sSistem          = 'SYSTEM';
  sNetSrv          = 'NETWORK SERVICE';
  sLocSrv          = 'LOCAL SERVICE';
  sNTAut           = 'NT AUTHORITY';
  sSecurity        = 'SECURITY';
  sSIDCacheAddErr  = 'SIDCache.Add Error!';
  sFMCacheAddErr   = 'FMCache.Add Error!';
  sSIDTypeEmptySID = '';
  ERR_NOTIFY_THREAD =
    '������ ������ �������� ����������. ��� ������ %d, �������� "%s"';

{$IFDEF RUS}
    sMsgNotFound = '�� ������� �������� ��� ������� � ����� ( %0:u ) � ��������� ( %1:s ).'+
                   ' ��������, �� ��������� ���������� ��� ������ ������ � ������� ��� '+
                   '������ DLL ��������� ��� ����������� ��������� ���������� ����������. '+
                   '� ������ ������� ���������� ��������� ����������: %2:s';

//    sSIDNotFound = 'SID �����������';
//    sSidTypeUser = 'SID ������������';
//    sSidTypeGroup = 'SID ������';
//    sSidTypeDomain = 'SID ������';
//    sSidTypeAlias = 'SID ���������� ������';
//    sSidTypeWellKnownGroup = 'SID ����������� ������';
//    sSidTypeDeletedAccount = 'SID ��������� ������';
//    sSidTypeInvalid = '�������� SID';
//    sSidTypeUnknown = '����������� ��� SID';
//    sSidTypeComputer = 'SID ����������';
//    sSidTypeLabel = '������������ SID ������ �����������';

//    sSuccess = '�����';
//    sError = '������';
//    sWarning = '��������������';
//    sInformation = '�����������';
//    sSuccess_audit = '����� �������';
//    sFailure_audit = '����� �������';
//    sUnknown = '����������� ���';

    sNotAvailable = '�/�';
    sNone = '�����������';
{$ELSE}
    sMsgNotFound = 'The description for Event ID ( %0:u ) in Source ( %1:s ) cannot '+
                    'be found. The local computer may not have the necessary '+
                    'registry information or message DLL files to display messages '+
                    'from a remote computer. The following information is part of' +
                    ' the event: %2:s';
    sSIDNotFound = 'SID not found';
    sSidTypeUser = 'User SID';
    sSidTypeGroup = 'Group SID';
    sSidTypeDomain = 'Domain SID';
    sSidTypeAlias = 'An alias SID';
    sSidTypeWellKnownGroup = 'SID for a well-known group';
    sSidTypeDeletedAccount = 'SID for a deleted account';
    sSidTypeInvalid = 'SID that is not valid';
    sSidTypeUnknown = 'SID of unknown type';
    sSidTypeComputer = 'SID for a computer';
    sSidTypeLabel = 'Mandatory integrity label SID';

    sSuccess = 'Success';
    sError = 'Error';
    sWarning = 'Warning';
    sInformation = 'Information';
    sSuccess_audit = 'Success audit';
    sFailure_audit = 'Failure audit';
    sUnknown = 'Unknown type';

    sNotAvailable = 'N/A';
    sNone =  'None';
{$ENDIF}
{$endregion}
type
    {----------------------------------------------------------
    ��������� ������������ � API �-��� GetEventLogInformation
    �� ������ LogIsFull
    -----------------------------------------------------------}
  PEVENTLOG_FULL_INFO = ^TEVENTLOG_FULL_INFO;
  TEVENTLOG_FULL_INFO = record
    dwFull : DWORD;
    end;

procedure Parse(StatusCode:Word; Count: Word; ptr: pointer); external 'CommonEvt.dll';
function dll_init(): boolean; external 'CommonEvt.dll';
procedure dll_deinit(); external 'CommonEvt.dll';


{-- ������ ������ TEventLog-----------------------}
{$region '��������� ������'}
{-- ��������� ������ --}
procedure TEventLog._PrevSIDInfoInit(var aValue: TPrevSIDInfo);
begin
  with aValue do
    begin
    _SidLength := 0;
    GetMem(_SID,SIZE_OF_SID);
    FillChar(_SID^, SIZE_OF_SID, 0);
    _UserName := '';
    _StringSID := '';
    _SIDType := 0;
    end;
end;
{
procedure TEventLog._PrevSIDInfoClear(var aValue: TPrevSIDInfo);
begin
  with aValue do
    begin
    _SidLength := 0;
    FillChar(_SID^, SIZE_OF_SID, 0);
    _UserName:='';
    _StringSID:='';
    _SIDType:=0;
    end;
end;
}
procedure TEventLog._PrevSIDInfoDeinit(var aValue: TPrevSIDInfo);
begin
  with aValue do
    begin
    _SidLength := 0;
    FillChar(_SID^, SIZE_OF_SID, 0);
    FreeMem(_SID,SIZE_OF_SID);
    _UserName:='';
    _StringSID:='';
    _SIDType:=0;
    end;
end;
function TEventLog._GetPrevSIDInfo(const aSID: PSID; var aSIDLength, aSIDType: DWORD;
                                                     var aData, aStrSID: string): boolean;
begin
  with m_PrevSIDInfo do
    begin
    Result := _EqualSid(aSID,_SID);
    if Result then //���������� �������e ���� (��� L1)
      begin
      aSIDLength := _SidLength;
      aData := copy(_UserName,1,MaxInt);
      aStrSID := copy(_StringSID,1,MaxInt);
      aSIDType := _SIDType;
      end;
    end;
end;
procedure TEventLog._SetPrevSIDInfo(const aSID: PSID; const aSIDLength, aSIDType: DWORD;
                          const aData, aStringSID: string); //throw EOSError
begin
  with m_PrevSIDInfo do //���������� ���������� �������� ����
    begin
    _SidLength := aSIDLength;
    FillChar(_SID^,SIZE_OF_SID,0);
    _CopySid(aSIDLength,_SID,aSID);
    _StringSID:=copy(aStringSID,1,MaxInt);
    _UserName:=copy(aData,1,MaxInt);
    _SIDType:=aSIDType;
    end;
end;
function TEventLog._GetDateTimeStamp(const aUnixDateTime: DWORD):TDateTime;
var
    lpTimeZoneInformation: TTimeZoneInformation;
    SystemTime: TSystemTime;
begin
    Result := EncodeDate(1970, 1, 1) + (aUnixDateTime / 86400);
    GetTimeZoneInformation(lpTimeZoneInformation);
    with SystemTime do
        begin
        DecodeDate(Result, wYear, wMonth, wDay);
        DecodeTime(Result, wHour, wMinute, wSecond, wMilliseconds);
        SystemTimeToTzSpecificLocalTime(@lpTimeZoneInformation, SystemTime, SystemTime);
        wMilliseconds := 0;
        Result := EncodeDate(wYear, wMonth, wDay) + EncodeTime(wHour, wMinute, wSecond, wMilliseconds);
        end;
end;
{
function TEventLog._GetDateTimeStamp(const aDelphiDateTime: TDateTime):dword; register;
var
    lpTimeZoneInformation: TTimeZoneInformation;
    SystemTime: TSystemTime;
    tmp: TDateTime;
begin
  GetTimeZoneInformation(lpTimeZoneInformation);
  with SystemTime do
    begin
    DecodeDateTime(aDelphiDateTime,wYear,wMonth,wDay,wHour,wMinute,wSecond,wMilliseconds);
    TzSpecificLocalTimeToSystemTime(@lpTimeZoneInformation,SystemTime,SystemTime);
    tmp := EncodeDateTime(wYear,wMonth,wDay,wHour,wMinute,wSecond,wMilliseconds);
    wMilliseconds := 0;
    end;
  Result := round((tmp - EncodeDate(1970, 1, 1)) * 86400);
end;
}

function TEventLog._GetMessage(Mode:TFormatMessageMode;
                               hModule:THandle;
                               var MsgLen:integer;
                               ParametrID:DWORD =0): string;
var
    MsgFlags, MsgID : dword;
    buffer : Pointer;
begin
{
---------------+---------------------------------------------------------+
               |             ErrorCodes (Getlasterror)                   |
---------------+--------------------+---------------+--------------------+
  dll          |  fmParseParameters | fmDescription | fmEventCategory    |
               |    %%1234          |               |                    |
---------------+--------------------+---------------+--------------------+
 MsAuditE.dll  |   317              |    0          |   0 <-������ ���-� |
 ws03res.dll   |   317              |    317        |   0                |
 xpsp2res.dll  |   317              |    317        |   0                |
 MSObjs.dll    |   0                |    317        |   0                |
---------------+--------------------+---------------+--------------------+
ErrorCode = 317 (ERROR_MR_MID_NOT_FOUND ):
The system cannot find message text for message number
0x%1 in the message file for %2.
}
    MsgFlags := {FORMAT_MESSAGE_ALLOCATE_BUFFER //����� ���������� ���������� LocalFree()
                or} FORMAT_MESSAGE_FROM_HMODULE
                or FORMAT_MESSAGE_FROM_SYSTEM;

    buffer := nil;
    case Mode of
        fmDescription: begin
              MsgFlags := MsgFlags or FORMAT_MESSAGE_ARGUMENT_ARRAY;
              buffer := m_ArgsList.list; //FStrs.List
              MsgID := m_EventID;
              end;
        fmEventCategory: begin
               MsgID := m_EventCategory;
               end;
        fmParseParameters: begin
               MsgID := ParametrID;
               end
        else
          begin
          Result := '';
          MsgLen := 0;
          exit;
          end;
    end;

    Result := headers._GetMessage(MsgFlags, pointer(hModule), MsgID, MsgLen, buffer);
end;
{$endregion}
{-------------------------------------------------}
function TEventLog.GetSIDTypeAsString: string;
const
    //sSIDNotFound = 'SID �����������';
    sSidTypeUser           = 'SID ������������';
    sSidTypeGroup          = 'SID ������';
    sSidTypeDomain         = 'SID ������';
    sSidTypeAlias          = 'SID ���������� ������';
    sSidTypeWellKnownGroup = 'SID ����������� ������';
    sSidTypeDeletedAccount = 'SID ��������� ������';
    sSidTypeInvalid        = '�������� SID';
    sSidTypeUnknown        = '����������� ��� SID';
    sSidTypeComputer       = 'SID ����������';
    sSidTypeLabel          = '������������ SID ������ �����������';
begin
    case m_SIDType of
          0:                      Result := sSIDTypeEmptySID;
          SidTypeUser:            Result := sSidTypeUser;           {=1}
          SidTypeGroup:           Result := sSidTypeGroup;          {=2}
          SidTypeDomain:          Result := sSidTypeDomain;         {=3}
          SidTypeAlias:           Result := sSidTypeAlias;          {=4}
          SidTypeWellKnownGroup:  Result := sSidTypeWellKnownGroup; {=5}
          SidTypeDeletedAccount:  Result := sSidTypeDeletedAccount; {=6}
          SidTypeInvalid:         Result := sSidTypeInvalid;        {=7}
          SidTypeUnknown:         Result := sSidTypeUnknown;        {=8}
          9:                      Result := sSidTypeComputer;       {SidTypeComputer = 9}
          10:                     Result := sSidTypeLabel;          {SidTypeLabel=10}
          else Result := sSidTypeUnknown;
    end;
end;

//function TEventLog.ContentFilter:boolean;
//var
//  buffer : string;
//begin
//    result:=true; // �� ����� ����������� ������
//    if m_NumStrings = 0 then exit;
//{$IFDEF _TVA_list}
//    case m_EventID of
//        528:  begin
//               if StrUpper(m_ArgsBuffer[0]) = sSistem then Result:=false else
//                 if StrUpper(m_ArgsBuffer[0]) = sNetSrv then Result:=false else
//                   if StrUpper(m_ArgsBuffer[0]) = sLocSrv then Result:=false;
//          end; //528
//        538:  begin
//              if m_ArgsBuffer[0] = (m_ComputerName + '$') then Result:=false else
//                if StrUpper(m_ArgsBuffer[1]) = sNTAut then Result:=false;
//        end; //538
//        540:  begin
//               if m_ArgsBuffer[0] = (m_ComputerName + '$') then Result:=false
//        end; //540
//        552:  begin
//              if strcomp(m_ArgsBuffer[6],'-') = 0 then Result:=false;
//        end; //552
//        560:  begin
//                if m_ArgsBuffer[1]<> 'File' then Result:=false
//        end; //560
//        562:  begin
//              if StrUpper(m_ArgsBuffer[0]) <> sSecurity then Result:=False;
//        end; //562
//        576:  begin
//               if StrUpper(m_ArgsBuffer[0]) = sNetSrv then Result:=false else
//                 if StrUpper(m_ArgsBuffer[0]) = sLocSrv then Result:=False else
//                   if m_ArgsBuffer[0] = (m_ComputerName + '$') then Result:=false;
//        end; //576
//    else exit
//    end; //case
//{$ELSE}
//
//    case m_EventID of
//        528:  begin
//               buffer := pwidechar(m_ArgsList[0]);
//               if UpperCase(buffer) = sSistem then Result:=false else
//                 if UpperCase(buffer) = sNetSrv then Result:=false else
//                   if UpperCase(buffer) = sLocSrv then Result:=false;
//          end; //528
//        538:  begin
//              StrIComp(); //���������� ��� ������ ��� ����� ��������.
//              if m_ArgsList[0] = (m_ComputerName + '$') then Result:=false else
//                if StrUpper(m_ArgsList[1]) = sNTAut then Result:=false;
//        end; //538
//        540:  begin
//               if m_ArgsList[0] = (m_ComputerName + '$') then Result:=false
//        end; //540
//        552:  begin
//              if strcomp(m_ArgsList[6],'-') = 0 then Result:=false;
//        end; //552
//        560:  begin
//                if m_ArgsList[1]<> 'File' then Result:=false
//        end; //560
//        562:  begin
//              if StrUpper(m_ArgsList[0]) <> sSecurity then Result:=False;
//        end; //562
//        576:  begin
//               if StrUpper(m_ArgsList[0]) = sNetSrv then Result:=false else
//                 if StrUpper(m_ArgsList[0]) = sLocSrv then Result:=False else
//                   if m_ArgsList[0] = (m_ComputerName + '$') then Result:=false;
//        end; //576
//    else exit
//    end; //case
//{$ENDIF}
//end;

function TEventLog.ArgumentsFilter(const aValue: PwideChar):boolean;
var
  i,cnt: WORD;
begin
  result:=false; // �� ����� ����������� ������
  if Strlen(aValue) = 0 then
    begin
    Result := true;
    exit;
    end;

  if (m_NumStrings <> 0) then
    begin
    i := 0; cnt := m_NumStrings-1;
    while (i <= cnt) and (not Result) do
      begin
      Result := (strcomp(m_ArgsList[i],aValue) = 0);
      inc(i);
      end;
    end;
end;

function TEventLog.DateTimeFilter(aStartDataTime, aEndDataTime: DWORD):integer;
begin
    {case fDirection of
    dForvards: Result:=_DateTimeFilterForvard(StartData,EndData);
    dBackwards: Result:=_DateTimeFilterackward(StartData,EndData);
    end; }
    Result := m_DateTimeFilter(aStartDataTime,aEndDataTime);
end;

function TEventLog.EventIDFilter(const aEventIDArray: TLongWordDynArray; aCount: DWORD; const Include:Boolean = True):boolean;
{
Result = True - ���� EventID ������ � ������� Data
Result = False - ���� EventID �� ������ � ������ Data
}
var
    i,cnt,tmp: DWORD;
begin
 { TODO : ������� ��������� ������� �� ������ ����� �� ������ ������ ���� }
  i := 0; cnt := aCount - 1;
  if (Include) then
    begin
    Result := false;
    while (i <= cnt) and (not Result) do
      begin
      tmp := _GetEventID(aEventIDArray[i]);
      Result := ((m_EventID and $FFFF) = tmp); //aEventIDArray[i];
      inc(i)
      end;
    end
  else
    begin
    Result := true;
    while (i <= cnt) and (Result) do
      begin
      tmp := _GetEventID(aEventIDArray[i]);
      Result := ((m_EventID and $FFFF) <> tmp);//aEventIDArray[i]);
      inc(i)
      end;
    end;
end;
function TEventLog.EventTypeFilter(aEventType:word):boolean;
begin
    Result := (m_EventType = aEventType) or (aEventType = EVENTLOG_AUDIT_ANY);
end;

procedure TEventLog.CallOutput;
begin
  m_MaxArgumentsCount := _max(m_MaxArgumentsCount,m_NumStrings);
end;
// =============================================================================

{$region '��������� ������ Code'}
procedure TEventLog._GetUserInfoFromSID(const aSID: PSID; var aDomainName: string;
                                        var aTypeOfSID: DWORD;
                                        const aSystemName: PWideChar = nil);
var
  lpName,lpDomain: PWideChar;
  szName, szDomain: DWORD;

  pName, pDomain : array[0..MAX_SIZE-1] of widechar;

begin
    lpName := @pName[0]; lpDomain:= @pDomain[0];
    szName := MAX_SIZE-1; szDomain := MAX_SIZE-1;

    _LookupAccountSid(aSID,lpName,lpDomain,szName,szDomain,
                        aTypeOfSID, aSystemName); //throw EOSError
    if (szDomain <> 0) and (szDomain <> MAX_SIZE-1) then
        aDomainName := format('%0:s\%1:s',[lpDomain,lpName])
    else aDomainName := lpName;
end;

procedure TEventLog._GetDataFromSID(const aSID: PSID;
                        var aDecodeData, aStrSID: string;
                        var aSIDType: DWORD; var aIsFindInCache: Boolean);
var
  dwStub: DWORD; //dwStub - ������ ��������
begin

  if _GetPrevSIDInfo(aSID,dwStub,aSIDType,aDecodeData,aStrSID) then
    begin
    aIsFindInCache := true;
    exit; //���������� � SID ���� � L1
    end;

    aIsFindInCache := False;
    if m_SIDCache.Find(aSID,aStrSID,aDecodeData,aSIDType) then //throw ESIDCacheError
        begin //���������� � SID ���� � L2
        exit
        end
    else
        begin //������� ���������� �  L2
        try
            aStrSID := _ConvertSidToStringSid(aSID);
            _GetUserInfoFromSID(aSID, aDecodeData, aSIDType); // throw ESysError
            m_SIDCache.Add(aSID, aStrSID,aDecodeData, aSIDType) //throw EMemError, ESIDCacheError
        except
            on E: ESysError do
                begin
                aDecodeData := E.GetErrorMsg;
                end;
            on E: EOSError do
                begin
                if E.ErrorCode = ERROR_NONE_MAPPED then
                    aDecodeData := aStrSID
                else aDecodeData := E.Message;
                end;
            else raise;
        end;
        end {������ ��������� � L2}
end;

function TEventLog._GetEventID(const aEventID: DWORD): DWORD;
begin

{
-----------------+-----------------+------------------+
     remote host |                 |                  |
                 | Win 2003        | Vista+           |
                 | osfPreVista     | osfVistaAndLater |
_local_host______|_________________|__________________|
                 |                 |                  |
Win 2003         |                 | aEventID + 4096  |
osfPreVista      |                 |                  |
_________________|_________________|__________________|
                 |                 |                  |
Vista+           | aEventID - 4096 |                  |
osfVistaAndLater |                 |                  |
-----------------+-----------------+------------------+

}
    Result := aEventID;
    if not m_IsLocalHost then //fIsLocalHost = false - load remote log
        begin
        with m_OSCheck do
          begin
          {start new code}
          if (_LocalHost = osfPreVista) then
              begin
              if (_RemoteHost = osfPreVista) and (aEventID > 4096) then
                Result := aEventID - 4096;
              if (_RemoteHost = osfVistaAndLater) and (aEventID < 4096) then
                Result := aEventID + 4096;
              end;
          // ====
          if (_LocalHost = osfVistaAndLater) then
              begin
              if (_RemoteHost = osfPreVista) and (aEventID > 4096) then
                Result := aEventID - 4096;
              if (_RemoteHost = osfVistaAndLater) and (aEventID < 4096) then
                Result := aEventID + 4096;
              end;
          {end new code}
          end;
        end;
end;

procedure TEventLog._ApplyParametersStringsToMessage;
const
  sPercent = '%%';
  sSID1    = '%{S-';
  sSID2    = 'S-1-';

var
    offset      : integer;
    i, cnt      : word;
    dwStub      : DWORD;
    Buffer      : string;
    DecodeData  : string;
    ID          : string;
    stub        : string;
    IsSID       : Boolean;
    SID         : PSID;
    FindInCache : Boolean;

function ReplaceParamStrings(var aBuffer: String): Boolean;
const
  PattLenPreVista: integer = 6;   // %%1234
  PattLenAfterVista: integer = 7; // %%12345
var
    Position,offset,index,i,len : integer;
    ParameterID: string;
    dwID  : DWORD;
    MsgBfr: string;

    NewStr,StrBfr: string;
    PattLen: integer;

begin

  Result := false;
  offset := 1;

  if m_IsLocalHost then
    begin
    if m_OSCheck._LocalHost = osfPreVista then PattLen := PattLenPreVista
      else PattLen := PattLenAfterVista;
    end
  else
    begin
    if m_OSCheck._RemoteHost = osfPreVista then PattLen := PattLenPreVista
      else PattLen := PattLenAfterVista;
    end;



  while (True) do
    begin
    Position := PosEx(sPercent,aBuffer,offset);
    if Position = 0 then
        break;

    Result := true; //���� ��������� ����-�� ���� ������
    { TODO : �������� ��� ���������� ����������� ������ }
    ParameterID := copy(aBuffer,Position+2, PattLen - 2);
    try
      dwID := strtoint(trim(ParameterID));
    except
        SetLength(ParameterID,length(ParameterID)-1);
        dwID := strtoint(trim(ParameterID));
    end;


    if m_FMCache.Find(dwID,MsgBfr,Len) <> RTCACHE_FIND then
      begin
      if m_Param_PrevSource <> m_SourceName then
        begin
        m_DllList.GetDLList(m_SourceName,dtParamMsgFile,m_Param_hModule,m_Param_Count);
        m_Param_PrevSource := copy(m_SourceName,1,MaxInt);
        end;

      if m_Param_Count = 0 then
        begin
        exit;
        end;
      if m_Param_Count = 1 then
        begin
        MsgBfr := _GetMessage(fmParseParameters, m_Param_hModule[0], Len, dwID);
        end
      else
        for I := 2 to m_Param_Count - 1 do {��� ���� �������� "0"}
          begin
          MsgBfr := _GetMessage(fmParseParameters, m_Param_hModule[i], Len, dwID);
          if (*(m_ErrorCode = 0) and *) (len > 0) then break
          end;

      try
        m_FMCache.Add(dwID,MsgBfr);
      except
        raise EEventLogCacheAdd.Create(sFMCacheAddErr);
      end; //try
      end; //if FMCache.Find

    if Len <> 0 then
      begin
      {��� ��������� ������ ������������� ��������� StringReplaceOpt}
      StrBfr := '';
      NewStr := aBuffer;

      if Position > 1 then
        begin
        StrBfr := StrBfr + copy(NewStr,1,Position-1) + MsgBfr;
        end
      else begin
        StrBfr := StrBfr + MsgBfr;
        end;

      index := Position + PattLen;
      NewStr := Copy(NewStr,index,MaxInt);
      StrBfr := StrBfr + NewStr;

      aBuffer := StrBfr;
      offset := Position + len;
      end
    else inc(offset,PattLen);
    end; //while (true)

end;

begin
    cnt := m_NumStrings - 1;
    for I := 0 to cnt do //���� ��������� ����������
        begin
        Buffer := pwidechar(m_ArgsList[i]);
        IsSID := false;
        if length(buffer) > 5 then
          begin
          if CompareMem(@buffer[1],@sPercent[1],4) then //%%
            begin
            if ReplaceParamStrings(Buffer) then
              begin
              StrPCopy(m_ArgsList[i], Buffer);
              Continue;
              end;
            end
          else
            begin
            if CompareMem(@buffer[1],@sSID1[1],8) then //%{S-
              begin
              offset := PosEx('}',Buffer,4);
              ID := copy(Buffer,3,offset-3);
              IsSID := true;
              end
            else
              begin
              if CompareMem(@buffer[1],@sSID2[1],8) then //S-1-
                begin
                offset := Length(Buffer);
                ID := copy(Buffer,1,offset);
                IsSID := true;
                end;
              end;
            end;

          if IsSID then
            begin
            try
              SID := nil;
              _ConvertStringSidToSid(pwidechar(ID),SID); //throw EOSError
              _GetDataFromSID(SID, DecodeData, stub, dwStub, FindInCache); //throw EMemError, ESIDCacheError
              StrPCopy(m_ArgsList[i], DecodeData);
              LocalFree(cardinal(SID));
            except
                LocalFree(cardinal(SID));
                //����� ��
            end;
            end; //if if (IsSID)
          end; // length(buffer) > 5
        end; //for I

end;

function _CompareDateTime(const A: DWORD; const B: DWORD): Integer;
begin
//  if Abs(A - B) = 0 then
  if A = B then
    Result := 0
  else if A < B then
    Result := -1
  else
    Result := 1


end;
function TEventLog._DateTimeFilterForvard(const StartData,EndData:DWORD): Integer;
begin

    Result:=0; //������ � �������� ���������
    if _CompareDateTime(m_TimeGenerated,StartData) = -1 then Result:=1;
    if _CompareDateTime(m_TimeGenerated,EndData) = 1 then Result:=-1;

end;

function TEventLog._DateTimeFilterBackward(const StartData,EndData:DWORD):integer;
begin

    Result:=0; //������ � �������� ���������
    if _CompareDateTime(m_TimeGenerated,EndData) = 1 then Result:=1;
    if _CompareDateTime(m_TimeGenerated,StartData) = -1 then Result:=-1;

end;

{$endregion}
{---- ������� ----}
{$region 'Getters'}
function TEventLog.GetDirection: TDirection;
begin
  Result := m_Direction;
end;
procedure TEventLog.SetDirection(const aDirection: TDirection);
begin

  if (aDirection <> m_Direction) then
    begin
    m_Direction := aDirection;
    case m_Direction of
        dForvards: begin
                   m_DateTimeFilter := Self._DateTimeFilterForvard;
                   m_DirectionFlag := EVENTLOG_FORWARDS_READ;
                   end;
        dBackwards: begin
                    m_DateTimeFilter := self._DateTimeFilterBackward;
                    m_DirectionFlag := EVENTLOG_BACKWARDS_READ;
                    end;
    else exit
    end;
    end;

end;

function TEventLog.GetRecordNumber: DWORD;
begin
    Result := m_RecordNumber
end;

function TEventLog.dwGetTimeGenerated: DWORD;
begin
    Result := m_TimeGenerated
end;
function TEventLog.dwGetTimeWritten: DWORD;
begin
    Result := m_TimeWritten
end;
function TEventLog.dtGetTimeGenerated: TDateTime;
begin
        with m_PrevTimeGenerated do
          begin
          if m_TimeGenerated = _UnixDateTime
                then Result := _DelphiDateTime
          else
            begin
            Result := _GetDateTimeStamp(m_TimeGenerated);
            _UnixDateTime := m_TimeGenerated;
            _DelphiDateTime := Result;
            end;
          end;
    //Result := self._GetDateTimeStamp(fTimeGenerated);
end;
function TEventLog.dtGetTimeWritten: TDateTime;
begin
        with m_PrevTimeWritten do
          begin
          if m_TimeWritten = _UnixDateTime then
            Result := _DelphiDateTime
          else
            begin
            Result := _GetDateTimeStamp(m_TimeWritten);
            _UnixDateTime := m_TimeWritten;
            _DelphiDateTime := Result;
            end;
          end;
    //Result := self._GetDateTimeStamp(fTimeWritten);
end;

function TEventLog.GetEventID: DWord;
begin
    Result := m_EventID
end;
function TEventLog.GetEventType: Word;
begin
    Result := m_EventType
end;
function TEventLog.GetEventCategory: Word;
begin
    Result := m_EventCategory
end;

function TEventLog.GetSIDLength: dword;
begin
    Result := m_UserSidLength
end;
function TEventLog.GetSourceName: String;
begin
    Result := m_SourceName
end;
function TEventLog.GetComputerName: String;
begin
    Result := m_ComputerName
end;
function TEventLog.GetStringSID:string;
begin
    Result := m_StringSID
end;

function TEventLog.GetDescription: string;
begin
    Result := m_Description
end;
function TEventLog.GetUserName: String;
begin
    Result := m_UserName
end;
function TEventLog.GetErrorCode: DWORD;
begin
    Result := m_ErrorCode
end;
    //statistics
function TEventLog.GetBytesReadCount : int64;
begin
    Result := m_ByteReadCount
end;
function TEventLog.GetMaxArgumentsCount  : WORD;
begin
    Result := m_MaxArgumentsCount
end;
function TEventLog.GetEventsReadCount: Int64;
begin
  Result := m_EventsReadCount
end;
{$endregion}
{-- ��������� ������ --}

constructor TEventLog.Create(const ServerName: string = '';
                             const Cache: TSIDCache = nil;
                              Direction: TDirection = dForvards);
begin
    inherited create;

    m_Source  := nil;
    m_src     := nil;

    m_ServerName := trim(ServerName);
    m_ServerName := AnsiupperCase(m_ServerName);

    m_Direction := Direction;
    case m_Direction of
        dForvards: begin
                   m_DateTimeFilter := Self._DateTimeFilterForvard;
                   m_DirectionFlag := EVENTLOG_FORWARDS_READ;
                   end;
        dBackwards: begin
                    m_DateTimeFilter := self._DateTimeFilterBackward;
                    m_DirectionFlag := EVENTLOG_BACKWARDS_READ;
                    end;
    end;

    m_IsLocalHost   := true; //��������� ����������
    m_RecordNumber  := 0;
    m_TimeGenerated := 0;
    m_TimeWritten   := 0;
    m_SourceName    := '';
    m_ComputerName  := '';
    m_EventID       := 0;
    m_EventType     := 0;
    m_EventCategory := 0;
    m_Description   := ''; //������� ������
    m_UserName      := '';    // domain\username
    m_StringSID     := '';   // S-1-5-...
    m_SIDType       := 0;
    m_UserSidLength := 0;
    m_ErrorCode     := 0;
    m_NumStrings    := 0;

    with m_PrevEventCategory do
      begin
      _EventCategory := 0;
      _StrEventCategory := '';
      end;

    _PrevSIDInfoInit(m_PrevSIDInfo);

    with m_PrevTimeGenerated do
      begin
      _UnixDateTime := 0;
      _DelphiDateTime := 0;
      end;

    with m_PrevTimeWritten do
      begin
      _UnixDateTime := 0;
      _DelphiDateTime := 0;
      end;

    m_dwread            := 0;
    m_dwneeded          := 0;
    m_dwBufSize         := 524287; //MSDN: max_dwBufSize=524287 bytes
    SetLastError(ERROR_SUCCESS);

    m_api               := TAPIHelper.Create;
    m_src               := m_api.AllocMem(m_dwBufSize);

    m_Source            := m_src;
    m_ByteReadCount     := 0;
    m_MaxArgumentsCount := 0;

    m_Param_Count       := high(dword) - 1;
    m_CategoryCount     := High(dword) - 1;

    m_Category_hModule  := nil;
    m_Param_hModule     := nil;
    m_ArgsList          := TVAList.Create;
{
-----------------------+-----------------+------------------------+
Operating system	     |  Version number |  My ID's               |
-----------------------+-----------------+-----+------------------+
Windows 7              |       6.1       |  61 |                  |
Windows Server 2008 R2 |	     6.1       |  61 |                  |
Windows Server 2008    |       6.0       |  60 | osfVistaAndLater |
Windows Vista          |       6.0       |  60 |                  |
-----------------------+-----------------+-----+------------------+
Windows Server 2003 R2 |       5.2       |  52 |                  |
Windows Server 2003    |       5.2       |  52 | osfPreVista      |
Windows XP             |       5.1       |  51 |                  |
-----------------------+-----------------+-----+------------------+
Windows 2000           |       5.0       |  50 | osf2000          |
-----------------------+-----------------+-----+------------------+
}
    //��������, ��� ������� ���� ������
    with m_OSCheck do
        begin
        GetNameOfLocalComputer(_LocalHostName); //�������� ��� ���������� �����
        _LocalHostName := AnsiupperCase(_LocalHostName);
        case OSCheck of // Local host
            50      : _LocalHost:=osf2000;
            51..52  : _LocalHost:=osfPreVista;
            60..61  : _LocalHost:=osfVistaAndLater
        else _LocalHost:=osfUnknown;
        end;
        if m_ServerName <> '' then //�������� ����, ��������� ��� ��������� ���� ������ �����
            begin
            if (Pos(m_ServerName,_LocalHostName) = 0) and
                    (Pos(_LocalHostName,m_ServerName) = 0) then
                begin //������ ��� �� ���������� �������
                m_IsLocalHost:=false; //��� ���� ������ ��������� ����
                case OSCheck(m_ServerName) of
                    50      : _RemoteHost:=osf2000;
                    51..52  : _RemoteHost:=osfPreVista;
                    60..61  : _RemoteHost:=osfVistaAndLater
                else _RemoteHost:=osfUnknown;
                end; {case}
                end
            end;
        end; //with

    if Assigned(Cache) then
        begin
        m_IsInternalCashe := True;
        m_SIDCache := Cache;
        end
    else
        begin
        m_IsInternalCashe := false;
        m_SIDCache := TSIDCache.Create('',''); { TODO : ����� ������ ��� ��������! }
        end;

    m_FMCache := TFMCache.Create;
    dll_parse_init := dll_init();
end;

destructor TEventLog.Destroy;
begin
    if Assigned(m_src) then
        m_api.FreeMem(m_dwBufSize, pointer(m_src));
        FreeAndNil(m_api);
    //ShowMessage('VirtualFree ok');

    if (not m_IsInternalCashe) then
        FreeAndNil(m_SIDCache);
    //ShowMessage('SID Cache ok');

    //ShowMessage('fCurrentArgsCount: ' + IntToStr(fCurrentArgsCount));

  FreeAndNil(m_ArgsList);

    m_CurrentArgsCount := 0;
    //ShowMessage('Arguments ok');

  m_NumStrings := 0;
  m_EventLogName := '';
  _PrevSIDInfoDeinit(m_PrevSIDInfo);
    //ShowMessage('fPrevSIDInfo ok');

  FreeAndNil(m_FMCache);
    //ShowMessage('FM Cache ok');

  Finalize(m_Param_hModule);
    //ShowMessage('Param_hModule ok');

  Finalize(m_Category_hModule);
    //ShowMessage('Category_hModule ok');

  if dll_parse_init then
    dll_deinit();

  FreeAndNil(m_ArgsList);

  inherited destroy;
end;

procedure TEventLog.OpenLog(const aEventLogName: string);
var
    i: Integer;
    ServerName: TStringList;
begin
    if m_api.Handle <> 0 then exit;

    m_EventLogName := aEventLogName;
    if not Assigned(m_DllList) then
      m_DllList := TDLLLoader.Create(m_EventLogName);

    try //m_api throw
    if length(m_ServerName) = 0 then
        m_api.OpenEventLog('', m_EventLogName)
    else
      begin
      ServerName := TStringList.Create;
      try
        ServerName.Delimiter     := ';';
        ServerName.DelimitedText := m_ServerName;
        m_ServerName             := '';
        for I := 0 to ServerName.Count - 1 do
          begin
          m_ServerName := ServerName.Strings[i];
          if Length(m_ServerName) <> 0 then
              m_api.OpenEventLog(m_ServerName, m_EventLogName);
          if m_api.Handle <> 0 then
              Break;
          end; {for}

      finally
        FreeAndNil(ServerName);
      end;
      end;
    except
    on E: EOSError do
        raise EEventLogError.Create(4, E.ErrorCode, '���������� ������� ������. ��������� ���������� ������.'+
                                                    #13#10 + E.Message);
    end;
    m_EventsReadCount := 0;
    m_MaxArgumentsCount := 0;

{MSDN: If you specify a custom log and it cannot be found, the event logging service
opens the Application log; however, there will be no associated message or
category string file.}
end;

procedure TEventLog.OpenLog();
begin
    if m_api.Handle <> 0 then exit;


    if length(m_ServerName) = 0 then
        m_api.OpenEventLog('', 'Security')
    else
      m_api.OpenEventLog(m_ServerName, 'Security');

    m_EventsReadCount := 0;
    m_MaxArgumentsCount := 0;

{MSDN: If you specify a custom log and it cannot be found, the event logging service
opens the Application log; however, there will be no associated message or
category string file.}
end;

procedure TEventLog.CloseLog();
begin
    if Assigned(m_DllList) then
        FreeAndNil(m_DllList);
    if m_api.Handle <> 0 then
        begin
        m_api.CloseEventLog();
        end;
end;


function TEventLog.ReadLog:boolean;
begin
    Result := m_api.ReadEventLog(m_DirectionFlag, m_src, m_dwBufSize, m_dwread, m_dwneeded);
    if not Result then
      exit;

    m_Source := m_src; //��������������� ��������� �� ������ ������
    inc(m_ByteReadCount,m_dwread);
    m_EndOfRecords := PEventLogRecord(DWORD(m_src) + m_dwread);
end;
procedure TEventLog.OpenBackupLog(const aBackupName: string);
begin
  if m_api.Handle <> 0 then exit;
    m_api.OpenBackupEventLog(m_ServerName, aBackupName);
end;
procedure TEventLog.BackupLog(const aBackupName: string);
var
  BName:PWideChar;
begin
  if m_api.Handle = 0 then
    begin
    exit;
    end;

    if aBackupName = '' then BName := nil else BName := pchar(aBackupName);
    m_api.BackupEventLog(BName);
end;

procedure TEventLog.ClearLog( const aBackupName : string = '');
var
  BName: PWideChar;
begin
  if aBackupName = '' then BName := nil else BName := pchar(aBackupName);
  m_api.ClearEventLog(BName);
end;
function TEventLog.LogIsFull: boolean;
var
  buffer : PEVENTLOG_FULL_INFO;
  bytesneded, BuffSize : DWORD;
begin
    BuffSize := sizeof(TEVENTLOG_FULL_INFO);
    getmem(buffer,BuffSize);
  try
    m_api.GetEventLogInfo(buffer, BuffSize, bytesneded);
    Result := (buffer.dwFull = 0);
  finally
    Freemem(buffer);
  end;
end;

function TEventLog.NumberOfLogRecords():DWORD;
begin
  Result := m_api.GetNumberOfEventLogRecords();
end;

function TEventLog.NumberOfOldestLogRecord(): DWORD;
begin
  Result := m_api.GetOldestEventLogRecord();
end;

procedure TEventLog.SetPtrToExtSource(aSource: Pointer);
begin
    if Assigned(aSource) then
      m_Source := PEventLogRecord(aSource)
end;

function TEventLog.GetPtrFromExtSource: pointer;
begin
  Result := Pointer(m_Source);
end;

procedure TEventLog.SetHandleOfLog(aHandle: THandle);
begin
    if aHandle <> 0 then m_api.Handle := aHandle;
end;
function TEventLog.GetHandleOfLog: THandle;
begin
  Result := m_api.Handle;
end;
procedure TEventLog.Next;
begin
  with m_Source^ do
    begin
    m_Source := PEventLogRecord(DWORD(m_Source)+Length);
    end;
end;

function TEventLog.IsNotDone:Boolean;
begin
  {$POINTERMATH ON}
  Result := (m_Source < m_EndOfRecords)
  {$POINTERMATH OFF}
end;

procedure TEventLog.DecodeBase;
var
    StrOffset : DWORD;
begin
    with m_Source^ do
        begin
        m_UserSidLength := UserSidLength;
        m_RecordNumber  := RecordNumber;
        {
        ��� ��������� ������ ���������� ������ ������ ���������� �������
        ���������� ���������� GetOldestEventLogRecord() � GetNumberOfEventLogRecords()
        }
        m_TimeGenerated := TimeGenerated;
        m_TimeWritten   := TimeWritten;

        m_EventID := EventID;  //_GetEventID(EventID);
        if EventID = 4672 then
          asm
          nop
          end;
        m_EventType     := EventType;
        m_NumStrings    := NumStrings;
        m_EventCategory := EventCategory;
        end;
    StrOffset      := dword(m_Source)+ SIZE_OF_TEventLogRecord;
    m_SourceName   := PWideChar(StrOffset);
    StrOffset      := StrOffset+dword((Length(m_SourceName)+1) shl 1);
    m_ComputerName := PWideChar(StrOffset);
    inc(m_EventsReadCount);
end;

procedure TEventLog.DecodeArg; register;
var
    i, cnt: word;
    Ptr: PWideChar;
begin
    with m_Source^ do
    begin
    if (m_NumStrings > 0) then
        begin
        m_ArgsList.Clear();
        Ptr := PWideChar(dword(m_Source)+ StringOffset);
        cnt := m_NumStrings - 1;
        for I := 0 to cnt do
          begin
          m_ArgsList.Add(Ptr);
          Ptr := Ptr + StrLen(Ptr) + 1;
          end;
        _ApplyParametersStringsToMessage;
        end; //if (m_NumStrings > 0)
    end; // with fSource^
end;

//procedure TEventLog.DecodeMsgDesc;
//var
//    alpMsgBfr : PWideChar;
//    i,cnt     : integer;
//    OnFind    : boolean;
//    ResLen    : DWORD;
//    //----------------------
//    tstlist : tstringlist;
//begin
//{
//    OnFind := false; //������ �� �������
//    i := 0;
//try
//    i := 0; cnt := fCount - 1;
//    while (i <= cnt) and (not OnFind) do
//      begin
//      if _GetMessage(fmDescription,arr_hModule[i],lpMsgBfr)<>0 then
//        begin
//        fDescription := lpMsgBfr;
//        OnFind := true; //�������� ����������
//        end;
//      inc(i);
//      end;
//
//    if not OnFind then
//       fDescription := format(sMsgNotFound,[fEventID,fsourcename,
//                                            SysErrorMessage(fErrorCode)]);
//except
//  tstlist := TStringList.Create;
//  with tstlist, self do
//    begin
//    Add('fRecordNumber '+IntToStr(fRecordNumber));
//    Add('fEventID '+IntToStr(fEventID));
//    Add('EventType '+EventTypeToStr(fEventType));
//    Add('EventCategory ' +EventCategoryToStr);
//    Add('lpMsgBfr '+lpMsgBfr);
//    Add('Description '+fDescription);
//    Add('fUserName '+fUserName);
//    Add('fStringSID '+fStringSID);
//    Add('ErrorCode '+SysErrorMessage(fErrorCode));
//    Add('List of Arguments:');
//    Add(GetArgumentsStr);
//    end;
//  tstlist.SaveToFile('errorlog.txt');
//  FreeAndNil(tstlist);
//end;
//}
//    OnFind:=false; //������ �� �������
//    cnt := m_count - 1;
//    ResLen := 0;
//    for I := 0 to cnt do
//        begin
//            try
//            alpMsgBfr := nil;
//            ResLen := _GetMessage(fmDescription,m_Arr_hModule[i], m_Description);
//            if ResLen <> 0 then
//                begin
////                m_Description:=alpMsgBfr;
////                LocalFree(cardinal(alpMsgBfr));
//                OnFind:=true; //�������� ����������
//                break;
//                end;
//            except
//  tstlist := TStringList.Create;
//  with tstlist, self do
//    begin
//    Add('fRecordNumber '+IntToStr(m_RecordNumber));
//    Add('fEventID '+IntToStr(m_EventID));
//    Add('EventType '+ GetEventTypeAsString);
//    Add('EventCategory ' +GetEventCategoryAsString);
//    Add('lpMsgBfr '+alpMsgBfr);
//    Add('Description '+m_Description);
//    Add('fUserName '+m_UserName);
//    Add('fStringSID '+m_StringSID);
//    Add('ErrorCode '+SysErrorMessage(m_ErrorCode));
//    Add('List of Arguments: ');
//    Add(GetArgumentsAsString);
//    Add('Result of _GetMessage '+IntToStr(ResLen));
//    LocalFree(cardinal(alpMsgBfr))
//    end;
//  tstlist.SaveToFile('errorlog_'+IntToStr(m_RecordNumber)+'_'
//                  +IntToStr(m_EventID)+ '.txt');
//  FreeAndNil(tstlist);
//            end;
//        end; {if}
//    if not OnFind then
//       m_Description:=format(sMsgNotFound,[m_EventID,m_SourceName,SysErrorMessage(m_ErrorCode)]);
//end;

procedure TEventLog.DecodeUserInfo;
var
  SID : PSID;
  FindInCache: Boolean;
begin
    //good known SID = 12 bytes
    //user SID = 28 bytes
    with m_Source^ do
    if m_UserSidLength > 0 then
        begin
        SID := PSID(DWORD(m_Source) + UserSidOffset);
        try
            _ValidateSID(SID); //throw EOSError
            try
                _GetDataFromSID(SID, m_UserName, m_StringSID, m_SIDType, FindInCache); //throw ESIDCacheError,ESysError,EMemError
                if (not FindInCache) then
                    _SetPrevSIDInfo(SID,m_UserSidLength,m_SIDType,m_UserName,m_StringSID);
            except
                on E: ESysError do
                    begin
                    m_UserName := E.GetErrorMsg;
                    m_StringSID := sSIDTypeEmptySID;
                    end;
                else raise;
            end;

        except
            on EOSError do // generate _ValidateSID(SID)
                begin
                m_UserName  := '';
                m_SIDType   := SidTypeInvalid;
                m_StringSID := sSIDTypeEmptySID;
                end;
            else raise;
        end; {except}
        end
    else //UserSidLength>0
      begin //� ����� ����� SID �����������
      m_UserName  := '�/�'; //sNotAvailable;
      m_SIDType   := 0;
      m_StringSID := 'SID �����������'; //sSIDNotFound;
      end; // UserSidLength>0
end;

procedure TEventLog.Clear;
//var
//    i,cnt:integer;
begin
     m_RecordNumber  := 0;
     m_TimeGenerated := 0;
     m_SourceName    := '';
     m_ComputerName  := '';
     m_EventID       := 0;
     m_EventType     := 0;
     m_EventCategory := 0;
     m_Description   := '';
     m_UserName      := '';
     m_StringSID     := '';
     m_SIDType       := 0;
     m_UserSidLength := 0;
     m_ErrorCode     := 0;
//    if (fCurrentArgsCount <> 0) and (length(ArgsBuffer) <> 0) then
//        begin
//        cnt := fCurrentArgsCount - 1;
//        for I := 0 to cnt do
//            begin
//            ZeroMemory(argsBuffer[i],4096);
//            end;
//        end;
     m_NumStrings:=0;
end;

procedure TEventLog.ClearMemory;
begin
    FillChar(m_src^,m_dwBufSize,0);
end;

function TEventLog.GetEventTypeAsString: String; // old - 0.14
const
    sSuccess       = '�����';
    sError         = '������';
    sWarning       = '��������������';
    sInformation   = '�����������';
    sSuccess_audit = '����� �������';
    sFailure_audit = '����� �������';
    sUnknown       = '����������� ���';
begin
    Case m_EventType of
        EVENTLOG_SUCCESS          : Result := sSuccess; //0
        EVENTLOG_ERROR_TYPE       : Result := sError;   //1
        EVENTLOG_WARNING_TYPE     : Result := sWarning; //2
        EVENTLOG_INFORMATION_TYPE : Result := sInformation; //4
        EVENTLOG_AUDIT_SUCCESS    : Result := sSuccess_audit; //8
        EVENTLOG_AUDIT_FAILURE    : Result := sFailure_audit; //16
    else Result := sUnknown;
 end;
end;

function TEventLog.GetArgumentsAsString: string;
const
  sDotComma1 = '";"';
  sDotComma2 = ';';
  sKav       = '"';
var
    i,count,cnt : DWORD;
    FullSize    : DWORD;
    offset      : DWORD;
    ArrOfLen    : TCardinalDynArray;
//    buf         : TStringBuilder;
begin
// 0.10/0.10
    if m_NumStrings = 0 then
        begin
        Result := '';
        exit;
        end;

//    Parse(m_EventID and $FFFF, m_NumStrings, @m_ArgsBuffer);

//------- test stringbuilder

//  try
//    try
//      buf := TStringBuilder.Create();
//      buf.Append(sKav);
//      count := m_NumStrings - 1;
//      if m_NumStrings > 1 then
//        begin
//        for i:= 0 to count - 1 do
//          begin
//          buf.Append(m_ArgsBuffer[i]);
//          buf.Append(sDotComma1);
//          end;
//        end;
//      buf.Append(m_ArgsBuffer[count]);
//      buf.Append(sKav);
//      buf.Append(sDotComma2);
//
//      Result := buf.ToString;
//    except
//    end;
//
//  finally
//    FreeAndNil(buf);
//  end;


//--------------------------
    count := m_NumStrings - 1;
    FullSize := 0;
    SetLength(ArrOfLen,m_NumStrings);

    for I := 0 to Count do
      begin
      ArrOfLen[i] := StrLen(Pwidechar(m_ArgsList[i]));
      inc(FullSize,ArrOfLen[i]);
      end;
    FullSize := FullSize + (m_NumStrings shl 1)+ m_NumStrings;
    SetLength(Result,FullSize);

    Result[1] := sKav;
    offset := 2;

  if m_NumStrings > 1 then
    begin
    cnt := count - 1;
    for I := 0 to Cnt do
      begin
      move(m_ArgsList[i]^,Result[offset],ArrOfLen[i] shl 1);
      inc(offset,ArrOfLen[i]);
      move(sDotComma1,Result[offset],6);
      inc(offset,3);
      end;
    end;
  move(m_ArgsList[count]^,Result[offset],ArrOfLen[count] shl 1);
  Result[offset+ArrOfLen[count]] := sKav;
  Result[offset+ArrOfLen[count]+1] := sDotComma2;
end;

function TEventLog.GetArgumentsCount:dword;
begin
    Result := m_NumStrings;
end;

procedure TEventLog.GetArgumentsAsArray(var Arr: Tva_list);
var
    i,cnt,Len:integer;
begin
    if m_NumStrings = 0 then
        begin
        exit;
        end;
    cnt := m_NumStrings - 1;
    for I := 0 to cnt do
      begin
      len := StrLen(pwidechar(m_ArgsList[i]))+1;
      Arr[i] := StrAlloc(Len);
      wstrcopy(Arr[i],m_ArgsList[i]);
      end;
end;
function  TEventLog.GetArgumentItem(ItemIndex: Integer): string;
begin
  Result := pwidechar(m_ArgsList[ItemIndex]);
end;
function TEventLog.GetFacility: Word;
begin // ��� �������. ��� �������� ����� ���� FACILITY_NULL
  Result := (m_EventID shr 16) and $FFF;
end;

function TEventLog.GetStatusCode: Word;
begin
  Result := m_EventID and $FFFF;
end;

function TEventLog.GetSeverity: Byte;
begin
  Result := m_EventID shr 30;
end;

function TEventLog.GetEventCategoryAsString: string;
var
    i : integer;
    res: integer;
begin
    Result := '';
    res := 0;
    if m_EventCategory = 0 then
      begin
      Result := sNone; //�����������
      exit;
      end;

    with m_PrevEventCategory do
      begin
      if (_EventCategory = m_EventCategory) then
        begin
        Result := _StrEventCategory; //copy(_StrEventCategory,1,length(_StrEventCategory));
        exit;
        end;
      end;

      if m_Category_PrevSource <> m_SourceName then
        begin
        //if category_Count = (high(dword) - 1) then
        m_DllList.GetDLList(m_SourceName,dtCatMsgFile,m_Category_hModule,m_CategoryCount);
        m_Category_PrevSource := m_SourceName
        end;

      if m_CategoryCount = 0 then
        begin
        Result := sNone; //�����������
        exit;
        end;
      if m_CategoryCount = 1 then
        Result := _GetMessage(fmEventCategory,m_Category_hModule[0], Res)
      else
        for I := 0 to m_CategoryCount - 1 do
          begin
          Result := _GetMessage(fmEventCategory, m_Category_hModule[i], Res);
          end;
     if res <> 0 then
      begin
        with m_PrevEventCategory do
          begin
          _EventCategory := m_EventCategory;
          _StrEventCategory := Result; //copy(Result,1,length(Result));
          end;
      end;
end;
end.
