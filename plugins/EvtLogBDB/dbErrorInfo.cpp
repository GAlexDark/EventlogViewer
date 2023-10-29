#include "stdafx.h"
#include <stdlib.h>
#include "bdbErrorInfo.h"


void _BDBSetLastError(dbErrorInfo *db_ErrorInfo, int Code, int SysCode, const wchar_t* Description)
{
	if (db_ErrorInfo != NULL) {
		memset(db_ErrorInfo, 0x00, sizeof(DBERRORINFO));
		db_ErrorInfo->Code = Code;
		db_ErrorInfo->SysCode = SysCode;
		StringCopy(db_ErrorInfo->Description, Description, ERROR_DESCRIPTION_MAX_SIZE-1);
		}
	return;
}
DWORD SysErrorMessage(const DWORD aErrorCode, wchar_t* &lpMsgBuf) 
{ 
	//возвращает кол-во записанных символов в случае успеха и 0 в случае неуспеха.
	return FormatMessageW(
		FORMAT_MESSAGE_ALLOCATE_BUFFER | 
		FORMAT_MESSAGE_FROM_SYSTEM |
		FORMAT_MESSAGE_IGNORE_INSERTS,
		NULL,
		aErrorCode,
		MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
		(wchar_t*)&lpMsgBuf, //LPWSTR 
		0, NULL );
}
/* ---  --- */
wchar_t* StringAlloc(const size_t aElemetsCount)
{
	if (aElemetsCount == 0) return NULL;	
	return (wchar_t*)calloc(aElemetsCount,sizeof(wchar_t));
}
void StringFreeAndNil(const wchar_t* aPtr)
{
	if (aPtr != NULL)
		free((void*)aPtr);
	aPtr = NULL;
	return;
}

void StringCopy(wchar_t* aDest, const wchar_t* aSource, const size_t aElemetsCount)
{
	if ((aDest == NULL) || (aSource == NULL) || aElemetsCount == 0)
		return;

		wcscpy_s(aDest,
				aElemetsCount, //принимает количество символов которые максимум можно положить в Dest
				aSource);
	return;
}
wchar_t* StringReAlloc(wchar_t* aPtr ,const size_t aElemetsCount)
{
	if ((aPtr == NULL) || (aElemetsCount == 0)) return NULL;

	size_t _size = aElemetsCount*sizeof(wchar_t);	
	
	wchar_t* new_buf = (wchar_t*)realloc(aPtr, _size);
	if (new_buf != NULL)
		memset(new_buf,0x00, _size);
	return (new_buf == NULL)? aPtr: new_buf;
}

/* --- EBaseException methods --- */
EBaseException::EBaseException(const int ErrorCode)
: m_ErrorCode(ErrorCode), m_SysCode(0),m_Msg(NULL){}

EBaseException::~EBaseException()
{
	StringFreeAndNil(m_Msg);
};
EBaseException::EBaseException(const int ErrorCode, const wchar_t* Msg)
: m_ErrorCode(ErrorCode), m_SysCode(0)
{
	size_t Count = wcslen(Msg);
	m_Msg = StringAlloc(Count+1); // +'\0'
	StringCopy(m_Msg, Msg, Count+1);
}

EBaseException::EBaseException(const int ErrorCode, const int SysCode, const wchar_t* Msg)
: m_ErrorCode(ErrorCode), m_SysCode(SysCode)
{
	size_t Count = wcslen(Msg);
	m_Msg = StringAlloc(Count+1); // +'\0'
	StringCopy(m_Msg,Msg,Count+1);
}

EBaseException::EBaseException(const EBaseException& Exception)
: m_ErrorCode(Exception.GetErrorCode()), m_SysCode(Exception.GetSysCode())
{
	size_t Count = wcslen(Exception.GetErrorMessage());
	m_Msg = StringAlloc(Count+1);
	StringCopy(m_Msg,Exception.GetErrorMessage(), Count+1);
}

EBaseException& EBaseException::operator =(const EBaseException& Exception)
{
	this->SetErrorCode(Exception.m_ErrorCode);
	this->SetSysCode(Exception.m_SysCode);
	this->SetErrorMessage(Exception.m_Msg);
	return *this;
}

//************************************************************************************
/*  Getters  */


/*  Setters  */
void EBaseException::SetErrorMessage(const wchar_t* Msg)
{
	size_t Count = wcslen(Msg);
	m_Msg = StringAlloc(Count+1);
	StringCopy(m_Msg,Msg,Count+1);	
	return;
}
void EBaseException::SetErrorCode(int ErrorCode)
{
	this->m_ErrorCode = ErrorCode;
}
void EBaseException::SetSysCode(int SysCode)
{
	this->m_SysCode = SysCode;
}

