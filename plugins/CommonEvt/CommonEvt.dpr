library CommonEvt;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  SysUtils,
  Classes,
  windows,
  IdBaseComponent,
  IdComponent,
  IdTCPConnection,
  IdDNSResolver;

{$R *.res}

const
{$ifdef RELEASE}
  cDNS1 = '10.36.1.101';
  cDNS2 = '10.36.1.102';
  cDNS3 = '10.36.241.101';
  cDNS4 = '10.36.241.102';
{$else}
  cDNS5 = '192.168.1.2'; //home use
  cDNS6 = '192.168.1.1'; //home use
{$endif}

type
    Tva_list = array of va_list;
    Pva_list = ^Tva_list;

var
  IP2NameDNSResolver,
  Name2IPDNSResolver: TIdDNSResolver;
  is_inited: boolean = false;

procedure GetVersion(var Major, Minor: Integer);
begin
  Major := 1; //главна€ верси€
  Minor := 1; //подрелиз
  //данные значени€ могут не совпадать с данными в version info файла
end;

function GetDescription(): WideString;
begin
    Result := 'Ѕиблиотека парсера общего назначени€';
end;

function dll_init(): boolean;
begin
  IP2NameDNSResolver := TIdDNSResolver.Create(nil);
  //Name2IPDNSResolver := TIdDNSResolver.Create(nil);
  try
    IP2NameDNSResolver.QueryType := [qtPTR];
    Name2IPDNSResolver.QueryType := [qtA];
    {$ifdef RELEASE}
        IP2NameDNSResolver.Host := cDNS1;
        //Name2IPDNSResolver.Host := cDNS1;
    {$else}
        IP2NameDNSResolver.Host := cDNS5;
        //Name2IPDNSResolver.Host := cDNS5;
    {$endif}
    //IP2NameDNSResolver.WaitingTime := 200; //врем€ ожидани€ в миллисекундах
    //Name2IPDNSResolver.WaitingTime := 200; //врем€ ожидани€ в миллисекундах

    Result := true;
    is_inited := true;
  except
    is_inited := False;
    Result := false; //неудачно инициализировали DNSResolver
  end;
end;

procedure dll_deinit();
begin
  if is_inited then
    begin
    FreeAndNil(IP2NameDNSResolver);
    //FreeAndNil(Name2IPDNSResolver);
    is_inited := False;
    end;
end;

function _GetErrorCodeAsMessage(const Buf: string): string;
begin
    case StrToInt(buf) of
        $0        : result := 'login success (0x0)';
        $C0000064 : Result := 'user name does not exist (0xC0000064)';
        $C000006A : Result := 'user name is correct but the password is wrong (0xC000006A)';
        $C0000234 : Result := 'user is currently locked out (0xC0000234)';
        $C0000072 : Result := 'account is currently disabled (0xC0000072)';
        $C000006F : Result := 'user tried to logon outside his day of week or time of day restrictions (0xC000006F)';
        $C0000070 : Result := 'workstation restriction (0xC0000070)';
        $C0000193 : Result := 'account expiration (0xC0000193)';
        $C0000071 : Result := 'expired password (0xC0000071)';
        $C0000224 : Result := 'user is required to change password at next logon (0xC0000224)';
        $C0000225 : Result := 'evidently a bug in Windows and not a risk (0xC0000225)';
        end; {StrToInt}
end;

function _GetLogonTypeAsMessage(const LogonType: string): string;
begin
    case StrToInt(LogonType) of
    2  : Result := 'Interactive (logon at keyboard and screen of system) (2)';
    3  : Result := 'Network (i.e. connection to shared folder on this computer from elsewhere on network) (3)';
    4  : Result := 'Batch (i.e. scheduled task) (4)';
    5  : Result := 'Service (Service startup) (5)';
    7  : Result := 'Unlock (i.e. unnattended workstation with password protected screen saver) (7)';
    8  : Result := 'NetworkCleartext (Logon with credentials sent in the clear text. Most often indicates a logon to IIS with "basic authentication") (8)';
    9  : Result := 'NewCredentials such as with RunAs or mapping a network drive with alternate credentials.  This logon type does not seem to show up in any events (9)';
    10 : Result := 'RemoteInteractive (Terminal Services, Remote Desktop or Remote Assistance) (10)';
    11 : Result := 'CachedInteractive (logon with cached domain credentials such as when logging on to a laptop when away from the network) (11)';
    end;
end;

function _GetResultCodeAsMessage(const ResultCode: string): string;
begin
    case StrToInt(ResultCode) of
    $0  : result := 'No error (0x0)';
    $1  : result := 'Client''s entry in database has expired (0x1)';
    $2  : result := 'Server''s entry in database has expired (0x2)';
    $3  : result := 'Requested protocol version # not supported (0x3)';
    $4  : result := 'Client''s key encrypted in old master key (0x4)';
    $5  : result := 'Server''s key encrypted in old master key (0x5)';
    $6  : result := 'Client not found in Kerberos database (Bad user name, or new computer/user account has not replicated to DC yet) (0x6)';
    $7  : result := 'Server not found in Kerberos database (New computer account has not replicated yet or computer is pre-w2k) (0x7)';
    $8  : result := 'Multiple principal entries in database (0x8)';
    $9  : result := 'The client or server has a null key (administrator should reset the password on the account) (0x9)';
    $A  : result := 'Ticket not eligible for postdating (0xA)';
    $B  : result := 'Requested start time is later than end time (0xB)';
    $C  : result := 'KDC policy rejects request (Workstation restriction) (0xC)';
    $D  : result := 'KDC cannot accommodate requested option (0xD)';
    $E  : result := 'KDC has no support for encryption type (0xE)';
    $F  : result := 'KDC has no support for checksum type (0xF)';
    $10 : result := 'KDC has no support for padata type (0x10)';
    $11 : result := 'KDC has no support for transited type (0x11)';
    $12 : result := 'Clients credentials have been revoked	Account disabled, expired, locked out, logon hours (0x12)';
    $13 : result := 'Credentials for server have been revoked (0x13)';
    $14 : result := 'TGT has been revoked (0x14)';
    $15 : result := 'Client not yet valid - try again later (0x15)';
    $16 : result := 'Server not yet valid - try again later (0x16)';
    $17 : result := 'Password has expired	The userТs password has expired (0x17)';
    $18 : result := 'Pre-authentication information was invalid (Usually means bad password) (0x18)';
    $19 : result := 'Additional pre-authentication required* (0x19)';
    $1F : result := 'Integrity check on decrypted field failed (0x1F)';
    $20 : result := 'Ticket expired	Frequently logged by computer accounts (0x20)';
    $21 : result := 'Ticket not yet valid (0x21)';
    $22 : result := 'Request is a replay (0x22)';
    $23 : result := 'The ticket isn''t for us (0x23)';
    $24 : result := 'Ticket and authenticator don''t match (0x24)';
    $25 : result := 'Clock skew too great	WorkstationТs clock too far out of sync with the DCТs (0x25)';
    $26 : result := 'Incorrect net address	 IP address change? (0x26)';
    $27 : result := 'Protocol version mismatch (0x27)';
    $28 : result := 'Invalid msg type (0x28)';
    $29 : result := 'Message stream modified (0x29)';
    $2A : result := 'Message out of order (0x2A)';
    $2C : result := 'Specified version of key is not available (0x2C)';
    $2D : result := 'Service key not available (0x2D)';
    $2E : result := 'Mutual authentication failed	 may be a memory allocation failure (0x2E)';
    $2F : result := 'Incorrect message direction (0x2F)';
    $30 : result := 'Alternative authentication method required* (0x30)';
    $31 : result := 'Incorrect sequence number in message (0x31)';
    $32 : result := 'Inappropriate type of checksum in message (0x32)';
    $3C : result := 'Generic error (description in e-text) (0x3C)';
    $3D : result := 'Field is too long for this implementation (0x3D)';
    end;
end;

function _GetStatusAsMessage(const Status: string): string;
begin
    case StrToInt(Status) of
        $C0000234: Result := 'user is currently locked out (C0000234)';
        $C0000193: Result := 'account expiration (C0000193)';
        $C0000133: Result := 'clocks between DC and other computer too far out of sync C0000133';
        $C0000224: Result := 'user is required to change password at next logon (C0000224)';
        $C0000225: Result := 'evidently a bug in Windows and not a risk (C0000225)';
        $C000015B: Result := 'The user has not been granted the requested logon type (aka logon right) at this machine (C000015B)';
        $C000006D: Result := 'This is either due to a bad username or authentication information (C000006D)';
        $C000006E: Result := 'Unknown user name or bad password (C000006E)';
        $C00002EE: Result := 'Failure Reason: An Error occurred during Logon (C00002EE)';
        $C000005E,
        $C00000DC,
        $C0000192,
        $C0000413,
        $C000009A: Result := 'Uncnown status (' + Status + ')';
    end;
end;
function _IP2Name(const Address: string): string;
var
    p,i, len: integer;
    ipbuf, res: string;
begin
    if Length(Address) in [7..22] then //(Length(Address) >= 7) and (Length(Address)<= 22) then
        begin
        p := pos('::ffff:',Address);
        if p > 0 then
            ipbuf := Copy(Address, 8, length(Address)-7)
        else
            ipbuf := Address;

        try
            IP2NameDNSResolver.Resolve(ipbuf);
            res := '';
            with IP2NameDNSResolver.QueryResult do
                begin
                if Count > 0 then
                    begin
                    for I := 0 to Count - 1 do
                        if (Items[i] is TPTRRecord) then
                            begin
                            res := res + (Items[i] as TPTRRecord).HostName+ ', ';
                            end;

                    res := trim(res);
                    len := Length(res);
                    if res[len] = ',' then
                        SetLength(res, len - 1);
                    end
                else
                    Res := ' Not resolved';
                end;

            Res := Address + format(' [%s]',[res]);
        except
            Res := Address + ' [DNS Error]';
        end;
        Result := res;
        end
    else
        Result := Address;
end;

procedure Parse(StatusCode:Word; Count: Word; ptr: Pointer);
var
    Buf, res: string;
    pbuf: Tva_list;
begin
    pbuf := Tva_list(ptr^);
    case StatusCode of
        528: begin //может быть переменной длины
             buf := StrPas(pbuf[3]);
             res := _GetLogonTypeAsMessage(Buf);
             //ZeroMemory(pbuf[3], 4096);
             //StringToWideChar(res, pbuf[3], length(res)+1);
             StrPCopy(pbuf[3], res);

             //ip addr to name
             if is_inited and (Count >=13) then
                begin
                buf := StrPas(pbuf[13]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[13], _IP2Name(Buf));
                end; //if
             end;
        529: begin //может быть переменной длины
             buf := StrPas(pbuf[2]);
             res := _GetLogonTypeAsMessage(Buf);
             //ZeroMemory(pbuf[2], 4096);
             //StringToWideChar(res, pbuf[2], length(res)+1);
             StrPCopy(pbuf[2], res);

             //ip addr to name
             if is_inited and (Count >= 11) then
                begin
                buf := StrPas(pbuf[11]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[11], _IP2Name(Buf));
                end; //if

             end; {529}
        537: begin
             //ToDo: [6], [7]
              if is_inited and (Count >= 13) then
                begin
                buf := StrPas(pbuf[13]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[13], _IP2Name(Buf));
                end; //if
             end;
        538: begin
             buf := StrPas(pbuf[3]);
             res := _GetLogonTypeAsMessage(Buf);
             //ZeroMemory(pbuf[3], 4096);
             //StringToWideChar(res, pbuf[3], length(res)+1);
             StrPCopy(pbuf[3], res);
             end;
        540: begin //может быть переменной длины
             buf := StrPas(pbuf[3]);
             res := _GetLogonTypeAsMessage(Buf);
             //ZeroMemory(pbuf[3], 4096);
             //StringToWideChar(res, pbuf[3], length(res)+1);
             StrPCopy(pbuf[3], res);

             if is_inited and (Count >= 13) then
                begin
                buf := StrPas(pbuf[13]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[13], _IP2Name(Buf));
                end; //if
             end;
        552: begin
             if is_inited and (Count >= 10) then
                begin
                buf := StrPas(pbuf[10]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[10], _IP2Name(Buf));
                end; //if
             end;
        680: begin
             Buf := StrPas(pbuf[3]);
             res := _GetErrorCodeAsMessage(Buf);
             //ZeroMemory(pbuf[3], 4096);
             //StringToWideChar(res, pbuf[3], length(res)+1);
             StrPCopy(pbuf[3], res);
            end; {680}
        4624: begin
              buf := StrPas(pbuf[8]);
              res:= _GetLogonTypeAsMessage(Buf);
              //ZeroMemory(pbuf[8], 4096);
              //StringToWideChar(res, pbuf[8], length(res)+1);
              StrPCopy(pbuf[8], res);

             if is_inited and (Count >= 18) then
                begin
                buf := StrPas(pbuf[18]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[18], _IP2Name(Buf));
                end; //if

              end;
        4625: begin//////////////////////////////////////////////
              buf := StrPas(pbuf[7]);
              res:= _GetStatusAsMessage(Buf);
              //ZeroMemory(pbuf[7], 4096);
              //StringToWideChar(res, pbuf[7], length(res)+1);
              StrPCopy(pbuf[7], res);

              buf := StrPas(pbuf[9]);
              res:= _GetErrorCodeAsMessage(Buf);
              //ZeroMemory(pbuf[9], 4096);
              //StringToWideChar(res, pbuf[9], length(res)+1);
              StrPCopy(pbuf[9], res);

             if is_inited and (Count >= 19) then
                begin
                buf := StrPas(pbuf[19]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[19], _IP2Name(Buf));
                end; //if
              end;
        4634: begin
              buf := StrPas(pbuf[4]);
              res := _GetLogonTypeAsMessage(Buf);
              //ZeroMemory(pbuf[4], 4096);
              //StringToWideChar(res, pbuf[4], length(res)+1);
              StrPCopy(pbuf[4], res);
              end;
        4768: begin
              buf := StrPas(pbuf[6]);
              res := _GetResultCodeAsMessage(Buf);
              //ZeroMemory(pbuf[6], 4096);
              //StringToWideChar(res, pbuf[6], length(res)+1);
              StrPCopy(pbuf[6], res);

             if is_inited and (Count >= 9) then
                begin
                buf := StrPas(pbuf[9]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[9], _IP2Name(Buf));
                end; //if
              end;
        4771: begin
              buf := StrPas(pbuf[4]);
              res := _GetResultCodeAsMessage(Buf);
              //ZeroMemory(pbuf[4], 4096);
              //StringToWideChar(res, pbuf[4], length(res)+1);
              StrPCopy(pbuf[4], res);

              if is_inited and (Count >= 6) then
                begin
                buf := StrPas(pbuf[6]);
                //res := IP2Name(Buf);
                StrPCopy(pbuf[6], _IP2Name(Buf));
                end; //if
              end;
        4776: begin
              buf := StrPas(pbuf[3]);
              res := _GetErrorCodeAsMessage(Buf);
              //ZeroMemory(pbuf[3], 4096);
              //StringToWideChar(res, pbuf[3], length(res)+1);
              StrPCopy(pbuf[3], res);
              end;
    end; {StatusCode}

end;


exports
GetVersion,
GetDescription,
Parse,
dll_init,
dll_deinit;

begin
end.
