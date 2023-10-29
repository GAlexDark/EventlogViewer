#include "cdrvloader.h"
#include "exceptions.h"
#include <QDir>
#include <QSqlDriverPlugin>

CDrvLoader::CDrvLoader(const QString &DBDriverName, const QString &DBDriverFileName): m_driver(NULL), m_IsLoad(false)
{
    qDebug() << "CDrvLoader::CDrvLoader(const QString &DBDriverName, const QString &DBDriverFileName)";
    if (DBDriverName.isEmpty() || DBDriverName.isNull() || DBDriverFileName.isEmpty() || DBDriverFileName.isNull())
        throw EDBError(0,0, "Empty string");

    _LoadDrv(DBDriverName, QDir::fromNativeSeparators(DBDriverFileName));
}

CDrvLoader::~CDrvLoader()
{
    qDebug() << "CDrvLoader::~CDrvLoader()";
    _UnloadDrv();
}

QSqlDriver* CDrvLoader::_LoadDrv(const QString &DBDriverName, const QString &DBDriverFileName)
{
    qDebug("QSqlDriver* CDrvLoader::_LoadDrv(const QString &aDBDrv, const QString &FileName)");
    try {
        m_loader.setFileName(DBDriverFileName);  // <--загрузка файла плагина
        m_IsLoad = m_loader.load();
        if (!m_IsLoad) { //Loading SQL Driver failed
            qDebug() << "[ERROR] " << PL_BadPluginFile.arg(m_loader.errorString());
            throw EDBError(PL_ERROR_BAD_PLUGIN, 0,
                           PL_BadPluginFile.arg(m_loader.errorString()));
            }

        /* Если файл, который мы пытаемся загрузить, является подключаемым модулем Qt и имеет ту же саму версию Qt,
            какую имеет приложение,  */
        /* функция QPluginLoader::instance() возвратит указатель QObject*, ссылающийся на подключаемый модуль Qt. */
        QObject* object = m_loader.instance();
            if (object == NULL) { //Loading SQL Driver Instance failed
                qDebug() << "[ERROR] " << "_loader.instance() " << PL_ErrorLoadPlugin;
                throw EDBError(PL_ERROR_LOAD_PLUGIN, 0, PL_ErrorLoadPlugin);
                }

        QSqlDriverPlugin* plugin = qobject_cast<QSqlDriverPlugin*>(object);
        if (plugin == NULL) {
            qDebug() << "qobject_cast<QSqlDriverPlugin*>(object) " << PL_ErrorLoadPlugin;
            throw EDBError(PL_ERROR_LOAD_PLUGIN, 0, PL_ErrorLoadPlugin);
            }

        m_driver = plugin->create(DBDriverName);
        if (m_driver == NULL) { //Loading DBDrv Driver Instance failed
            qDebug() << "plugin->create(aDBDrv) " << PL_ErrorLoadDrvInst.arg(DBDriverName);
            throw EDBError(PL_ERROR_LOAD_DRV, 0, PL_ErrorLoadDrvInst.arg(DBDriverName));
            }
    } catch (EDBError) {
        throw; //поднимаем ошибку наверх
    } catch (...) {
        throw EDBError(PL_UNCNOWN_ERROR, 0, PL_UncnownError);
    }
    return m_driver;
}

void CDrvLoader::_UnloadDrv()
{
    qDebug() << "void CDrvLoader::_UnloadDrv()";
    m_driver = NULL;
    if (m_IsLoad) {
        m_loader.unload();
        m_IsLoad = false;
        }
}

QSqlDriver* CDrvLoader::GetDrvInstanse(const QString &DBDriverName, const QString &DBDriverFileName)
{
    qDebug() << "QSqlDriver* CDrvLoader::GetDrvInstanse(const QString &aDBDrv, const QString &FileName)";
    if (DBDriverName.isEmpty() || DBDriverName.isNull() || DBDriverFileName.isEmpty() || DBDriverFileName.isNull())
        throw EDBError(0,0, "Empty string");

    return _LoadDrv(DBDriverName, QDir::fromNativeSeparators(DBDriverFileName));
}

QSqlDriver* CSQLiteLoader::GetDrvInstanse(const QString &DBDriverFileName)
{   
    qDebug() << "QSqlDriver* CSQLiteLoader::GetDrvInstanse(const QString &FileName)";
    return CDrvLoader::GetDrvInstanse("QSQLITE",DBDriverFileName);
}

QSqlDriver* CODBCLoader::GetDrvInstanse(const QString &DBDriverFileName)
{
    qDebug() << "QSqlDriver* CODBCLoader::GetDrvInstanse(const QString &FileName)";
    return CDrvLoader::GetDrvInstanse("QODBC", DBDriverFileName);
}

//-------------------------------------------------------------------------------------------------

QSqlDriver* CSQLDrvFactory::Get(const QString &DBDriverName, const QString &DBDriverFileName)
{
    QSqlDriver* buf = _find(DBDriverName);
    if (buf != 0)
        return buf;

    return _add(DBDriverName, DBDriverFileName);
}

QSqlDriver* CSQLDrvFactory::_find(const QString &DBDriverName)
{
    CDrvLoader *buf = 0;
    TDrvFab::iterator i = m_DrvFab.find(DBDriverName);
    if (i != m_DrvFab.end()) {
        buf = i.value();
        return buf->GetDrvInstanse();
    } else return 0;
}

CDrvLoader* CSQLDrvFactory::_findDrv(const QString &DBDriverName)
{
    TDrvFab::iterator i = m_DrvFab.find(DBDriverName);
    if (i != m_DrvFab.end()) {
        return i.value();
    } else return 0;
}

QSqlDriver* CSQLDrvFactory::_add(const QString &DBDriverName, const QString &DBDriverFileName)
{
    try {
        CDrvLoader* buf = new CDrvLoader(DBDriverName, DBDriverFileName);
        m_DrvFab.insert(DBDriverName, buf);

        return buf->GetDrvInstanse();
    } catch (...) {
        return 0;
    }
}

void CSQLDrvFactory::_delete(const QString &DBDriverName)
{
    CDrvLoader* buf = _findDrv(DBDriverName);
    delete buf; buf = 0;
    m_DrvFab.remove(DBDriverName);
}

void CSQLDrvFactory::_delete()
{
    // удаляем классы
    TDrvFab::iterator iEnd = m_DrvFab.end();
    for(TDrvFab::iterator i = m_DrvFab.begin(); i != iEnd; ++i)
        delete i.value();
}


