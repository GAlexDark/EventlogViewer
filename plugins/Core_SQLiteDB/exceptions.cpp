#include "exceptions.h"

EBaseException::EBaseException(const int ErrorCode)
    : m_ErrorCode(ErrorCode), m_SysCode(0),m_Msg("") {}

EBaseException::EBaseException(const int ErrorCode, const QString& Msg)
    : m_ErrorCode(ErrorCode), m_SysCode(0), m_Msg(Msg) {}

EBaseException::EBaseException(const int ErrorCode, const int SysCode, const QString& Msg)
    : m_ErrorCode(ErrorCode), m_SysCode(SysCode), m_Msg(Msg) {}

EBaseException::EBaseException(const EBaseException& Exception)
    : m_ErrorCode(Exception.GetErrorCode()), m_SysCode(Exception.GetSysCode()), m_Msg(Exception.GetErrorMessage()) {}

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
void EBaseException::SetErrorMessage(const QString& Msg)
{
    m_Msg = Msg;
}
void EBaseException::SetErrorCode(int ErrorCode)
{
    m_ErrorCode = ErrorCode;
}
void EBaseException::SetSysCode(int SysCode)
{
    m_SysCode = SysCode;
}

//************************************************************************************
