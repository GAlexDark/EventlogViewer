unit logwriter;

interface
uses
    sysutils, windows;
const
    FULL_MAXSIZE_FAT = $80000000;


type
    TLogDest = (LD_NullLog, LD_EvtLog, LD_FileLog, LD_SysLog);
    {
    NullLog - заглушка. ог никуда не пишется
    EvtLog  - данные пушутся в лог Винды
    FileLog - данные пушутся в файл
    SysLog  - на развитие - данные пушутся в сислог
    }
    TLogMode = (LM_LOCAL, LM_REMOTE); //using from windows logs only!
    TEvtCategory = (LC_NONE, LC_INF, LC_WRN, LC_ERR, LC_CRI, LC_DBG);

{
public - доступны всем
protected - потомкам и текущему модулю
private - текущему модулю
strict protected - потомкам
strict private - никому
}

 TLogWriter = class
 strict private
    m_logname: string;
    m_logmode: TLogMode;
    m_logdest: TLogDest;
    m_IsOpem: Boolean;
  private
    {---- Getters/Setters ----}
    function GetLogName(): string;
    function GetLogMode(): TLogMode;
    function GetLogDest(): TLogDest;

    procedure SetLogName(const Logname: string);
    procedure SetLogMode(logmode: TLogMode);
    procedure SetLogDest(logdest: TLogDest);

 public
//   constructor Create; override;
//   destructor Destroy; override;
    procedure Openlog(); virtual; abstract;
    procedure CloseLog(); virtual; abstract;

    property LogName: string read GetLogName write SetLogName;
    property LogMode: TLogMode read GetLogMode write SetLogMode;
    property LogDest: TLogDest read GetLogDest write SetLogDest;

 end;







implementation

function TLogWriter.GetLogName(): string;
begin
    Result := m_logname;
end;
function TLogWriter.GetLogMode(): TLogMode;
begin
  Result := m_logmode;
end;
function TLogWriter.GetLogDest(): TLogDest;
begin
  Result := m_logdest;
end;
procedure TLogWriter.SetLogName(const Logname: string);
begin
    m_logname := Logname;  //todo: insert throw
end;
procedure TLogWriter.SetLogMode(logmode: TLogMode);
begin
    m_logmode := logmode;
end;
end.
