#ifndef _EvtLogBDB_h
#define _EvtLogBDB_h

#include "bdbErrorInfo.h"


	MBDb		*MSID_db = NULL;
	dbErrorInfo db_ErrorInfo;


#define pcAPI __stdcall
#ifdef __cplusplus
#   define pcEXTERN_C extern "C"
#else
#   define pcEXTERN_C
#endif
//==========================================================
#define pcFUNC(ret) pcEXTERN_C ret pcAPI

pcFUNC(bool) MBDBInit(); //const char* DBName
pcFUNC(bool) MBDBInited();
pcFUNC(void) MBDBDeIntit();
pcFUNC(bool) MBDBClose();
pcFUNC(bool) MBDBAdd(DWORD aSIDLength,
						PSID aSID,
						LPWSTR aUserInfo,
						DWORD aSIDType,
						LPWSTR aStringSID);
pcFUNC(bool) MBDBFind(PSID aSID,
						LPWSTR &aUserInfo, //&
						size_t UserInfoBufSize,
						DWORD &aSIDType,
						LPWSTR &aStringSID, //&
						size_t StringSIDBufSize);
pcFUNC(void) MBDBGetLastError(dbErrorInfo *aErrorInfo);
pcFUNC(void) MBDBClear();
#endif

