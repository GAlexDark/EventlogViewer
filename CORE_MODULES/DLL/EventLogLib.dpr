library EventLogLib;


uses
  EventLog in '..\EventLog.pas',
  RTCache in '..\RTCache.pas',
  networkAPI in '..\networkAPI.pas',
  StrRepl in '..\StrRepl.pas';

{$R *.res}
function GetEventLogInterface(const aServerName: WideString = '';
                              aCache: TSIDCache = nil;
                              aDirection: TDirection = dForvards): IEventLog; stdcall;
begin
  Result := TEventLog.Create(string(aServerName), aCache, aDirection);
end;
exports
  GetEventLogInterface;
begin
end.
