unit ELRThreadUnit;

interface

uses
  Classes,windows,sysutils,Dialogs,
  Headers,EventLog,RTCache;
type
  EELRThreadError = class(Exception);
  EELRThreadCreateError = class (EELRThreadError);
  EOpenLogError = class(EELRThreadError);
  ENumberOfLogRecordsError = class(EELRThreadError);

type
    TDateTimeCache = record
    _dwDateTime: TDateTime;
    _strDate: string;
    _strTime: string;
    end;

type
  TEventLogReader = class(TEventLog)
  strict private
    fDateTimeGen,
    fDateTimeWrit: TDateTimeCache;
  public
      procedure CallOutput(); overload;
  end;

type
  TELRThread = class(TThread)
  private
    { Private declarations }
    fEventLog : TEventLogReader;
    fSourceName : string;
    fServerName : string;
    fEventTypeFilter : word;

    fEventIDArray : TLongWordDynArray;
    fEventIDCount : DWORD;

    fDataTimeFilterEnable : boolean;
    fStartData : DWORD;
    fEndData : DWORD;
    fArgument : string;

    RecordsCount : DWORD;
    fStop : boolean;
    fMainlist,fResList: TStringList;
    ErrorFlag: boolean;
    fCurrentDir : string;
  protected
    //proc's from Synchronize
    procedure NoErrorConnect;
    procedure ErrorConnect;
    procedure EventLogRecords;
    procedure ReadEventLogRecords;
    procedure GetMainList;
    procedure GetList;
    procedure EndReadEventLogRecords;
    procedure SaveBaseLog;
    procedure SaveResLog;
    procedure ResStop;

    procedure Execute; override;
  public

    constructor create(const ServerName:string = '';
                        Cashe:PSIDCache = nil;
                        Direction:TDirection = dForvards);
    destructor Destroy; override;
    procedure SetDataML(const Value : string);
    procedure SetDataRL(const Value : string);

    property CurrentDir : string write fCurrentDir;
    property Reset : boolean read fstop write fstop;
    property EventLogPtr : TEventLogReader read fEventLog;
    property SourceName : string read fSourceName write fSourceName;
    property EventTypeFilter : word read fEventTypeFilter write fEventTypeFilter;
    property EventIDArray : TLongWordDynArray read fEventIDArray write fEventIDArray;
    property EventIDCount : DWORD read fEventIDCount write fEventIDCount;
    property DataTimeFilterEnable : boolean read fDataTimeFilterEnable write fDataTimeFilterEnable;
    property StartData : DWORD read fStartData write fStartData;
    property EndData : DWORD read fEndData write fEndData;
    property Argument : string read fArgument write fArgument;
    //property
  end;

implementation
uses
    DateUtils,
    EventViewUnit,StrRepl;
const
    ResStrng: string = 'Record number: %0:7u source: %1:s Date Generated: %2:10s Time Generated: %3:8s Date Written %10:10s Time Written %11:8s Computer: %4:s Event ID: %5:4u Event type: %7:s (%6:u) Event Category: %9:s (%8:u) ;';
var
  s1, s2: string;
{==============================================================================}
procedure TEventLogReader.CallOutput();
const
  ResStrng =   '"%0:7u";"%1:s";"%2:s %3:s";"%10:s %11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';
var
  res_str: string;
  dg,tg, dw,tw: string;

  Arguments: Tva_list;
  ArgListCount:dword;
begin
  inherited;

//    ArgListCount:=GetArgumentsCount;
//    SetLength(Arguments,ArgListCount);
//    ZeroMemory(Arguments,ArgListCount*sizeof(va_list));
//    GetArgumentsAsArray(Arguments);

  // Optimization block
{$region 'Optimization TimeGenerated'}
    with fDateTimeGen do
        if CompareDateTime(dtTimeGenerated,_dwDateTime) = 0 then
            begin
            dg := _strDate;
            tg := _strTime
            end
        else
            begin
            _dwDateTime := dtTimeGenerated;
            _strDate := DateToStr(dtTimeGenerated);
            dg := _strDate;
            _strTime := TimeToStr(dtTimeGenerated);
            tg := _strTime;
            end;
{$endregion}
{$region 'Optimization TimeWritten'}
    with fDateTimeWrit do
        if CompareDateTime(dtTimeWritten,_dwDateTime) = 0 then
            begin
            dw := _strDate;
            tw := _strTime
            end
        else
            begin
            _dwDateTime := dtTimeWritten;
            _strDate := DateToStr(dtTimeWritten);
            dw := _strDate;
            _strTime := TimeToStr(dtTimeWritten);
            tw := _strTime;
            end;
{$endregion}
    res_str := format(ResStrng,
              [RecordNumber,
              SourceName,
              dg, //DateToStr(dtTimeGenerated), // default format dd.mm.yyyy  <-- dg
              tg, //TimeToStr(dtTimeGenerated), // default format  hh:mm:ss  <-- dg
              ComputerName,
              GetStatusCode, //EventID,
              EventType,
              GetEventTypeAsString,
              EventCategory,
              GetEventCategoryAsString,
              dw, //DateToStr(dtTimeWritten),  // default format dd.mm.yyyy <-- dw
              tw]); //TimeToStr(dtTimeWritten)]); // default format hh:mm:ss <-- dw

//  res_str := res_str + format(';"%0:s (%2:s)";"%3:s (Len: %4:d bytes)";%1:s',[UserName,
//              res_str1, GetSIDTypeAsString, StringSID, SIDLength]);

//  s1 := res_str + format(' ; %0:s ; %1:s ; %2:s',[Arguments[1] ,Arguments[2],Arguments[3]]); {680}
//  s2 := format('%0:s ; %1:s',[Arguments[1],Arguments[2]]);

  s1 := res_str + format(' ; %0:s ; %1:s ; %2:s',[GetArgumentItem(1),GetArgumentItem(2),GetArgumentItem(3)]); {680}
  s2 := format('%0:s ; %1:s',[GetArgumentItem(1),GetArgumentItem(2)]);

//    s1 := res_str;
//    s2 := GetArgumentItem(1)+ ' ; ' + GetArgumentItem(2);

//  SetLength(Arguments,sizeof(va_list));
//  Arguments[0]:='';
end;
{==============================================================================}    
{ELRThread}
constructor TELRThread.create(const ServerName:string = '';
                              Cashe:PSIDCache = nil;
                              Direction:TDirection = dForvards);
begin
    {инициализация}
    inherited create(true); //создание в приостановленом состоянии - избегание гонок
try
    fMainlist := TStringList.Create;
    fResList := TStringList.Create;
    fServerName := ServerName;
    fEventLog:=TEventLogReader.Create(fServerName,Cashe^,Direction); //create class
except
    raise EELRThreadCreateError.Create(fServerName+' '+IntToStr(ThreadID)+'Error create Thread');
    exit;
end;
    //конфигурирование параметров
    ErrorFlag:=false; //нет ошибок
    fStop := false;
    //EventLog.SetDirection(Direction);

    //даем автоматически уничтожиться после окончания работы
    FreeOnTerminate:=true;
end;

destructor TELRThread.Destroy;
begin
    FreeAndNil(fEventLog);
    FreeAndNil(fMainlist);
    FreeAndNil(fResList);
    fEventIDArray := nil;
    inherited;
end;
{$region 'Sync'}
procedure TELRThread.SetDataML(const Value : string);
begin
  fMainlist.Add(Value);
end;
procedure TELRThread.SetDataRL(const Value : string);
begin
  fResList.Add(Value)
end;
{-------------------------------------------------}
procedure TELRThread.NoErrorConnect;
begin
    with  Form1.Memo1.Lines  do
        begin
        Add('');
        Add(fServerName+' '+IntToStr(ThreadID)+' - Подключенеие прошло успешно');
        end;
end;
procedure TELRThread.ErrorConnect;
begin
    Form1.Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+' - Ошибка подключнеия. Поток завершает работу');
end;
procedure TELRThread.EventLogRecords;
begin
    with form1 do
        begin
        RecordsCount := fEventLog.RecordNumber;
        Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+' - Всего записей в Журнале: '+
          IntToStr(RecordsCount));
        inc(counter, RecordsCount); //передаем статистику
        end;
end;
procedure TELRThread.ReadEventLogRecords;
begin
    Form1.Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+' - Идет считывание данных...')
end;
procedure TELRThread.GetList;
begin
  EnterCriticalSection(EventViewUnit.CriticalCection2);
  try
    EventViewUnit.list.AddStrings(fResList);    
  finally
    LeaveCriticalSection(EventViewUnit.CriticalCection2);
  end;
end;
procedure TELRThread.GetMainList;
begin
  EnterCriticalSection(EventViewUnit.CriticalCection1);
  try
    EventViewUnit.MainList.AddStrings(fMainlist); //добавление строк в список к существующим
  finally
    LeaveCriticalSection(EventViewUnit.CriticalCection1);
  end;        
end;
procedure TELRThread.EndReadEventLogRecords;
begin
    with  Form1.Memo1.Lines  do
        begin
        Add('');
        Add(fServerName+' '+IntToStr(ThreadID)+'  - Считывание данных окончено')
        end;
end;
procedure TELRThread.SaveBaseLog;
begin
   Form1.Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+' - Базовый лог был успешно сохранен')
end;
procedure TELRThread.SaveResLog;
begin
   Form1.Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+'  - Данные для анализа были успешно сохранены')
end;
procedure TELRThread.ResStop;
begin
    form1.Memo1.Lines.Add(fServerName+' '+IntToStr(ThreadID)+' - Выполнение прервано')
end;
{$endregion}
{==============================================================================}
procedure TELRThread.Execute;
label
    NextRec;
var
  counter : integer;
//  s: string;
begin
    //fEventLog.OpenLog(fSourceName);
    fEventLog.OpenLog();
    if fEventLog.ErrorCode <> 0 then
        begin
        //ошибка открытия лога
        Synchronize(ErrorConnect);
        raise EOpenLogError.Create(fServerName+' '+IntToStr(ThreadID)+' - Ошибка подключнеия. Поток завершает работу');
        exit;
        end;
     Synchronize(NoErrorConnect);

    if fEventLog.NumberOfLogRecords() = 0 then
        begin
        //ошибка NumberOfLogRecords
        raise ENumberOfLogRecordsError.Create(fServerName+
        ' '+IntToStr(ThreadID)+' - Ошибка NumberOfLogRecords. Поток завершает работу');
        exit
        end;
    Synchronize(EventLogRecords);
    fStop:=false;
    //try
    while fEventLog.ReadLog and (not fStop) do
        begin
        while fEventLog.IsNotDone do
            begin
            fEventLog.Clear;
            fEventLog.DecodeBase;
            with fEventLog do
                begin
                if not EventTypeFilter(fEventTypeFilter) then
                  goto NextRec;

                if fEventIDArray[0] <> 0 then //masID[0]=0 & Length(masID)=1
                    if not EventIDFilter(fEventIDArray,fEventIDCount) then
                      goto NextRec;

                if DataTimeFilterEnable then // используем фильтр по дате+времени
                    begin
                    case DateTimeFilter(fStartData, fEndData) of
                    -1: begin
                        fStop:=true;
                        Break
                        end;
                    1: goto NextRec;
                    end; {case of}
                    end;
                end; {with eventlog do}
            {end save data to class TEventLog}

            {parse messages}
            fEventLog.DecodeArg;
            if not fEventLog.ArgumentsFilter(PWideChar(fArgument)) then
              goto NextRec;

            //PASTE CONTENT FILTER HERE
            //if not EventLog.ContentFilter then goto NextRec;

            //EventLog.DecodeUserInfo;
            //EventLog.DecodeMsgDesc;
            {--- Тут находился код, который сейчас находится в MyProcedure ---}
            fEventLog.CallOutput;
            SetDataML(s1);
            SetDataRL(s2);
            s1:=''; s2:='';
            {--- Тут находился код, который сейчас находится в MyProcedure ---}
            {parse messages}
NextRec:
            fEventLog.Next;
            sleep(0);
            end; {while IsDone do}
        end; {while ReadEventLog}
    //finally
    fEventLog.CloseLog;
    Sleep(0);
    if not ErrorFlag then
        begin
        Synchronize(EndReadEventLogRecords); //Считывание данных окончено
        counter := fMainlist.Count;
        with  fMainlist  do
            if counter <> 0 then
                begin
                SaveToFile(fCurrentDir + fServerName +'_'+ IntToStr(Handle)+'_baselog.txt',TEncoding.Unicode);
                Synchronize(SaveBaseLog); //Базовый лог был успешно сохранен
                GetMainList; //fMainlist -> EventViewUnit.MainList
                end;
        counter := fResList.Count;
        with  fResList  do
            if counter <> 0 then
                begin
                SaveToFile(fCurrentDir + fServerName +'_'+ IntToStr(Handle)+'_result.txt',TEncoding.Unicode);
                Synchronize(SaveResLog);
                GetList;     //fResList -> EventViewUnit.List
                end;
        end; {errorflag}
    //end;
end; {Execute}

end.
