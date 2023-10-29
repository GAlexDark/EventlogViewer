#ifndef DBUNIT_H
#define DBUNIT_H

#include "core_headers.h"
//#include <QMutex>
#include <QtSql/QSqlDatabase>
#include <QtSql/QSqlQuery>
#include <QSqlDriver>
#include <QPluginLoader>
#include <QDate>


class DBEngine
{
private:
    //������ � ��������� ��
    QPluginLoader   m_loader;
    QSqlDriver      *m_driver;
    bool            m_DBPluginLoad;
    //������ � ��
    QSqlDatabase    m_dbinstance;
    QSqlQuery       m_SQLRes;

//�������
    //QMutex          m_CS;

//���������
    bool            m_IsInited;         //���� ����������� � ��. True - connected, false - not connected
    bool            m_IsOpen;
    QString         m_ConnectionName;   //���������� ��� ����������
    int             m_ErrorCode;        //��� ������
    bool            m_IsDBLock;         //���� ���������� �� True-block, False-no block
	bool            m_IsBeginTransaction;
    QString         m_dbdir;            //���� � �����, ��� ����� ��������� ���� ��

    void _LoadDrv(const QString aDBDrv, const QString &aPluginName);
    void _UnloadDrv();
    //void _DBLock();
    //void _DBUnLock();
    void _SQLExec(const QString &aSQLString); //���������� ����� ��� ���������� ������ ��������, �� ������������ ���������
    void _Prepare(const QString &aSQLString);
    void _BindValue(THolderList HolderList, TValueList ValList);
    void _VacuumDB();

public:
    DBEngine(const QString &aConnectionName);
    ~DBEngine();
    QString GetConnectionName() const { return m_ConnectionName; }
    QSqlDatabase GetDBinstance() const { return m_dbinstance; }
    bool IsConnected() const { return m_IsInited; }

//#ifdef _SQLite
//    void Init(const QString &adbDir, const QString &aFileName, const QString &aPluginName);
//#else
    void Init(const QString &aConnectionString, const QString &aPluginName);
//#endif
    void DeInit();
    void Open();
    void Close();
    void BeginTransaction();
    void CommitTransaction ();
    void RollbackTransaction();

    QString CalcFileHash(const QString& aFileName);
    void SaveHashSumToFile(const QString& aFileName, const QString& aHashSum);
    void LoadHashSumFromFile(const QString& aFileName,QString& aHashSum);
    void BackupDB(const QString& aSource, const QString& aBackupPath);
    void RestoreDB(const QString& aBackupPath, const QString& aSource, const QDate &aDate);

    void Execute(const QString &aSQLString);
    void PrepareInsert(const QString &aSQLString);
    void BindValue(THolderList ValueList, TValueList ArgList);
    void WhoSearch(const QString &aSQLString);
    bool SearchResult(TValueList &ValList, int &ColumnCnt);
};

#endif // DBUNIT_H
