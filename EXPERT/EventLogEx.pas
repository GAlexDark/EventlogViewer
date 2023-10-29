unit EventLogEx;

interface

uses
    Classes, SysUtils, Registry, Windows, JwaWinType, JwaWinBase, JwaWinNT;


type
  TLogIterateDirection = (idForward, idBackward);


  EEventLogError = class(Exception);
  EInvalidLogOperation = class(EEventLogError);
  EInvalidEventLogRecord = class(EEventLogError);

  TEventLog = class;


  TDLLCache = class( TObject )
  protected
    FLibs : TStringList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure UnloadAll;
    function LoadLibrary( const Name : string; FLags : DWORD ) : HInstance;
    procedure UnloadLibrary( const Name : string );
  end;

  TEventLogRecordDecoder = class( TObject )
  protected
    FLogName : string;
    FRecPtr : PEVENTLOGRECORD;
    FDLLS : TDLLCache;
    FStrs : TList;
    FReg : TRegistry;
    procedure VerifyState;
    function GetCode: Word;
    function GetComputerName: string;
    function GetData: Pointer;
    function GetDataLength: DWORD;
    function GetEventType: Word;
    function GetFacility: Word;
    function GetGenerated: TDatetime;
    function GetNumber: DWORD;
    function GetRecLength: DWORD;
    function GetSeverity: Byte;
    function GetSourceName: string;
    function GetUserName: string;
    function GetWritten: TDatetime;
    function GetEventID: DWORD;
    procedure LoadStrings;
    function FormatEventMessage(MsgID : DWORD; const RegValueName : string): string;
    function GetCategory: string;
    function GetEventMessage: string;
  public
    constructor Create( const ALogName : string );
    destructor Destroy; override;
    procedure Reset;

    procedure GetRawData(Stream : TStream);
    procedure GetRawRecord(Stream : TStream);
    procedure ValidateRecord;

    property RecPtr : PEVENTLOGRECORD read FRecPtr write FRecPtr;
    property LogName : string read FLogName write FLogName;

    property RecLength: DWORD read GetRecLength;
    property Number : DWORD read GetNumber;
    property Generated : TDatetime read GetGenerated;
    property Written : TDatetime read GetWritten;

    property ID : DWORD read GetEventID;
    property Code : word read GetCode;
    property Facility : word read GetFacility;
    property Severity : byte read GetSeverity;

    property EventType : word read GetEventType;
    property SourceName : string read GetSourceName;
    property ComputerName : string read GetComputerName;
    property UserName : string read GetUserName;

    property EventMessage : string read GetEventMessage;
    property Category : string read GetCategory;

    property DataLength : DWORD read GetDataLength;
    property Data : pointer read GetData;
  end;

  TEventLogIterator = class( TObject )
  protected
    FCurrent : TEventLogRecordDecoder;
    FEventLog : TEventLog;
    FDirection : TLogIterateDirection;
    FBuffSize : DWORD;
    FBuffer : pointer;
    FLog : THANDLE;
    FBytesInBuffer : DWORD;
    FCurrentOffset : DWORD;
    FReadFlags : DWORD;
    FIsDone : boolean;
    FResetRequired : boolean;

    function ReadBuffer( SeekTo : DWORD; Flags : DWORD ): Boolean;
    procedure ReAllocateBuffer;
    procedure SetEventLog(const Value: TEventLog);
    function GetCurrent: TEventLogRecordDecoder;
    procedure SetDirection(const Value: TLogIterateDirection);
  public
    constructor Create( AEventLog : TEventLog; ADirection : TLogIterateDirection );
    destructor Destroy; override;

    function IsEmpty : boolean;
    procedure Reset;
    function IsDone : boolean;
    function Next : boolean;
    function Seek( Number : DWORD ) : boolean;

    property Current : TEventLogRecordDecoder read GetCurrent;
    property EventLog : TEventLog read FEventLog write SetEventLog;
    property Direction : TLogIterateDirection read FDirection write SetDirection;
  end;


  TEventLog = class( TObject )
  protected
    FLogName: string;
    FHandle : THandle;
    procedure SetLogName(const Value: string);
    function GetActive: boolean;
    procedure SetActive(const Value: boolean);
    function GetRegKey: string;
    function GetCount : DWORD;
    procedure ActiveStateRequired;
    function GetOldestRecord: DWORD;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open;
    procedure OpenBackup( const BackupName : string );
    procedure Close;
    procedure Clear( const BackupName : string = '' );
    procedure Backup( const BackupName : string );
    function CreateIterator( Direction : TLogIterateDirection=idBackward) : TEventLogIterator;

    property Active : boolean read GetActive write SetActive;
    property Count : DWORD read GetCount;
    property OldestRecord : DWORD read GetOldestRecord;
    property Handle : THandle read FHandle;
    property LogName : string read FLogName write SetLogName;
    property RegKey : string read GetRegKey;
  end;

implementation

const
  sApplication = 'Application';
  sRegEventLog = '\SYSTEM\CurrentControlSet\Services\Eventlog';
  sParameterMessageFile = 'ParameterMessageFile';
  sCategoryMessageFile = 'CategoryMessageFile';
  sEventMessageFile = 'EventMessageFile';
  sMsgNotFound = 'The description for Event ID ( %d ) in Source ( %s ) cannot '+
                 'be found. The local computer may not have the necessary '+
                 'registry information or message DLL files to display messages '+
                 'from a remote computer. The following information is part of' +
                 ' the event: %s';

  sErrCannotChangeName = 'Cannot change log name while log is open.';
  sErrLogNotOpen = 'Event log is not open';
  sErrEventLogEmpty = 'Event log is empty';
  sErrNoRecPtr = 'Record pointer is nil';
  sErrInvalidRecord = 'Invalid event log record';
  sErrInvalidIterator = 'Iterator is not attached to TEventLog instance';

function UTCToDateTime( UTC : DWORD ) : TDatetime;
type
    TimeRec = packed record
      case integer of
        0 : (FT : FILETIME);
        1 : (LL : int64);
    end;
var
   ST, ST1 : SYSTEMTIME;
   FTLocal : FILETIME;
   tr1970, trUTC : TimeRec;

begin
  with ST do
  begin
    wYear := 1970;
    wMonth := 1;
    wDay := 1;
    wHour := 0;
    wMinute := 0;
    wSecond := 0;
    wMilliseconds := 0;
  end;
  SystemTimeToFileTime( ST, tr1970.FT );
  trUTC.LL := 0;
  trUTC.FT.dwLowDateTime := UTC;
  trUTC.LL := trUTC.LL * 10000000;
  inc( trUTC.LL, tr1970.LL );
  FileTimeToLocalFileTime( trUTC.FT, FTLocal );
  FileTimeToSystemTime( FTLocal, ST1 );
  Result := SystemTimeToDateTime( Windows. SYSTEMTIME(ST1) );
end;

function WordScan( const S : string; var StartPos, WordLen : integer; Delimiters : TSysCharSet ) : boolean;
var
   i, l : integer;
begin
  Result := false;
  WordLen := 0;

  i := StartPos;
  l := length( s );
  StartPos := 0;
  while i <= l do
    if s[i] in Delimiters then
      inc(i)
    else
    begin
      StartPos := i;
      break;
    end;

  while i <= l do
    if not(s[i] in Delimiters) then
    begin
      inc(i);
      inc( WordLen );
    end else
      break;

  Result := WordLen <> 0;
end;



{ TDLLCache }

constructor TDLLCache.Create;
begin
  inherited Create;
  FLibs := TStringList.Create;
end;

destructor TDLLCache.Destroy;
begin
  UnloadAll;
  FreeAndNil( FLibs );
  inherited Destroy;
end;

function TDLLCache.LoadLibrary(const Name: string;
  Flags: DWORD): HInstance;
var
   i : integer;
begin
  Result := 0;
  if Name = '' then
    exit;
  i := FLibs.IndexOf( Name );
  if i = -1 then
  begin
    Result := LoadLibraryEx( PChar(Name), 0, FLags );
    if Result <> 0 then
    begin
      FLibs.AddObject( Name, TObject( Result ));
    end;
  end else
    Result := HInstance( FLibs.Objects[i] );
end;

procedure TDLLCache.UnloadAll;
var
   i : integer;
   H : HInstance;
begin
  for i := 0 to FLibs.Count-1 do
  begin
    H := HInstance( FLibs.Objects[i] );
    FreeLibrary( H );
  end;
  FLibs.Clear;
end;

procedure TDLLCache.UnloadLibrary(const Name: string);
var
   i : integer;
   H : HInstance;
begin
  i := FLibs.IndexOf( Name );
  if i <> -1 then
  begin
    H := HInstance( FLibs.Objects[i] );
    FLibs.Delete( i );
    FreeLibrary( H );
  end;
end;


{ TEventLog }

constructor TEventLog.Create;
begin
  inherited Create;
  FHandle := 0;
  LogName := sApplication;
end;

destructor TEventLog.Destroy;
begin
  Close;
  inherited Destroy;
end;



function TEventLog.GetRegKey: string;
begin
  Result := sRegEventLog + '\' +LogName;
end;


function TEventLog.GetActive: boolean;
begin
  Result := FHandle <> 0;
end;

procedure TEventLog.SetActive(const Value: boolean);
begin
  if Value <> Active then
    if Value then Open
    else Close;
end;


procedure TEventLog.Open;
begin
  if FHandle <> 0 then exit;
  FHandle := OpenEventLog( nil, PChar(FLogName) );
  if FHandle = 0 then
    RaiseLastWin32Error;
end;

procedure TEventLog.Close;
begin
  if FHandle <> 0 then
  begin
    if not CloseEventLog( FHandle ) then
      RaiseLastWin32Error;
    FHandle := 0;
  end;
end;



procedure TEventLog.SetLogName(const Value: string);
begin
  if FLogName <> Value then
  begin
    if Active then
      raise EInvalidLogOperation.Create( sErrCannotChangeName );
    FLogName := Value;
  end;
end;

procedure TEventLog.ActiveStateRequired;
begin
  if not Active then
    raise EInvalidLogOperation.Create( sErrLogNotOpen );
end;


procedure TEventLog.Clear(const BackupName: string);
var
   BkpNamePtr : PChar;
begin
  ActiveStateRequired;
  if BackupName = '' then BkpNamePtr := nil
    else BkpNamePtr := PChar(BackupName);
  if not ClearEventLog( FHandle, BkpNamePtr ) then
    RaiseLastWin32Error;
end;

procedure TEventLog.Backup(const BackupName: string);
var
   BkpNamePtr : PChar;
begin
  ActiveStateRequired;
  if BackupName = '' then BkpNamePtr := nil
    else BkpNamePtr := PChar(BackupName);
  if not BackupEventLog( FHandle, BkpNamePtr ) then
    RaiseLastWin32Error;

end;



function TEventLog.CreateIterator( Direction : TLogIterateDirection ): TEventLogIterator;
begin
  Result := TEventLogIterator.Create( self, Direction )
end;

function TEventLog.GetCount: DWORD;
begin
  Result := 0;
  if FHandle <> 0 then
    if not GetNumberOfEventLogRecords( FHandle, Result ) then
      RaiseLastWin32Error;
end;

function TEventLog.GetOldestRecord: DWORD;
begin
  ActiveStateRequired;
  GetOldestEventLogRecord( FHandle, Result );
end;


procedure TEventLog.OpenBackup(const BackupName: string);
var
   pName : PChar;
begin
  if FHandle <> 0 then exit;
  if BackupName = '' then
    pName := nil
  else
    pName := PChar(BackupName);
  FHandle := OpenBackupEventLog( nil, PName );
  if FHandle = 0 then
    RaiseLastWin32Error;
end;

{ TEventLogRecordDecoder }

constructor TEventLogRecordDecoder.Create( const ALogName : string );
begin
  inherited Create;
  FLogName := ALogName;
  FStrs := TList.Create;
  FDLLS := TDLLCache.Create;
  FReg := TRegistry.Create;
  FReg.RootKey := HKEY_LOCAL_MACHINE;

end;


destructor TEventLogRecordDecoder.Destroy;
begin
  FreeAndNil( FStrs );
  FreeandNil( FDLLS );
  FreeAndNil( FReg );
  inherited Destroy;
end;

procedure TEventLogRecordDecoder.Reset;
begin
  FDLLS.UnloadAll;
end;




procedure TEventLogRecordDecoder.VerifyState;
begin
  if FRecPtr = nil then
    raise EInvalidEventLogRecord.Create( sErrNoRecPtr );
end;

procedure TEventLogRecordDecoder.ValidateRecord;
var
   P : ^DWORD;
begin
  VerifyState;
  if FRecPtr.Length <> 0 then
  begin
    Cardinal(P) := Cardinal(FRecPtr) + FRecPtr.Length - 4;
    if P^ <> FRecPtr.Length then
      raise EInvalidEventLogRecord.Create( sErrInvalidRecord );
  end;
end;

function TEventLogRecordDecoder.GetCode: Word;
begin
  VerifyState;
  Result := FRecPtr.EventID and $FFFF;
end;

function TEventLogRecordDecoder.GetComputerName: string;
var
   P : PChar;
begin
  VerifyState;
  P := PChar(@(FRecPtr.DataOffset))+4;
  Result := P + StrLen(P) + 1;
end;

function TEventLogRecordDecoder.GetData: Pointer;
begin
  VerifyState;
  Cardinal(Result) := Cardinal(FRecPtr) + FRecPtr.DataOffset;
end;

function TEventLogRecordDecoder.GetDataLength: DWORD;
begin
  VerifyState;
  Result := FRecPtr.DataLength;
end;

function TEventLogRecordDecoder.GetEventType: Word;
begin
  VerifyState;
  Result := FRecPtr.EventType;
end;

function TEventLogRecordDecoder.GetFacility: Word;
begin
  VerifyState;
  Result := (FRecPtr.EventID shr 16) and $FFF;
end;

function TEventLogRecordDecoder.GetGenerated: TDatetime;
begin
  VerifyState;
  Result := UTCToDateTime( FRecPtr.TimeGenerated );
end;

function TEventLogRecordDecoder.GetNumber: DWORD;
begin
  VerifyState;
  Result := FRecPtr.RecordNumber;
end;

function TEventLogRecordDecoder.GetRecLength: DWORD;
begin
  VerifyState;
  Result := FRecPtr.Length;
end;

function TEventLogRecordDecoder.GetSeverity: Byte;
begin
  VerifyState;
  Result := (FRecPtr.EventID shr 30);
end;

function TEventLogRecordDecoder.GetSourceName: string;
begin
  VerifyState;
  Result := PChar(@(FRecPtr.DataOffset))+4;
end;

function TEventLogRecordDecoder.GetUserName: string;
var
   S : PSID;
   sAccount, sDomain : string;
   lAccount, lDomain : DWORD;
   snu : SID_NAME_USE;
begin
  VerifyState;
  Result := '';
  if FRecPtr.UserSidLength > 0 then
  begin
    S := PSID( Cardinal(FRecPtr) + FRecPtr.UserSidOffset );
    SetLength( sAccount, 70 );
    SetLength( sDomain, 70 );
    lAccount := length( sAccount );
    lDomain := length(sDomain);
    LookupAccountSid( nil, s, @sAccount[1], lAccount,
       @sDomain[1], lDomain, snu );
    Result := PChar(@sDomain[1]) + '\' + PChar(@sAccount[1]);
  end;

end;

function TEventLogRecordDecoder.GetWritten: TDatetime;
begin
  VerifyState;
  Result := UTCToDateTime( FRecPtr.TimeWritten );
end;



function TEventLogRecordDecoder.GetEventID: DWORD;
begin
  VerifyState;
  Result := FRecPtr.EventID;

end;

procedure TEventLogRecordDecoder.LoadStrings;
var
   i : integer;
   Ptr : PChar;
procedure ClearList;
begin
  FStrs.Count := 0;
  FillChar( FStrs.List^, FStrs.Capacity * Sizeof( pointer ), 0 );
end;

begin
  VerifyState;
  ClearList;
  if FRecPtr.NumStrings = 0 then exit;
  try
    Ptr := PChar(Cardinal(FRecPtr) + FRecPtr.StringOffset);
    for i := 0 to FRecPtr.NumStrings - 1 do
    begin
      FStrs.Add( Ptr );
      Ptr := Ptr + StrLen( Ptr ) + 1;
    end;
  except
    ClearList;
  end;

end;

procedure TEventLogRecordDecoder.GetRawData(Stream: TStream);
begin
  VerifyState;
  Stream.Write( FRecPtr^, RecLength );
end;

procedure TEventLogRecordDecoder.GetRawRecord(Stream: TStream);
begin
  VerifyState;
  Stream.Write( Data^, DataLength );
end;

function TEventLogRecordDecoder.FormatEventMessage(MsgID : DWORD; const 
    RegValueName : string): string;
var
   RegKey, Value, lib : string;
   StrBuff : array[0..1024] of char;
   wStart, wLen : integer;
   HDLL : THandle;
   BUFF : PChar;
begin
  Result := '';
  RegKey := Format( sRegEventLog + '\%s\%s', [ FLogName, SourceName ]);

  if FReg.OpenKey( RegKey, false ) then
  begin
    if FReg.ValueExists( RegValueName ) then
    begin

      Value := FReg.ReadString( RegValueName );
      Win32Check( ExpandEnvironmentStrings( PChar(Value), @StrBuff,
            SizeOf( StrBuff ))<>0);
      Value := PChar(@StrBuff[0]);
      wStart := 1;
      wLen := 0;
      while WordScan( Value, wStart, wLen, [';'] ) do
      begin
        lib := copy( Value, wStart, wLen );
        if lib <> '' then
        begin
          HDLL := FDLLS.LoadLibrary( lib, LOAD_LIBRARY_AS_DATAFILE );
          if HDLL <> 0 then
          begin
            try
              Buff := nil;
              if FormatMessage( FORMAT_MESSAGE_ALLOCATE_BUFFER or
                   FORMAT_MESSAGE_FROM_HMODULE or FORMAT_MESSAGE_ARGUMENT_ARRAY,
                   Pointer(HDLL), MsgID,
                   MAKELANGID( LANG_NEUTRAL, SUBLANG_DEFAULT),
                   @Buff, 0, FStrs.List ) <> 0 then
              begin
                Result := TRIM(Buff);
                LocalFree( cardinal(Buff) );
                break;
              end;
            except
              //исключения должны быть проигнорированы
            end;

          end
        end;
        inc( wStart, wLen );
      end;


    end;
    FReg.CloseKey;
  end;
end;

function TEventLogRecordDecoder.GetCategory: string;
begin
  VerifyState;
  Result := FormatEventMessage( FRecPtr.EventCategory, sCategoryMessageFile );
end;

function TEventLogRecordDecoder.GetEventMessage: string;
var
   s, tmp : string;
   n, strLen, nbrLen, {param,} wStart, wLen, ercode : integer;
   param : dword;
begin
  VerifyState;
  LoadStrings;
  Result := '';
  s := FormatEventMessage( FRecPtr.EventID, sEventMessageFile );
  if s = '' then
  begin
    //не удалось найти текст сообщения
    if FStrs.Count <> 0 then
    begin
      for n := 0 to FStrs.Count - 1 do
        s := s + PChar( FStrs[n]) + #$0D#$0A;
      Result := Format( sMsgNotFound, [ ID, SourceName, s ]);
    end;
  end else

    //поиск и подстановка параметров вида %123
    if FStrs.Count <> 0 then
    begin
      wStart := 1;
      wLen := 0;
      strLen := length(s);
      n := 1;

      while (n < strLen-1) do
      begin
        if (s[n] = '%') and (s[n+1] in ['0'..'9']) then
        begin
          tmp := '';
          Result := Result + Copy( s, wStart, wLen );
          wLen := 1;

          nbrLen := 0;
          repeat
            inc(nbrLen);
          until ( n + 1 + nbrLen > strLen ) or not (s[n+1+nbrLen] in ['0'..'9']);
          wStart := n + 1 + nbrLen;
          val( copy( s, n + 1, nbrLen ), param, ercode );
          if ercode = 0 then
            tmp := FormatEventMessage( param, sParameterMessageFile );
          if tmp <> '' then
            Result := Result + tmp
          else
            Result := Result + '%' + copy( s, n + 1, nbrLen );
          n := wStart;

        end else
        begin
          inc( wLen );
          inc( n );
        end;
      end;
      Result := Result + Copy( s, wStart, MAXINT );
    end else
      Result := s;

end;







{ TEventLogIterator }


constructor TEventLogIterator.Create( AEventLog : TEventLog;
  ADirection: TLogIterateDirection);
begin
  inherited Create;
  FResetRequired := true;
  FBuffSize := 4096;
  FCurrent := TEventLogRecordDecoder.Create( AEventLog.LogName );
  Direction := ADirection;

  EventLog := AEventLog;
end;

destructor TEventLogIterator.Destroy;
begin
  FreeAndNil( FCurrent );
  FreeMem( FBuffer );
  inherited Destroy;
end;

procedure TEventLogIterator.SetDirection(
  const Value: TLogIterateDirection);
var
   Old : TLogIterateDirection;
begin
    old := FDirection;
    FDirection := Value;

    if FDirection = idForward then
      FReadFlags := EVENTLOG_FORWARDS_READ
    else
      FReadFlags := EVENTLOG_BACKWARDS_READ;
    if (old <> Value) and (FCurrent.RecPtr <> nil) then
      Seek( FCurrent.Number );
end;




function TEventLogIterator.IsDone: boolean;
begin
  if FResetRequired then reset;
  Result := (FLog = 0) or FIsDone;
end;

function TEventLogIterator.Next: boolean;
var
   n : DWORD;
begin
  Result := false;
  if FResetRequired then reset;
  if FIsDone then exit;
  Result := true;
  if (FCurrent.RecPtr=nil) or ((FCurrentOffset + FCurrent.RecLength)>=
     FBytesInBuffer) then
  begin
    if FCurrent.RecPtr=nil then
    begin
       //первое чтение из журнала
      n := FEventLog.OldestRecord;
      if FDirection = idBackward then
        n := n + FEventLog.Count - 1;
      Result := ReadBuffer( n, FReadFlags or EVENTLOG_SEEK_READ )
    end else
      Result := ReadBuffer( 0, FReadFlags or EVENTLOG_SEQUENTIAL_READ );
    FCurrentOffset := 0;
    FIsDone := not Result;
  end else
    FCurrentOffset := FCurrentOffset + FCurrent.RecLength;
  if Result then
  begin
    FCurrent.FRecPtr := pointer(longword(FBuffer) + FCurrentOffset);
    FCurrent.ValidateRecord;
  end;
end;

function TEventLogIterator.ReadBuffer( SeekTo : DWORD; Flags : DWORD ): Boolean;
var
   MinBytesNeeded, err : DWORD;
procedure TryRead; register;
begin
  Result := ReadEventLog(FLog, Flags, SeekTo,
                FBuffer, FBuffSize, FBytesInBuffer, MinBytesNeeded );
end;


begin
  if FLog <> 0 then
  begin
    if FBuffer = nil then
      ReAllocateBuffer;
    TryRead;
    err := GetLastError;
    if not Result then
      case err of
        ERROR_INSUFFICIENT_BUFFER :
          if (MinBytesNeeded > FBuffSize) then
          begin
            FBuffSize := MinBytesNeeded;
            ReAllocateBuffer;
            TryRead;
          end;
        ERROR_HANDLE_EOF : FIsDone := true;
      else
        RaiseLastWin32Error;
      end;
  end
  else
    Result := false;
end;


function TEventLogIterator.Seek( Number : DWORD ) : boolean;
begin
  FCurrentOffset := 0;
  FBytesInBuffer := 0;
  FCurrent.RecPtr := nil;
  if FEventLog <> nil then
  begin
    FCurrent.LogName := FEventLog.LogName;
    FLog := FEventLog.Handle;
    FIsDone := FEventLog.Count = 0;
    Result := ReadBuffer( Number, FReadFlags or EVENTLOG_SEEK_READ );
    FResetRequired := false;
  end else
    Result := false;
  FIsDone := not Result;
  if Result then
  begin
    FCurrent.FRecPtr := pointer(longword(FBuffer) + FCurrentOffset);
    FCurrent.ValidateRecord;
  end;

end;


procedure TEventLogIterator.ReAllocateBuffer;
begin
  ReAllocMem( FBuffer, FBuffSize );
end;


procedure TEventLogIterator.Reset;
begin
  FCurrentOffset := 0;
  FBytesInBuffer := 0;
  FCurrent.RecPtr := nil;
  if FEventLog <> nil then
  begin
    FCurrent.LogName := FEventLog.LogName;
    FCurrent.Reset;
    FLog := FEventLog.Handle;
    FIsDone := FEventLog.Count = 0;
    FResetRequired := false;
    Next;
  end;
end;


procedure TEventLogIterator.SetEventLog(const Value: TEventLog);
begin
  if FEventLog <> Value then
  begin

    FEventLog := Value;
    FResetRequired := true;
  end;
end;

function TEventLogIterator.IsEmpty: boolean;
begin
  Result := (FEventLog = nil) or (FEventLog.Count = 0);
end;

function TEventLogIterator.GetCurrent: TEventLogRecordDecoder;
begin
  if FEventLog = nil then
    raise EEventLogError.Create( sErrInvalidIterator );
  if FResetRequired then Reset;
  if FEventLog.Count = 0 then
    raise EEventLogError.Create( sErrEventLogEmpty );
  Result := FCurrent;
end;



end.