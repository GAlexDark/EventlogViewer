unit networkAPI;

interface
uses
    windows, sysutils, WinSock;
//const
  //INADDR_NONE         = DWORD($FFFFFFFF);
  //INADDR_ANY          = $00000000;
  //ERROR_NA_SUCCESS    = $20000000;
  //ERROR_NA_WSAStartup = $20000001;
  //ERROR_NA_IA_NONE    = $20000002;
  //ERROR_NA_IA_ANY     = $20000003;

type
  ENetApiError = class(Exception)
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

CNetHelper = class
private
    m_WSAData : TWSAData;
    m_hIP     : THandle;
    m_Host    : String;
    m_Addr    : string;

public
  constructor Create;
  destructor Destroy; override;
  function Ping(var AddrType: string):integer;
  procedure GetNameOfLocalComputer();
  procedure GetNameFromIP();
  procedure GetIPFromName();

  property HostName: String read m_Host write m_Host;
  property Address: String read m_Addr write m_Addr;

end;

function GetListOfDCs(const aDomain: string): string; //FDN - name
function GetDNSDomainName(var DomainName,DnsForestName: string; var error: DWORD): DWORD;
function GetNameOfLocalComputer(var aHostName: string): Boolean;
function OSCheck(const aServerName:string = ''):DWORD;

function GetNameFromIP(const aIPAddress: AnsiString; var aHostName: AnsiString):boolean;
function GetIPFromName(const aHostName: AnsiString; var aIPAddress:AnsiString): boolean;

implementation
uses
     Classes;

const
  WINSOCK_VERSION          = $0101;
  RES_UNKNOWN              = 'Not Find';
  LDAP_PATH                = '_ldap._tcp.dc._msdcs.';
  DNS_ATMA_MAX_ADDR_LENGTH = 20;
  DNS_TYPE_SRV	           = $0021;
  DNS_QUERY_STANDARD       = 0;
{
  u_char  = Char;
  u_short = Word;
  u_int   = Integer;
  u_long  = Longint;
}
type

  NET_API_STATUS = DWORD;
  PVOID = Pointer;

{$region 'DNS types'}
  {--- DNS types ---}
  DNS_FREE_TYPE = (
    DnsFreeFlat,
    DnsFreeRecordList,
    DnsFreeParsedMessageFields
    );

  DNS_STATUS = LongInt;
  IP4_ADDRESS = DWORD;
  IP6_ADDRESS = array[0..3] of dword;
  DNS_AAAA_DATA = IP6_ADDRESS;
  DNS_A_DATA = IP4_ADDRESS;
  DNS_PTR_DATA = PWideChar;
  DNS_PTR_DATAA = DNS_PTR_DATA;

  PIP4_ARRAY = ^IP4_ARRAY;
  IP4_ARRAY = record
    AddrCount: DWORD;
    AddrArray: array[0..10] of IP4_ADDRESS; //[0..10]
  end;

  DNS_RECORD_FLAGS = record
    Section: DWORD;
    Delete: DWORD;
    CharSet: DWORD;
    Unused: DWORD;
    Reserved: DWORD;
  end;
  TFlags = record
    case Integer of
      1: (DW: DWORD);
      2: (S: ^DNS_RECORD_FLAGS);
  end;

  DNS_SOA_DATAA = record
    pNamePrimaryServer: PChar;
    pNameAdministrator: PChar;
    dwSerialNo: DWORD;
    dwRefresh: DWORD;
    dwRetry: DWORD;
    dwExpire: DWORD;
    dwDefaultTtl: DWORD;
  end;

  DNS_MINFO_DATAA = record
    pNameMailbox: PChar;
    pNameErrorsMailbox: PChar;
  end;
  DNS_MX_DATAA = record
    pNameExchange: PChar;
    wPreference: Word;
    Pad: Word;
  end;
  DNS_TXT_DATAA = record
    dwStringCount: DWORD;
    pStringArray: array[0..10] of PChar;
  end;
  DNS_NULL_DATA = record
    dwByteCount: DWORD;
    Data: array[0..10] of Byte;
  end;
  DNS_WKS_DATA = record
    IpAddress: IP4_ADDRESS;
    chProtocol: UCHAR;
    BitMask: array[0..0] of Byte;       // BitMask[1];
  end;

  DNS_KEY_DATA = record
    wFlags: Word;
    chProtocol: Byte;
    chAlgorithm: Byte;
    Key: array[0..0] of Byte;
  end;
  DNS_SIG_DATAA = record
    pNameSigner: PChar;
    wTypeCovered: Word;
    chAlgorithm: Byte;
    chLabelCount: Byte;
    dwOriginalTtl: DWORD;
    dwExpiration: DWORD;
    dwTimeSigned: DWORD;
    wKeyTag: Word;
    Pad: Word;                          // keep Byte field aligned
    Signature: array[0..0] of Byte;
  end;
  DNS_ATMA_DATA = record
    AddressType: Byte;
    Address: array[0..(DNS_ATMA_MAX_ADDR_LENGTH - 1)] of Byte;
  end;
  DNS_NXT_DATAA = record
    pNameNext: PChar;
    wNumTypes: Word;
    wTypes: array[0..1] of Word;
  end;
  DNS_SRV_DATAA = record
    pNameTarget: PChar;
    wPriority: Word;
    wWeighty: Word;
    wPorty: Word;
    Pady: Word;                         // keep ptrs DWORD aligned
  end;
  DNS_TKEY_DATAA = record
    pNameAlgorithm: PChar;
    pAlgorithmPacket: ^Byte;
    pKey: ^Byte;
    pOtherData: ^Byte;
    dwCreateTime: DWORD;
    dwExpireTime: DWORD;
    wMode: Word;
    wError: Word;
    wKeyLength: Word;
    wOtherLength: Word;
    cAlgNameLength: UCHAR;
    bPacketPointers: Boolean;
  end;
  DNS_TSIG_DATAA = record
    pNameAlgorithm: PChar;
    pAlgorithmPacket: ^Byte;
    pSignature: ^Byte;
    pOtherData: ^Byte;
    i64CreateTime: longlong;
    wFudgeTime: Word;
    wOriginalXid: Word;
    wError: Word;
    wSigLength: Word;
    wOtherLength: Word;
    cAlgNameLength: UCHAR;
    bPacketPointers: Boolean;
  end;
  DNS_WINS_DATA = record
    dwMappingFlag: DWORD;
    dwLookupTimeout: DWORD;
    dwCacheTimeout: DWORD;
    cWinsServerCount: DWORD;
    WinsServers: array[0..0] of IP4_ADDRESS;
  end;
  DNS_WINSR_DATA = record
    dwMappingFlag: DWORD;
    dwLookupTimeout: DWORD;
    dwCacheTimeout: DWORD;
    pNameResultDomain: PWideChar;
  end;
  TDataA = record
    case Integer of
      1: (A: DNS_A_DATA);
      2: (SOA: DNS_SOA_DATAA);
      3: (PTR: DNS_PTR_DATAA);
      4: (MINFO: DNS_MINFO_DATAA);
      5: (MX: DNS_MX_DATAA);
      6: (HINFO: DNS_TXT_DATAA);
      7: (Null: DNS_NULL_DATA);
      8: (WKS: DNS_WKS_DATA);
      9: (AAAA: DNS_AAAA_DATA);
      10: (KEY: DNS_KEY_DATA);
      11: (SIG: DNS_SIG_DATAA);
      12: (ATMA: DNS_ATMA_DATA);
      13: (NXT: DNS_NXT_DATAA);
      14: (SRV: DNS_SRV_DATAA);
      15: (TKEY: DNS_TKEY_DATAA);
      16: (TSIG: DNS_TSIG_DATAA);
      17: (DWINS: DNS_WINS_DATA);
      18: (WINSR: DNS_WINSR_DATA);
  end;

  PDNS_RECORDA = ^DNS_RECORDA;
  DNS_RECORDA = record
    pnext: PDNS_RECORDA;
    pName: PChar;
    wType: Word;
    wDataLength: Word;
    flags: TFlags;
    dwTtl: DWORD;
    dwReserved: DWORD;
    Data: TDataA;
  end;
  {-----------------}
{$endregion}

  PServerInfo101 = ^SERVER_INFO_101;
  SERVER_INFO_101 = record
    sv101_platform_id    : DWORD;
    sv101_name           : LPWSTR;
    sv101_version_major  : DWORD;
    sv101_version_minor  : DWORD;
    sv101_type           : DWORD;
    sv101_comment        : LPWSTR;
  end;

  PDOMAIN_CONTROLLER_INFOW = ^DOMAIN_CONTROLLER_INFOW;
  DOMAIN_CONTROLLER_INFOW = record
    DomainControllerName        : LPWSTR;
    DomainControllerAddress     : LPWSTR;
    DomainControllerAddressType : ULONG;
    DomainGuid                  : TGUID;
    DomainName                  : LPWSTR;
    DnsForestName               : LPWSTR;
    Flags                       : ULONG;
    DcSiteName                  : LPWSTR;
    ClientSiteName              : LPWSTR;
  end;

{------------------------------------------------------------------------------
Информация заголовка IP
(Наполнение этой структуры и формат полей описан в RFC791)
------------------------------------------------------------------------------}
    PIPINFO = ^TIPOptionInformation;
    TIPOptionInformation = packed record
        Ttl         : byte;    // Время жизни (используется traceroute-ом)
        Tos         : byte;    // Тип обслуживания, обычно 0
        Flags       : byte;    // Флаги заголовка IP, обычно 0
        OptionsSize : byte;    // Размер данных в заголовке, обычно 0, максимум 40
        OptionsData : Pointer; // Указатель на данные
    end;

   PIcmpEchoReply = ^TIcmpEchoReply;
   TIcmpEchoReply = packed record
        Address : u_long;      // Адрес отвечающего
        Status  : u_long;     // IP_STATUS (см. ниже)
        RTTime  : u_long;     // Время между эхо-запросом и эхо-ответом
         // в миллисекундах
        DataSize : u_short;      // Размер возвращенных данных
        Reserved : u_short;      // Зарезервировано
        Data : Pointer;  // Указатель на возвращенные данные
        Options : TIPOptionInformation; // Информация из заголовка IP
    end;

{==============================================================================}


  function IcmpCreateFile() : THandle; stdcall; external 'ICMP.DLL' name 'IcmpCreateFile';
  function IcmpCloseHandle(IcmpHandle : THandle) : BOOL; stdcall; external 'ICMP.DLL'  name 'IcmpCloseHandle';
  function IcmpSendEcho(
              IcmpHandle : THandle;    // handle, возвращенный IcmpCreateFile()
              DestAddress : u_long;    // Адрес получателя (в сетевом порядке)
              RequestData : PVOID;     // Указатель на посылаемые данные
              RequestSize : Word;      // Размер посылаемых данных
              RequestOptns : PIPINFO;  // Указатель на посылаемую структуру
                                          // TIPOptionInformation (может быть nil)
              ReplyBuffer : PVOID;     // Указатель на буфер, содержащий ответы.
              ReplySize : DWORD;       // Размер буфера ответов
              Timeout : DWORD          // Время ожидания ответа в миллисекундах
                         ) : DWORD; stdcall; external 'ICMP.DLL' name 'IcmpSendEcho';

//DWORD IcmpSendEcho(
//  __in     HANDLE IcmpHandle,
//  __in     IPAddr DestinationAddress,
//  __in     LPVOID RequestData,
//  __in     WORD RequestSize,
//  __in     PIP_OPTION_INFORMATION RequestOptions,
//  __inout  LPVOID ReplyBuffer,
//  __in     DWORD ReplySize,
//  __in     DWORD Timeout
//);

{-----------------------------------------------------------------------------}
function NetApiBufferAllocate(ByteCount: DWORD;
                              var Buffer: Pointer): NET_API_STATUS; stdcall;
          external 'netapi32.dll' name 'NetApiBufferAllocate';
function NetApiBufferFree(Buffer: Pointer): NET_API_STATUS; stdcall; external 'netapi32.dll';
function NetServerGetInfo(servername: LPWSTR;
                          level: DWORD;
                          var bufptr: Pointer): NET_API_STATUS; stdcall;
          external 'netapi32.dll' name 'NetServerGetInfo';
function DsGetDcNameW(ComputerName: PWideChar;
                      DomainName: PWideChar;
                      DomainGuid: Pointer;
                      SiteName: PWideChar;
                      Flags: Integer;
                      var DomainControllerInfo: PDOMAIN_CONTROLLER_INFOW): DWORD; stdcall;
          external 'Netapi32.dll' name 'DsGetDcNameW';
function DnsQuery_W(pszName: PWideChar;
                    wType: Word;
                    Options: DWORD;
                    aipServers: PIP4_ARRAY;
                    ppQueryResults: Pointer;
                    pReserved: Pointer): DNS_STATUS; stdcall;
          external 'dnsapi.dll' name 'DnsQuery_W';
procedure DnsRecordListFree(pRecordList: PDNS_RECORDA; FreeType: DNS_FREE_TYPE); stdcall; external 'dnsapi.dll';

{==============================================================================}
constructor ENetApiError.Create(const aMsg: String; const aErrorCode, aWin32ErrorCode: DWORD;
                                    const aDebugData: string = '');
begin
  inherited Create(aMsg);
  fCode := aErrorCode;
  fWin32ErrorCode := aWin32ErrorCode;
  if Length(aDebugData) <> 0 then fData := Copy(aDebugData,1,INFINITE);
end;

{==============================================================================}

function GetNameOfLocalComputer(var aHostName: string): Boolean;
var
  Size: DWord;
begin
  Size := MAX_PATH-1;
  SetLength(aHostName,Size);
  Result := GetComputerName(PChar(aHostName),Size);
  if Result then SetLength(aHostName,Size)
  else RaiseLastOSError;
end;

{==============================================================================}
function GetListOfDCs(const aDomain: string): string;
var
  pQueryResultsSet,ptr: PDNS_RECORDA;
  Req: string;
begin
  Req := LDAP_PATH + aDomain;
  pQueryResultsSet := nil;
  //nslookup -q=srv _ldap._tcp.dc._msdcs.org.domain
try
  if DnsQuery_W(pchar(Req), DNS_TYPE_SRV, DNS_QUERY_STANDARD,
              nil, @pQueryResultsSet, nil) = 0 then
    begin
    ptr := pQueryResultsSet;
    Result := '';
    while ptr <> nil do
      begin
      if ptr^.wType = DNS_TYPE_SRV then
          Result := Result+ptr^.Data.SRV.pNameTarget + ';';
      ptr := ptr^.pnext
      end;
    end;
finally
    DNSRecordListFree(pQueryResultsSet,DnsFreeFlat);
end;
end;

function GetDNSDomainName(var DomainName, DnsForestName: string; var error: DWORD): DWORD;
var
    lpNameBuffer: PDOMAIN_CONTROLLER_INFOW;
begin
  try
    NetApiBufferAllocate(1000,pointer(lpNameBuffer));
    result := DsGetDcNameW(nil,nil,nil,nil,0,lpNameBuffer);
    if Result = ERROR_SUCCESS then
      begin
      DomainName := lpNameBuffer^.DomainName;
      DnsForestName := lpNameBuffer^.DnsForestName;
      end;
    error:=GetLastError;
  finally
    NetApiBufferFree(lpNameBuffer);
  end;

end;

function OSCheck(const aServerName: string = ''):DWORD;
const
    level :DWORD = 101;
    NERR_SUCCESS = 0;
var
    res          : NET_API_STATUS;
    wcServerName : PWideChar;
    bufptr       :pointer;
    myInfo       :PServerInfo101;
begin
{
-----------------------+-----------------+------------------------+
Operating system	     |  Version number |  My ID's               |
-----------------------+-----------------+-----+------------------+
Windows 7              |       6.1       |  61 |                  |
Windows Server 2008 R2 |	     6.1       |  61 |                  |
Windows Server 2008    |       6.0       |  60 | osfVistaAndLater |
Windows Vista          |       6.0       |  60 |                  |
-----------------------+-----------------+-----+------------------+
Windows Server 2003 R2 |       5.2       |  52 |                  |
Windows Server 2003    |       5.2       |  52 | osfPreVista      |
Windows XP             |       5.1       |  51 |                  |
-----------------------+-----------------+-----+------------------+
Windows 2000           |       5.0       |  50 | osf2000          |
-----------------------+-----------------+-----+------------------+
}
    Result:=0;
    wcServerName := nil;
try
    res := NetApiBufferAllocate(1024,bufptr);
    if res <> NERR_SUCCESS then exit;

    if aServerName <> '' then
        begin //remote host
        GetMem(wcServerName,(Length(aServerName)+1)*2);
        //StringToWideChar(aServerName, wcServerName,(Length(aServerName)+1)*2);
        StrPCopy(wcServerName,aServerName);

        res := NetServerGetInfo(wcServerName, level, bufptr);
        end
    else
        begin //local host
        res := NetServerGetInfo(nil, level, bufptr);
        end;

        if res <> NERR_SUCCESS then
          RaiseLastOSError;

    myInfo := bufptr;
    Result := (myInfo.sv101_version_major shl 3)
                  + (myInfo.sv101_version_major shl 1)
                  + (myInfo.sv101_version_minor)
finally
    NetApiBufferFree(bufptr);
    FreeMem(wcServerName);
end;
end;

{ TNetHelper }

constructor CNetHelper.Create;
begin
    WSASetLastError(WSANOTINITIALISED);
    if WSAStartup(WINSOCK_VERSION, m_WSAData) <> ERROR_SUCCESS then
      RaiseLastOSError(WSAGetLastError());

    m_hIP := INVALID_HANDLE_VALUE;
end;

destructor CNetHelper.Destroy;
begin
    try
        if m_hIP <> INVALID_HANDLE_VALUE then
            IcmpCloseHandle(m_hIP);
        m_hIP := INVALID_HANDLE_VALUE;
        WSACleanup;
    except
    end;
end;

function CNetHelper.Ping(var AddrType: string):integer;
var
    SendData  : array [0..31] of AnsiChar;
    pIpe      : PIcmpEchoReply;
    replySize : DWORD;
    dwRetVal  : DWORD;
    ipaddr    : Integer;
    i: Integer;
    flag: Boolean;

begin
    pIpe := nil;
    SetLastError(ERROR_SUCCESS);
try
    m_hIP := IcmpCreateFile();
    if m_hIP = INVALID_HANDLE_VALUE then
        RaiseLastOSError;

    replySize := sizeof(TIcmpEchoReply) + sizeof(SendData);

    system.GetMem(pIpe, replySize); // throw EOutOfMemory

    pIpe.Data := @SendData;
    pIpe.DataSize := sizeof(SendData);

      with TStringList.Create do
        begin
        try
        Delimiter := ';';
        DelimitedText := m_Addr;

        flag := False;
        for I := 0 to Count - 1 do
          begin
          ipaddr := inet_addr(PAnsiChar(AnsiString(Strings[i])));
          if ipaddr = 16777343 then
            begin
            AddrType := 'Локальный интерфейс 127.0.0.1';
            Continue;
            end;

          if ipaddr = -1 then  // -1 Error
            begin
            AddrType := 'Ошибка в адресе: ' + Strings[i];
            Continue;
            end;

          if ipaddr = INADDR_ANY then //0 все интерфейсы на компьютере
            begin
            AddrType := 'Все сетевые интерфейсы';
            Continue;
            end;

          SetLastError(ERROR_SUCCESS);
          dwRetVal := IcmpSendEcho(m_hIP,
                                 ipaddr,
                                 @SendData,
                                 sizeof(SendData),
                                 nil,
                                 pIpe,
                                 replySize, 1000);

          if dwRetVal = 0 then
            RaiseLastOSError(GetLastError());
          flag := true;

          end; //for
        finally
          Free;
        end;
        end; //with
    if flag then
      Result := pIpe.RTTime
    else raise Exception.Create('Ping error');

finally
    FreeMem(pIpe);
    IcmpCloseHandle(m_hIP);
    m_hIP := INVALID_HANDLE_VALUE;
end;
end;

procedure CNetHelper.GetNameOfLocalComputer;
var
  Size: DWord;
begin
  Size := MAX_PATH-1;
  SetLength(m_Host,Size);
  if GetComputerName(PChar(m_Host),Size) then
    SetLength(m_Host,Size)
  else
    RaiseLastOSError();
end;

procedure CNetHelper.GetNameFromIP();
var
  SockAddrIn: TSockAddrIn;
  HostEnt: PHostEnt;
  ia : Integer;
  i : Integer;
begin
  m_Host := '';
  with TStringList.Create do
    begin
    try
    Delimiter := ';';
    DelimitedText := m_Addr;

    for I := 0 to Count - 1 do
      begin
      WSASetLastError(WSABASEERR);
      ia := inet_addr(pansichar(AnsiString(Strings[i])));
      if (ia <> -1) or (ia <> INADDR_ANY) then
        SockAddrIn.sin_addr.s_addr := ia
      else
        Continue;

      HostEnt := gethostbyaddr(@SockAddrIn.sin_addr.S_addr, 4, AF_INET);
      if HostEnt <> nil then
        begin
        m_Host := m_Host + string(Hostent^.h_name) + ';';
        end //HostEnt <> nil
      else
        Continue;
      end; // for
    finally
      Free;
    end;
    end; // with
  SetLength(m_Host, length(m_Host)-1);
end;

procedure CNetHelper.GetIPFromName();
type
  TaPInAddr = array[0..10] of PInAddr;
  PaPInAddr = ^TaPInAddr;
var
  p: PHostEnt;
  pPtr :PaPInAddr;
  i: integer;
begin
  m_Addr := '';
  WSASetLastError(WSABASEERR);
  p := GetHostByName(pansichar(AnsiString(m_Host)));
  if p = nil then
    RaiseLastOSError(WSAGetLastError())
  else
    begin
    pPtr := PaPInAddr(p^.h_addr_list);
    i := 0;
    while pPtr^[i] <> nil do
        begin
        m_Addr := m_Addr + string(inet_ntoa(pptr^[i]^)) + ';';
        Inc(i);
        end;
    SetLength(m_Addr, length(m_Addr)-1); //убираем хвостовой ';'
    end;

end;

//=====
function GetNameFromIP(const aIPAddress: AnsiString; var aHostName:AnsiString):boolean;
var
  Res: Integer;
  SockAddrIn: TSockAddrIn;
  HostEnt: PHostEnt;
  WSAData: TWSAData;
begin
  Result := False;
try
  Res := WSAStartup(WINSOCK_VERSION, WSAData);
  if not Boolean(Res) then
    begin
    SockAddrIn.sin_addr.s_addr := inet_addr(PAnsiChar(aIPAddress));
    HostEnt := gethostbyaddr(@SockAddrIn.sin_addr.S_addr, 4, AF_INET);
    if HostEnt <> nil then
      begin
      aHostName := Hostent^.h_name;
      Result := true
      end; //HostEnt <> nil
    end; //not Boolean(Res)
finally
    WSACleanup;
end;
end;

function GetIPFromName(const aHostName: AnsiString; var aIPAddress:AnsiString ): boolean;
type
  TaPInAddr = array[0..10] of PInAddr;
  PaPInAddr = ^TaPInAddr;
var
  WSAData: TWSAData;
  p: PHostEnt;
  pPtr :PaPInAddr;
  Res,i: integer;
  error:DWORD;
  Buffer: PAnsiChar;
  Name : string;
begin
  Result := False;
try
  res := WSAStartup(WINSOCK_VERSION, WSAData);
  if not Boolean(Res) then
    begin
    if aHostName = '' then
      begin
      if GetNameOfLocalComputer(name) then Buffer := PAnsiChar(AnsiString(Name))
      else
        begin
        Result := false;
        exit
        end;
      end
    else Buffer := PAnsiChar(aHostName);
    p := GetHostByName(Buffer);
    error := GetLastError();
    if error = ERROR_SUCCESS then
      begin
      pPtr := PaPInAddr(p^.h_addr_list);
      i := 0;
      while pPtr^[i] <> nil do
        begin
        aIPAddress := inet_ntoa(pptr^[i]^);
        Inc(i);
        end;
      Result := true
      end; //error = ERROR_SUCCESS

    end; //not Boolean(Res)
finally
  WSACleanup;
end;
end;

end.
