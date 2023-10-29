#include "stdafx.h"
#include "BerkeleyDB.h"
#include "stdio.h"

void BDBSetLastError(wchar_t* &Dest, const wchar_t* Msg, ...)
{
	memset(Dest,0x00,(ERROR_DESCRIPTION_MAX_SIZE-1)*sizeof(wchar_t));
	va_list var;
	va_start( var, Msg );
	vswprintf_s(Dest, ERROR_DESCRIPTION_MAX_SIZE-2, Msg, var);
	va_end( var );
	return;
}


	wchar_t ErrMsg[ERROR_DESCRIPTION_MAX_SIZE-1];
	wchar_t* ptr = &ErrMsg[0];

MBDb::MBDb():
	m_IsInited(false), m_IsOpen(false)  //m_mdb(NULL), m_db(NULL), ???
{
	//memset(&m_ErrorInfo,0,sizeof(DBERRORINFO));
	// Env open flags
	u_int32_t EnvFlags =
			DB_CREATE     |  // Create the environment if it does not exist
			DB_INIT_MPOOL |  // Initialize the memory pool (in-memory cache)
			DB_PRIVATE;

	try {
		m_mdb = new DbEnv(0);				
		// Specify in-memory logging
		m_mdb->log_set_config(DB_LOG_DIRECT, 1);
		// Specify the size of the in-memory cache	
/*		m_mdb->set_cachesize(0, 12*1024*1024, 2); // было 4*1024*1024 | SIDDATA_SIZE*/
		m_mdb->open(NULL, EnvFlags, 0);

		m_db = new Db(m_mdb,0) ;
		m_IsInited = true;

		} catch(const DbException &e) {
			BDBSetLastError(ptr, L"Error opening database environment: %s", e.what());
			throw EBDBError(-1,-1,&ErrMsg[0]);
		} catch (const std::exception &e) {
			BDBSetLastError(ptr, L"Error opening database environment: %s", e.what());
			throw EBDBError(-1,-1,&ErrMsg[0]);
		} catch (...) {			
			throw EBDBError(-1,-1, L"Unknown Error in MBDb::MBDb");
			}
}
MBDb::~MBDb()
{	
	if ((m_db != NULL) && (m_IsOpen)) Close();
	if (m_mdb != NULL) m_mdb->close(0);	
	delete m_db;
	delete m_mdb;
}

void MBDb::Open()
{
	if (!m_IsInited)
		throw EBDBError(-1, -1, L"BDB is not initialized");
	try {
		// Open the database. 
		m_db->open(NULL, NULL, NULL, DB_BTREE, DB_CREATE, 0);
		m_IsOpen = true;
		// DbException is not a subclass of std::exception, so we
		// need to catch them both.
	} catch(const DbException &e) {
		BDBSetLastError(ptr, L"Error opening database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch(const std::exception &e) {
		BDBSetLastError(ptr, L"Error opening database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch (...) {			
		throw EBDBError(-1,-1, L"Unknown Error in MBDb::Open");
	}
	return;
}

void MBDb::Close()
{
	try {	
		if (m_IsOpen) m_db->close(0);		
		m_IsOpen = false;
	} catch(const DbException &e) {
		BDBSetLastError(ptr, L"Error closing database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch(const std::exception &e) {
		BDBSetLastError(ptr, L"Error closing database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch (...) {			
		throw EBDBError(-1,-1, L"Unknown Error in MBDb::Close");
	}
}



/* ---  --- */
void MBDb::_Add(DWORD	aSIDLength,
				PSID		aSID,
				LPWSTR	&aUserInfo,
				DWORD	aSIDType,
				LPWSTR	&aStringSID)
{
	TSIDDATA SIDData;
	memset(&SIDData,0x00,sizeof(TSIDDATA));
	
	SetLastError(ERROR_SUCCESS);
	if (!CopySid(aSIDLength, &SIDData._binSID, aSID)) {
		DWORD err = GetLastError();
		wchar_t *buf = NULL;
		int code = SysErrorMessage(err, buf); //возвращает 0 в случае ошибки
		if (code != 0)
			BDBSetLastError(ptr, L"Error copy SID.\nDetails: %Is", buf);
		else
			BDBSetLastError(ptr, L"Unknown error in CopySid.\nDetails: Error in SysErrorMessage.\nError Code: %d", GetLastError());
		
		LocalFree(buf);
		throw EBDBError(-1,err,&ErrMsg[0]);
		}

	try {
		wcscpy_s(SIDData._UserInfo, MAX_SIZE, aUserInfo);
		wcscpy_s(SIDData._StringSID, MAX_SIZE, aStringSID); // <---- error. before MAX_SIZE-1
		SIDData._SIDType = aSIDType;
		Dbt key (SIDData._binSID, (u_int32_t)SID_SIZE);
		Dbt data(&SIDData, sizeof(TSIDDATA));

		int res = m_db->put(NULL,&key,&data,0);
		if (res != 0)
			throw EBDBError(-1, res, L"Error add to database");
	} catch (EBDBError) {
		throw; // e;
	} catch(const DbException &e) {
		BDBSetLastError(ptr, L"Error add to database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);					
		}
	catch(const std::exception &e) {
		BDBSetLastError(ptr, L"Error add to database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch (...) {			
		throw EBDBError(-1,-1, L"Unknown Error in MBDb::_Add");
		}
}

void MBDb::_Find(PSID aSID,
					LPWSTR	&aUserInfo,				//out &
					size_t		UserInfoBufSize,	//in
					DWORD	&aSIDType,				//out &
					LPWSTR	&aStringSID,			//out &
					size_t		StringSIDBufSize)	//in
{
	Dbt data;
	TSIDDATA SIDData;
	memset(&SIDData,0,sizeof(TSIDDATA));

	SetLastError(ERROR_SUCCESS);
	if (!CopySid(GetLengthSid(aSID),&SIDData._binSID,aSID)) {
		DWORD err = GetLastError();
		wchar_t *buf = NULL;
		int code = SysErrorMessage(err,buf); //возвращает 0 в случае ошибки
		if (code != 0)
			BDBSetLastError(ptr, L"Error copy SID.\nDetails: %Is", buf);
		else
			BDBSetLastError(ptr, L"Unknown error in CopySid.\nDetails: Error in SysErrorMessage.\nError Code: %d", GetLastError());
		LocalFree(buf);
		throw EBDBError(-1,err,&ErrMsg[0]);
		}

	try {
		Dbt key(SIDData._binSID,(u_int32_t)SID_SIZE);

		data.set_data(&SIDData);
		data.set_ulen(sizeof(TSIDDATA));
		data.set_flags(DB_DBT_USERMEM);

		// Get the record
		int Res = m_db->get(NULL, &key, &data, 0);
		if (Res !=0) {
			//DB_NOTFOUND /* -30988 - Key/data pair not found (EOF). */
			if (Res == DB_NOTFOUND)
				throw EBDBError(-1, Res, L"Key/data pair not found");
			else throw EBDBError(-1, Res, L"Unknown error getting data");
			}

		//return data	
		wcscpy_s(aUserInfo, UserInfoBufSize, SIDData._UserInfo);
		wcscpy_s(aStringSID, StringSIDBufSize, SIDData._StringSID);
		aSIDType = SIDData._SIDType;

	} catch (EBDBError) {
			throw; //e;
	} catch(const DbException &e) {
		BDBSetLastError(ptr, L"Error add to database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);		
	} catch(const std::exception &e) {
		BDBSetLastError(ptr, L"Error add to database: %s", e.what());
		throw EBDBError(-1,-1,&ErrMsg[0]);
	} catch (...) {
		throw EBDBError(-1,-1, L"Unknown Error in MBDb::_Find");
		}
	return;
}