#ifndef dbErrorInfo_h
#define dbErrorInfo_h

/************************************************************************/
/* Error message struct                                                 */
/************************************************************************/
#define ERROR_DESCRIPTION_MAX_SIZE	512
#define BDB_ERROR_SUCCESS			0
#define BDB_ERROR_NOT_ENOUGH_MEMORY 1

typedef struct dbErrorInfo {
	int     Code;
	int		SysCode;	
	wchar_t	Description[ERROR_DESCRIPTION_MAX_SIZE-1];
	} DBERRORINFO;

void _BDBSetLastError(dbErrorInfo *db_ErrorInfo, int Code, int SysCode, const wchar_t* Description);
void StringCopy(wchar_t* aDest, const wchar_t* aSource, const size_t aElemetsCount);
DWORD SysErrorMessage(const DWORD aErrorCode, wchar_t* &lpMsgBuf);

class EBaseException
{
private: //недоступны для наследования
	int			m_ErrorCode;
	int			m_SysCode;
	wchar_t*	m_Msg;

protected: //доступны для наследования
	virtual void SetErrorMessage(const wchar_t *Msg);
	virtual void SetErrorCode(int ErrorCode);
	virtual void SetSysCode(int SysCode);

public:
	EBaseException(const int ErrorCode);
	EBaseException(const int ErrorCode, const wchar_t* Msg);
	EBaseException(const int ErrorCode, const int SysCode, const wchar_t* Msg);
	EBaseException(const EBaseException& Exception);
	EBaseException& operator=(const EBaseException& Exception);
	virtual ~EBaseException();

	virtual wchar_t* GetErrorMessage() const { return m_Msg; }
	virtual int GetErrorCode() const { return m_ErrorCode; }
	virtual int GetSysCode() const { return m_SysCode; }
};

class EMemoryError : public EBaseException
{
public:
	EMemoryError() : EBaseException(BDB_ERROR_NOT_ENOUGH_MEMORY) {} //Недостаточно оперативной памяти
};

class 	EBDBError : public EBaseException
{
public:
	EBDBError(const int ErrorCode, const int SysCode, const wchar_t* Msg) : EBaseException(ErrorCode, SysCode, Msg) {}
};
/*
варнинги с конструкторе
http://gshep.ru/2010/12/29/gcc-cpp-compiler-warnings/
*/



#endif
