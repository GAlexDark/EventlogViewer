unit SupportUnit;

interface
uses
    Registry,windows;

function UnixDateTimeToDelphiDateTime(const UnixDateTime: LongInt):TDateTime;
function PosOfChar(const Ch: Char; const S: String): Integer;
function BMSearch(StartPos: Integer; const S, P: string): Integer;
function EventTypeToStr(EventType: Word): String;
function GetRegValue(ARootKey: HKEY; AKey, Value: String): String;
function UnixToDateTime(const AValue: Int64): TDateTime;

implementation
uses
    sysutils,ELRThreadUnit,ELTypes;

function PosOfChar(const Ch: Char; const S: String): Integer;
var
    i: Integer;
begin
    Result := 0;
    for i := 1 to Length(S) do
        if S[i] = Ch then
            begin
            Result := i;
            Exit;
            end;
end;

function BMSearch(StartPos: Integer; const S, P: string): Integer;
type
  TBMTable = array[0..255] of Integer;
var
  Pos, lp, i: Integer;
  BMT: TBMTable;
begin

  for i := 0 to 255 do
    BMT[i] := Length(P);
  for i := Length(P) downto 1 do
    if BMT[Byte(P[i])] = Length(P) then
      BMT[Byte(P[i])] := Length(P) - i;

  lp := Length(P);
  Pos := StartPos + lp - 1;
  while Pos <= Length(S) do
    if P[lp] <> S[Pos] then
      Pos := Pos + BMT[Byte(S[Pos])]
    else if lp = 1 then
    begin
      Result := Pos;
      Exit;
    end
    else
      for i := lp - 1 downto 1 do
        if P[i] <> S[Pos - lp + i] then
        begin
          Inc(Pos);
          Break;
        end
        else if i = 1 then
        begin
          Result := Pos - lp + 1;
          Exit;
        end;
  Result := 0;
end;

function EventTypeToStr(EventType: Word): String;
begin
 Case EventType of
  EVENTLOG_SUCCESS          : Result := 'Success';
  EVENTLOG_ERROR_TYPE       : Result := 'Error';
  EVENTLOG_WARNING_TYPE     : Result := 'Warning';
  EVENTLOG_INFORMATION_TYPE : Result := 'Information';
  EVENTLOG_AUDIT_SUCCESS    : Result := 'Success audit';
  EVENTLOG_AUDIT_FAILURE    : Result := 'Failure audit';
  else Result := 'Unknown';
 end;
end;

function UnixDateTimeToDelphiDateTime(const UnixDateTime: LongInt):TDateTime;
var
    lpTimeZoneInformation: TTimeZoneInformation;
    SystemTime: TSystemTime;
begin
    Result := EncodeDate(1970, 1, 1) + (UnixDateTime / 86400);
    GetTimeZoneInformation(lpTimeZoneInformation);
    with SystemTime do
        begin
        DecodeDate(Result, wYear, wMonth, wDay);
        DecodeTime(Result, wHour, wMinute, wSecond, wMilliseconds);
        SystemTimeToTzSpecificLocalTime(@lpTimeZoneInformation, SystemTime, SystemTime);
        Result := EncodeDate(wYear, wMonth, wDay) + EncodeTime(wHour, wMinute, wSecond, wMilliseconds);
        end;
end;

function UnixToDateTime(const AValue: Int64): TDateTime;
begin
  Result := AValue / SecsPerDay + UnixDateDelta;
end;

function GetRegValue(ARootKey: HKEY; AKey, Value: String): String;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create;
   try
    with Reg do
     begin
      RootKey := ARootKey;
      OpenKey(AKey, False);
      Result := ReadString(Value);
     end;
   finally
    Reg.Free;
   end;
end;

end.
