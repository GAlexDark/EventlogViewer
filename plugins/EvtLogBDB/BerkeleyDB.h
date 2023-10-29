#ifndef BerkeleyDB_H
#define BerkeleyDB_H

#include "db_cxx.h"
#include "bdbErrorInfo.h"

#define SID_LEN			8											
#define MAX_SIZE		64
#define SID_SIZE		SID_LEN*sizeof(DWORD)		// attrib 32 = 8*4(SID size = 28 bytes) + 1*4(rezerv for use)
//#define SIDDATA_SIZE	64*1024*1024

typedef struct TSIDData {
	DWORD	_binSID[SID_LEN];		/* size 32 bytes			*/
	DWORD	_reserved;				/* size 4 bytes - reserved	*/
	wchar_t _UserInfo[MAX_SIZE];	/* length 128 bytes	*/
	DWORD	_SIDType;				/* size 4 bytes				*/
	wchar_t _StringSID[MAX_SIZE]; /* length 128 bytes	*/
	} TSIDDATA;


	
class MBDb {
public:
	MBDb();
	~MBDb();
	void Open();
	void Close();
	bool IsInited() const { return m_IsInited; }

	void _Add(DWORD aSIDLength,
				PSID	aSID,
				LPWSTR	&aUserInfo,
				DWORD	aSIDType,
				LPWSTR	&aStringSID);
	void _Find(PSID		aSID,
				LPWSTR	&aUserInfo, //&
				size_t	UserInfoBufSize,
				DWORD	&aSIDType,
				LPWSTR	&aStringSID, //&
				size_t	StringSIDBufSize);
private:
	DbEnv		*m_mdb;
	Db			*m_db;
	bool		m_IsInited;
	bool		m_IsOpen;
	//DBERRORINFO	m_ErrorInfo;
};

#endif