unit EventViewUnit;
//{$DEFINE Ping}
interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls,Buttons,
  ELRThreadUnit,EventLog,RTCache;                         //My



type
  TForm1 = class(TForm)
    Panel1: TPanel;
    Memo1: TMemo;
    Button1: TButton;
    Edit1: TEdit;
    Label1: TLabel;
    Button2: TButton;
    SaveDialog1: TSaveDialog;
    Button3: TButton;
    StatusBar1: TStatusBar;
    Label2: TLabel;
    Edit2: TEdit;
    Button4: TButton;
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
    SpeedButton1: TSpeedButton;
    ComboBox1: TComboBox;
    SpeedButton2: TSpeedButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure CheckBox1Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure SpeedButton1Click(Sender: TObject);
    procedure SpeedButton2Click(Sender: TObject);
  private
    { Private declarations }
    ThreadCount:integer;
    
  public
    { Public declarations }
    SourceList:TStringList; //список серверов, полученый с формы
    SourceListFlag:boolean; //True - используем форму, false - строку
    counter:integer;    
    procedure THreadsDone(Sender: TObject);
  end;

  var
    Form1: TForm1;
    list,MainList:TStringList;
    {Thread}
    ELRThread:TELRThread;
    SIDCache : TSIDCache;
    ptrSIDCache : PSIDCache;

    arrTELRThread: array of TELRThread;
    DoneFlag:integer =0;
    CriticalCection1,CriticalCection2: TRTLCriticalSection;

implementation

{$R *.dfm}
uses
    DualList,strutils,ActiveX,dateutils,
    networkAPI, Headers, DsUtils, DLLLoader;
const
    ResStrng:string =   '"%0:7u";"%1:s";"%2:s %3:s";"%10:s %11:s";"%4:s";"%5:u";"%7:s (%6:u)";"%9:s (%8:u)"';

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

    {----------------------------------}
procedure TForm1.THreadsDone(Sender: TObject);
begin
  InterlockedIncrement(DoneFlag);
    if DoneFlag = ThreadCount then
        begin
        //EnterCriticalSection(CriticalCection);
        //try
        if CBVisible.Checked then //включить визуализацию
            begin
            StatusBar1.Panels[2].Text:='Вывод данных';
            Application.ProcessMessages;
            with Memo1 do
              begin
              Visible := false;
              with  Memo1.Lines  do
                begin
                //BeginUpdate;
                AddStrings(MainList);
                //EndUpdate;
                end;
              Visible := true;
              end;
            end;
        Application.ProcessMessages;
        with  StatusBar1  do
            begin
            Panels[0].Text:='Считано строк: '+IntToStr(MainList.Count);
            Panels[1].Text:='Не сохранено';
            end;
        Button1.Enabled:=true;
        StatusBar1.Panels[2].Text:='Обработано записей: '+IntToStr(counter);         
        //finally
        //  LeaveCriticalSection(CriticalCection);
        //end;
        end;
end;
{----------------------------------}


procedure TForm1.Button1Click(Sender: TObject);
var
    {----Thread-----}
    i:integer;
    {---- getcomputername----}
    size : cardinal;
    pres : pchar;
    bres : boolean;
    ServerName, IPAddress : AnsiString;
    echo:longint;

    wHour, wMinute, wSecond, wMilliseconds:word;
    value : word;
    StartDataTime,EndDataTime:DWORD;
    strID, tmp : string;
    masIDCount : DWORD;
    offset, k : integer;
    masID : TLongWordDynArray;
    Position1 : integer;
    tmp_list: TStringList;
    err: dword;
begin
    Button1.Enabled:=false;
    counter:=0;
    DoneFlag := 0;
    Memo1.Lines.BeginUpdate;
    Memo1.Clear;
    Memo1.Lines.EndUpdate;
    MainList.Clear;
    list.Clear;

    StatusBar1.Panels[1].Text:='Ожидание считывания данных';
{----------------------------------------------------------------------------}

{----------------------------------------------------------------------------}
    if CheckBox1.Checked then //если используем фильтр по дата+время
        begin
        DecodeTime(StartTime.Time, wHour, wMinute, wSecond, wMilliseconds);
        StartDataTime := GetDateTimeStamp(int(StartDate.Date)+EncodeTime(wHour, wMinute, wSecond,0));
        DecodeTime(EndTime.Time, wHour, wMinute, wSecond, wMilliseconds);
        EndDataTime := GetDateTimeStamp(int(EndDate.Date)+EncodeTime(wHour, wMinute, wSecond,0));
        end;

    case ComboBox1.ItemIndex of
      -1: begin
          value:=EVENTLOG_AUDIT_ANY; {еcли не был выбран тип}
          end;
       0: value:=EVENTLOG_AUDIT_ANY;
       1: value:=EVENTLOG_AUDIT_SUCCESS;
       2: value:=EVENTLOG_AUDIT_FAILURE;

    end;

  strID:=Trim(Edit2.Text);
  if length(strID) <>0 then
    begin
    for I := 1 to length(strID) do
        if not CharInSet(strID[i],['0'..'9'])  then
            begin
            strID[i]:= Widechar(',');
            end;
    if strID[length(strID)] = ',' then strID[length(strID)]:=' ';
    strID:=trim(strID);
    masIDCount:=0;
    for I := 1 to length(strID) do
        if strID[i] = ',' then inc(masIDCount);
    inc(masIDCount);
    SetLength(masID,masIDCount);
    k:=0;
    Position1:=Pos(',',strID);
    offset:=1; masIDCount:=0;
    if Position1 > 0 then
        begin
        while Position1 > 0 do
            begin
            tmp := '';
            tmp := copy(strID,offset,Position1 - offset);
            masID[k] := StrToInt(tmp);
            inc(k);
            inc(masIDCount);
            offset := Position1 + 1;
            Position1 := PosEx(',',strID,offset);
            end; //while Position1>0
        tmp := '';
        tmp := copy(strID,offset,length(strID) - offset + 1);
        masID[k] := StrToInt(tmp);
        inc(masIDCount);
        end //if Position1 > 0
    else //Position = 0 - tolko edinichnoe znachenie
        begin
        SetLength(masID,1);
        masID[k] := StrToInt(strID);
        masIDCount := 1
        end;
    end
  else
    begin
    SetLength(masID,1);
    masID[0] := 0;
    masIDCount := 1;
    end;
{----------------------------------------------------------------------------}
    // V 1 potok
  if not SourceListFlag then
    begin  
    ThreadCount := 1;
    //проверка имени хоста (наличия прямой и обратной записи) (преобразование alias в netbios-имя хоста)
    ServerName := AnsiString(Trim(Edit1.Text));
    if Length(ServerName) <> 0 then
        begin
        // Name2IP
        if not GetIPFromName(ServerName,IPAddress) then
            begin
            StatusBar1.Panels[1].Text:='GetIPFromName Error';
            Button1.Enabled:=true;
            exit;
            end;
        end
    else
        begin
        //get loacal IP
        GetIPFromName('',IPAddress);
        end;
        //IP2Name
{$IFDEF Ping}
        if not ping(IPAddress,echo) then
            begin
            StatusBar1.Panels[1].Text:='Ping Error';
            Button1.Enabled:=true;
            exit
            end
        else StatusBar1.Panels[1].Text:='Ping time '+IntToStr(echo)+ ' ms';
{$ENDIF}
    if not GetNameFromIP(IPAddress,ServerName) then
        begin
        StatusBar1.Panels[1].Text:='GetNameFromIP Error';
        Button1.Enabled:=true;
        exit
        end;
    Edit1.Text := string(ServerName);
    ELRThread := TELRThread.create(string(ServerName),ptrSIDCache);
    with ELRThread do
      begin
      SourceName := 'Security';
      if CheckBox1.Checked then
        begin
        DataTimeFilterEnable := true;
        StartData := StartDataTime;
        EndData := EndDataTime;
        end
      else DataTimeFilterEnable := false;

      CurrentDir := GetCurrentDir + '\';
      EventTypeFilter := value;
      EventIDArray := masID;
      EventIDCount := masIDCount;
      Argument := trim(Edit3.Text);
      OnTerminate := threadsdone;
      end; //with
    ELRThread.Resume;
    end
  else
    begin //несколько серверов
    ThreadCount:=SourceList.Count;
    SetLength(arrTELRThread,SourceList.Count);
    for I := 0 to SourceList.Count - 1 do
      begin
      arrTELRThread[i] := TELRThread.create(trim(SourceList.Strings[i]),ptrSIDCache);
      with arrTELRThread[i] do
        begin
        SourceName := 'Security';
        if CheckBox1.Checked then
          begin
          DataTimeFilterEnable := true;
          StartData := StartDataTime;
          EndData := EndDataTime;
          end
        else DataTimeFilterEnable := false;

        CurrentDir := GetCurrentDir + '\';
        EventTypeFilter := value;
        EventIDArray := masID;
        EventIDCount := masIDCount;
        Argument := trim(Edit3.Text);
        OnTerminate := threadsdone;
        end;
      arrTELRThread[i].Resume
      end;
    end;
  Application.ProcessMessages;


{----------------------------------------------------------------------------}
    Form1.Caption:=trim(Edit1.Text);
    StatusBar1.Panels[1].Text:='Считывание данных';
  SetLength(masID,1);
  masID := nil;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
    if SaveDialog1.Execute then
        begin
        MainList.SaveToFile(SaveDialog1.FileName+'_Summary_baselog.txt',TEncoding.Unicode);
        StatusBar1.Panels[1].Text:='Cохранено';
        end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var
    i,j,len,count,FindDotComma:integer;
    s:string;
    tmplist:TStringList;
begin
    Button3.Enabled:=false;
    StatusBar1.Panels[1].Text:='Идет анализ';

    tmplist:=TStringList.Create;
try
    if cbFindDubl.Checked then tmplist.Duplicates:=dupAccept
    else tmplist.Duplicates:=dupIgnore;
    tmplist.Sorted:=true;

//    FindDotComma:=0;
    count:=List.Count - 1;
    for i:=0 to count do
        begin
        s:=list.Strings[i];
        s:=trim(s);
        len:=length(s);
        //find ';'
        FindDotComma := pos(s,';');
//        for j:=1 to len do
//            begin
//            if s[j]=widechar(';') then
//                begin
//                FindDotComma:=j;
//                break
//                end
//            end;
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

    if CBVisible.Checked then
        begin
        Memo1.Lines.BeginUpdate;
        Memo1.Clear;
        Memo1.Lines.EndUpdate;
        Memo1.Lines.Assign(list);
        end;
    StatusBar1.Panels[0].Text:='Результат: '+IntToStr(list.Count)+' строк';
    StatusBar1.Panels[1].Text:='Не сохранено';
    if SaveDialog1.Execute then
        begin
        list.SaveToFile(SaveDialog1.FileName + '_result.txt',TEncoding.Unicode);
        StatusBar1.Panels[1].Text:='Cохранено';
        end;
    Button3.Enabled:=true;
end;

procedure TForm1.FormActivate(Sender: TObject);
begin
    SourceList:=TStringList.Create;
    SourceListFlag:=false;
    SourceList.Clear;

    MainList:=TStringList.Create;
    list:=TStringList.Create;
  //sozdaem SID Cache
  SIDCache := TSIDCache.Create('','');
  ptrSIDCache := @SIDCache;

    StartDate.Date := Date;
    EndDate.Date := Date;

    StartTime.Time := Time;
    EndTime.Time := Time;


    InitializeCriticalSectionAndSpinCount(CriticalCection1,4000);
    InitializeCriticalSectionAndSpinCount(CriticalCection2,4000);
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  DeleteCriticalSection(CriticalCection1);
  DeleteCriticalSection(CriticalCection2);
  FreeAndNil(Mainlist);
  FreeAndNil(list);
  FreeAndNil(SourceList);
  FreeAndNil(SIDCache);
  ptrSIDCache := nil;
  SetLength(arrTELRThread,1);
  arrTELRThread[0]:=nil;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
begin
    SourceList.Clear;
    DualList.DualListDlg.ShowModal;
    if SourceListFlag then Edit1.Enabled:=false else Edit1.Enabled:=true
end;

procedure TForm1.SpeedButton2Click(Sender: TObject);
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

procedure TForm1.Button4Click(Sender: TObject);
var
    i:integer;
begin
    if SourceListFlag then
        // несколько серверов
        for I := 0 to SourceList.Count - 1 do
            if Assigned(arrTELRThread[i]) then
                begin
                arrTELRThread[i].Reset :=true
                end
    else //один сервер
        if Assigned(ELRThread) then
            begin
            ELRThread.Reset:=true;
            end;
    StatusBar1.Panels[2].Text:='Прервано пользователем'
end;

procedure TForm1.CheckBox1Click(Sender: TObject);
begin
    if CheckBox1.Checked then
        begin
        StartDate.Enabled :=true;
        StartTime.Enabled:=true;
        EndDate.Enabled:=true;
        EndTime.Enabled:=true
        end;
end;

end.
