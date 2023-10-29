unit RTCache;

interface

uses
  classes, windows, SyncObjs,
  DLLWrapUnit;

const
  RTCACHE_NOT_FIND     = 0;
  RTCACHE_FIND         = 1;
  RTCACHE_LIST_EMPTY   = 2;
  RTCACHE_SID_ERROR    = 4;
  RTCACHE_ADD_SUCCESS  = 8;
  RTCACHE_ADD_FAILURE  = 16;

type
{$region 'Other Types'}
  PSIDList = ^TSIDList;
  TSIDList = packed record
    _binSID     : array[0..7] of cardinal; // attrib 32=7*4(SID)+1*4(rezerv)
    _UserInfo   : integer;                 //domain\user  - body
    _SIDType    : DWORD;
    _StringSID  : integer;                 // S-1-5-...
    end;

  PFMCItem = ^TFMCItem;
  TFMCItem = record
    _ID     : DWORD;
    _String : string;
    end;
{$endregion}
{==============================================================================}
{$region 'class TSQLLiteDB)'}
TSQLLiteDB = class
  strict private
  { private declarations }
  m_ConnString     : string;
  m_PluginName : string;
  m_hDLL       : THandle;
  m_Connected  : Boolean;
  m_pErrorInfo : PDBERRORINFO;

public
    { public declarations }
  constructor Create(const aDLLPath: string); //путь к ДЛЛ с интерфейсом БД
  destructor Destroy; override;

  procedure Init();

  procedure Open();
  procedure Close();
  procedure WhoSearch(const aSQLString: String);
  procedure BeginTransaction();
  procedure EndTransaction();

  function GetSearchResult(var pSID,pUserName: PWideChar; var SIDType: DWORD; var Count: Integer): Boolean;
  procedure PrepareInsert(const aSQLString: String);
  procedure InsertToDB(const aStrSID, aUserInfo: string; const aSIDType: dword);

  property ConnString : string read m_ConnString     write m_ConnString;
  property PluginName : string read m_PluginName write m_PluginName;

end;
{$endregion}
{==============================================================================}
{$region 'class TSIDCache'}

  TSIDData = record
    _SIDType: DWORD;
    _SIDSize: DWORD;
  end;

  PSIDCache = ^TSIDCache;
  TSIDCache = class
  strict private
    { private declarations }
    m_Ptr         : PSIDList;
    m_StartAddr   : PSIDList;
    m_EndAddr     : PSIDList;
    m_CurrentEnd  : PSIDList;
    m_count       : DWORD;       //кол-во новых записей
    m_UserInfo    : TStringList; //domain\user  - body
    m_StringSID   : TStringList; //S-1-5-...
    m_db          : TSQLLiteDB;
    m_hDLL        : THandle;
    m_pSID        : PSID;
    m_SIDData     : TSIDData;
    m_pErrorInfo  : PDBERRORINFO;
    m_pSIDBuf,
    m_pUsrBuf     : PWideChar;

    procedure _AddToMemDB(const aSID: PSID; const aUserName, awSID: WideString; const aSIDType: DWORD);
    procedure _AddToCache(aSID: Pointer; const UserInfo: string; SIDType: Cardinal; const strSID: string);

  public
    { public declarations }
    constructor Create(const aBDB_DLL_Path,          // расположение интерфейса с Berkeley DB (DLL)
                             aSQL_DLL_Path: string); // расположение интерфейса с DB SQLitе (DLL)
    procedure Init(const aConnString,                     //путь к папке с БД
                         aPluginName: string);
    destructor Destroy; override;

    function Find(aSID:PSID; var strSID,UserInfo: string; var SIDType:DWORD):Boolean;
    procedure Add(aSID:PSID; const strSID,UserInfo: string; SIDType:DWORD);
    procedure LoadFromDB(var aCount: DWORD);
    procedure SaveToDB(var aCount: DWORD);
    //procedure ShadowCopy(const strSID,UserInfo:string; SIDType:DWORD);
    property ItemsCount : DWORD read m_count;

end;
{$endregion}
{==============================================================================}
{$region 'class TShadowCopy'}
//TShadowCopy = class(TThread) //Background
//strict private
//  db: TSQLLiteDB;
//
//  fStringSID: string;
//  fUserInfo: string;
//  fSIDType: DWORD;
//protected
//    procedure Execute; override;
//public
//  property StringSID: string read fStringSID write fStringSID;
//  property UserInfo: string read fUserInfo write fUserInfo;
//  property SIDType: DWORD read fSIDType write fSIDType;
//
//  constructor Create(const aSource: TSQLLiteDB);
//  destructor Destroy; override;
//end;
{$endregion}
{==============================================================================}
// FormatMessage Cache
{$region 'class TFMCache'}
TFMCache = class
strict private
    m_Ptr         : PFMCItem;
    m_StartAddr   : PFMCItem;
    m_EndAddr     : PFMCItem;
    m_CurrentEnd  : PFMCItem;
    m_count       : DWORD;

public
    constructor Create;
    destructor Destroy; override;

    function Find(const aValue: DWORD; var aStr: string; var aSize: integer):integer;
    function Add(const aValue: DWORD; const aStr: string):integer;
    property ItemsCount : DWORD read m_count;
end;
{$endregion}
{==============================================================================}

implementation
uses
    SysUtils,StrRepl,Headers;

const
    SIZE_OF_SIDList           = sizeof(TSIDList);         //40 bytes
    USERSIDCACHE_MAXMEM_SIZE  = 160000 * SIZE_OF_SIDList; //1562p*4096b+2048b

    SIZE_OF_FMCache           = sizeof(TFMCItem);
    FMCACHE_MAXMEM_SIZE       = 512 * SIZE_OF_FMCache;
    size_wchar                = sizeof(WideChar);

resourcestring
  SQLstrInsert       = 'INSERT INTO tableSID (strSID,UserName,SIDType) VALUES (:strSID,:UserName,:SIDType);';
  SQLstrSELECT_All   = 'SELECT strsid,username,sidtype FROM tableSID';
  //sErrorLoadLib      = 'Ошибка загрузки библиотеки %0:s.' + #13#10 + 'Код ошибки - %1:d';
  sErrorIntLib       = 'Ошибка инициализации библиотеки %0:s' + #13#10 + 'Описание: %1:s';
  //sDBFileNotFind     = 'Файл базы данных не найден';
  sErrorProcAddr     = 'Не найдена функция %0:s';

var
  FLatch,FLatch1{,Flatch2} : TRTLCriticalSection;


{$region 'Internal Proc'}
function GetSpinCount(aDefaultSpinCount: DWORD = 4000): integer;
var
  lpSystemInfo: TSystemInfo;
  CPUCount : DWORD;
begin
  GetSystemInfo(lpSystemInfo);
  CPUCount := lpSystemInfo.dwNumberOfProcessors;
   if CPUCount = 1 then Result := aDefaultSpinCount
    else Result := (CPUCount-1) * 1000;
end;
{$endregion}
{==============================================================================}
{$region 'TSIDCache Methods'}
procedure TSIDCache._AddToMemDB(const aSID: PSID; const aUserName, awSID: WideString; const aSIDType: DWORD);
var
    size: DWORD;
    error: string;
begin
    with m_SIDData do
//        if _SIDType = aSIDType then
//            begin
//            size := _SIDSize;
//            end
//        else
//            begin
//            _SIDType := aSIDType;
//            _SIDSize := _GetLengthSid(aSID);
//            size     := _SIDSize;
//            end; //GetLengthSid(aSID)
        begin
        if _SIDType <> aSIDType then
            begin
            _SIDType := aSIDType;
            _SIDSize := _GetLengthSid(aSID);
            end; //GetLengthSid(aSID)
            size     := _SIDSize;
        end;
    if not OnMem_BDBAdd(size, aSID, aUserName, aSIDType, awSID) then
        begin
        FillChar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        OnMem_BDBGetLastError(m_pErrorInfo);
        error := 'OnMem_BDBAdd Error. Details: %0:s';
        raise ESIDCacheError.Create(m_pErrorInfo.Code, m_pErrorInfo.SysCode,
                                    format(error,[WideCharToString(m_pErrorInfo.Description)]));
        end;
end;
procedure TSIDCache._AddToCache(aSID: Pointer; const UserInfo: string; SIDType: Cardinal; const strSID: string);
var
  Buffer: string;
begin
  {Добавляем в локальный кеш ранее немзвестные СИДы}
  if m_CurrentEnd = m_EndAddr then
    raise ESIDCacheError.Create(RTCACHE_ADD_FAILURE, 'Ошибка добавления нового SID в кеш. Описание: Переполнение списка');

//  if (CopySid(GetLengthSid(aSID), m_CurrentEnd, aSID)) then
//  begin
//    with m_CurrentEnd^ do
//    begin
//      Buffer := copy(UserInfo, 1, length(UserInfo));
//      _UserInfo := m_UserInfo.Add(Buffer);
//      Buffer := copy(strSID, 1, length(strSID));
//      _StringSID := m_StringSID.Add(Buffer);
//      _SIDType := SIDType;
//    end;
//    //with
//    Inc(m_CurrentEnd);
//    Inc(m_count);
//  end
//  else
//    raise ESIDCacheError.Create(RTCACHE_ADD_FAILURE, GetLastError, SysErrorMessage(GetLastError));
    _CopySid(_GetLengthSid(aSID), m_CurrentEnd, aSID);
    with m_CurrentEnd^ do
    begin
      Buffer := copy(UserInfo, 1, length(UserInfo));
      _UserInfo := m_UserInfo.Add(Buffer);
      Buffer := copy(strSID, 1, length(strSID));
      _StringSID := m_StringSID.Add(Buffer);
      _SIDType := SIDType;
    end;
    //with
    Inc(m_CurrentEnd);
    Inc(m_count);
end;

constructor TSIDCache.Create(const aBDB_DLL_Path,           // расположение интерфейса с Berkeley DB (DLL)
                                   aSQL_DLL_Path: string);  // расположение интерфейса с DB SQLitе (DLL)
begin
//    inherited create;
try
    { --- инициализация кеша для новых SID'ов --- }
    SetLastError(ERROR_SUCCESS);
    m_Ptr := VirtualAlloc(nil,USERSIDCACHE_MAXMEM_SIZE,MEM_COMMIT,PAGE_READWRITE);
    // изучить http://www.delphikingdom.com/asp/viewitem.asp?catalogid=1322
    if not Assigned(m_Ptr) then
        RaiseLastOSError;

    m_StartAddr              := m_Ptr;
    m_CurrentEnd             := m_Ptr;
    m_EndAddr                := PSIDList(DWORD(m_Ptr)+USERSIDCACHE_MAXMEM_SIZE);;

    m_UserInfo               := TStringList.Create;
    m_UserInfo.Sorted        := false;
    m_UserInfo.CaseSensitive := false;

    m_StringSID              := TStringList.Create;
    m_StringSID.Sorted       := false;
    { --- инициализация кеша для новых SID'ов --- }
    m_count := 0;

    m_db := TSQLLiteDB.Create(aSQL_DLL_Path); //создаем экземпляр TSQLLiteDB, передаем расположение интерфейса с DB SQLitе (DLL)
    m_pSID := pointer(LocalAlloc(LMEM_ZEROINIT,SIZE_OF_SID));
    if not Assigned(m_pSID) then
        RaiseLastOSError;

    m_SIDData._SIDType := 0;
    m_SIDData._SIDSize := 0;

    LoadDll(aBDB_DLL_Path,m_hDLL);  //throw

    GetMem(m_pErrorInfo, SizeOf(TDBERRORINFO));
    ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
    GetMem(m_pSIDBuf,(SID_LEN)*size_wchar);
    GetMem(m_pUsrBuf,(MAX_SIZE)*size_wchar);

{$region 'BDB GetProcAddr'}
    GetProcAddr(m_hDLL,sMBDBInit,@OnMem_BDBInit);
    GetProcAddr(m_hDLL,sMBDBInited,@OnMem_BDBInited);
    GetProcAddr(m_hDLL,sMBDBDeIntit,@OnMem_BDBDeIntit);
    GetProcAddr(m_hDLL,sMBDBClose,@OnMem_BDBClose);
    GetProcAddr(m_hDLL,sMBDBAdd,@OnMem_BDBAdd);
    GetProcAddr(m_hDLL,sMBDBFind,@OnMem_BDBFind);
    GetProcAddr(m_hDLL,sMBDBGetLastError,@OnMem_BDBGetLastError);
    GetProcAddr(m_hDLL,sMBDBClear,@OnMem_BDBClear);
{$endregion}

except
    if Assigned(m_Ptr) then
      begin
      VirtualFree(m_Ptr,USERSIDCACHE_MAXMEM_SIZE,MEM_RELEASE);
      m_Ptr := nil;
      end;
    if Assigned(m_pErrorInfo) then FreeMem(m_pErrorInfo);
    if Assigned(m_pSIDBuf) then FreeMem(m_pSIDBuf);
    if Assigned(m_pUsrBuf) then FreeMem(m_pUsrBuf);

    if Assigned(m_UserInfo) then FreeAndNil(m_UserInfo );
    if Assigned(m_StringSID) then FreeAndNil(m_StringSID);
    if Assigned(m_db) then FreeAndNil(m_db);
    Exception.RaiseOuterException(ESIDCacheError.Create('Ошибка инициализации кеша'));
    end;
end;
destructor TSIDCache.Destroy;
begin
    if Assigned(OnMem_BDBClose) then
        OnMem_BDBClose;
    UnLoadDll(m_hDLL);
    ClearBDBVars();

    FreeAndNil(m_db);
    m_StartAddr  := nil;
    m_CurrentEnd := nil;
    m_EndAddr    := nil;
    FreeAndNil(m_UserInfo);
    FreeAndNil(m_StringSID);

    if Assigned(m_pErrorInfo) then
        FreeMem(m_pErrorInfo);
    { --- Деинициализация кеша для новых SID'ов --- }
    if Assigned(m_Ptr) then
        VirtualFree(m_Ptr,USERSIDCACHE_MAXMEM_SIZE,MEM_RELEASE);
    LocalFree(cardinal(m_pSID)); m_pSID := nil;
    if Assigned(m_pSIDBuf) then FreeMem(m_pSIDBuf,(SID_LEN)*sizeof(WideChar));
    if Assigned(m_pUsrBuf) then FreeMem(m_pUsrBuf,(MAX_SIZE)*sizeof(WideChar));
end;
procedure TSIDCache.Init(const aConnString,         //путь к папке с БД
                         aPluginName: string);
begin
    m_db.ConnString := aConnString;
    m_db.PluginName := aPluginName;

    if (not OnMem_BDBInit) then
        begin
        FillChar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        OnMem_BDBGetLastError(m_pErrorInfo);
        Raise ESIDCacheError.Create(m_pErrorInfo.Code,
                                    m_pErrorInfo.SysCode,
                                    format(sErrorIntLib,[cBDB_DllName,widechartostring(m_pErrorInfo.Description)]));
        end;
    m_db.Init();
end;

function TSIDCache.Find(aSID:PSID; var strSID,UserInfo: string; var SIDType:DWORD):Boolean;
var
    error: string;
begin
  //WaitForSingleObject(self.hEvent, 5000);
  //возващает управление либо по таймауту либо когда объект, переданный ей в параметре,
  //передет в свободное состояние.
  //Для "события" свододное состояние наступает когда какой либо поток вызовет SetEvent.
  //hEvent.WaitFor(5000);

    //_ValidateSID(aSID);
    { TODO :
Удалил _ValidateSID(aSID), т.к. тут оно лишнее.
СИД не передается между процессами }
    Result := OnMem_BDBFind(aSID, m_pUsrBuf, MAX_SIZE, SIDType, m_pSIDBuf, SID_LEN);
    if Result then
        begin
        strSID   := WideCharToString(m_pSIDBuf);
        UserInfo := WideCharToString(m_pUsrBuf);
        end
    else
        begin
            //ConvertSidToStringSidW(aSID,m_pSIDBuf); //temporaly
        fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        OnMem_BDBGetLastError(m_pErrorInfo);
        if (m_pErrorInfo.SysCode <> -30988) then
            begin
            error := 'Ошибка выполнения поиска %0:s' + #13#10+
            'Код ошибки: %1:d Субкод: %3:d' + #13#10 +
            'Описание: %2:s';
            raise ESIDCacheError.Create(format(error,[cBDB_DllName,
                                           m_pErrorInfo.Code,
                                           WideCharToString(m_pErrorInfo.Description),
                                           m_pErrorInfo.SysCode]));
            end;
        end;
end;
procedure TSIDCache.Add(aSID:PSID; const strSID,UserInfo:string; SIDType:DWORD);
var
    pwUserInfo : WideString;
    pwstrSID   : WideString;

begin
  EnterCriticalSection(FLatch);
try
    try
    pwUserInfo := UserInfo;
    pwstrSID := strSID;

    _AddToMemDB(aSID, pwUserInfo, pwstrSID, SIDType);  // add to OnMem berkeley DB, throw - ESIDCacheError
  {Добавляем в локальный кеш ранее немзвестные СИДы}
    _AddToCache(aSID, UserInfo, SIDType, strSID);

    except
        on EOutOfMemory do
        begin
            raise EMemError.Create(RTCACHE_ADD_FAILURE, ERROR_OUT_OF_MEM);
        end;
        on ESIDCacheError do
            raise;
    else
        raise ESIDCacheError.Create(RTCACHE_ADD_FAILURE,'Неизвестная ошибка в методе TSIDCache.Add');
    end;

finally
//    FreeMem(pwstrSID);
    LeaveCriticalSection(FLatch);
end;
end;

procedure TSIDCache.LoadFromDB(var aCount: DWORD);
var
  SIDType     : DWORD;
  count       : Integer;
begin
    with m_db do
        try
        Open(); //throw ESQLiteError
        WhoSearch(SQLstrSELECT_All); //throw ESQLiteError
        aCount := 0;
        count := NO_COLUMNS;

        while GetSearchResult(m_pSIDBuf, m_pUsrBuf, SIDType, count) do //throw ESQLiteError
            begin
            inc(aCount);
            _ConvertStringSidToSid(m_pSIDBuf,m_pSID); //_ConvertStringSidToSid(m_pSIDBuf,m_pSID); //throw ESysError
            _AddToMemDB(m_pSID,m_pUsrBuf,m_pSIDBuf,SIDType); //throw ESIDCacheError
            end; //while
    finally
        Close();
    end;
end;
procedure TSIDCache.SaveToDB(var aCount: DWORD);
var
  LocalPtr : PSIDList;
begin
    aCount := m_count;
    if m_count = 0 then
        begin
        exit;
        end;

    with m_db do
        try
            Open();
            LocalPtr := m_StartAddr;
            //через поименованые параметры
            BeginTransaction(); //ESQLiteError
            PrepareInsert(SQLstrInsert); //ESQLiteError
            repeat
                InsertToDB(m_StringSID[LocalPtr^._StringSID], //ESQLiteError
                           m_UserInfo[LocalPtr^._UserInfo],
                           LocalPtr^._SIDType);
                inc(LocalPtr);
            until (LocalPtr = m_CurrentEnd);

        finally
            EndTransaction();  //ESQLiteError
            Close();  //ESQLiteError
        end;
end;


//procedure TSIDCache.ShadowCopy(const strSID,UserInfo:string; SIDType:DWORD);
//var
//  scdb: TShadowCopy;
//begin
//  scdb := TShadowCopy.Create(db);
//try
//  scdb.StringSID := copy(strSID,1,MaxInt);
//  scdb.UserInfo := copy(UserInfo,1,MaxInt);
//  scdb.SIDType := SIDType;
//  scdb.Resume;
//except
//  FreeAndNil(scdb);
//end;
//end;
{$endregion}
{==============================================================================}
{$region 'TShadowCopy Methods'}
//constructor TShadowCopy.Create(const aSource: TSQLLiteDB);
//begin
//  {инициализация}
//  inherited create(true); //создание в приостановленом состоянии - избегание гонок
//  //даем автоматически уничтожиться после окончания работы
//  FreeOnTerminate := true;
//
//  db := aSource;
//end;
//destructor TShadowCopy.Destroy;
//begin
//  inherited;
//end;
//procedure TShadowCopy.Execute;
//begin
//  db.Open;
//try
//  //db.BeginTransaction;
//  db.AddSimply(fStringSID,fUserInfo,fSIDType);
//  //db.Commit;
//finally
//  db.Close;
//end;
//end;
{$endregion}
{==============================================================================}
{$region 'SQLLiteDB Methods'}
constructor TSQLLiteDB.Create(const aDLLPath: string); // расположение интерфейса с DB SQLitе (DLL)
begin
try
    m_Connected := false;
    LoadDll(aDLLPath, m_hDLL);

{$region 'SQLite GetProcAddr'}
    GetProcAddr(m_hDLL,sSQLite_GetLastError,@SQLite_GetLastError);
    GetProcAddr(m_hDLL,sSQLite_ClearError,@SQLite_ClearError);
    GetProcAddr(m_hDLL,sSQLite_Create,@SQLite_Create);
    GetProcAddr(m_hDLL,sSQLite_free,@SQLite_Free);
    GetProcAddr(m_hDLL,sSQLite_Connect,@SQLite_Connect);
    GetProcAddr(m_hDLL,sSQLite_Inited,@SQLite_Inited);
    GetProcAddr(m_hDLL,sSQLite_Disconnect,@SQLite_Disconnect);
    GetProcAddr(m_hDLL,sSQLite_BeginTransaction,@SQLite_BeginTransaction);
    GetProcAddr(m_hDLL,sSQLite_CommitTransaction,@SQLite_CommitTransaction);
    GetProcAddr(m_hDLL,sSQLite_RollbackTransaction,@SQLite_RollbackTransaction);
    GetProcAddr(m_hDLL,sSQLite_Execute,@SQLite_Execute);
    GetProcAddr(m_hDLL,sSQLite_PrepareInsert,@SQLite_PrepareInsert);
    GetProcAddr(m_hDLL,sSQLite_BindValue,@SQLite_BindValue);
    GetProcAddr(m_hDLL,sSQLite_WhoSearch,@SQLite_WhoSearch);
    GetProcAddr(m_hDLL,sSQLite_SearchResult,@SQLite_SearchResult);
    GetProcAddr(m_hDLL,sSQLite_Open,@SQLite_Open);
    GetProcAddr(m_hDLL,sSQLite_Close,@SQLite_Close);
{$endregion}

  GetMem(m_pErrorInfo, SizeOf(TDBERRORINFO));
  ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
except

    if Assigned(m_pErrorInfo) then
      begin
      FreeMem(m_pErrorInfo,SizeOf(TDBERRORINFO));
      m_pErrorInfo := nil;
      end;
    // этот код должен быть всегда последним!
    UnLoadDll(m_hDLL);
    raise;
end;
end;
destructor TSQLLiteDB.Destroy;
begin
  try
    if (m_Connected) and Assigned(SQLite_Disconnect) then
        begin
        SQLite_Disconnect();
        m_Connected := false;
        end;
    if Assigned(SQLite_Free) then
        SQLite_Free();
    UnLoadDll(m_hDLL);
    ClearSQLiteVars();
    if Assigned(m_pErrorInfo) then
        begin
        FreeMem(m_pErrorInfo,SizeOf(TDBERRORINFO));
        m_pErrorInfo := nil;
        end;
  except
  end;
end;
procedure TSQLLiteDB.Init();
var
    pConnString : WideString;
    pPluginName : WideString;
    error       : string;
begin
    try
    if (not SQLite_Create('SID_DB')) then
        begin
        error := 'Ошибка инициализации %0:s' + #13#10+
        'Код ошибки: %1:d Субкод: %3:d' + #13#10 +
        'Описание: %2:s';
        fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        SQLite_GetLastError(m_pErrorInfo);
        raise ESQLiteError.Create(format(error,[cDB_DllName,
                                           m_pErrorInfo.Code,
                                           WideCharToString(m_pErrorInfo.Description),
                                           m_pErrorInfo.SysCode]));
        end;

        pConnString := m_ConnString;
        pPluginName := m_PluginName;

    if (not SQLite_Connect(pConnString, pPluginName)) then

        begin
        error := 'Ошибка подключения к базе данных %0:s' + #13#10+
        'Код ошибки: %1:d Субкод: %3:d' + #13#10 +
        'Описание: %2:s';
        fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        SQLite_GetLastError(m_pErrorInfo);
        raise ESQLiteError.Create(format(error,[cDB_DllName,
                                           m_pErrorInfo.Code,
                                           WideCharToString(m_pErrorInfo.Description),
                                           m_pErrorInfo.SysCode]));
        end
    else m_Connected := true;

    except
        on EOutOfMemory do
            begin
            SQLite_Free();
            raise ESQLiteError.Create(ERROR_OUT_OF_MEM,0);
            end;
        on E: ESQLiteError do
            begin
            SQLite_Disconnect();
            SQLite_Free();
            m_Connected := false;
            Exception.RaiseOuterException(ESIDCacheError.Create(E.GetErrorCode,E.GetSysCode,'Ошибка инициализации БД'));
            end;
        else raise ESQLiteError.Create('Неизвестная ошибка в TSQLLiteDB.Init');
    end;

end;
procedure TSQLLiteDB.Open();
var
  error: string;
begin
    if (not SQLite_Open()) then
      begin
      error := 'Ошибка открытия файла базы данных %0:s' + #13#10+
      'Код ошибки: %1:d Субкод: %3:d' + #13#10 +
      'Описание: %2:s';
      ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
      SQLite_GetLastError(m_pErrorInfo);
      raise ESQLiteError.Create(format(error,[cDB_DllName,
                                           m_pErrorInfo.Code,
                                           WideCharToString(m_pErrorInfo.Description),
                                           m_pErrorInfo.SysCode]));

      end;
end;
procedure TSQLLiteDB.Close();
var
  error: string;
begin
    if (not SQLite_Close()) then
      begin
      error := 'Ошибка закрытия базы данных %0:s' + #13#10 +
      'Код ошибки: %1:d Субкод: %3:d' + #13#10 +
      'Описание: %2:s';
      ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
      SQLite_GetLastError(m_pErrorInfo);
      raise ESQLiteError.Create(format(error,[m_ConnString,
                                           m_pErrorInfo.Code,
                                           WideCharToString(m_pErrorInfo.Description),
                                           m_pErrorInfo.SysCode]));
      end;
end;
procedure TSQLLiteDB.WhoSearch(const aSQLString: String);
var
    pwSQLString : WideString;
    error       : string;
begin
    try
        pwSQLString := aSQLString;
        if (not SQLite_WhoSearch(pwSQLString)) then
            begin
            error := 'Ошибка обращения к базе данных.' + #13#10 +
            'Код ошибки: %0:d Субкод: %1:d' + #13#10 +
            'Описание: %2:s';
            fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
            SQLite_GetLastError(m_pErrorInfo);
            raise ESQLiteError.Create(m_pErrorInfo.Code,
                                      m_pErrorInfo.SysCode,
                                      Format(error,[m_pErrorInfo.Code,
                                                    m_pErrorInfo.SysCode,
                                                    WideCharToString(m_pErrorInfo.Description)]));
      end;
    except
        on EOutOfMemory do
            begin
            raise ESQLiteError.Create(ERROR_OUT_OF_MEM,0);
            end;
        on ESQLiteError do raise;
        else raise ESQLiteError.Create('Неизвестная ошибка в TSQLLiteDB.WhoSearch');
    end;
end;
function TSQLLiteDB.GetSearchResult(var pSID,pUserName: PWideChar; var SIDType: DWORD; var Count: Integer): Boolean;
var
  error: string;
begin
  //count = NO_COLUMNS - начальное значение при старте
  Result := SQLite_SearchResult(pSID,pUserName, SIDType, count);
  if (not Result) then
    if (count <> END_OF_DATA) then
        begin
        error := 'Ошибка обращения к базе данных.' + #13#10 +
        'Код ошибки: %0:d Субкод: %1:d' + #13#10 +
        'Описание: %2:s';
        ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
        SQLite_GetLastError(m_pErrorInfo);
        raise ESQLiteError.Create(Format(error,[m_pErrorInfo.Code,
                                          m_pErrorInfo.SysCode,
                                          WideCharToString(m_pErrorInfo.Description)]));
        end;
end;
procedure TSQLLiteDB.BeginTransaction();
var
  error: string;
begin
  if (not SQLite_BeginTransaction()) then
    begin
    error := 'Ошибка начала транзакции.' + #13#10 +
      'Код ошибки: %0:d Субкод: %1:d' + #13#10 +
      'Описание: %2:s';
    ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
    SQLite_GetLastError(m_pErrorInfo);
    Raise ESQLiteError.Create(Format(error,[m_pErrorInfo.Code,
                                         m_pErrorInfo.SysCode,
                                         WideCharToString(m_pErrorInfo.Description)]));
    end;
end;
procedure TSQLLiteDB.EndTransaction;
var
  error: string;
begin
  if (not SQLite_CommitTransaction()) then
      begin
      error := 'Ошибка завершения транзакции.' + #13#10 +
      'Код ошибки: %0:d Субкод: %1:d' + #13#10 +
      'Описание: %2:s';
      ZeroMemory(m_pErrorInfo,sizeof(TDBERRORINFO));
      SQLite_GetLastError(m_pErrorInfo);
      raise ESQLiteError.Create(Format(error,[m_pErrorInfo.Code,
                                          m_pErrorInfo.SysCode,
                                          WideCharToString(m_pErrorInfo.Description)]));
      end;
end;
procedure TSQLLiteDB.PrepareInsert(const aSQLString: String);
var
  pwSQLString: WideString;
  error : string;
begin
    try
    pwSQLString := aSQLString;
    if (not SQLite_PrepareInsert(pwSQLString)) then
        begin
        fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        SQLite_GetLastError(m_pErrorInfo);
        error := 'Ошибка обращения к базе данных.' + #13#10 +
          'Код ошибки: %0:d Субкод: %1:d' + #13#10 +
          'Описание: %2:s';
        raise ESQLiteError.Create(Format(error,[m_pErrorInfo.Code,
                                             m_pErrorInfo.SysCode,
                                             WideCharToString(m_pErrorInfo.Description)]));
        end;
    except
        on EOutOfMemory do
            raise ESQLiteError.Create(ERROR_OUT_OF_MEM,0);
        on ESQLiteError do raise;
        else raise ESQLiteError.Create('Неизвестная ошибка в TSQLLiteDB.PrepareInsert');
    end;
end;
procedure TSQLLiteDB.InsertToDB(const aStrSID, aUserInfo: string; const aSIDType: dword);
var
    pwStringSID, pwUserInfo: PWideChar;
    len: Integer;
begin
    pwStringSID := nil;
    pwUserInfo := nil;
try
    try
    len := length(aStrSID)+1;
    GetMem(pwStringSID,len*size_wchar);
    //pwStringSID := StringToWideChar(aStrSID,pwStringSID,len);
    StrPCopy(pwStringSID,aStrSID);

    len := length(aUserInfo)+1;
    GetMem(pwUserInfo,len*size_wchar);
    //pwUserInfo := StringToWideChar(aUserInfo,pwUserInfo,len);
    StrPCopy(pwUserInfo, aUserInfo);

    if (not SQLite_BindValue(pwStringSID, pwUserInfo, aSIDType)) then
        begin
        fillchar(m_pErrorInfo^,sizeof(TDBERRORINFO),0);
        SQLite_GetLastError(M_pErrorInfo);
        raise ESQLiteError.Create('Ошибка обращения к библиотеке'+
                            #13#10 + WideCharToString(m_pErrorInfo.Description));
        end;
    except
        on EOutOfMemory do
            raise ESQLiteError.Create(ERROR_OUT_OF_MEM,0);
        on ESQLiteError do raise;
        else raise ESQLiteError.Create('Неизвестная ошибка в TSQLLiteDB.InsertToDB');
    end;

finally
    FreeMem(pwStringSID);
    FreeMem(pwUserInfo);
end;
end;
{$endregion}
{==============================================================================}
{$region 'TFMCache Methods'}
constructor TFMCache.Create;
begin
    inherited create;
    self.m_Ptr := VirtualAlloc(nil,FMCACHE_MAXMEM_SIZE,MEM_COMMIT,PAGE_READWRITE);
    // изучить http://www.delphikingdom.com/asp/viewitem.asp?catalogid=1322

    self.m_StartAddr := self.m_Ptr;
    self.m_CurrentEnd := self.m_Ptr;
    self.m_EndAddr := PFMCItem(DWORD(self.m_Ptr)+FMCACHE_MAXMEM_SIZE);
end;
destructor TFMCache.Destroy;
var
  LocalPtr: PFMCItem;
begin
  if (self.m_CurrentEnd <> self.m_StartAddr) then
    begin
    LocalPtr := self.m_StartAddr;
    repeat
      if LocalPtr^._String <> '' then LocalPtr^._String := '';
      inc(LocalPtr);
    until (LocalPtr = self.m_CurrentEnd);
    end;

  VirtualFree(self.m_Ptr,FMCACHE_MAXMEM_SIZE,MEM_RELEASE);

  self.m_StartAddr := nil;
  //LocalPtr := nil;
  self.m_CurrentEnd := nil;
  self.m_EndAddr := nil;

    inherited destroy;
end;
function TFMCache.Find(const aValue: DWORD; var aStr: string; var aSize: integer):integer;
var
    OnFind:boolean;
    LocalPtr : PFMCItem;
begin
    Result := RTCACHE_FIND;
    aSize := 0;
    //OnFind := false;

    if self.m_CurrentEnd = self.m_StartAddr then //List pustoy
        begin
        Result := RTCACHE_LIST_EMPTY;
        exit
        end;

    LocalPtr := self.m_StartAddr;
    repeat
        OnFind := (aValue = LocalPtr^._ID);
        inc(LocalPtr);
    until OnFind or (LocalPtr = self.m_CurrentEnd);
    if OnFind then
        begin
        dec(LocalPtr);
        aStr := copy(LocalPtr._String,1,MaxInt);
        aSize := length(aStr)
        end
    else Result := RTCACHE_NOT_FIND;
end;
function TFMCache.Add(const aValue: DWORD; const aStr: string):integer;
begin
    result := RTCACHE_ADD_SUCCESS;
    if self.m_CurrentEnd = self.m_EndAddr then //perepolnenie spiska
        begin
        Result := RTCACHE_ADD_FAILURE;
        exit
        end;

  EnterCriticalSection(FLatch1);
try
  with self.m_CurrentEnd^ do
    begin
    _ID := aValue;
    _String := copy(aStr,1,length(aStr));
    end;
    Inc(self.m_CurrentEnd);
    inc(m_count);
finally
  LeaveCriticalSection(FLatch1);
end;
end;
{$endregion}
{==============================================================================}
{$region 'Init_Deinit'}
initialization
    InitializeCriticalSectionAndSpinCount(FLatch,4000);
    InitializeCriticalSectionAndSpinCount(FLatch1,4000);
    //InitializeCriticalSectionAndSpinCount(FLatch2,4000);

finalization
    DeleteCriticalSection(FLatch);
    DeleteCriticalSection(FLatch1);
    //DeleteCriticalSection(FLatch2);
{$endregion}

end.
