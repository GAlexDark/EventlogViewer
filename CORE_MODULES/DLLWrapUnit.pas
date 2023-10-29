unit DLLWrapUnit;

interface
uses
  windows, Headers;
const
    ERROR_DESCRIPTION_MAX_SIZE = 512;
    NO_COLUMNS                 = -100;
    END_OF_DATA                = -101;

  sSQLite_GetLastError        = 'SQLite_GetLastError';
  sSQLite_ClearError          = 'SQLite_ClearError';

  sSQLite_Create              = 'SQLite_Create';
  sSQLite_Free                = 'SQLite_Free';
  sSQLite_Connect             = 'SQLite_Connect';
  sSQLite_Disconnect          = 'SQLite_Disconnect';

  sSQLite_Open                = 'SQLite_Open';
  sSQLite_Close               = 'SQLite_Close';
  sSQLite_Inited              = 'SQLite_Inited';

  sSQLite_BeginTransaction    = 'SQLite_BeginTransaction';
  sSQLite_CommitTransaction   = 'SQLite_CommitTransaction';
  sSQLite_RollbackTransaction = 'SQLite_RollbackTransaction';
  sSQLite_Execute             = 'SQLite_Execute';
  sSQLite_PrepareInsert       = 'SQLite_PrepareInsert';
  sSQLite_BindValue           = 'SQLite_BindValue';
  sSQLite_WhoSearch           = 'SQLite_WhoSearch';
  sSQLite_SearchResult        = 'SQLite_SearchResult';
  {
  ExecuteSQLStatement("PRAGMA count_changes = false");
  ExecuteSQLStatement("PRAGMA journal_mode = DELETE");
  ExecuteSQLStatement("PRAGMA synchronous = 0");
  ExecuteSQLStatement("PRAGMA temp_store = MEMORY");
  PRAGMA locking_mode = EXCLUSIVE
  PRAGMA journal_mode = OFF
  PRAGMA count_changes = off
  }


  sMBDBInit         = 'MBDBInit';
  sMBDBInited       = 'MBDBInited';
  sMBDBDeIntit      = 'MBDBDeIntit';
  sMBDBClose        = 'MBDBClose';
  sMBDBAdd          = 'MBDBAdd';
  sMBDBFind         = 'MBDBFind';
  sMBDBGetLastError = 'MBDBGetLastError';
  sMBDBClear        = 'MBDBClear';


type

  PDBERRORINFO = ^TDBERRORINFO;
  TDBERRORINFO = record
      Code, SysCode: Integer;
      Description: array[0.. ERROR_DESCRIPTION_MAX_SIZE-1] of widechar;
  end;

{$region 'SQLite proc'}
   TSQLite_GetLastError        = procedure(dbErrorInfo: PDBERRORINFO); stdcall;
   TSQLite_ClearError          = procedure(); stdcall;

   TSQLite_Create              = function(const ConnectionName: PWideChar):boolean; stdcall;
   TSQLite_Free                = procedure(); stdcall;

   //TSQLite_Connect             = function(const ConnectionString: PWideChar; const PluginName: PWideChar):boolean; stdcall;
   TSQLite_Connect             = function(const ConnectionString, PluginName: WideString):boolean; stdcall;
   TSQLite_Inited              = function():boolean; stdcall;
   TSQLite_Disconnect          = function():boolean; stdcall;
   TSQLite_Open                = function(): Boolean; stdcall;
   TSQLite_Close               = function(): Boolean; stdcall;

   TSQLite_BeginTransaction    = function():boolean; stdcall;
   TSQLite_CommitTransaction   = function():boolean; stdcall;
   TSQLite_RollbackTransaction = function():boolean; stdcall;
   TSQLite_Execute             = function (const SQLString: PWideChar):boolean; stdcall;
   //TSQLite_PrepareInsert       = function(const SQLString: PWideChar):boolean; stdcall;
   TSQLite_PrepareInsert       = function(const SQLString: WideString):boolean; stdcall;
   TSQLite_BindValue           = function(const SID: PWideChar; const UserName: PWideChar; SIDType: dword):boolean; stdcall;
   //TSQLite_WhoSearch           = function(const SQLString: PWideChar):boolean; stdcall;
   TSQLite_WhoSearch           = function(const SQLString: WideString):boolean; stdcall;
   TSQLite_SearchResult        = function(strSID, UserName: PWideChar; var SIDType: dword; var Count: integer):boolean; stdcall;
  {$endregion}

{$region 'BDB proc'}
  TMBDBInit         = function (): Boolean ; stdcall;
  TMBDBInited       = function(): Boolean; stdcall;
  TMBDBDeIntit      = procedure (); stdcall;
  TMBDBClose        = function (): Boolean; stdcall;
//  TMBDBAdd          = function(aSIDLength: DWORD;
//                                aSID: PSID;
//                                aUserInfo: LPWSTR;
//                                aSIDType: DWORD;
//                                aStringSID: LPWSTR): Boolean; stdcall;
  TMBDBAdd          = function(aSIDLength: DWORD;
                                aSID: PSID;
                                aUserInfo: WideString;
                                aSIDType: DWORD;
                                aStringSID: WideString): Boolean; stdcall;
  TMBDBFind         = function(aSID: PSID;
                                var aUserInfo: LPWSTR;
                                UserInfoBufSize: size_t;
                                var aSIDType: DWORD;
                                var aStringSID: LPWSTR;
                                StringSIDBufSize: size_t): Boolean; stdcall;
  TMBDBGetLastError = procedure(dbErrorInfo: PDBERRORINFO); stdcall;
  TMBDBClear        = procedure(); stdcall;
{$endregion}

var
{$region 'SQLite vars'}
   SQLite_GetLastError        : TSQLite_GetLastError;
   SQLite_ClearError          : TSQLite_ClearError;
   SQLite_Create              : TSQLite_Create;
   SQLite_Free                : TSQLite_Free;
   SQLite_Connect             : TSQLite_Connect;
   SQLite_Inited              : TSQLite_Inited;
   SQLite_Disconnect          : TSQLite_Disconnect;
   SQLite_BeginTransaction    : TSQLite_BeginTransaction;
   SQLite_CommitTransaction   : TSQLite_CommitTransaction;
   SQLite_RollbackTransaction : TSQLite_RollbackTransaction;
   SQLite_Execute             : TSQLite_Execute;
   SQLite_PrepareInsert       : TSQLite_PrepareInsert;
   SQLite_BindValue           : TSQLite_BindValue;
   SQLite_WhoSearch           : TSQLite_WhoSearch;
   SQLite_SearchResult        : TSQLite_SearchResult;
   SQLite_Open                : TSQLite_Open;
   SQLite_Close               : TSQLite_Close;
{$endregion}

{$region 'BDB vars'}
  OnMem_BDBInit         : TMBDBInit;
  OnMem_BDBInited       : TMBDBInited;
  OnMem_BDBDeIntit      : TMBDBDeIntit;
  OnMem_BDBClose        : TMBDBClose;
  OnMem_BDBAdd          : TMBDBAdd;
  OnMem_BDBFind         : TMBDBFind;
  OnMem_BDBGetLastError : TMBDBGetLastError;
  OnMem_BDBClear        : TMBDBClear;
{$endregion}

procedure LoadDll(const DllName: string; var hDll:THandle);
procedure UnLoadDll(var hDll: THandle);
procedure GetProcAddr(const hDll: THandle; const ProcName: string; var ProcAddr: Pointer);
procedure ClearSQLiteVars();
procedure ClearBDBVars();

implementation
uses
  sysutils;

resourcestring
    sErrorLoadDll     = 'Невозможно загрузить библиотеку %0:s' + #13#10 + 'Описание: %1:s';
    sErrorUnloadDll   = 'Невозможно выгрузить библиотеку' + #13#10 + 'Описание: %0:s';
    sErrorGetProcAddr = 'Ошибка извлечения адреса экспортируемой функции %0:s' + #13#10 + 'Описание: %1:s';

procedure LoadDll(const DllName: string; var hDll:THandle);
var
    ErrorCode: Cardinal;
begin
  hDll := LoadLibrary(PWideChar(DllName));
    if hDLL = 0 then
      begin
      ErrorCode := GetLastError();
      raise ESysError.Create(ERROR_LOAD_DLL, ErrorCode,format(sErrorLoadDll,[DllName, SysErrorMessage(ErrorCode)]));
      end;
end;
procedure UnLoadDll(var hDll: THandle);
var
    ErrorCode: Cardinal;
begin
    if hDll <> 0 then
        begin
        if (not FreeLibrary(hDll)) then
            begin
            ErrorCode := GetLastError;
            raise ESysError.Create(ERROR_UNLOAD_DLL,ErrorCode,format(sErrorUnloadDll,[SysErrorMessage(ErrorCode)]));
            end
        else hDll := 0;
        end;
end;

procedure GetProcAddr(const hDll: THandle; const ProcName: string; var ProcAddr: Pointer);
var
    ErrorCode: Cardinal;
begin
  ProcAddr := GetProcAddress(hDll, PWideChar(ProcName));
  if (not Assigned(ProcAddr)) then
    begin
    ErrorCode := GetLastError();
    raise ESysError.Create(ERROR_PROC_ADDR,ErrorCode,format(sErrorGetProcAddr,[ProcName, SysErrorMessage(ErrorCode)]));
    end;
end;

procedure ClearSQLiteVars();
begin
   SQLite_GetLastError        := nil;
   SQLite_ClearError          := nil;
   SQLite_Create              := nil;
   SQLite_Free                := nil;
   SQLite_Connect             := nil;
   SQLite_Inited              := nil;
   SQLite_Disconnect          := nil;
   SQLite_BeginTransaction    := nil;
   SQLite_CommitTransaction   := nil;
   SQLite_RollbackTransaction := nil;
   SQLite_Execute             := nil;
   SQLite_PrepareInsert       := nil;
   SQLite_BindValue           := nil;
   SQLite_WhoSearch           := nil;
   SQLite_SearchResult        := nil;
   SQLite_Open                := nil;
   SQLite_Close               := nil;

end;
procedure ClearBDBVars();
begin
    OnMem_BDBInit         := nil;
    OnMem_BDBInited       := nil;
    OnMem_BDBDeIntit      := nil;
    OnMem_BDBClose        := nil;
    OnMem_BDBAdd          := nil;
    OnMem_BDBFind         := nil;
    OnMem_BDBGetLastError := nil;
    OnMem_BDBClear        := nil;
end;
end.
