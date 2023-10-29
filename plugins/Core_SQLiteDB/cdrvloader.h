#ifndef CDRVLOADER_H
#define CDRVLOADER_H

#include <QPluginLoader>
#include <QSqlDriver>
#include <QDebug>
#include <QMap>



class CDrvLoader
{
public:
    CDrvLoader(): m_driver(NULL), m_IsLoad(false) { qDebug("CDrvLoader::CDrvLoader()") ;}
    CDrvLoader(const QString &DBDriverName, const QString &DBDriverFileName);
    virtual ~CDrvLoader();
    virtual QSqlDriver* GetDrvInstanse(const QString &DBDriverName, const QString &DBDriverFileName);
    virtual QSqlDriver* GetDrvInstanse() const { return m_driver; }

private:
    QPluginLoader       m_loader;
    QSqlDriver*         m_driver;
    bool                m_IsLoad;

    void        _UnloadDrv();
    QSqlDriver* _LoadDrv(const QString &DBDriverName, const QString &DBDriverFileName);
};

class CSQLiteLoader : public CDrvLoader
{
public:
    QSqlDriver* GetDrvInstanse(const QString &DBDriverFileName);
};

class CODBCLoader : public CDrvLoader
{
public:
    QSqlDriver* GetDrvInstanse(const QString &DBDriverFileName) ;
};

class CSQLDrvFactory
{
public:
//    CSQLDrvFactory();
    virtual ~CSQLDrvFactory() { _delete(); }
    QSqlDriver* Get(const QString &DBDriverName, const QString &DBDriverFileName);

private:
    typedef QMap<QString, CDrvLoader*> TDrvFab;
    TDrvFab    m_DrvFab; //сюда загружаем созданные экземпл€ры класса

    QSqlDriver* _find(const QString &DBDriverName);
    CDrvLoader* _findDrv(const QString &DBDriverName);
    QSqlDriver* _add(const QString &DBDriverName, const QString &DBDriverFileName);
    void _delete(const QString &DBDriverName);
    void _delete();
};

#endif // CDRVLOADER_H
