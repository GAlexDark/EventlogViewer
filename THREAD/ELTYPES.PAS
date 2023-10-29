unit ELTypes;

interface
uses
    Windows,RTCache,EventLog;
type
  {управляющая структура}
  PTMR = ^TMR;
  TMR = record
    Version : string; {зарезервировано для последующих расширений версий протокола}
    //основные параметры
    ServerName : string;      //for create
    SourceName : string;
    Direction : TDirection;   //for create
    Cashe : TSIDCache;        //for create
    OutputProc : TOutputProc;

    //Далее идут настройки фильтров
    EventTypeFilter : Word;
    EventIDarr : array of Dword;
    Length : DWORD;

  end;

implementation

end.
