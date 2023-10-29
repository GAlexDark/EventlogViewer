//******************************************************************************
// Nom           : WinDns.pas
// Utilisation   : Fonction et Type pour l'acces a DnsApi.dll
// Auteur        : uncle_khemi@hotmail.com
// Date          : 27 Aout 2003
//
// Modifications :
// Date          :
//******************************************************************************

unit WinDNS;

interface
uses
  Windows;

const
  //  Options for DnsQuery
  DNS_QUERY_STANDARD = 0;
  DNS_QUERY_ACCEPT_TRUNCATED_RESPONSE = 1;
  DNS_QUERY_USE_TCP_ONLY = 2;
  DNS_QUERY_NO_RECURSION = 4;
  DNS_QUERY_BYPASS_CACHE = 8;

  //autres
  DNS_ATMA_MAX_ADDR_LENGTH = 20;
  DNS_ATMA_AESA_ADDR_LENGTH = 20;

DNS_TYPE_A	= $0001;
DNS_TYPE_NS	= $0002;
DNS_TYPE_MD	= $0003;
DNS_TYPE_MF	= $0004;
DNS_TYPE_CNAME	= $0005;
DNS_TYPE_SOA	= $0006;
DNS_TYPE_MB	= $0007;
DNS_TYPE_MG	= $0008;
DNS_TYPE_MR	= $0009;
DNS_TYPE_NULL	= $000a;
DNS_TYPE_WKS	= $000b;
DNS_TYPE_PTR	= $000c;
DNS_TYPE_HINFO	= $000d;
DNS_TYPE_MINFO	= $000e;
DNS_TYPE_MX	= $000f;
DNS_TYPE_TEXT	= $0010;
DNS_TYPE_RP	= $0011;
DNS_TYPE_AFSDB	= $0012;
DNS_TYPE_X25	= $0013;
DNS_TYPE_ISDN	= $0014;
DNS_TYPE_RT	= $0015;
DNS_TYPE_NSAP	= $0016;
DNS_TYPE_NSAPPTR = $0017;
DNS_TYPE_SIG	= $0018;
DNS_TYPE_KEY	= $0019;
DNS_TYPE_PX	= $001a;
DNS_TYPE_GPOS	= $001b;
DNS_TYPE_AAAA	= $001c;
DNS_TYPE_LOC	= $001d;
DNS_TYPE_NXT	= $001e;
DNS_TYPE_EID	= $001f;
DNS_TYPE_NIMLOC	= $0020;
DNS_TYPE_SRV	= $0021;
DNS_TYPE_ATMA	= $0022;
DNS_TYPE_NAPTR	= $0023;
DNS_TYPE_KX	= $0024;
DNS_TYPE_CERT	= $0025;
DNS_TYPE_A6	= $0026;
DNS_TYPE_DNAME	= $0027;
DNS_TYPE_SINK	= $0028;
DNS_TYPE_OPT	= $0029;
DNS_TYPE_DS	= $002B;
DNS_TYPE_RRSIG	= $002E;
DNS_TYPE_NSEC	= $002F;
DNS_TYPE_DNSKEY	= $0030;
DNS_TYPE_DHCID	= $0031;
DNS_TYPE_UINFO	= $0064;
DNS_TYPE_UID	= $0065;
DNS_TYPE_GID	= $0066;
DNS_TYPE_UNSPEC	= $0067;
DNS_TYPE_ADDRS	= $00f8;
DNS_TYPE_TKEY	= $00f9;
DNS_TYPE_TSIG	= $00fa;
DNS_TYPE_IXFR	= $00fb;
DNS_TYPE_AXFR	= $00fc;
DNS_TYPE_MAILB	= $00fd;
DNS_TYPE_MAILA	= $00fe;
DNS_TYPE_ALL	= $00ff;
DNS_TYPE_ANY	= $00ff;
DNS_TYPE_WINS	= $ff01;
DNS_TYPE_WINSR	= $ff02;
DNS_TYPE_NBSTAT	= DNS_TYPE_WINSR;

  DNS_UPDATE_SECURITY_USE_DEFAULT = 0;

type
  IP6_ADDRESS = array[0..3] of dword;
  IP4_ADDRESS = DWORD;
  DNS_A_DATA = IP4_ADDRESS;
  DNS_PTR_DATA = PWideChar;
  DNS_PTR_DATAA = DNS_PTR_DATA;
  DNS_PTR_DATAW = DNS_PTR_DATA;
  DNS_AAAA_DATA = IP6_ADDRESS;
  DNS_STATUS = LongInt;
  PIP4_ARRAY = ^IP4_ARRAY;

  //validation d'un nom DNS
  DNS_NAME_FORMAT = (DnsNameDomain,
    DnsNameDomainLabel,
    DnsNameHostnameFull,
    DnsNameHostnameLabel,
    DnsNameWildcard,
    DnsNameSrvRecord);

  //definie le type de liberation pour avec DnsFreeRecordList
  DNS_FREE_TYPE = (
    DnsFreeFlat,
    DnsFreeRecordList,
    DnsFreeParsedMessageFields
    );

  //tableau d'adresse IP
  IP4_ARRAY = record
    AddrCount: DWORD;
    AddrArray: array[0..10] of IP4_ADDRESS; //[0..10]
  end;

  DNS_SRV_DATAA = record
    pNameTarget: PChar;
    wPriority: Word;
    wWeighty: Word;
    wPorty: Word;
    Pady: Word;                         // keep ptrs DWORD aligned
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

  DNS_NXT_DATAA = record
    pNameNext: PChar;
    wNumTypes: Word;
    wTypes: array[0..1] of Word;
  end;

  DNS_WINSR_DATA = record
    dwMappingFlag: DWORD;
    dwLookupTimeout: DWORD;
    dwCacheTimeout: DWORD;
    pNameResultDomain: PWideChar;
  end;

  DNS_WINSR_DATAA = record
    dwMappingFlag: DWORD;
    dwLookupTimeout: DWORD;
    dwCacheTimeout: DWORD;
    pNameResultDomain: PChar;
  end;

  DNS_RECORD_FLAGS = record
    Section: DWORD;                     //DWORD   Section     : 2;
    Delete: DWORD;                      //DWORD   Delete      : 1;
    CharSet: DWORD;                     //DWORD   CharSet     : 2;
    Unused: DWORD;                      //DWORD  Unused      : 3;
    Reserved: DWORD;                    //DWORD  Reserved    : 24;
  end;

  DNS_TXT_DATAA = record
    dwStringCount: DWORD;
    pStringArray: array[0..10] of PChar;
  end;

  DNS_NULL_DATA = record
    dwByteCount: DWORD;
    Data: array[0..10] of Byte;
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

  DNS_WKS_DATA = record
    IpAddress: IP4_ADDRESS;
    chProtocol: UCHAR;
    BitMask: array[0..0] of Byte;       // BitMask[1];
  end;

  DNS_MX_DATAA = record
    pNameExchange: PChar;
    wPreference: Word;
    Pad: Word;
  end;

  DNS_MINFO_DATAA = record
    pNameMailbox: PChar;
    pNameErrorsMailbox: PChar;
  end;

  DNS_WINS_DATA = record
    dwMappingFlag: DWORD;
    dwLookupTimeout: DWORD;
    dwCacheTimeout: DWORD;
    cWinsServerCount: DWORD;
    WinsServers: array[0..0] of IP4_ADDRESS;
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

  DNS_SOA_DATAA = record
    pNamePrimaryServer: PChar;
    pNameAdministrator: PChar;
    dwSerialNo: DWORD;
    dwRefresh: DWORD;
    dwRetry: DWORD;
    dwExpire: DWORD;
    dwDefaultTtl: DWORD;
  end;

  //probleme non resolu lorsqu'on utilise les flags de type S
  TFlags = record
    case Integer of
      1: (DW: DWORD);                   // flags as DWORD
      2: (S: ^DNS_RECORD_FLAGS);        // flags as structure   ???
  end;

  TDataA = record
    case Integer of
      1: (A: DNS_A_DATA);               //    A;
      2: (SOA: DNS_SOA_DATAA);          //   SOA, Soa;
      3: (PTR: DNS_PTR_DATAA);          //PTR, Ptr, NS, Ns, CNAME, Cname, MB, Mb, MD, Md, MF, Mf, MG, Mg, MR, Mr;
      4: (MINFO: DNS_MINFO_DATAA);      //MINFO, Minfo,    RP, Rp;
      5: (MX: DNS_MX_DATAA);            //MX, Mx,         AFSDB, Afsdb,             RT, Rt;
      6: (HINFO: DNS_TXT_DATAA);        //HINFO, Hinfo,        ISDN, Isdn,        TXT, Txt,          X25;
      7: (Null: DNS_NULL_DATA);         //Null;
      8: (WKS: DNS_WKS_DATA);           //WKS, Wks;
      9: (AAAA: DNS_AAAA_DATA);         //AAAA;
      10: (KEY: DNS_KEY_DATA);          //KEY, Key;
      11: (SIG: DNS_SIG_DATAA);         //SIG, Sig;
      12: (ATMA: DNS_ATMA_DATA);        //ATMA, Atma;
      13: (NXT: DNS_NXT_DATAA);         //NXT, Nxt;
      14: (SRV: DNS_SRV_DATAA);         //SRV, Srv;
      15: (TKEY: DNS_TKEY_DATAA);       //TKEY, Tkey;
      16: (TSIG: DNS_TSIG_DATAA);       //TSIG, Tsig;
      17: (DWINS: DNS_WINS_DATA);       //WINS, Wins;
      18: (WINSR: DNS_WINSR_DATA);      //WINSR, WinsR, NBSTAT, Nbstat;
  end;



  PDNS_RECORDA = ^DNS_RECORDA;
  DNS_RECORDA = record
    pnext: PDNS_RECORDA;                //  struct _DnsRecordW *
    pName: PChar;                       //PSTR
    wType: Word;                        //WORD                                              //WORD                    wType;
    wDataLength: Word;                  //WORD
    flags: TFlags;                      //
    dwTtl: DWORD;                       //DWORD;
    dwReserved: DWORD;                  //DWORD;
    Data: TDataA;
  end;



  //------------------------------------------------------------------------------
  //Fonctions
  //------------------------------------------------------------------------------


  //------------------------------------------------------------------------------
  //voir un enregistrement
function DnsQuery_W(
                    pszName: PWideChar;
                    wType: Word;
                    Options: DWORD;
                    aipServers: PIP4_ARRAY;
                    ppQueryResults: Pointer;
                    pReserved: Pointer
  ): DNS_STATUS; stdcall; external 'dnsapi.dll' name 'DnsQuery_W';

//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//ajouter, modifier et supprimer un enregistrement
function DnsModifyRecordsInSet_A(
  pAddRecords: PDNS_RECORDA;
  pDeleteRecords: PDNS_RECORDA;
  Options: DWORD;
  hContext: Hwnd;
  pServerList: PIP4_ARRAY;
  pReserved: Pointer
  ): DNS_STATUS; stdcall; external 'dnsapi.dll';
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//verifie si un nom DNS est correct
function DnsValidateName_A(
  pszName: PChar;
  Format: DNS_NAME_FORMAT
  ): DNS_STATUS; stdcall; external 'dnsapi.dll';
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//supprime la memoire aloue pour la reponse par un DNS_QUERY
procedure DnsRecordListFree(
  pRecordList: PDNS_RECORDA;
  FreeType: DNS_FREE_TYPE
  ); stdcall; external 'dnsapi.dll';
//------------------------------------------------------------------------------

//------------------------------------------------------------------------------
//supprime la memoire aloue pour la reponse par un DNS_QUERY
//procedure DnsFreeRecordListDeep(
//  pRecordList: PDNS_RECORDA;
//  FreeType: DNS_FREE_TYPE
//  ); stdcall; external 'dnsapi.dll';
//------------------------------------------------------------------------------



implementation

end.
