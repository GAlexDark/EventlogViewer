unit EventViewUnit;
interface

{$Define RUS}
{$Define Ping}
{$Define IP2Name}
{$define _SQLite}

uses
  Windows, SysUtils, Classes, Graphics, Forms, Buttons, Controls,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls, Grids,
  EventLog,RTCache, Headers;

{$region 'Form Types'}
type
  TForm1 = class(TForm)
    Panel1: TPanel;
    btRead: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    btSave: TButton;
    SaveDialog1: TSaveDialog;
    Button3: TButton;
    StatusBar1: TStatusBar;
    Label2: TLabel;
    edStrID: TEdit;
    btStop: TButton;
    Label3: TLabel;
    Edit3: TEdit;
    StartDate: TDateTimePicker;
    Label4: TLabel;
    StartTime: TDateTimePicker;
    Label5: TLabel;
    EndDate: TDateTimePicker;
    EndTime: TDateTimePicker;
    CheckBox1: TCheckBox;
    CBVisible: TCheckBox;
    cbFindDubl: TCheckBox;
    StringGrid1: TStringGrid;
    cbUseUniqueID: TCheckBox;
    ComboBox1: TComboBox;
    CheckBox2: TCheckBox;
    SpeedButton1: TSpeedButton;
    procedure btReadClick(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btStopClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure SpeedButton1Click(Sender: TObject);
    procedure StringGrid1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure Init(const aServerName: string = '');
    procedure Execute(const aStartDataTime,aEndDataTime: DWORD; const aType: Word;
                        const aEventsID:TLongWordDynArray; const aEventsIDCount: DWORD;
                        var volume: Int64; const Include: Boolean;
                        const aCache:TSIDCache = nil);
    procedure DeInit();

  private
    { Private declarations }

  public
    { Public declarations }
  end;

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
    procedure CallOutput; overload;
    constructor Create(const ServerName: string = '';
                       const Cache:TSIDCache = nil; Direction: TDirection = dForvards);

  end;
{$endregion}

  var
    Form1: TForm1;
    list, MainList: TStringList;

    fStop:boolean;
    OldTitle:string;

    Mode:word;
    EventLog : TEventLogReader;
    SIDCache : TSIDCache;

    ConnStr, DB_DllPath, pluginPath: string; // Конфигурирование подключения к БД

implementation
uses
    //UDebugMemoryLeak,
    StrUtils, ActiveX,DateUtils,
    NetworkAPI,StrRepl, DsUtils;

{$R *.dfm}

 {$region 'resourcestring'}
resourcestring
//  ResStrng =   '"%0:7u";"%1:s";"%2:s %3:s";"%10:s %11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';
{$IFDEF RUS}
  sFixedRowText = '"№ записи";"Источник";"Дата/Время генерации";"Дата/Время записи";"Компьютер";"Код события";"Тип события";"Категория события";"Пользователь (Тип SID)";"SID";"Аргументы[0..N]"';

  sErrorOpenLog = 'Невозможно открыть журнал. Программа остановила работу.';
  sErrorKod = ' (код ';

  sErrorNumLog = 'Не удается получить кол-во записей. Программа остановила работу.';

  sDBFileNotFind = 'Файл базы данных не найден' + #13#10 + 'Программа завершает работу';
  sErrorLoadDB = 'Ошибка чтения базы данны';
  sErrorSaveDB = 'Ошибка сохранения базы данных';
  sLoadCnt = 'Из базы загружено %0:u записей';
  sReadCnt = 'В базу было добавлено %0:u новых записей.';
  sReady = 'Готов';
{$ELSE}
  sFixedRowText = '"Record number";"Source";"Date/Time Generated";"Date/Time Written";"Computer";"Event ID";"Event type";"Event Category";"Domain\UserName (SID Type)";"SID";"Arguments[0..N]"';

  sErrorOpenLog = 'Can not open log. The program stopped working.';
  sErrorKod = ' (code ';

  sErrorNumLog = 'Unable to get count of records. The program stopped working.';
{$ENDIF}
{$endregion}


{-- Вспомогательные функции-----------------------}
procedure AutoSizeGridColumn(Grid : TStringGrid; column : integer);
var
  i : integer;
  temp : integer;
  max, count : integer;
begin
  max := 0;
  with Grid do
    begin
    count := RowCount;
    for i := 0 to (Count - 1) do
        begin
        temp := Canvas.TextWidth(cells[column, i]);
        if temp > max then max := temp;
        end;
    ColWidths[column] := Max + GridLineWidth + 12; //3;
    end; {with}
end;

procedure SorGrid(Grid : TStringGrid; column : integer);
//сортировка по столбцу - column.
var
  i, j: Integer;
  lTmpStr: string;
begin
  for i := 1 to Grid.RowCount - 1 do
      begin
      for j := i + 1 to Grid.RowCount - 1 do
          if Grid.Cells[column, i] > Grid.Cells[column, j] then
              begin
              lTmpStr := Grid.Cells[column, i];
              Grid.Cells[column, i] := Grid.Cells[column, j];
              Grid.Cells[column, j] := lTmpStr;
              end;
      end;
end;

function GetDateTimeStamp(const aDelphiDateTime: TDateTime):dword; register;
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

{-------------------------------------------------}
procedure TForm1.Init(const aServerName: string = '');
var
    dwEventLogRecords: DWORD;
    _evtlogname: string;
begin
    EventLog := TEventLogReader.Create(aServerName, SIDCache); //Создаем класс для работы с Логами

    EventLog.Direction := dForvards; //направление чтения (СТАРЫЙ -> НОВЫЙ)
    StatusBar1.Panels[1].Text := 'Ожидание считывания данных...';

    _evtlogname := 'Security'; //Security | Application | System

    StatusBar1.Panels[1].Text:='Открытие журнала...';
    EventLog.OpenLog(_evtlogname);

    Application.ProcessMessages;

    dwEventLogRecords := EventLog.NumberOfLogRecords();

    Application.ProcessMessages;

    with StatusBar1 do
        begin
        Panels[0].Text:='Записей в Журнале: '+IntToStr(dwEventLogRecords);
        Panels[1].Text:='Идет считывание данных...';
        end;
    Application.ProcessMessages;
end;

procedure TForm1.Execute(const aStartDataTime,aEndDataTime: DWORD; const aType: Word;
                        const aEventsID:TLongWordDynArray; const aEventsIDCount: DWORD;
                        var volume: Int64; const Include: Boolean;
                        const aCache:TSIDCache = nil);
label NextRec;
var

    RecordCount:dword;
//    UniqueIDHash:TStringList;
begin
    RecordCount:=0;

//    if cbUseUniqueID.Checked then
//        begin
//        UniqueIDHash:=TStringList.Create;
//        UniqueIDHash.Clear;
//        UniqueIDHash.Sorted:=true;
//        end;

  with EventLog do
    begin
    while ReadLog and (not fStop) do
      begin
      volume := BytesReadCount;  //range check error! volume - DWORD;
      while IsNotDone do
        begin
        Clear;
        DecodeBase;
        inc(RecordCount);
        if (RecordCount mod 1000)=0 then
             StatusBar1.Panels[2].Text:='Обработано записей: '+IntToStr(RecordCount);
        Application.ProcessMessages;

        if not EventTypeFilter(aType) then
            goto NextRec;

        if Assigned(aEventsID) then
          begin
          if not EventIDFilter(aEventsID,aEventsIDCount,Include) then goto NextRec;
          end;

//        if cbUseUniqueID.Checked then
//          begin
//          UniqueIDstr:=format('%0:d_%1:d',[eventid,EventType]);
//          if UniqueIDHash.Find(UniqueIDstr,index) then
//            begin
//            goto NextRec;
//            end
//          else
//            begin
//            UniqueIDHash.Add(UniqueIDstr);
//            end;
//          end;

        if CheckBox1.Checked then // используем фильтр по дате+времени
          begin
          case DateTimeFilter(aStartDataTime,aEndDataTime) of // <--
            -1: begin
                  fStop:=true;
                  Break
                  end;
            1: goto NextRec;
              end; {case of}
          end;


        {parse messages}
        DecodeArg;
        if not ArgumentsFilter(PWideChar(trim(Edit3.Text))) then //поле для ввода поиска значений аргументов
            goto NextRec;

        //PASTE CONTENT FILTER HERE
        //if not ContentFilter then goto NextRec;

        DecodeUserInfo;
        //DecodeMsgDesc;

        CallOutput;
        {parse messages}
NextRec:
        Next;
        end; {while IsDone do}
      end; {while ReadEventLog}

//{TEST Fast Direction switch}
//    Direction := dBackwards;
//    if btRead.Tag = 0 then
//      begin
//      btRead.Tag := btRead.Tag +1;
//      CloseLog;
//      OpenLog('Security');
//      goto NewIter;
//      end;
    end; {with eventlog do}
end;

procedure TForm1.Deinit();
begin
    EventLog.CloseLog;
    StatusBar1.Panels[1].Text := 'Close Log';
    if Assigned(EventLog) then
      FreeAndNil(EventLog);
    StatusBar1.Panels[1].Text := 'Free EventLog';
//    FreeAndNil(UniqueIDHash);
    StatusBar1.Panels[1].Text := 'Free Uniqui ID Hash';

    StatusBar1.Panels[1].Text:='Идет обработка...';
    Application.ProcessMessages;
end;
{$region 'Clicks Events'}
constructor TEventLogReader.Create(const ServerName: string = '';
                       const Cache:TSIDCache = nil; Direction: TDirection = dForvards);
begin
    inherited Create(ServerName,Cache,Direction);
    fDateTimeGen._dwDateTime  := 0;
    fDateTimeGen._strDate     := '';
    fDateTimeGen._strTime     := '';
    fDateTimeWrit._dwDateTime := 0;
    fDateTimeWrit._strDate    := '';
    fDateTimeWrit._strTime    := '';

end;

procedure TEventLogReader.CallOutput;
const
    ResStrng =   '"%0:7u";"%1:s";"%2:s %3:s";"%10:s %11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';
var
  dg,tg, dw,tw: string;
  buf: TStringBuilder;
begin
  inherited;
  // Optimization block
{$region 'Optimization TimeGenerated'}
    with fDateTimeGen do
        begin
        if CompareDateTime(dtTimeGenerated,_dwDateTime) <> 0 then
            begin
            _dwDateTime := dtTimeGenerated;
            _strDate    := DateToStr(dtTimeGenerated);
            _strTime    := TimeToStr(dtTimeGenerated);
            end;
        dg := _strDate;
        tg := _strTime;

//        if CompareDateTime(dtTimeGenerated,_dwDateTime) = 0 then
//            begin
////            dg := _strDate;
////            tg := _strTime
//            end
//        else
//            begin
//            _dwDateTime := dtTimeGenerated;
//            _strDate := DateToStr(dtTimeGenerated);
//            //dg := _strDate;
//            _strTime := TimeToStr(dtTimeGenerated);
//            //tg := _strTime;
//            end;
        end;
{$endregion}
{$region 'Optimization TimeWritten'}
    with fDateTimeWrit do
        begin
        if CompareDateTime(dtTimeWritten,_dwDateTime) <> 0 then
            begin
            _dwDateTime := dtTimeWritten;
            _strDate    := DateToStr(dtTimeWritten);
            _strTime    := TimeToStr(dtTimeWritten);
            end;
        dw := _strDate;
        tw := _strTime;

//        if CompareDateTime(dtTimeWritten,_dwDateTime) = 0 then
//            begin
//            dw := _strDate;
//            tw := _strTime
//            end
//        else
//            begin
//            _dwDateTime := dtTimeWritten;
//            _strDate := DateToStr(dtTimeWritten);
//            dw := _strDate;
//            _strTime := TimeToStr(dtTimeWritten);
//            tw := _strTime;
//            end;
        end;
{$endregion}
//    s:=format(ResStrng,
//              [RecordNumber,
//              SourceName,
//              dg, //DateToStr(dtTimeGenerated), // default format dd.mm.yyyy  <-- dg
//              tg, //TimeToStr(dtTimeGenerated), // default format  hh:mm:ss  <-- dg
//              ComputerName,
//              GetStatusCode, //EventID,
//              EventType,
//              GetEventTypeAsString,
//              EventCategory,
//              GetEventCategoryAsString,
//              dw, //DateToStr(dtTimeWritten),  // default format dd.mm.yyyy <-- dw
//              tw]); //TimeToStr(dtTimeWritten)]); // default format hh:mm:ss <-- dw

//  s1 := GetArgumentsAsString;
//  if Pos(#$D,s1) >0  then
//    s1 := StringReplaceOpt(s1,#$D#$A,'',[rfReplaceAll]);
//  if pos(#9,s1) > 0 then
//    s1 := StringReplaceOpt(s1,#9#9#9,', ',[rfReplaceAll]);

//  s:=s+format(';"%0:s (%2:s)";"%3:s (Len: %4:d bytes)";%1:s',[UserName,
//              s1, GetSIDTypeAsString, StringSID, SIDLength]);

try
    buf := TStringBuilder.Create;
    buf.AppendFormat(ResStrng,
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


    buf.AppendFormat(';"%0:s (%2:s)";"%3:s (Len: %4:d bytes)";%1:s',[UserName,
              GetArgumentsAsString, GetSIDTypeAsString, StringSID, SIDLength]);
    buf.Replace(#$D#$A, ',');
    buf.Replace(#9#9#9, '');

    try
        MainList.Add(buf.ToString);
    except
      on E:EOutOfMemory do
        begin
        ShowMessage('Недостаточно памяти для StringList' + #13#10 +
                    'Кол-во строк - ' + IntToStr(MainList.Count)+ #13#10 +
                    'Обьем - ' + IntToStr(MainList.Capacity));
        raise;
        end
      else
        begin
          raise;
        end;
    end;

finally
  FreeAndNil(buf);
end;
end;


procedure TForm1.btReadClick(Sender: TObject);
label
    NextRec,NewIter;
var
    {global variables for work with EventLog f-ons}
    masID : TLongWordDynArray;
    masIDCount: Integer;
    MaxArgumentsCount: Word;
    value:word;
    strID:string;
    StartDataTime,EndDataTime:DWORD;
    i, cnt :integer;
    //{ServerName,} IPAddress : AnsiString;
    servername: string;

    //UniqueIDHash:TStringList;  // <--
    //UniqueIDstr:string;
    //index:integer;
    //echo:longint;
    wHour, wMinute, wSecond, wMilliseconds:word;
    //ErrorCode: integer;
    {--------------------}
    //worktime
    Nachalo,Conetc : TTime;
    objem : int64;
    vremja : int64;
    H,M,S,MS : word;
    res : real ;
    pos_del, len: Integer;
    lan: CNetHelper;
    msg: string;

procedure NormalzationStrData(var aStr: string; const aChr: Char; const CharSet: TSysCharSet);
var
    i: Integer;
begin
    for I := 1 to length(aStr) do
        if not CharInSet(aStr[i], CharSet)  then
            begin
            aStr[i]:= aChr;
            end;
    aStr:=trim(aStr);
end;
{ - процедуру NormalzationSrvName можно заменить на
    NormalzationStrData(var aStr: string; const aChr: Char; const CharSet: TSysCharSet) - }

//procedure NormalzationSrvName(var aStr: string; const aChr: Char);
//var
//    i: Integer;
//begin
//    for I := 1 to length(aStr) do
//        if not CharInSet(aStr[i],[',',';'])  then
//            begin
//            aStr[i]:= aChr;
//            end;
//    aStr:=trim(aStr);
//end;
procedure StrToArray(const aSource: string; var Count: Integer; var Mas: TLongWordDynArray);
var
    Position,offset,k:integer;
    tmp:string;
begin
    k:=0;
    Position:=Pos(' ',aSource);
    offset:=1; Count:=0;
    if Position>0 then
        begin
        while Position>0 do
            begin
            tmp := copy(aSource,offset,Position-offset);
            Mas[k] := StrToInt(tmp);
            inc(k);
            inc(Count);
            offset := Position+1;
            Position := PosEx(' ',aSource,offset);
            end; //while Position>0
        tmp := copy(aSource,offset,length(aSource)-offset+1);
        Mas[k] := StrToInt(tmp);
        inc(Count);
        end //if Position>0
    else //Position=0 - tolko edinichnoe znachenie
        begin
        SetLength(Mas,1);
        Mas[k] := StrToInt(aSource);
        Count := 1
        end;
end;
begin
    fStop := false;
    btRead.Enabled := false;
    Mode := 0;
    value := EVENTLOG_AUDIT_ANY;

    if CheckBox1.Checked then //если используем фильтр по дата+время
        begin
        DecodeTime(StartTime.Time, wHour, wMinute, wSecond, wMilliseconds);
        StartDataTime := GetDateTimeStamp(int(StartDate.Date)+EncodeTime(wHour, wMinute, wSecond,0));
        DecodeTime(EndTime.Time, wHour, wMinute, wSecond, wMilliseconds);
        EndDataTime := GetDateTimeStamp(int(EndDate.Date)+EncodeTime(wHour, wMinute, wSecond,0));
        end;

    case ComboBox1.ItemIndex of
      -1: value:=EVENTLOG_AUDIT_ANY; {еcли не был выбран тип}
       0: value:=EVENTLOG_AUDIT_ANY;
       1: value:=EVENTLOG_AUDIT_SUCCESS;
       2: value:=EVENTLOG_AUDIT_FAILURE;
    end;

  MainList.Clear;

  StatusBar1.Panels[1].Text := 'Считывание исходных данных...';

    strID := Trim(edStrID.Text);
    masIDCount := 0;
    if length(strID) <> 0 then
        begin
        NormalzationStrData(strID,' ', ['0'..'9']);

        for I := 1 to length(strID) do
            if strID[i] = ' ' then inc(masIDCount);
        inc(masIDCount);

        SetLength(masID, masIDCount);
        StrToArray(strID, masIDCount, masID);
        end;

  Form1.Caption := Edit1.Text;
  StatusBar1.Panels[1].Text := 'Проверка доступности сервера...';

    //проверка имени хоста (наличия прямой и обратной записи) (преобразование alias в netbios-имя хоста)
    lan := CNetHelper.Create;
    try {finally}
      try {except}
        lan.HostName := Trim(Edit1.Text);
        if Length(lan.HostName) = 0 then
          lan.GetNameOfLocalComputer();
        lan.GetIPFromName();

        StatusBar1.Panels[1].Text := IntToStr(lan.Ping(msg));
        lan.GetNameFromIP();

      except
        on E:Exception do
          ShowMessage(format('Ошибка проверки сетевой доступности: %0:s ', [E.Message]));
      end;
    finally
      ServerName := lan.HostName;
      FreeAndNil(lan);
    end;



    pos_del := Pos(';', ServerName);
    if pos_del <> 0 then
        begin
        len := Length(ServerName);
        if  pos_del = len then
            SetLength(ServerName, Length(ServerName)-1)
        else
            SetLength(servername,pos_del-1);
        end;
    Edit1.Text := ServerName; //string(ServerName);
    try
        try
          Init(ServerName);
          objem := 0;
          Nachalo := Now;
          Execute(StartDataTime, EndDataTime,
                  value, masID,masIDCount, objem, CheckBox2.Checked, SIDCache);
          //throw:
        except on E: Exception do
            ShowMessage(E.Message);
        end;

    finally
        Conetc := now;
        btRead.Enabled := true;
        MaxArgumentsCount := EventLog.MaxArgumentsCount;
        DeInit();
    end;

    StatusBar1.Panels[1].Text := 'MaxArgumentsCount';
    if MaxArgumentsCount > 0 then
        dec(MaxArgumentsCount);

    if (CBVisible.Checked) {and (MaxArgumentsCount > 0)} then //включить визуализацию
        with StringGrid1 do
          begin
          Visible:=false;
          try
          RowCount:=MainList.Count+1;

          ColCount := 11 + MaxArgumentsCount;

          cnt := MainList.Count;
          for I := 1 to cnt do
            with Rows[i] do
                begin
                BeginUpdate;
                try
                  Delimiter:=';';
                  QuoteChar:='"';
                  DelimitedText:=MainList.Strings[i-1];
                finally
                  EndUpdate;
                end;
                end;
          for I := 0 to ColCount - 1 do
            begin
            Rows[i].BeginUpdate;
            try
            AutoSizeGridColumn(StringGrid1, i);
            finally
              Rows[i].EndUpdate;
            end;
            end;
          finally
            Visible:=true;
          end;
          end;

    StatusBar1.Panels[1].Text := 'End of load';
    Application.ProcessMessages;


    Conetc := Conetc - Nachalo;
    decodetime(Conetc,H,M,S,MS);
    vremja := S + 60*M + 3600*H;
    try
    if (vremja <> 0) then
        begin
        res := (objem * 8) / vremja;
        res := res / (1024*1024);
        end
    else res := 0;
    except
      res := 0;
    end;

    with StatusBar1 do
        begin
        Panels[0].Text:='Считано строк: '+IntToStr(MainList.Count);
        Panels[1].Text:='Не сохранено';
        //Panels[2].Text:='Обработано записей: '+IntToStr(RecordCount) + ' из '+ IntToStr(dwEventLogRecords);
        Panels[2].Text := 'Средняя скорость передачи: '+ FloatToStrF(res,ffFixed,8,3) + ' Mб/с';
        end;
    Form1.Caption:=Form1.Caption+' - Считано';
    OldTitle:=Application.Title;
    Application.Title:='Считано';
    btRead.Enabled:=true;
end;

procedure TForm1.btSaveClick(Sender: TObject);
var
    i,count,cnt:integer;
    s, FN:string;
    myFile : TextFile;
begin
    try
    SaveDialog1.FileName:=Edit1.Text;
    if SaveDialog1.Execute then
        begin
        FN := SaveDialog1.FileName + '_baselog.txt';
        if FileExists(FN) then
            DeleteFile(FN);

        AssignFile(myFile, FN);
        ReWrite(myFile);
        Writeln(myFile, sFixedRowText);

        if CBVisible.Checked then //включена визуализация
            begin
            MainList.Clear;
            with StringGrid1 do
                begin
                count:=RowCount;
                cnt := Count - 1;
                for I := 1 to cnt do
                    begin
                    //s:='';
                    with Rows[i] do
                        begin
                        Delimiter:=';';
                        QuoteChar:='"';
                        s:=DelimitedText;
                        end;
                    s := StringReplaceOpt(s,#$D#$A,'<CR>',[rfReplaceAll]);
                    s := StringReplaceOpt(s,#9#9#9,'<T>',[rfReplaceAll]);
                    Writeln(myFile, s);
                    end;
                end;
            end
        else
            begin //выключена визуализация
            count:=MainList.Count;
            cnt := Count - 1;
            for I := 0 to cnt do
                    begin
                    //s:='';
                    s:=MainList.Strings[i];
                    s := StringReplaceOpt(s,#$D#$A,'<CR>',[rfReplaceAll]);
                    s := StringReplaceOpt(s,#9#9#9,'<T>',[rfReplaceAll]);
                    Writeln(myFile, s);
                    end;
            end;
            StatusBar1.Panels[1].Text:='Cохранено';
            Application.Title:='Cохранено';
            end;
    finally
      CloseFile(myFile);
      MainList.Clear;
    end;

end;

procedure TForm1.Button3Click(Sender: TObject);
var
    tmplist:TStringList;
    i,j,len,count:integer;
    s:string;
    FindDotComma:integer;
begin
    Mode:=1;
    Button3.Enabled:=false;
    StatusBar1.Panels[1].Text:='Идет анализ';

    tmplist:=TStringList.Create;
try
    if cbFindDubl.Checked then tmplist.Duplicates:=dupAccept
    else tmplist.Duplicates:=dupIgnore;
    tmplist.Sorted:=true;

    FindDotComma:=0;
    count:=List.Count - 1;
    for i:=0 to count do
        begin
        s:=list.Strings[i];
        s:=trim(s);
        len:=length(s);
        //find ';'
        for j:=1 to len do
            begin
            if s[j]=widechar(';') then
                begin
                FindDotComma:=j;
                break
                end
            end;
        // find '.' & '?'
        inc(FindDotComma);
        for j := FindDotComma to len do
            begin
            if s[j]=widechar('.') then
                begin
                delete(s,j,length(s));
                break
                end;
            end;
        len:=Length(s);
        for j := FindDotComma to len do
            begin
            if S[j]=widechar('?') then
                begin
                delete(s,j,length(s))
                end;
            end;
        Application.ProcessMessages;
        list.Strings[i]:=s
        end;

    tmplist.Assign(list);
    list.Clear;
    list.Assign(tmplist);
finally
    FreeAndNil(tmplist);
end;

    Application.ProcessMessages;

    with StatusBar1 do
        begin
        Panels[1].Text:='Не сохранено';
        end;
    Application.ProcessMessages;

    if SaveDialog1.Execute then
        begin
        list.SaveToFile(SaveDialog1.FileName+'_result.txt',TEncoding.Unicode);
        StatusBar1.Panels[1].Text:='Cохранено';
        end;
    Button3.Enabled:=true;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
var
  Picker: IDsObjectPicker;
  DatObj: IDataObject;
  Buffer: string;
begin
//инициализируем COM+
  if Succeeded(CoInitialize(nil)) then
  try
// создаем Picker как объект COM+
    if Succeeded(CoCreateInstance(CLSID_DsObjectPicker, nil,
      CLSCTX_INPROC_SERVER, IID_IDsObjectPicker, Picker)) then
    try
//если инициализация Picker успешна вызываем сам диалог
      if Succeeded(InitObjectPicker(Picker)) then
        case Picker.InvokeDialog(Self.Handle, DatObj) of
          S_OK:
            try
//вызов диалога
              ProcessSelectedObjects(DatObj,Buffer);
            finally
//освобождаем DatObj
              DatObj := nil;
            end;
          S_FALSE:
            ShowMessage('Ничего не выбрано');
        end;
    finally
      Picker := nil;
    end;
  finally
    CoUninitialize;
  end;
  Edit3.Text := Buffer
end;

procedure TForm1.btStopClick(Sender: TObject);
begin
    fStop:=true;
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
    if CheckBox1.Checked then
        begin
        StartDate.Enabled :=true;
        StartTime.Enabled:=true;
        EndDate.Enabled:=true;
        EndTime.Enabled:=true
        end
    else
        begin
        StartDate.Enabled :=false;
        StartTime.Enabled:=false;
        EndDate.Enabled:=false;
        EndTime.Enabled:=false
        end;
end;
{$endregion}

{$region 'Form Events'}
procedure TForm1.FormActivate(Sender: TObject);
var
    i,cnt:integer;
    count: DWORD;
    BDB_path, sql_path: string;
begin
    fStop:=false;
    StartDate.Date := Date;
    EndDate.Date := Date;

    StartTime.Time := Time;
    EndTime.Time := Time;

    MainList:=TStringList.Create;
    list:=TStringList.Create;
    with StringGrid1 do
        begin
        with Rows[0] do
            begin
            Delimiter:=';';
            QuoteChar:='"';
            DelimitedText := sFixedRowText;
            end;
        DefaultRowHeight := abs(StringGrid1.Font.Height)+6; //высота строки
        cnt := ColCount - 1;
        for I := 0 to cnt do
                AutoSizeGridColumn(StringGrid1, i);
        end;

    saveDialog1.InitialDir := GetCurrentDir;
    Application.ProcessMessages;

    { TODO : Глобальные настройки доступа в БД }
//        DB_DllPath := 'E:\PROJECTS\Codegear Rad Studio\EVENTLOG\EventView\EXPERT\';
//
//{$ifdef _SQLite}
//        ConnStr := 'QSQLITE;E:\PROJECTS\Codegear Rad Studio\EVENTLOG\EventView\EXPERT\' + cDBName;
//        pluginPath := 'D:\Program files\PROJECTS\Codegear Rad Studio\Projects\EVENTLOG\EventView\EXPERT\qsqlite4.dll';
//{$else}
//        ConnStr := 'QODBC;DRIVER={SQL Native Client};SERVER=GALEXPC\SQLEXPRESS;DATABASE=SIDS;Trusted_Connection=Yes;';
//        pluginPath := 'E:\PROJECTS\Codegear Rad Studio\EVENTLOG\EventView\EXPERT\qsqlodbc4.dll';
//{$endif}

    DB_DllPath := GetCurrentDir + '\'; // <--боевые пути
//{$ifdef _SQLite}
    ConnStr := 'QSQLITE;' + DB_DllPath + cDBName;
    pluginPath := GetCurrentDir + '\qsqlite4.dll'; // <--боевые пути
//    pluginPath := DB_DllPath + 'qsqlite4.dll';
//{$else}
//    ConnStr := 'QODBC;DRIVER={SQL Native Client};SERVER=GALEXPC\SQLEXPRESS;DATABASE=SIDS;Trusted_Connection=Yes;';
//    pluginPath := GetCurrentDir + '\qsqlodbc4.dll';
//{$endif}
    try
      BDB_path := DB_DllPath + cBDB_DllName;
      //BDB_path := 'E:\PROJECTS\Visual Studio 2008\EvtLogBDB\Static Debug\' + cBDB_DllName;
      sql_path := DB_DllPath + cDB_DllName;
      SIDCache:=TSIDCache.Create(BDB_path, // Berkeley DB
                                 sql_path);
      SIDCache.Init(ConnStr, pluginPath);
      SIDCache.LoadFromDB(count);
    except
      on E: Exception do
        begin
        MainList.Free;
        list.Free;
        ShowMessage('Внутрення ошибка программы:' + #13#10 + E.Message + #13#10 + E.InnerException.Message);
        Application.Terminate;
        end;
    end;
    StatusBar1.Panels[0].Text := format(sLoadCnt,[count]);
    StatusBar1.Panels[1].Text := sReady;

    Application.ProcessMessages;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
var
  count: DWORD;

begin
try
    SIDCache.SaveToDB(count);
    if count > 0 then
      begin
      ShowMessage(format(sReadCnt,[count]));
      end;
except
    ShowMessage(sErrorSaveDB);
end;
  if Assigned(SIDCache) then
    FreeAndNil(SIDCache);
  if Assigned(MainList) then
    FreeAndNil(MainList);
  if Assigned(list) then
    FreeAndNil(list);

end;
{$endregion}

procedure TForm1.StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
    S:String;
begin
    with StringGrid1 do
        begin
        if (ARow > 0) and ((ARow and $1) = 0) then
            begin
            //if (ARow and $1 = 0) then
                //begin
                S := Cells[ACol, ARow];
                with Canvas do
                    begin
                    Pen.Color := clGray;
                    //
                    Brush.Color := clSkyBlue;
                    FillRect(Rect);
                    //
                    //Font.Style := [];
                    //TextRect(Rect, Rect.Left+2, rect.Top+2, S);
                    TextOut(Rect.Left+2, rect.Top+2, s);
                    end;
                //end
            end;
        end;
end;


procedure TForm1.StringGrid1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Buffer: string;
  i:integer;
  _Row, _Column: Integer;

function CopyStringToClipboard(Value: string): boolean; //GetForegroundWindow
var
  hData: HGlobal;
  pData: pointer;
  Len: integer;
  str: widestring;
begin
  Result := True;
  str:=WideString(Value);
  if OpenClipboard(GetForegroundWindow) then
    begin
    try
      Len := (Length(Value) shl 1) + 2;
      hData := GlobalAlloc(GMEM_MOVEABLE or GMEM_DDESHARE, Len);
      try
        pData := GlobalLock(hData);
        try
          Move(PChar(str)^, pData^, Len);
          EmptyClipboard;
          SetClipboardData(CF_UNICODEText, hData);
      finally
        GlobalUnlock(hData);
      end;
      except
      GlobalFree(hData);
      raise
      end;
    finally
      CloseClipboard;
    end;
    end
  else
  Result := False;
end;
procedure SelectRow( StringGrid: TStringGrid; RowNumber: integer );
var
  NewSel: TGridRect;
begin
   with StringGrid do
   begin
      if ( RowNumber > FixedRows-1 ) and ( RowNumber < RowCount ) then
      begin
         NewSel.Left := FixedCols;
         NewSel.Top  := RowNumber;
         NewSel.Right  := ColCount - 1;
         NewSel.Bottom := RowNumber;
         Selection     := NewSel;
      end;
   end;
end;

begin
        // row - строка
        //column - столбец
//    if Button = mbLeft then //левая  - сортировка
//        begin
//        StringGrid1.MouseToCell(X,Y,_Column,_Row);
//        if (_Row = 0) then
//            begin
//            form1.StatusBar1.Panels[1].Text := 'Начало сортировки';
//            SorGrid(StringGrid1,_Column);
//            form1.StatusBar1.Panels[1].Text := 'Отсортировано';
//            end;
//        end;
    if Button = mbRight then //правая - в буффер обмена
        begin
        with StringGrid1 do
            begin
            MouseToCell(X,Y,_column,_Row);
            if (_Row > 0) then
                begin
                SelectRow(StringGrid1,_Row);
                for i := Selection.Left to Selection.Right do
                    begin
                    Buffer := Buffer + Cells[i,Row] + #13#10;
                    end;
                Buffer := trim(Buffer);
                if Length(Buffer) <> 0 then
                    CopyStringToClipboard(Buffer);
                end;
            end;
        end;
end;

initialization
  ReportMemoryLeaksOnShutdown := True;

end.
