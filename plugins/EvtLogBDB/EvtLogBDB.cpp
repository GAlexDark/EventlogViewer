// EvtLogBDB.cpp: определяет экспортированные функции для приложения DLL.
//

#include "stdafx.h"
#include "BerkeleyDB.h"
#include "EvtLogBDB.h"


//=============================================
BOOL APIENTRY DllMain( HMODULE hModule,
						DWORD  ul_reason_for_call,
						LPVOID lpReserved)
{
	switch (ul_reason_for_call)
		{
		case DLL_PROCESS_ATTACH:
					break;
		case DLL_THREAD_ATTACH:
					break;
		case DLL_THREAD_DETACH:
					break;
		case DLL_PROCESS_DETACH:
					break;
		}
	return TRUE;
}

pcFUNC(bool) MBDBInit()
{
	bool res =true;	
	if (MSID_db != NULL)
		return res;	
	try {		
		MSID_db = new MBDb;
		MSID_db->Open();	

	} catch (const EBDBError &e) {
		_BDBSetLastError(&db_ErrorInfo, -1, e.GetSysCode(), e.GetErrorMessage());
		res = false;
	} catch (const std::exception &e) {
		_BDBSetLastError(&db_ErrorInfo, -1, -1, (wchar_t*)e.what());
		res = false;
	} catch (...) {
		_BDBSetLastError(&db_ErrorInfo, -1, -1, L"Unknown error in MBDBInit");
		res = false;
	}	
	return res;
}
pcFUNC(bool) MBDBInited()
{
	if (MSID_db == NULL) {
		_BDBSetLastError(&db_ErrorInfo, -1, -1, L"MBDB is not initialized");
		return false;
		}
	else return MSID_db->IsInited();
}

pcFUNC(void) MBDBDeIntit()
{
	try {
		delete MSID_db;
		MSID_db = NULL;
	} catch (...) { return; }
	return;
}

pcFUNC(bool) MBDBClose()
{
	bool res = true;
	try {
		MSID_db->Close();
	} catch (const EBDBError &e) {
		_BDBSetLastError(&db_ErrorInfo, -1, e.GetSysCode(), e.GetErrorMessage());	
		res = false;
	} catch (...) {
		_BDBSetLastError(&db_ErrorInfo, -1, -1, L"Unknown error in MBDBClose");
		res = false;
		}
	return res;
}
pcFUNC(bool) MBDBAdd(DWORD aSIDLength,
					PSID aSID,
					LPWSTR aUserInfo,
					DWORD aSIDType,
					LPWSTR aStringSID)
{
	bool res = false;
	if (aSIDLength == 0) {
		_BDBSetLastError(&db_ErrorInfo,-2,1,L"Data error in [in]SIDLength");
		return res; }
	if (aSID == NULL) {
		_BDBSetLastError(&db_ErrorInfo,-2,2,L"Data error in [in]aSID");
		return res; }
	if (aUserInfo == NULL && *aUserInfo == 0x00) {
		_BDBSetLastError(&db_ErrorInfo,-2,3,L"Data error in [in]aUserInfo");
		return res; }
	if (aSIDType == 0) {
		_BDBSetLastError(&db_ErrorInfo,-2,4,L"Data error in [in]aSIDType");
		return res; }
	if (aStringSID == NULL && *aStringSID == 0x00) {
		_BDBSetLastError(&db_ErrorInfo,-2,5,L"Data error in [in]aStringSID");
		return res; }

	try {
		MSID_db->_Add(aSIDLength, aSID, aUserInfo, aSIDType, aStringSID);
		res = true;
	} catch (const EBDBError &e) {
		_BDBSetLastError(&db_ErrorInfo, -2, e.GetSysCode(), e.GetErrorMessage());	
		res = false;		
	} catch (...) {
		_BDBSetLastError(&db_ErrorInfo, -2, -2, L"Unknown error in MBDBAdd");
		res = false;
		}	
	return res;
}

pcFUNC(bool) MBDBFind(PSID aSID,
						LPWSTR &aUserInfo, //&
						size_t UserInfoBufSize,
						DWORD &aSIDType,
						LPWSTR &aStringSID, //&
						size_t StringSIDBufSize)
{
	bool res = false;
	if (aSID == NULL) {
		_BDBSetLastError(&db_ErrorInfo,-1,-1,L"Data error in [in]aSID");
		return res;}
	if (aUserInfo == NULL) {
		_BDBSetLastError(&db_ErrorInfo,-1,-1,L"Data error in [out]aUserInfo");
		return res;}
	if (UserInfoBufSize == 0) {
		_BDBSetLastError(&db_ErrorInfo,-1,-1,L"Data error in [in]UserInfoBufSize");
		return res;}
	if (aStringSID == NULL) {
		_BDBSetLastError(&db_ErrorInfo,-1,-1,L"Data error in [out]aStringSID");
		return res;}
	if (StringSIDBufSize == 0) {
		_BDBSetLastError(&db_ErrorInfo,-1,-1,L"Data error in [in]StringSIDBufSize");
		return res;}

	try {
		MSID_db->_Find(aSID, aUserInfo, UserInfoBufSize, aSIDType, aStringSID, StringSIDBufSize);	
		res = true;
	} catch (const EBDBError &e) {
		_BDBSetLastError(&db_ErrorInfo, -1, e.GetSysCode(), e.GetErrorMessage());	
		res = false;			
	} catch (...) {
		_BDBSetLastError(&db_ErrorInfo, -1, -1, L"Unknown error in MBDBFind");
		res = false;
	}

	return res;
}

pcFUNC(void) MBDBClear()
{
	memset(&db_ErrorInfo,0x00,sizeof(DBERRORINFO));
	return;
}

pcFUNC(void) MBDBGetLastError(dbErrorInfo *aErrorInfo)
{
	memcpy(aErrorInfo,&db_ErrorInfo,sizeof(DBERRORINFO));
	return;
}