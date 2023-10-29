unit MPUnit;

interface
uses classes,windows;

type
  TProc = reference to procedure(Arg: String);
  procedure ParallelFor(nMin, nMax, nThreads: Integer; aProc: TProc);

implementation
uses
  SyncObjs;

type
TParallel = class(TThread)
private
  FProc: TProc;
protected
  procedure Execute; override;
  function GetNextValue: Integer;
public
  constructor Create;
  destructor Destroy; override;
  property Proc: TProc
  read FProc write FProc;
class var
  CurrPos: Integer;
  MaxPos: Integer;
  cs: TCriticalSection;
  ThCount: Integer;
end;

//=============================================================================
function GetCPUCount: integer;
var
  lpSystemInfo: TSystemInfo;
  CPUCount : DWORD;
begin
  GetSystemInfo(lpSystemInfo);
  Result := lpSystemInfo.dwNumberOfProcessors;
end;
//=============================================================================
procedure TParallel.Execute;
var
  nCurrent: Integer;
begin
  nCurrent := GetNextValue;
while nCurrent <= MaxPos do
  begin
  Proc ();
  nCurrent := GetNextValue;
  end;
end;

function TParallel.GetNextValue: Integer;
begin
  cs.Acquire;
  try
    Result := CurrPos;
    Inc(CurrPos);
  finally
    cs.Release;
  end;
end;
//=============================================================================
procedure ParallelFor (nMin, nMax, nThreads: Integer; aProc: TProc);
var
  threads: array of TParallel;
  I: Integer;
begin
  // inizialize TParallel class data
  TParallel.CurrPos := nMin;
  TParallel.MaxPos := nMax;
  TParallel.cs := TCriticalSection.Create;
  TParallel.ThCount := 0;
  // create the threads
  SetLength (threads, nThreads * 2);
  for I := 0 to Length (threads) - 1 do
    begin
    threads[I] := TParallel.Create; // suspended
    threads[I].Proc := aProc;
    threads[I].Resume;
    end;
while TParallel.ThCount > 0 do
    begin
    Sleep (100);
    end;
end;
end.
