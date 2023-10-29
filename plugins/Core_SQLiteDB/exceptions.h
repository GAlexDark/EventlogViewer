#ifndef EXCEPTIONS_H
#define EXCEPTIONS_H

#include "core_headers.h"


class EBaseException
{
private: //недоступны для наследования
    int    m_ErrorCode;
    int    m_SysCode;
    QString     m_Msg;


protected: //доступны для наследования
    virtual void SetErrorMessage(const QString& Msg);
    virtual void SetErrorCode(int ErrorCode);
    virtual void SetSysCode(int SysCode);

public:
    EBaseException(const int ErrorCode);
    EBaseException(const int ErrorCode, const QString& Msg);
    EBaseException(const int ErrorCode, const int SysCode, const QString& Msg);
    EBaseException(const EBaseException& Exception);
    EBaseException& operator=(const EBaseException& Exception);
    virtual ~EBaseException() {}

    virtual QString GetErrorMessage() const
        { return m_Msg; }
    virtual int GetErrorCode() const
        { return m_ErrorCode; }
    virtual int GetSysCode() const
        { return m_SysCode; }
};

class EMemoryError : public EBaseException
{
public:
    EMemoryError() : EBaseException(PL_ERROR_NOT_ENOUGH_MEMORY) {} //Недостаточно оперативной памяти
};

class 	EDBError : public EBaseException
{
public:
    EDBError(const int ErrorCode, const int SysCode, const QString& Msg) :
                                            EBaseException(ErrorCode, SysCode, Msg) {}
};
/*
варнинги с конструкторе
http://gshep.ru/2010/12/29/gcc-cpp-compiler-warnings/
*/
#endif // EXCEPTIONS_H
