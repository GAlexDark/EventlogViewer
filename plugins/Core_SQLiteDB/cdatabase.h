#ifndef CDATABASE_H
#define CDATABASE_H

#include "core_headers.h"
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QSqlDriver>

class CDataBase
{
public:
    CDataBase(const QString &aConnectionName = "");
    virtual ~CDataBase();

    QString GetConnectionName() const { return m_ConnectionName; }
    QSqlDatabase GetDBinstance() const { return m_dbinstance; }
    bool IsConnected() const { return m_IsInited; }

    virtual void Init(const QString &aConnectionString);
    virtual void DeInit();
    virtual void SetDrvInstanse(QSqlDriver* Drv = 0);
    virtual void Open();
    virtual bool Close();
    virtual void BeginTransaction();
    virtual void CommitTransaction();
    virtual void RollbackTransaction();
    virtual void VacuumDB() { _exec("vacuum;"); }

protected:
    QSqlQuery       m_SQLRes;

	virtual void _exec(const QString &sql_req);
	virtual void _exec();
	virtual void _prepare(const QString &sql_req);

private:
    //������ � ��
    QSqlDriver*     m_driver;
    QSqlDatabase    m_dbinstance;

    bool            m_IsInited;         //���� ����������� � ��. True - connected, false - not connected
    bool            m_IsOpen;
    QString         m_ConnectionName;   //���������� ��� ����������
    int             m_ErrorCode;        //��� ������
    bool            m_IsDBLock;         //���� ���������� �� True-block, False-no block
    QString         m_dbdir;            //���� � �����, ��� ����� ��������� ���� ��
    bool            m_IsTransaction;

    void            _Close();
    void            _DeInit();

};

#endif // CDATABASE_H
