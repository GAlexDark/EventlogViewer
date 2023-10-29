{$IFDEF PROFILE} {$O-} {$WARNINGS OFF} {$ENDIF }
{$IFDEF PROFILE} {    Do not delete previous line(s) !!! } {$ENDIF }
{$IFDEF PROFILE} { Otherwise sources can not be cleaned !!! } {$ENDIF }
unit EventViewUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, Registry, ComCtrls, Grids, //standart
  EventLog{$IFNDEF PROFILE};{$ELSE}{},Profint;{$ENDIF}                                                //My

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
    Edit2: TEdit;
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
    Label6: TLabel;
    Edit4: TEdit;
    CBVisible: TCheckBox;
    cbFindDubl: TCheckBox;
    StringGrid1: TStringGrid;
    cbUseUniqueID: TCheckBox;
    procedure btReadClick(Sender: TObject);
    procedure btSaveClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure btStopClick(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

  var
    Form1: TForm1;
    list,MainList:TStringList;

    fStop:boolean;
    OldTitle:string;

    Mode:word;

implementation

{$R *.dfm}
const
    //ResStrng:string =   '"%0:7u";"%1:s";"%2:s";"%3:s";"%10:s";"%11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';
    ResStrng:string =   '"%0:7u";"%1:s";"%2:s %3:s";"%10:s %11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';


{-- Вспомогательные функции-----------------------}

procedure AutoSizeGridColumn(Grid : TStringGrid; column : integer);
var
  i : integer;
  temp : integer;
  max,count : integer;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(102); try;{$ENDIF}
  max := 0;
  with Grid do
    begin
    count:=RowCount;
    for i := 0 to (Count - 1) do
        begin
        temp := Canvas.TextWidth(cells[column, i]);
        if temp > max then max := temp;
        end;
    ColWidths[column] := Max + GridLineWidth + 6; //3;
    end; {with}
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(102); end; {$ENDIF}
end;

function ReplaceStr(const S, Srch, Replace: string): string;
{замена подстроки в строке}
var
 I:Integer;
 Source:string;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(103); try;{$ENDIF}
    if Length(Srch) > Length(s) then
        begin
        Result:=S;
        exit
        end;
    Source:= S;
    Result:= '';
    repeat
    I:=Pos(Srch, Source);
    if I > 0 then
        begin
        Result:=Result+Copy(Source,1,I-1)+Replace;
        Source:=Copy(Source,I+Length(Srch),MaxInt);
        end
    else Result:=Result+Source;
    until I<=0;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(103); end; {$ENDIF}
end;

{-------------------------------------------------}

procedure TForm1.btReadClick(Sender: TObject);
label
    NextRec;
var
    {global variables for work with EventLog f-ons}
    h:Thandle;
    p:Pointer;
    dwread, dwneeded,dwBufSize:dword;

    dwEventLogRecords,ID,RecordCount:dword;
    src:Pointer;
    EventLog:TEventLog;
    s,hErrorCode:string;
    StartDataTime,EndDataTime:TDateTime;
    ErrorCode:dword;
    field,i:integer;

    UniqueIDHash:TStringList;
    UniqueIDstr:string;
    index:integer;

function OpenLog(const ServerName:string; const SourceName:string; var ErrorCode:DWORD):THandle;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(104); try;{$ENDIF}
    if h<>0 then
        begin
        ErrorCode:=0;
        Result:=0;
        exit;
        end;
    if length(ServerName)=0 then
        Result:=OpenEventLogW(nil,PWideChar(SourceName))
    else Result:=OpenEventLogW(PWideChar(ServerName),PWideChar(SourceName));
    ErrorCode:=GetLastError;

{MSDN: If you specify a custom log and it cannot be found, the event logging service
opens the Application log; however, there will be no associated message or
category string file.}
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(104); end; {$ENDIF}
end;

function ReadLog(var ErrorCode:DWORD):boolean; register;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(105); try;{$ENDIF}
    Result:=ReadEventLogW(h, EVENTLOG_FORWARDS_READ or EVENTLOG_SEQUENTIAL_READ, 0, p,dwBufSize, dwread, dwneeded);
    ErrorCode:=GetLastError;
    if ErrorCode=ERROR_HANDLE_EOF then h:=0; //достигнут конец файла (EOF), лог был закрыт ф-цией
                               //ErrorCode=0 все нормaльно
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(105); end; {$ENDIF}
end;

function NumberOfLogRecords(var NumberOfEventLogRecords:DWORD; var ErrorCode:DWORD): boolean;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(106); try;{$ENDIF}
    Result:=GetNumberOfEventLogRecords(h,NumberOfEventLogRecords);
    ErrorCode:=GetLastError
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(106); end; {$ENDIF}
end;

function NumberOfOldestLogRecord(var OldestRecord:DWORD; var ErrorCode:DWORD): Boolean;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(107); try;{$ENDIF}
    Result:=GetOldestEventLogRecord(h,OldestRecord);
    ErrorCode:=GetLastError
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(107); end; {$ENDIF}
end;

function CloseLog(var ErrorCode:DWORD): boolean;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(108); try;{$ENDIF}
    Result:=true;
    if h<>0 then
        begin
        Result:=CloseEventLog(h);
        ErrorCode:=GetLastError;
        h:=0;
        end;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(108); end; {$ENDIF}
end;

begin
{$IFDEF PROFILE}try; Profint.PomoEnter(109); try;{$ENDIF}

    btRead.Enabled:=false;
    Mode:=0;
    dwread:=0; dwneeded:=0;
    h:=0;

    if CheckBox1.Checked then //если используем фильтр по дата+время
        begin
        StartDataTime:=int(StartDate.Date)+frac(StartTime.Time);
        EndDataTime:=int(EndDate.Date)+frac(EndTime.Time);
        end;
  MainList.Clear;
  //list.Clear;

  StatusBar1.Panels[1].Text:='Ожидание считывания данных';
  try
    ID:=StrToInt(Trim(Edit2.Text));
  except
    ShowMessage('Не введен номер кода (ID)');
    btRead.Enabled:=true;
    exit
  end;

  if Edit3.GetTextLen=0 then
        begin
        ShowMessage('Не введен код ошибки');
        btRead.Enabled:=true;
        exit
        end
    else hErrorCode:='0x'+trim(Edit3.Text);

  if Edit4.GetTextLen =0 then
        begin
        ShowMessage('Не введен номер поля');
        btRead.Enabled:=true;
        exit
        end
    else field:=StrToInt(trim(Edit4.Text));

  Form1.Caption:=Edit1.Text;


    h:=OpenLog(trim(Edit1.Text),'Security',ErrorCode);
    if h=0 then
        begin
        ShowMessage('Невозможно открыть журнал. Программа остановила работу.'+
        #13#10 + SysErrorMessage(ErrorCode)+' (код '+IntToStr(ErrorCode)+')');
        btRead.Enabled:=true;
        exit;
        end;

    Application.ProcessMessages;

    if not NumberOfLogRecords(dwEventLogRecords,ErrorCode) then
        begin
        ShowMessage('Не удается получить кол-во записей. Программа остановила работу.'
        + #13#10 + SysErrorMessage(ErrorCode)+' (код '+IntToStr(ErrorCode)+')');
        CloseLog(ErrorCode);
        btRead.Enabled:=true;
        exit
        end;
    //Memo1.Lines.Add('GetNumberOfEventLogRecords - '+SysErrorMessage(ErrorCode)+' (код '+IntToStr(ErrorCode)+')');

    Application.ProcessMessages;

    with StatusBar1 do
        begin
        Panels[0].Text:='Записей в Журнале: '+IntToStr(dwEventLogRecords);
        Panels[1].Text:='Идет считывание данных';
        end;
    Application.ProcessMessages;

    dwBufSize:=524287; RecordCount:=0; //MSDN: max_dwBufSize=524287 bytes
    s:='';
    P:=VirtualAlloc(nil,dwBufSize,MEM_COMMIT,PAGE_READWRITE);
    src:=p; //сохраняем указатель на начало памяти

    EventLog:=TEventLog.Create;
    if cbUseUniqueID.Checked then
        begin
        UniqueIDHash:=TStringList.Create;
        UniqueIDHash.Clear;
        UniqueIDHash.Sorted:=true;
        end;
try
    while ReadLog(ErrorCode) and (not fStop) do
    //while EventLog.ReadLog and (not fStop) do
        begin
        //b:=p;
        EventLog.GetPtr(p);
        while (dwread>0) do
        //while EventLog.IsDone do
            begin
            //b:=p;
            {start save data to class TEventLog}
            EventLog.Clear;
            EventLog.DecodeBase;
            inc(RecordCount);
            with EventLog do
                begin
                if (RecordCount mod 1000)=0 then StatusBar1.Panels[2].Text:='Обработано записей: '+IntToStr(RecordCount);


                //if EventType<>EVENTLOG_AUDIT_FAILURE then goto nextRec;

                if ID<>0 then
                    begin
                    if EventID<>ID then goto NextRec;
                    end;
                if cbUseUniqueID.Checked then
                    begin
                    UniqueIDstr:=format('%0:d_%1:d',[eventid,EventType]);
                    if UniqueIDHash.Find(UniqueIDstr,index) then
                        begin
                        goto NextRec;
                        end
                    else
                        begin
                        UniqueIDHash.Add(UniqueIDstr);
                        end;
                    end;

                if CheckBox1.Checked then // используем фильтр по дате+времени
                    begin
                    if (TimeGenerated < StartDataTime) then goto NextRec;
                    if (TimeGenerated > EndDataTime) then
                        begin
                        fStop:=true;
                        Break
                        end;
                    end;
                end; {with eventlog do}
            {end save data to class TEventLog}

            {parse messages}
            EventLog.DecodeArg;
            {with eventlog do
                begin
                if hErrorCode<>'0x0' then //в поле "код ошибки" введено '0'
                    if (string(argsBuffer[field])<>hErrorCode) then //Имя пользователя верное, пароль неверный (default)
                        if (string(argsBuffer[field])<>'0xC0000064') then //Имя пользователя не существует
                            if (string(argsBuffer[field])<>'0xC0000234') then //Пользователь в данное время заблокирован
                                if (string(argsBuffer[field])<>'0xC0000072') then //Учетная запись в данное время заблокирована
                        begin
                        s:='';
                        goto NextRec
                        end;
                end; }
            //EventLog.DecodeMsgDesc;
            EventLog.DecodeUserInfo;
            with eventlog do
                    begin
                    s:=format(ResStrng,
                    [RecordNumber,
                     SourceName,
                     DateToStr(TimeGenerated),
                     TimeToStr(TimeGenerated),
                     ComputerName,
                     EventID,
                     EventType,
                     EventTypeToStr(EventType),
                     EventCategory,
                     EventCategoryToStr,
                     DateToStr(TimeWritten),
                     TimeToStr(TimeWritten)]);

                    MainList.Add(s+format(';"%0:s (%2:s)";"%3:s (Len: %4:d bytes)";%1:s',[UserName,GetArgumentsStr,SIDType,StringSID,SIDLength]));
                    //MainList.Add(Description);
                    //list.Add(format('%0:s ; %1:s',[argsBuffer[1],argsBuffer[2]]));
                    end; {with eventlog}
            s:='';
            Application.ProcessMessages;
            {parse messages}
NextRec:
            //dwread:=dwread-b^.Length;
            //p:=pointer(dword(p)+b^.Length);
            dec(dwread,EventLog.GetLength); //<--paste in metod Next
            EventLog.Next;
            Application.ProcessMessages;
            end; {while dwread>0 do}
        p:=src; //восстанавливаем указатель на начало памяти

        ZeroMemory(p, dwBufSize);
        Application.ProcessMessages;
        end; {while ReadEventLog}

    //Memo1.Lines.Add('ReadEventLog - '+SysErrorMessage(ErrorCode)+' (код '+IntToStr(ErrorCode)+')');
    Application.ProcessMessages;
finally
    CloseLog(ErrorCode);
    //Memo1.Lines.Add('CloseEventLog - '+SysErrorMessage(ErrorCode)+' (код '+IntToStr(ErrorCode)+')');
    VirtualFree(P,dwBufSize,MEM_RELEASE);
    EventLog.Free;
    UniqueIDHash.Free;

    StatusBar1.Panels[1].Text:='Идет обработка';
    Application.ProcessMessages;
    if CBVisible.Checked then //включить визуализацию
        begin
        StringGrid1.Visible:=false;
        StringGrid1.RowCount:=MainList.Count+1;
        for I := 1 to MainList.Count do
            with StringGrid1.Rows[i] do
                begin
                Delimiter:=';';
                QuoteChar:='"';
                DelimitedText:=MainList.Strings[i-1];
                Application.ProcessMessages;
                end;
        for I := 0 to StringGrid1.ColCount - 1 do
            begin
            AutoSizeGridColumn(StringGrid1, i);
            end;
        StringGrid1.Visible:=true;
        end;
    Application.ProcessMessages;
    with StatusBar1 do
        begin
        Panels[0].Text:='Считано строк: '+IntToStr(MainList.Count);
        Panels[1].Text:='Не сохранено';
        Panels[2].Text:='Обработано записей: '+IntToStr(RecordCount) + ' из '+ IntToStr(dwEventLogRecords);
        end;
    Form1.Caption:=Form1.Caption+' - Считано';
    OldTitle:=Application.Title;
    Application.Title:='Считано';
    btRead.Enabled:=true;
end; {try EventLog}
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(109); end; {$ENDIF}
end;

procedure TForm1.btSaveClick(Sender: TObject);
var
    i,count:integer;
    s:string;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(110); try;{$ENDIF}
    SaveDialog1.FileName:=Edit1.Text;
    if SaveDialog1.Execute then
        begin
        if CBVisible.Checked then //включена визуализация
            begin
            MainList.Clear;
            with StringGrid1 do
                begin
                count:=RowCount;
                for I := 0 to Count - 1 do
                    begin
                    s:='';
                    with Rows[i] do
                        begin
                        Delimiter:=';';
                        QuoteChar:='"';
                        s:=DelimitedText;
                        end;
                    MainList.Add(ReplaceStr(s,#$D#$A#9#9#9,' ~ '));
                    end;
                end;
            end
        else
            begin //выключена визуализация
            count:=MainList.Count;
            for I := 0 to Count - 1 do
                    begin
                    MainList.Strings[i]:=ReplaceStr(MainList.Strings[i],#$D#$A#9#9#9,' ~ ');
                    end;
            MainList.Insert(0,'"Record number";"Source";"Date Generated";"Time Generated";"Date Written";"Time Written";"Computer";"Event ID";"Event type";"Event Category";"Domain\UserName (SID Type)";"SID";"Arguments[0..N]"');
            end;
        with MainList do
            begin
            Delimiter:=';';
            QuoteChar:='"';
            SaveToFile(SaveDialog1.FileName+'_baselog.txt',TEncoding.Unicode);
            end;
            end;

        StatusBar1.Panels[1].Text:='Cохранено';
    Application.Title:='Cохранено';
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(110); end; {$ENDIF}
end;

procedure TForm1.Button3Click(Sender: TObject);
var
    tmplist:TStringList;
    i,j,len,count:integer;
    s:string;
    FindDotComma:integer;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(111); try;{$ENDIF}
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
    tmplist.Free;
end;


    //Memo1.Clear;
    //Memo1.Lines.Assign(list);
    Application.ProcessMessages;

    with StatusBar1 do
        begin
        //Panels[0].Text:='Результат: '+IntToStr(Memo1.Lines.Count)+' строк';
        Panels[1].Text:='Не сохранено';
        end;
    Application.ProcessMessages;

    if SaveDialog1.Execute then
        begin
        list.SaveToFile(SaveDialog1.FileName+'_result.txt',TEncoding.Unicode);
        StatusBar1.Panels[1].Text:='Cохранено';
        end;
    Button3.Enabled:=true;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(111); end; {$ENDIF}
end;

procedure TForm1.FormActivate(Sender: TObject);
var
    i,w:integer;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(112); try;{$ENDIF}
    fStop:=false;
    StartDate.Date:=Date;
    EndDate.Date:=Date;

    StartTime.Time:=Time;
    EndTime.Time:=Time;

    MainList:=TStringList.Create;
    list:=TStringList.Create;
    with StringGrid1 do
        begin
        with Rows[0] do
            begin
            Delimiter:=';';
            QuoteChar:='"';
            //DelimitedText:='"Record number";"Source";"Date Generated";"Time Generated";"Date Written";"Time Written";"Computer";"Event ID";"Event type";"Event Category";"Domain\UserName (SID Type)";"SID";"Arguments[0..N]"';
            DelimitedText:='"Record number";"Source";"Date/Time Generated";"Date/Time Written";"Computer";"Event ID";"Event type";"Event Category";"Domain\UserName (SID Type)";"SID";"Arguments[0..N]"';
            end;
        DefaultRowHeight:=abs(StringGrid1.Font.Height)+6;
        for I := 0 to ColCount - 1 do
                AutoSizeGridColumn(StringGrid1, i);
        end;
    saveDialog1.InitialDir := GetCurrentDir;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(112); end; {$ENDIF}
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(113); try;{$ENDIF}
        Mainlist.Free;
        list.free;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(113); end; {$ENDIF}
end;

procedure TForm1.StringGrid1DrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
    S:String;
    i,w:integer;
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(114); try;{$ENDIF}
    with StringGrid1 do
        begin
        if (ARow > 0) then
            begin
            if (ARow mod 2 = 0) then
                begin
                S := Cells[ACol, ARow];
                with Canvas do
                    begin
                    Pen.Color := clGray;
                    //
                    Brush.Color := clSkyBlue;
                    FillRect(Rect);
                    //
                    Font.Style := [];
                    //TextRect(Rect, S,[tfLeft, tfVerticalCenter, tfSingleLine]);
                    TextOut(Rect.Left+2,rect.Top+2,s);
                    end;
                end
            end;
        end;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(114); end; {$ENDIF}
end;

procedure TForm1.btStopClick(Sender: TObject);
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(115); try;{$ENDIF}
    fStop:=true;
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(115); end; {$ENDIF}
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
{$IFDEF PROFILE}try; Profint.PomoEnter(116); try;{$ENDIF}
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
{$IFDEF PROFILE}except else Profint.PomoExce; end; finally; Profint.PomoExit(116); end; {$ENDIF}
end;

end.
