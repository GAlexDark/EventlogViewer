unit LoggerUnit;

interface
{$Define RUS}


uses
  windows,
  //SyncObjs,
  sysutils;
const
  ERROR_FL_SUCCESS        = $20000000;
  ERROR_FL_CREATE         = $20000001;
  ERROR_FL_SEC_INIT       = $20000002; //1
  ERROR_FL_INVALID_PATH   = $20000003; //2
  ERROR_FL_CREATE_FOLDER  = $20000004; //3
  ERROR_FL_LIST_OF_FILES  = $20000005; //4
  ERROR_FL_UNK_WRITE_TO_FILE  = $20000006; //5
  ERROR_FL_FILE_DIR_EXIST = $20000007;
  ERROR_FL_ACCESS_DENY    = $20000008;
  ERROR_FL_DISK_FULL      = $20000009;
  ERROR_FL_IO             = $20000010;
  ERROR_FL_NOT_OPEN       = $20000011;
  ERROR_FL_NOT_ASSIGN     = $20000012;
  ERROR_FL_FILE_NOT_FIND = $20000013;

type
  TLogType = (LE_CRI, LE_ERR, LE_WRN, LE_INF, LE_DBG, LE_NONE);

  EFileLoggerError = class(Exception)
  strict private
    fCode: DWORD;
    fWin32ErrorCode: DWORD;  //GetLastError
    fData: string;
  public
    constructor Create(const aMsg: String; const aErrorCode, aWin32ErrorCode: DWORD;
                        const aDebugData: string = '');
    property ErrorCode: DWORD read fCode {write fCode};
    property Win32ErrorCode: DWORD read fWin32ErrorCode {write fWin32ErrorCode};
    property DebugData: string read fData;
  end;

TFile_Logger = class
strict private
  fLogDir : string;   // каталог, где сохраняются журналы
  fLogName : string;  // имя файла текущего журнала
  fExtLogName : Boolean;
  fLogFile: TextFile;

  //fHistoryInterval: integer; //период за какой хранить журналы
  fMaxSizeOfLog: Int64;
  fIsFileLocked : boolean; //true - file open
  fPartCnt: integer;

  flog_level: TLogType;
  _global_ses_id: Integer;

  _cs: _RTL_CRITICAL_SECTION;
  _cs_inited: boolean;
public
  constructor Create(aProcessID: THandle);
  destructor Destroy; override;

  procedure InitLog(log_level: TLogType);
  procedure DeInitLog;
  function new_id: integer;
  property LogDir: string write fLogDir;
  property IsFileLocked: boolean read fIsFileLocked;
  property MaxSizeLog: Int64 write fMaxSizeOfLog;
  property ExtLogName: Boolean read fExtLogName write fExtLogName;
  property LogName: string read fLogName write fLogName;

  procedure AddToLog(const aMessage: string; const PID: Integer;
                      aMsgType: TLogType = LE_NONE); overload;
  procedure AddToLog(const aMessage: string); overload;
//  procedure AddToLog(aBinaryData: Pointer); overload;

end;

implementation
uses
  classes;
  //dialogs;

resourcestring
  sLogName = '%0:s%1:s_%2:.4d.log';
  sLogSearch ='%0:s%1:s_*.log';
  sLE_NON = '---';
  sDate = 'yyyy-mm-dd';
  sCR = #13#10;

  sInitError = 'Ошибка инициализации';
  sInvalidPath = 'Не указан путь';
  sErrorCreateFolder = 'Невозможно создать папку';
  sDirectoryExist = 'Ошибка проверки существования файла\папки';
  sCreateListOfFiles = 'Ошибка создания списка файлов';
  sIOError = 'Ошибка ввода/вывода';
  sWrtError = 'Невозможно внести данные в файл';
  sDiskFull = 'Диск заполнен';
  sFileNotFind = 'Файл не найден';
  sAccessDeny = 'Нет прав на доступ к папке/файлу';

{$IFDEF RUS}
  HeaderStr = '==== %0:s %1:s | Идентификатор сессии= %2:u | Тип= %3:s ====';

  sLE_CRI = 'КРИТИЧЕСКАЯ ОШИБКА';
  sLE_ERR = 'ОШИБКА';
  sLE_WRN = 'ПРЕДУПРЕЖДЕНИЕ';
  sLE_INF = 'УВЕДОМЛЕНИЕ';
  sLE_DBG = 'ОТЛАДОЧНАЯ ИНФОРМАЦИЯ';
{$ELSE}
  HeaderStr = '==== %0:s %1:s | Session ID= %2:u | Type= %3:s ====';

  sLE_CRI = 'CRITICAL ERROR';
  sLE_ERR = 'ERROR';
  sLE_WRN = 'WARNING';
  sLE_INF = 'INFORMATION';
  sLE_DBG = 'DEBUG INFO';
{$ENDIF}

{------------------------------------------------------------------------------}
constructor EFileLoggerError.Create(const aMsg: String; const aErrorCode, aWin32ErrorCode: DWORD;
                                    const aDebugData: string = '');
begin
  inherited Create(aMsg);
  fCode := aErrorCode;
  fWin32ErrorCode := aWin32ErrorCode;
  if Length(aDebugData) <> 0 then fData := Copy(aDebugData,1,INFINITE);
end;
{------------------------------------------------------------------------------}
function GetFileSize(aFileName: string): Int64;
var
  InfoFile: TSearchRec;
begin
    Result := 0;
  try
  if FileExists(aFileName) then
    begin
    if FindFirst(aFileName, faAnyFile, InfoFile) = 0 then
      Result := InfoFile.Size
    end
  else
    begin
    Result := -1
    end;
  finally
    FindClose(InfoFile);
  end;
end;

function _DirectoryExists(const aDirectory: string; var aErrorCode: DWORD): Boolean;
var
  Code: Cardinal;
begin
  Code := GetFileAttributes(PChar(aDirectory));
  aErrorCode := GetLastError;
  Result := (Code <> INVALID_FILE_ATTRIBUTES) and
            (FILE_ATTRIBUTE_DIRECTORY and Code <> 0);
end;

function _CreateDir(const aDir: string; var aErrorCode: DWORD): Boolean;
begin
  Result := CreateDirectory(PChar(aDir), nil);
  aErrorCode := GetLastError;
end;

{------------------------------------------------------------------------------}
constructor TFile_Logger.Create(aProcessID: THandle);
var
  ErrorCode: DWORD;
begin
  flog_level := LE_NONE; // не логировать
  _global_ses_id := integer(aProcessID);
  fPartCnt := 0;
  fIsFileLocked:= false; //файл не занят
  fExtLogName := false;

  if InitializeCriticalSectionAndSpinCount(_cs,4000) then
      begin
      _cs_inited := True;
      end
    else
      begin
      ErrorCode := GetLastError;
      _cs_inited := false;
      raise EFileLoggerError.Create(sInitError,ERROR_FL_CREATE,ErrorCode);
      end;
end;

destructor TFile_Logger.Destroy;
begin
  DeInitLog;
  if _cs_inited then
    begin
    DeleteCriticalSection(_cs);
    _cs_inited := false
    end;
  inherited;
end;
{------------------------------------------------------------------------------}
procedure TFile_Logger.InitLog(log_level: TLogType);
var
  sr : TSearchRec;
  LogTime: TDateTime;
  List: TStringList;
  Cnt: integer;
  ErrorCode: DWORD;
  Size: Int64;

begin
  if fLogDir = '' then
    begin
    raise EfileLoggerError.Create(sInvalidPath,ERROR_FL_INVALID_PATH,0);
    end;
  //проверка пути, где будут храниться логи
  if not _DirectoryExists(fLogDir,ErrorCode) then
    begin
    if ErrorCode = ERROR_FILE_NOT_FOUND then
      begin
      if not _CreateDir(fLogDir,ErrorCode) then
        begin
        raise EfileLoggerError.Create(sErrorCreateFolder,ERROR_FL_CREATE_FOLDER,
                                        ErrorCode);
        end;
      end
    else
      begin
      raise EfileLoggerError.Create(sDirectoryExist,ERROR_FL_FILE_DIR_EXIST,
                                    ErrorCode);
      end; {if ErrorCode}
    end; {if not _DirectoryExists}

    //проверяем наличие завершающего "обратного слеша"
    fLogDir := IncludeTrailingPathDelimiter(fLogDir);

    if log_level < LE_CRI then flog_level := LE_CRI
      else if log_level > LE_NONE then flog_level := LE_NONE
        else flog_level := log_level;

{
  // журналы ведутся в отдельных файлах по каждой дате
  // удаление старых файлов журнала
  //(сохраняются только последние 7 журналов)
  with TStringList.Create do
    begin
    Sorted := True;
    i := FindFirst(fLogDir+'*.log',faAnyFile,sr);
    while i = 0 do
      begin
      Add(sr.Name);
      i := FindNext(sr);
      end;
    FindClose(sr);
    if Count > 7 then
      for i := 0 to Count - 8 do
        DeleteFile(fLogDir+Strings[i]);
    Free;
    end;
}
  if (not fExtLogName) then
    begin
    //ищем последний сегоднешний файл
    LogTime := now;
    //формируем строку для поиска
    fLogName := format(sLogSearch,[fLogDir,FormatDateTime(sDate,LogTime)]);
    try {except}
      List := TStringList.Create;
      try
        List.Clear;
        if FindFirst(fLogName,faAnyFile,sr) = 0 then
          begin
          repeat
            List.Add(sr.Name);
          until FindNext(sr) <> 0;
          FindClose(sr);
          end;

        Cnt := List.Count;
        if Cnt > 0 then
          begin
          Size := GetFileSize(fLogDir + List.Strings[Cnt-1]);
          if (Size <> -1) and (Size > fMaxSizeOfLog) then
            fPartCnt := Cnt
          else fPartCnt := Cnt-1;
          end;
      except
        raise EfileLoggerError.Create(sCreateListOfFiles,
                                    ERROR_FL_LIST_OF_FILES,0);
      end;
    finally
      FreeAndNil(List);
    end;
    end; {not fExtLogName}
end;

procedure TFile_Logger.DeInitLog;
begin
  fLogName := '';
  fLogDir := '';

  if _cs_inited then
    begin
    try
      EnterCriticalSection(_cs);
      {$I-}
      if fIsFileLocked then
        begin
        CloseFile(fLogFile);
        fIsFileLocked:= false;
        end;
      {$I+}
    finally
      LeaveCriticalSection(_cs);
      DeleteCriticalSection(_cs);
      _cs_inited := false;
    end;
    end
end;
function TFile_Logger.new_id: integer;
begin
    Result := InterlockedIncrement(_global_ses_id);
end;

procedure TFile_Logger.AddToLog(const aMessage: string; const PID: Integer;
                                aMsgType: TLogType = LE_NONE);
var
  LogTime: TDateTime;
  MsgType, str_buffer: string;
  Size: Int64;
begin
{ TODO : Включить позже }//  if aMsgType < flog_level then exit;

  LogTime := now;
  case aMsgType of
      LE_CRI: MsgType := sLE_CRI;
      LE_ERR: MsgType := sLE_ERR;
      LE_WRN: MsgType := sLE_WRN;
      LE_INF: MsgType := sLE_INF;
      LE_DBG: MsgType := sLE_DBG
    else
      MsgType := sLE_NON
  end;
  str_buffer := format(HeaderStr,[DateToStr(LogTime), TimeToStr(LogTime),
                        PID, MsgType]);
{===========================================================================
  Ф-ция            Коды ошибок
              IOResult (EInOutError)
AssignFile
Rewrite		            5,102
Append		            2,5,102
writeln		            101,102,105
CloseFile	            101

2     FILE_NOT_FIND
5     ACCESS_DENY
101   Disk Full ------------------------- ERROR_FL_DISK_FULL
102   File variable not assigned
105   File not open for output   -------- ERROR_FL_NOT_OPEN


===========================================================================}
  try {finally}
    try {except}

    // текущий файл журнала
    if (not fExtLogName) then
      fLogName := format(sLogName,[fLogDir,
                               FormatDateTime(sDate,LogTime),
                               fPartCnt]);

    EnterCriticalSection(_cs);

    fIsFileLocked := true; //заняли файл
    if (fExtLogName) then
      begin // fExtLogName - используем внешнее имя
      AssignFile(fLogFile,fLogName);
      //Rewrite(fLogFile);
      if FileExists(fLogName) then Append(fLogFile)
      else Rewrite(fLogFile);
      end
    else
      begin
      //выполняем подключение к сущ-му файлу или создаем новый
      if FileExists(fLogName) then
        begin
        Size := GetFileSize(fLogName);
        if Size > fMaxSizeOfLog then
          begin
          InterlockedIncrement(fPartCnt);
          fLogName := format(sLogName,[fLogDir,FormatDateTime(sDate,LogTime),
                                fPartCnt]);
          AssignFile(fLogFile,fLogName);
          Rewrite(fLogFile); //открываем новый файл на запись
          end
        else
          begin
          AssignFile(fLogFile,fLogName);
          Append(fLogFile) //открываем существующий файл на запись
          end;
        end {FileExists(fLogName) - true}
      else
        begin
        AssignFile(fLogFile,fLogName);
        Rewrite(fLogFile); //открываем новый файл на запись
        end; {FileExists(fLogName) - false}
      end;

    // пытаемся туда что-то писать
    writeln(fLogFile,str_buffer);
    Writeln(fLogFile,aMessage);
      //Writeln(fLogFile,sCR);
    except
      on EIOErr: EInOutError do
        begin
        case EIOErr.ErrorCode of
          2: begin
              //ShowMessage('EInOutError - 2');
              raise EFileLoggerError.Create(sFileNotFind,
                                            ERROR_FL_FILE_NOT_FIND,
                                            EIOErr.ErrorCode);
            end;
          5: begin
              //ShowMessage('EInOutError - 5');
              raise EFileLoggerError.Create(sAccessDeny,
                                            ERROR_FL_ACCESS_DENY,
                                            EIOErr.ErrorCode);
            end;
          101: begin
              //ShowMessage('EInOutError - 101');
              raise EFileLoggerError.Create(sDiskFull,
                                            ERROR_FL_DISK_FULL,
                                            EIOErr.ErrorCode);
            end;
          102: begin
              //ShowMessage('EInOutError - 102');
              raise EfileLoggerError.Create(sIOError,
                                            ERROR_FL_IO,
                                            EIOErr.ErrorCode);
            end
        else
          begin
          //ShowMessage('EInOutError - Uncnown Error'+ #13#10
          //+'Error Code = '+ IntToStr(EIOErr.ErrorCode));
              raise EfileLoggerError.Create(sWrtError,
                                            ERROR_FL_UNK_WRITE_TO_FILE,0);
          end;
        end; {case}
        end; {on except}
      on E: Exception do
        begin
          //ShowMessage('Exception - Uncnown Error');
          raise EfileLoggerError.Create(sWrtError,
                                        ERROR_FL_UNK_WRITE_TO_FILE,0);
        end;
    end;
  finally
    //ShowMessage('LoggerUnit - finally');
    {$I-}
    CloseFile(fLogFile);
    {$I+}
    fIsFileLocked := false; //освободили файл
    LeaveCriticalSection(_cs);
  end;
end;

procedure TFile_Logger.AddToLog(const aMessage: string);
var
  LogTime: TDateTime;
  Size: Int64;
begin
{ TODO : Включить позже }//  if aMsgType < flog_level then exit;

  LogTime := now;
{===========================================================================
  Ф-ция            Коды ошибок
              IOResult (EInOutError)
AssignFile
Rewrite		            5,102
Append		            2,5,102
writeln		            101,102,105
CloseFile	            101

2     FILE_NOT_FIND
5     ACCESS_DENY
101   Disk Full ------------------------- ERROR_FL_DISK_FULL
102   File variable not assigned
105   File not open for output   -------- ERROR_FL_NOT_OPEN


===========================================================================}
  try {finally}
    try {except}

    // текущий файл журнала
    if (not fExtLogName) then
      fLogName := format(sLogName,[fLogDir,
                               FormatDateTime(sDate,LogTime),
                               fPartCnt]);

    EnterCriticalSection(_cs);

    fIsFileLocked := true; //заняли файл
    if (fExtLogName) then
      begin // fExtLogName - используем внешнее имя
      AssignFile(fLogFile,fLogName);
      if FileExists(fLogName) then Append(fLogFile)
      else Rewrite(fLogFile);
      end
    else
      begin
      //выполняем подключение к сущ-му файлу или создаем новый
      if FileExists(fLogName) then
        begin
        Size := GetFileSize(fLogName);
        if Size > fMaxSizeOfLog then
          begin
          InterlockedIncrement(fPartCnt);
          fLogName := format(sLogName,[fLogDir,FormatDateTime(sDate,LogTime),
                                fPartCnt]);
          AssignFile(fLogFile,fLogName);
          Rewrite(fLogFile); //открываем новый файл на запись
          end
        else
          begin
          AssignFile(fLogFile,fLogName);
          Append(fLogFile) //открываем существующий файл на запись
          end;
        end {FileExists(fLogName) - true}
      else
        begin
        AssignFile(fLogFile,fLogName);
        Rewrite(fLogFile); //открываем новый файл на запись
        end; {FileExists(fLogName) - false}
      end;

    // пытаемся туда что-то писать
    Writeln(fLogFile,aMessage);
      //Writeln(fLogFile,sCR);
    except
      on EIOErr: EInOutError do
        begin
        case EIOErr.ErrorCode of
          2: begin
              //ShowMessage('EInOutError - 2');
              raise EFileLoggerError.Create(sFileNotFind,
                                            ERROR_FL_FILE_NOT_FIND,
                                            EIOErr.ErrorCode);
            end;
          5: begin
              //ShowMessage('EInOutError - 5');
              raise EFileLoggerError.Create(sAccessDeny,
                                            ERROR_FL_ACCESS_DENY,
                                            EIOErr.ErrorCode);
            end;
          101: begin
              //ShowMessage('EInOutError - 101');
              raise EFileLoggerError.Create(sDiskFull,
                                            ERROR_FL_DISK_FULL,
                                            EIOErr.ErrorCode);
            end;
          102: begin
              //ShowMessage('EInOutError - 102');
              raise EfileLoggerError.Create(sIOError,
                                            ERROR_FL_IO,
                                            EIOErr.ErrorCode);
            end
        else
          begin
          //ShowMessage('EInOutError - Uncnown Error'+ #13#10
          //+'Error Code = '+ IntToStr(EIOErr.ErrorCode));
              raise EfileLoggerError.Create(sWrtError,
                                            ERROR_FL_UNK_WRITE_TO_FILE,0);
          end;
        end; {case}
        end; {on except}
      on E: Exception do
        begin
          //ShowMessage('Exception - Uncnown Error');
          raise EfileLoggerError.Create(sWrtError,
                                        ERROR_FL_UNK_WRITE_TO_FILE,0);
        end;
    end;
  finally
    //ShowMessage('LoggerUnit - finally');
    {$I-}
    CloseFile(fLogFile);
    {$I+}
    fIsFileLocked := false; //освободили файл
    LeaveCriticalSection(_cs);
  end;
end;

//procedure TFile_Logger.AddToLog(aBinaryData: Pointer); overload;
//begin
//    write(fLogFile,)
//end;
{------------------------------------------------------------------------------}

end.
