unit DsUtils;

interface

uses
  Windows, ActiveX, SysUtils,classes;

const
  CLSID_DsObjectPicker: TGUID = (
    D1:$17d6ccd8; D2:$3b7b; D3:$11d2; D4:($b9,$e0,$00,$c0,$4f,$d8,$db,$f7));

  IID_IDsObjectPicker: TGUID = (
    D1:$0c87e64e; D2:$3b7a; D3:$11d2; D4:($b9,$e0,$00,$c0,$4f,$d8,$db,$f7));

type
  LPLPWSTR = ^PWideChar;

  TDsOpUpLevelFilterFlags = record
    flBothModes      : ULONG;
    flMixedModeOnly  : ULONG;
    flNativeModeOnly : ULONG;
  end;

  TDsOpFilterFlags = record
    Uplevel: TDsOpUpLevelFilterFlags;
    flDownlevel: ULONG;
  end;

  PDsOpScopeInitInfo = ^TDsOpScopeInitInfo;
  TDsOpScopeInitInfo = record
    cbSize      : ULONG;
    flType      : ULONG;
    flScope     : ULONG;
    FilterFlags : TDsOpFilterFlags;
    pwzDcName   : PWideChar;
    pwzADsPath  : PWideChar;
    hr          : HRESULT;
  end;

  TDsOpInitInfo = record
    cbSize             : ULONG;
    pwzTargetComputer  : PWideChar;
    cDsScopeInfos      : ULONG;
    aDsScopeInfos      : PDsOpScopeInitInfo;
    flOptions          : ULONG;
    cAttributesToFetch : ULONG;
    apwzAttributeNames : LPLPWSTR;
  end;

  IDsObjectPicker = interface (IUnknown)
  ['{0c87e64e-3b7a-11d2-b9e0-00c04fd8dbf7}']
    function Initialize(const pInitInfo: TDsOpInitInfo): HRESULT; stdcall;
    function InvokeDialog(hwndParent: HWND; out ppdoSelections: IDataObject): HRESULT; stdcall;
  end;

function InitObjectPicker(Picker: IDsObjectPicker): HRESULT;
function ProcessSelectedObjects(DatObj: IDataObject; var Text: string): HRESULT;

function GetListOfCompurersFromOU(var List: tstringlist):Boolean;
function GetLDAPPathFromOU: string;
function NextNode_Computer(PAPath: String;  var aList: string;
                            var FLastError : string): boolean;

implementation
uses
  dialogs, ActiveDs_TLB,Variants;
const
  CFSTR_DSOP_DS_SELECTION_LIST = 'CFSTR_DSOP_DS_SELECTION_LIST';
  ANYSIZE_ARRAY                = 1;

// DSBROWSEINFO flags
  DSBI_NOBUTTONS          = $00000001; // NOT TVS_HASBUTTONS
  DSBI_NOLINES            = $00000002; // NOT TVS_HASLINES
  DSBI_NOLINESATROOT      = $00000004; // NOT TVS_LINESATROOT
  DSBI_CHECKBOXES         = $00000100; // TVS_CHECKBOXES
  DSBI_NOROOT             = $00010000; // don't include pszRoot in tree (its children become top level nodes)
  DSBI_INCLUDEHIDDEN      = $00020000; // display hidden objects
  DSBI_EXPANDONOPEN       = $00040000; // expand to the path specified in pszPath when opening the dialog
  DSBI_ENTIREDIRECTORY    = $00090000; // browse the entire directory (defaults to having DSBI_NOROOT set)
  DSBI_RETURN_FORMAT      = $00100000; // dwReturnFormat field is valid
  DSBI_HASCREDENTIALS     = $00200000; // pUserName & pPassword are valid
  DSBI_IGNORETREATASLEAF  = $00400000; // ignore the treat as leaf flag when calling IsClassContainer
  DSBI_SIMPLEAUTHENTICATE = $00800000; // don't use secure authentication to DS
  DSBI_RETURNOBJECTCLASS  = $01000000; // return object class of selected object
  DSBI_DONTSIGNSEAL       = $02000000; // don't sign+seal communication with DS
  DSB_MAX_DISPLAYNAME_CHARS = 64;
  ADS_FORMAT_X500 = 5;
// this message is sent to the callback to see if it wants to insert or modify
// the item that is about to be inserted into the view.
//

  DSBM_QUERYINSERTW = 100; // lParam = PDSBITEMW (state, icon & name may be modified). Return TRUE if handled.
  DSBM_QUERYINSERT  = DSBM_QUERYINSERTW;
  DSBS_ROOT         = $00000004;

{---- Флаги, влияющие на поле "Размещение" ----}
  DSOP_SCOPE_TYPE_TARGET_COMPUTER              = $00000001;
  DSOP_SCOPE_TYPE_UPLEVEL_JOINED_DOMAIN        = $00000002;
  DSOP_SCOPE_TYPE_DOWNLEVEL_JOINED_DOMAIN      = $00000004;
  DSOP_SCOPE_TYPE_ENTERPRISE_DOMAIN            = $00000008;
  DSOP_SCOPE_TYPE_GLOBAL_CATALOG               = $00000010; //Узел "Entrie Directory"
  DSOP_SCOPE_TYPE_EXTERNAL_UPLEVEL_DOMAIN      = $00000020;
  DSOP_SCOPE_TYPE_EXTERNAL_DOWNLEVEL_DOMAIN    = $00000040;
  DSOP_SCOPE_TYPE_WORKGROUP                    = $00000080;
  DSOP_SCOPE_TYPE_USER_ENTERED_UPLEVEL_SCOPE   = $00000100;
  DSOP_SCOPE_TYPE_USER_ENTERED_DOWNLEVEL_SCOPE = $00000200;

  DSOP_SCOPE_FLAG_STARTING_SCOPE               = $00000001;
  DSOP_SCOPE_FLAG_WANT_PROVIDER_WINNT          = $00000002;
  DSOP_SCOPE_FLAG_WANT_PROVIDER_LDAP           = $00000004;
  DSOP_SCOPE_FLAG_WANT_PROVIDER_GC             = $00000008;
  DSOP_SCOPE_FLAG_WANT_SID_PATH                = $00000010;
  DSOP_SCOPE_FLAG_WANT_DOWNLEVEL_BUILTIN_PATH  = $00000020;
  DSOP_SCOPE_FLAG_DEFAULT_FILTER_USERS         = $00000040;
  DSOP_SCOPE_FLAG_DEFAULT_FILTER_GROUPS        = $00000080; //Группы
  DSOP_SCOPE_FLAG_DEFAULT_FILTER_COMPUTERS     = $00000100;
  DSOP_SCOPE_FLAG_DEFAULT_FILTER_CONTACTS      = $00000200;



  DSOP_FILTER_INCLUDE_ADVANCED_VIEW  = 1;
  DSOP_FILTER_USERS                  = 2;
  DSOP_FILTER_BUILTIN_GROUPS         = 4;  //Группы
  DSOP_FILTER_WELL_KNOWN_PRINCIPALS  = 8;
  DSOP_FILTER_UNIVERSAL_GROUPS_DL    = 16;
  DSOP_FILTER_UNIVERSAL_GROUPS_SE    = 32;
  DSOP_FILTER_GLOBAL_GROUPS_DL       = 64;
  DSOP_FILTER_GLOBAL_GROUPS_SE       = 128;
  DSOP_FILTER_DOMAIN_LOCAL_GROUPS_DL = 256;
  DSOP_FILTER_DOMAIN_LOCAL_GROUPS_SE = 512;
  DSOP_FILTER_CONTACTS               = 1024;
  DSOP_FILTER_COMPUTERS              = 2048;

{---- Флаги, влияющие на поле "Выберите тип обьекта" ----}
  DSOP_DOWNLEVEL_FILTER_USERS                  = DWORD($80000001);
  DSOP_DOWNLEVEL_FILTER_LOCAL_GROUPS           = $80000002; //Групы
  DSOP_DOWNLEVEL_FILTER_GLOBAL_GROUPS          = $80000004;
  DSOP_DOWNLEVEL_FILTER_COMPUTERS              = $80000008;
  DSOP_DOWNLEVEL_FILTER_WORLD                  = $80000010;
//Начало группы "Встроенные участники безопасности"
  DSOP_DOWNLEVEL_FILTER_AUTHENTICATED_USER     = $80000020;
  DSOP_DOWNLEVEL_FILTER_ANONYMOUS              = $80000040;
  DSOP_DOWNLEVEL_FILTER_BATCH                  = $80000080;
  DSOP_DOWNLEVEL_FILTER_CREATOR_OWNER          = $80000100;
  DSOP_DOWNLEVEL_FILTER_CREATOR_GROUP          = $80000200;
  DSOP_DOWNLEVEL_FILTER_DIALUP                 = $80000400;
  DSOP_DOWNLEVEL_FILTER_INTERACTIVE            = $80000800;
  DSOP_DOWNLEVEL_FILTER_NETWORK                = $80001000;
  DSOP_DOWNLEVEL_FILTER_SERVICE                = $80002000;
  DSOP_DOWNLEVEL_FILTER_SYSTEM                 = $80004000;
  DSOP_DOWNLEVEL_FILTER_EXCLUDE_BUILTIN_GROUPS = $80008000;
  DSOP_DOWNLEVEL_FILTER_TERMINAL_SERVER        = $80010000;
  DSOP_DOWNLEVEL_FILTER_ALL_WELLKNOWN_SIDS     = $80020000;
  DSOP_DOWNLEVEL_FILTER_LOCAL_SERVICE          = $80040000;
  DSOP_DOWNLEVEL_FILTER_NETWORK_SERVICE        = $80080000;
  DSOP_DOWNLEVEL_FILTER_REMOTE_LOGON           = $80100000;
//Конец группы "Встроенные участники безопасности"
  DSOP_DOWNLEVEL_FILTER_INTERNET_USER          = $80200000;
  DSOP_DOWNLEVEL_FILTER_OWNER_RIGHTS           = $80400000;
  DSOP_DOWNLEVEL_FILTER_SERVICES               = $80800000;

  DSOP_FLAG_MULTISELECT                        = $00000001;
  DSOP_FLAG_SKIP_TARGET_COMPUTER_DC_CHECK      = $00000002;

type
  TDsSelection = record
    pwzName               : PWideChar;
    pwzADsPath            : PWideChar;
    pwzClass              : PWideChar;
    pwzUPN                : PWideChar;
    pvarFetchedAttributes : POleVariant;
    flScopeType           : ULONG;
  end;

  PDSSelectionList = ^TDsSelectionList;
  TDsSelectionList = record
    cItems             : ULONG;
    cFetchedAttributes : ULONG;
    aDsSelection       : array [0..ANYSIZE_ARRAY - 1] of TDsSelection;
  end;

  PIEnumVARIANT=^IEnumVARIANT;

  TBFFCALLBACK = function(hwnd: HWND;
                          msg: UINT;
                          lParam,lpData: LPARAM): Integer; stdcall;

  PDSBROWSEINFOW = ^TDSBROWSEINFOW;
  TDSBROWSEINFOW = record
    cbStruct       : DWORD;        // size of structure in bytes
    hwndOwner      : HWND;         // dialog owner
    pszCaption     : LPCWSTR;      // dialog caption text (can be NULL)
    pszTitle       : LPCWSTR;      // displayed above the tree view control (can be NULL)
    pszRoot        : LPCWSTR;      // ADS path to root (NULL == root of DS namespace)
    pszPath        : LPWSTR;       // [in/out] initial selection & returned path (required)
    cchPath        : ULONG;        // size of pszPath buffer in characters
    dwFlags        : DWORD;
    pfnCallback    : TBFFCALLBACK; // callback function(see SHBrowseForFolder)
    lParam         : LPARAM;       // passed to pfnCallback as lpUserData
    dwReturnFormat : DWORD;        // ADS_FORMAT_* (default is ADS_FORMAT_X500_NO_SERVER)
    pUserName      : LPCWSTR;      // Username and Password to authenticate against DS with
    pPassword      : LPCWSTR;
    pszObjectClass : LPWSTR;       // UNICODE string for the object class
    cchObjectClass : ULONG;
  end;

{==============================================================================}
function ADsOpenObject(lpszPathName: PWideChar;
                        lpszUserName: PWideChar;
                        lpszPassword: PWideChar;
                        dwReserved: DWORD;
                        const riid: TGUID;
                        var ppObject: Pointer): HRESULT; stdcall;
          external 'activeds.dll' name 'ADsOpenObject';
function ADsGetObject(lpszPathName: PWideChar;
                      riid: TIID;
                      var ppObject: Pointer): HRESULT; stdcall;
          external 'Activeds.dll' name 'ADsGetObject';
function ADsBuildEnumerator(pADsContainerL: IADsContainer;
                            ppEnumVariant: PIEnumVARIANT): HRESULT; stdcall;
          external 'activeds.dll' name 'ADsBuildEnumerator';

function ADsEnumerateNext(pEnumVariant: IEnumVARIANT;
                          cElements: ULONG;
                          pvar: POleVariant;
                          pcElementsFetched: PULONG): HRESULT; stdcall;
          external 'activeds.dll' name 'ADsEnumerateNext';
function ADsGetLastError(lpError: PDWORD;
                          lpErrorBuf: PWideChar;
                          dwErrorBufLen: DWORD;
                          lpNameBuf: PWideChar;
                          dwNameBufLen: DWORD): HRESULT; stdcall;
          external 'activeds.dll' name 'ADsGetLastError';
function DsBrowseForContainerW(const pInfo: TDSBROWSEINFOW): Integer; stdcall;
          external 'Dsuiext.dll' name 'DsBrowseForContainerW';
{==============================================================================}
function InitObjectPicker(Picker: IDsObjectPicker): HRESULT;
var
  ScopeInit: array [0..2] of TDSOPScopeInitInfo; // ибъект который указывает что будем выбирать
  InitInfo: TDSOPInitInfo; // информация об инициализации
begin
  if nil = Picker then
    Result := E_INVALIDARG
  else
  begin
    ZeroMemory(@ScopeInit, SizeOf(ScopeInit)); //заполняем нулями
    //где ищем
    //====== TARGET_COMPUTER
    ScopeInit[0].cbSize := sizeof(TDSOPScopeInitInfo);
    ScopeInit[0].flType := DSOP_SCOPE_TYPE_TARGET_COMPUTER;

    ScopeInit[0].flScope := DSOP_SCOPE_FLAG_DEFAULT_FILTER_USERS;

    ScopeInit[0].FilterFlags.Uplevel.flBothModes := DSOP_FILTER_USERS;

    ScopeInit[0].FilterFlags.flDownlevel := DSOP_DOWNLEVEL_FILTER_USERS;
    //======  Forest
    ScopeInit[1].cbSize := sizeof(TDSOPScopeInitInfo);
    ScopeInit[1].flType := DSOP_SCOPE_TYPE_ENTERPRISE_DOMAIN;

    ScopeInit[1].flScope := DSOP_SCOPE_FLAG_DEFAULT_FILTER_USERS or
                            DSOP_SCOPE_FLAG_DEFAULT_FILTER_COMPUTERS;

    ScopeInit[1].FilterFlags.Uplevel.flBothModes := DSOP_FILTER_USERS or
                                                    DSOP_FILTER_COMPUTERS;

    ScopeInit[1].FilterFlags.flDownlevel := DSOP_DOWNLEVEL_FILTER_USERS or
                                            DSOP_DOWNLEVEL_FILTER_COMPUTERS;
    //======  Domain
    ScopeInit[2].cbSize := SizeOf(TDSOPScopeInitInfo); // заполняем структуру TDSOPScopeInitInfo
    ScopeInit[2].flType := DSOP_SCOPE_TYPE_UPLEVEL_JOINED_DOMAIN or
                           DSOP_SCOPE_TYPE_DOWNLEVEL_JOINED_DOMAIN or
                           DSOP_SCOPE_TYPE_EXTERNAL_UPLEVEL_DOMAIN or
                           DSOP_SCOPE_TYPE_EXTERNAL_DOWNLEVEL_DOMAIN;

    ScopeInit[2].flScope := DSOP_SCOPE_FLAG_DEFAULT_FILTER_USERS or
                            DSOP_SCOPE_FLAG_DEFAULT_FILTER_COMPUTERS or
                            DSOP_SCOPE_FLAG_STARTING_SCOPE;

    ScopeInit[2].FilterFlags.Uplevel.flBothModes := DSOP_FILTER_USERS or
                                                    DSOP_FILTER_COMPUTERS;

    ScopeInit[2].FilterFlags.flDownlevel := DSOP_DOWNLEVEL_FILTER_USERS or
                                            DSOP_DOWNLEVEL_FILTER_COMPUTERS;
    //======
    ZeroMemory(@InitInfo, SizeOf(InitInfo));// заполняем структуру TDSOPInitInfo
    InitInfo.cbSize := SizeOf(InitInfo);
    InitInfo.cDsScopeInfos := SizeOf(ScopeInit) div SizeOf(TDSOPScopeInitInfo);
    {$T-}
    InitInfo.aDsScopeInfos := @ScopeInit;
    {$T+}
    InitInfo.flOptions := DSOP_FLAG_MULTISELECT or DSOP_FLAG_SKIP_TARGET_COMPUTER_DC_CHECK;

// инициализируем объект выбора
    Result := Picker.Initialize(InitInfo);
  end;
end; 

function ProcessSelectedObjects(DatObj: IDataObject; var Text: string): HRESULT;
var
  StgMed: TStgMedium; //объект хранения данных
  FmtEtc: TFormatEtc;  //формат ыввода данных
  SelLst: PDSSelectionList;  //выбранные объекты
  Index: ULONG;

  sClass: string;
  sLogin: string;
begin 
//проверка на "дурака" 
 if nil = DatObj then 
    Result := E_INVALIDARG 
  else 
  begin
    with FmtEtc do 
    begin 
//регистрируем формат вывода данных
      cfFormat := RegisterClipboardFormat(CFSTR_DSOP_DS_SELECTION_LIST);
      ptd      := nil; 
      dwAspect := DVASPECT_CONTENT;
      lindex   := -1; 
      tymed    := TYMED_HGLOBAL; 
    end; 
    Result := DatObj.GetData(FmtEtc, StgMed);
    if Succeeded(Result) then
    begin 
//получаем результат вызора в удобоваримом формате
      SelLst := PDsSelectionList(GlobalLock(StgMed.hGlobal)); 
// и если не nil обрабатываем его
      if SelLst <> nil then 
      try 
        Text := '';
        for Index := 0 to SelLst.cItems - 1 do
        begin
          sClass := WideCharToString(SelLst.aDsSelection[Index].pwzClass);
          sClass := AnsiUpperCase(sClass);
          if  sClass = 'USER' then
            begin
            sLogin := WideCharToString(SelLst.aDsSelection[Index].pwzUPN);
            if length(sLogin) <> 0 then
              sLogin := copy(sLogin,1,pos('@',sLogin)-1)
            else sLogin := WideCharToString(SelLst.aDsSelection[Index].pwzName);
            end;
          if sClass = 'COMPUTER' then
            begin
            sLogin := WideCharToString(SelLst.aDsSelection[Index].pwzName);
            end;
          Text := Text + Format(
            'Object : %u'#13#10 +
            '  Name : %s'#13#10 +
            '  Class: %s'#13#10 +
            '  Path : %s'#13#10 +
            '  UPN  : %s'#13#10,[
            Index,
            WideCharToString(SelLst.aDsSelection[Index].pwzName),
            sclass,
            WideCharToString(SelLst.aDsSelection[Index].pwzADsPath),
            WideCharToString(SelLst.aDsSelection[Index].pwzUPN)]);
        end;
        ShowMessage(Text);
        Text := sLogin;
      finally 
        GlobalUnlock(StgMed.hGlobal); 
      end
      else
        Result := E_POINTER;

      ReleaseStgMedium(StgMed); 
    end;
  end; 
end;
{==============================================================================}

function GetLDAPPathFromOU: string;
var
  dsbi : TDSBROWSEINFOW;
  wszResult: array[0..MAX_PATH-1] of WideChar;
  res: integer;
  ObjectClass : array[0..MAX_PATH-1] of WideChar;
begin
  ZeroMemory(@dsbi, sizeof(dsbi));
  dsbi.cbStruct := sizeof(dsbi);
  dsbi.pszCaption := pwidechar('The container picker');
  dsbi.pszTitle := pwidechar('Pick a container for this example.');
  dsbi.pszRoot := nil;
  dsbi.pszPath := wszResult;
  dsbi.cchPath := MAX_PATH;
  dsbi.dwFlags := DSBI_ENTIREDIRECTORY or DSBI_EXPANDONOPEN or DSBI_EXPANDONOPEN
                  or DSBI_RETURNOBJECTCLASS;
  dsbi.pszObjectClass := ObjectClass; //тип: контейнер или орг.юнит
  dsbi.cchObjectClass := MAX_PATH;
  res := DsBrowseForContainerW(dsbi);
  if res = IDOK then
    Result := WideCharToString(wszResult);
  //pszPath видa 'LDAP://OU=Servers,OU=location,DC=org,DC=domain'
end;

function NextNode_Computer(PAPath: String; var aList: string;
                            var FLastError : string): boolean;
var objDomain: Pointer;
    objChild:  Pointer;
    hr {, hr1}: HResult;
    SWE, SWP: Array[0.. MAX_PATH] of WideChar; //255
    //PSWE, PSWP: PWideChar;
    s: String;
    i: Integer;
    iArr : OleVariant;
    iEnum: IEnumVARIANT;
    iFetch: ULONG;
    iAPath: String;
begin
  result:=false;
  hr:= ADsOpenObject(PWideChar(PAPath), nil, nil, ADS_SECURE_AUTHENTICATION,
                        IID_IADsContainer, objDomain);
  if hr<>S_OK then
    begin
    for i:=0 to MAX_PATH do //255
      begin
      SWE[i]:=#0;
      SWP[i]:=#0;
      end;
    //PSWE := SWE;
    //PSWP := SWP;
//    if  ADsGetLastError(@dword(hr),PSWE,MAX_PATH+1 ,SWP,MAX_PATH+1)<>S_OK then
//      begin
//      FLastError:='Fail ADsGetLastError';
//      Exit;
//      end;
    s:='';
    for i:=0 to 255 do
      begin
      if SWE[i]=#0 then break;
      s:=s+SWE[i];
      end;
    FLastError:=S;
    if Trim(FLastError)='' then FLastError:='**';
    Exit;
  end;

  hr:=ADsBuildEnumerator(IADsContainer(objDomain), @iEnum);
  if Failed(hr) then
    begin
    FLastError:='Failed ADsBuildEnumerator';
    Exit;
    end;
  hr := ADsEnumerateNext(iEnum, 1, @iArr, @iFetch);
  while (S_OK = hr) and (1 = iFetch) do
    begin
    hr:=IDispatch(iArr).QueryInterface(IADs,objChild);
    if Failed(hr) then
      begin
      FLastError:='Failed QueryInterface';
      Break;
      end;
    if AnsiLowerCase(IAds(objChild).Class_)='computer' then
      begin
      s:=IAds(objChild).Name;
      System.Delete(s,1,3);
      aList := aList + s + ';';
      end;
    if AnsiLowerCase(IAds(objChild).Class_)='organizationalunit' then
    begin
      s:=IAds(objChild).Name;
      iAPath:=PAPAth;
      System.Delete(iAPath, 1, 7);
      iAPath:='LDAP:// '+s+','+iAPath;
      if not NextNode_Computer(iAPath,aList,FLastError) then exit;
    end;
    if AnsiLowerCase(IAds(objChild).Class_)='container' then
    begin
      s:=IAds(objChild).Name;
      iAPath:=PAPAth;
      System.Delete(iAPath, 1, 7);
      iAPath:='LDAP:// '+s+','+iAPath;
      if not NextNode_Computer(iAPath,aList,FLastError) then exit;
    end;
    iArr := null;
    hr := ADsEnumerateNext(iEnum, 1, @iArr, @iFetch);
  end;

  if Failed(hr) then
  begin
    FLastError:='Failed ADsEnumerateNext';
    Exit;
  end;
  Result:=true;
end;

function GetListOfCompurersFromOU(var List: tstringlist):Boolean;
var
  objDomain: Pointer;
  objChild:  Pointer;
  hr: HResult;
  s: String;
  //i: Integer;
  iArr : OleVariant;
  iEnum: IEnumVARIANT;
  iFetch: ULONG;
  //iAPath: String;
  path: PWideChar;

begin
  CoInitialize(nil);
  List.Clear;
  Result := false;

  path := PWideChar(GetLDAPPathFromOU);
  try
//    hr:= ADsGetObject(path, IID_IADsContainer ,objDomain);
  hr:= ADsOpenObject(path, nil, nil, ADS_SECURE_AUTHENTICATION,
                        IID_IADsContainer, objDomain);
  except
    exit;
  end;
  if Failed(hr) then Exit;

  hr:=ADsBuildEnumerator(IADsContainer(objDomain), @iEnum);
  if Failed(hr) then Exit;

  hr := ADsEnumerateNext(iEnum, 1, @iArr, @iFetch);

  while (S_OK = hr) and (1 = iFetch) do
    begin
    hr:=IDispatch(iArr).QueryInterface(IADs,objChild);
    if Failed(hr) then Exit;

    if AnsiLowerCase(IAds(objChild).Class_)='computer' then
      begin
      s:=IAds(objChild).Name;
      System.Delete(s,1,3);
      List.Add(s);
      end;

    if AnsiLowerCase(IAds(objChild).Class_)='organizationalunit' then
      begin
      s:=IAds(objChild).Name;
{
      iAPath:=PAPAth;
      System.Delete(iAPath, 1, 7);
      iAPath:='LDAP:// '+s+','+iAPath;
      if not NextNode_Computer(iAPath) then exit;}
      end;
    if AnsiLowerCase(IAds(objChild).Class_)='container' then
      begin
      //Continue;
{      s:=IAds(objChild).Name;
      iAPath:=PAPAth;
      System.Delete(iAPath, 1, 7);
      iAPath:='LDAP:// '+s+','+iAPath;
      if not NextNode_Computer(iAPath) then exit;}
      end;
    //iArr := nil;
    hr := ADsEnumerateNext(iEnum, 1, @iArr, @iFetch);
  end;
  CoUninitialize();
end;


end.