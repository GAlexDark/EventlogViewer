#include "DBUnit.h"
#include <QVariant>
#include <QSqlDriverPlugin>
#include <QSqlRecord>
#include <QSqlError>
#include <QtSql/QSqlError>
#include <QUuid>
#include "exceptions.h"
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QDir>
#include <QCryptographicHash>
#include <QTextStream>


#ifdef _SQLite
    //const QString DBDrv = "QSQLITE"; //SQLite ver 3
    const QString Vacuum_DB = "VACUUM;";
#else
    //const QString DBDrv = "QODBC"; //QODBC (include MS SQL Server)
    const QString Vacuum_DB = "VACUUM;";
    //const QString connectionTemplate = "DRIVER={SQL SERVER};SERVER=%1;DATABASE=%2;Trusted_Connection=Yes;";
#endif

/*
File path format:
QApplication::applicationDirPath()	D:/QtSDK/Projects/Test/test-build-desktop/debug
QDir::fromNativeSeparators()		D:/QtSDK/Projects/Test/test-build-desktop/debug
QDir::toNativeSeparators()			D:\QtSDK\Projects\Test\test-build-desktop\debug
*/
QString FilePathBuilder(const QString &aPath)
{
	QString path = QDir::fromNativeSeparators(aPath);
	if (!path.endsWith(QLatin1Char('/')))
		path += QLatin1Char('/');
	return path;
}

/*===============================================================*/

void DBEngine::_LoadDrv(const QString aDBDrv, const QString &aPluginName)
{
    m_DBPluginLoad = true;
    try {
        m_loader.setFileName(aPluginName);  // <--загрузка файла плагина
        if (!m_loader.load()) { //Loading SQL Driver failed
            throw EDBError(PL_ERROR_BAD_PLUGIN, 0,
                           PL_BadPluginFile.arg(m_loader.errorString()));
            }

        /* Если файл, который мы пытаемся загрузить, является подключаемым модулем Qt и имеет ту же саму версию Qt,
            какую имеет приложение,  */
        /* функция QPluginLoader::instance() возвратит указатель QObject*, ссылающийся на подключаемый модуль Qt. */
        QObject* object = m_loader.instance();
        if (object == NULL) { //Loading SQL Driver Instance failed
            throw EDBError(PL_ERROR_LOAD_PLUGIN, 0, PL_ErrorLoadPlugin);
            }

        QSqlDriverPlugin* plugin = qobject_cast<QSqlDriverPlugin*>(object);
        if (plugin == NULL) {
            throw EDBError(PL_ERROR_LOAD_PLUGIN, 0, PL_ErrorLoadPlugin);
            }

        m_driver = plugin->create(aDBDrv);
        if (m_driver == NULL) { //Loading DBDrv Driver Instance failed
            throw EDBError(PL_ERROR_LOAD_DRV, 0, PL_ErrorLoadDrvInst.arg(aDBDrv));
            }
    } catch (const EDBError &E) {
        switch (E.GetErrorCode()) {
            case PL_ERROR_BAD_PLUGIN:
                break;
            case PL_ERROR_LOAD_PLUGIN:
            case PL_ERROR_LOAD_DRV:
                m_loader.unload();
                m_driver = NULL;
                break;
        };
        m_DBPluginLoad = false;
        throw; //поднимаем ошибку наверх
    } catch (...) {
        m_DBPluginLoad = false;
        throw EDBError(PL_UNCNOWN_ERROR, 0, PL_UncnownError);
    }
}
void DBEngine::_UnloadDrv()
{
    if (m_DBPluginLoad) {
        m_driver = NULL;
        m_DBPluginLoad = false;
        m_loader.unload(); //??? а надо ли? буду тестить
        }
}

//void DBEngine::_DBLock()
//{
//	m_CS.lock();
//    m_IsDBLock = true;
//    return;
//}
//void DBEngine::_DBUnLock()
//{
//    if (m_IsDBLock) {
//        m_CS.unlock();
//        m_IsDBLock = false;
//        }
//    return;
//}

void DBEngine::_SQLExec(const QString &aSQLString)
{
    m_SQLRes.clear();    
    if (!m_SQLRes.exec (aSQLString)) {
		QSqlError error = m_SQLRes.lastError();
        throw EDBError(PL_ERROR_SQL_EXECUTE, error.number(),
                       PL_ErrorSQLExec.arg(error.text()));
        }
    return;
}
void DBEngine::_Prepare(const QString &aSQLString)
{
    m_SQLRes.clear();
    if (!m_SQLRes.prepare(aSQLString)) {
		QSqlError error = m_SQLRes.lastError();
        throw EDBError(PL_ERROR_SQL_EXECUTE, error.number(),
                       PL_ErrorSQLExec.arg(error.text()));
    }
    return;
}
void DBEngine::_BindValue(THolderList HolderList, TValueList ValList)
{
    THolderList::iterator itH = HolderList.begin();
    TValueList::iterator itV = ValList.begin();
    //9.06.2012 micro optimization
    THolderList::iterator itHE = HolderList.end();

    //while (itH != HolderList.end()) {
    while (itH != itHE) {
        m_SQLRes.bindValue(*itH, *itV);
        ++itH; ++itV;
        }

    if (!m_SQLRes.exec()) {
        //_DBUnLock();
		QSqlError error = m_SQLRes.lastError();
        throw EDBError(PL_ERROR_SQL_EXECUTE, error.number(),
                       PL_ErrorSQLExec.arg(error.text()));
        }
    //_DBUnLock();
    return;
}

/*===============================================================*/

DBEngine::DBEngine(const QString &aConnectionName)
    : m_driver(NULL), m_DBPluginLoad(false), m_IsInited(false), m_IsOpen(false), m_ConnectionName(aConnectionName),
      m_ErrorCode(0), m_IsDBLock(false), m_IsBeginTransaction(false), m_dbdir("")

{
    //m_IsConnected = false -- нет соединения
    //m_IsDBLock = false -- _cs.lock не вызывалась
    //m_IsBeginTransaction = false -- Транзакций не намечается
    //m_ErrorCode = 0;
    //m_DBPluginLoad = false; -- дрова БД не загружены
    //m_driver = NULL;

	if (m_ConnectionName.isEmpty() || m_ConnectionName.isNull()) {
        QUuid guid = QUuid::createUuid();
		m_ConnectionName = guid.toString();
        }
}
DBEngine::~DBEngine()
{
    DeInit();
}

/*===============================================================*/
// adbDir - путь к папке с файлами БД. может содержать или не содержать "/" в конце строки
// aFileName - имя файла БД, путь к которому задан в adbDir и с которой будет работать класс

void DBEngine::Init (const QString &aConnectionString, const QString &aPluginName)
{
    if (m_IsInited) //IsConnected
        return;

    if ((aConnectionString.isEmpty() || aConnectionString.isNull()) ||
       (aPluginName.isEmpty() || aPluginName.isNull())) {
            throw EDBError(PL_ERROR_DATA, 0, PL_DataError.arg("No details"));
            }

    QString ConnStr;
    try {
        if (aConnectionString.indexOf("QSQLITE;") == 0) {
                ConnStr = aConnectionString.mid(8);
            _LoadDrv("QSQLITE",QDir::fromNativeSeparators(aPluginName));
            }
        else
            if (aConnectionString.indexOf("QODBC;") == 0) {
                ConnStr = aConnectionString.mid(6);
                _LoadDrv("QODBC",QDir::fromNativeSeparators(aPluginName));
                }
            else throw EDBError(PL_ERROR_DATA,0,"Unknown sql driver ID");
    } catch (...) {
        throw;
    }

    m_dbdir = "";
    m_dbinstance = QSqlDatabase::addDatabase(m_driver, m_ConnectionName);
    m_IsInited = m_dbinstance.isValid ();
    if (!m_IsInited) { //Если DBDrv недоступен или не может быть загружен
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_LOAD_DRV, error.number(),
                        PL_ErrorLoadDrv.arg(error.databaseText()));
        }
    m_dbinstance.setDatabaseName(ConnStr);
    return;
}

void DBEngine::Open()
{
    if(m_IsOpen)
        return;

    m_IsOpen = m_dbinstance.open();
    if (!m_IsOpen) {
        QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_OPEN_DB, error.number(),
                        PL_ErrorOpenDBFile.arg(error.databaseText()));
        }

    m_SQLRes = QSqlQuery(m_dbinstance); // <-- единое связывание всех запросов
	//m_SQLRes.exec("PRAGMA synchronous = OFF;");
	//m_SQLRes.exec("PRAGMA temp_store = MEMORY;");
	//m_SQLRes.exec("PRAGMA default_cache_size = 7340031;");
	//m_SQLRes.exec("PRAGMA page_size = 1024;");
	//m_SQLRes.exec("PRAGMA cache_size = 7340031;");
	//m_SQLRes.exec("PRAGMA auto_vacuum = NONE;");
	//m_SQLRes.exec("PRAGMA journal_mode = MEMORY;");

    return;
}

void DBEngine::DeInit()
{
    if (m_IsInited) {
		try {
            Close();
            // код избавления от бага:
            // QSqlDatabasePrivate::removeDatabase connection is still in use, all queries will cease to work.
            QString qs;
            qs.append(QSqlDatabase::database().connectionName());
            QSqlDatabase::removeDatabase(qs);
            //конец кода
            m_IsInited = false;
            _UnloadDrv();
       } catch (...) {
            // ...
            QString qs;
            qs.append(QSqlDatabase::database().connectionName());
            QSqlDatabase::removeDatabase(qs);
            // ...
            m_IsInited = false;
            _UnloadDrv();
            throw;
            }
        }
    return;
}
void DBEngine::Close()
{
    if (m_IsOpen) {
        try {
            CommitTransaction();
            //_DBUnLock();
            m_SQLRes.finish(); //отцепляем все запросы от БД
            if (m_dbinstance.isValid() && m_dbinstance.isOpen()) {
                m_dbinstance.close ();
                }
            m_IsOpen = false;
       } catch (...) {
            //_DBUnLock();
            m_SQLRes.finish();
            if (m_dbinstance.isValid() && m_dbinstance.isOpen()) {
                m_dbinstance.close ();
                }
            m_IsOpen = false;
            throw;
            }
        }
    return;
}
/*===============================================================*/

void DBEngine::BeginTransaction()
{
	if (m_IsBeginTransaction)
        return;
	m_IsBeginTransaction = m_dbinstance.transaction ();
	if (!m_IsBeginTransaction) {
		QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_TRANSACTION, error.number (),
                        PL_ErrorTransaction.arg(error.databaseText()).arg(error.number ()).arg(PL_ERROR_TRANSACTION)); //<---***
        }
    return;
}
void DBEngine::CommitTransaction ()
{
	if (!m_IsBeginTransaction)
        return;
    QString sRollbackError;
    int iRollbackError;

	if (!m_dbinstance.commit()) {
        QSqlError error1 = m_dbinstance.lastError();
        //теретически rollback тут лишний - это должно выполняться на уровне управления операциями БД
        if (!m_dbinstance.rollback ()) {
            QSqlError error2 = m_dbinstance.lastError ();
            sRollbackError = error2.databaseText();
            iRollbackError = error2.number();
            }
        else {
            iRollbackError = 0;
            sRollbackError = "Rollback is success!" ;
            }
        throw EDBError(PL_ERROR_COMMIT, error1.number(),
                        PL_ErrorTransaction.arg(error1.databaseText()).arg(iRollbackError).arg(sRollbackError));
		}
    m_IsBeginTransaction = false;
    return;
}
void DBEngine::RollbackTransaction()
{
	if (!m_dbinstance.rollback ()){
		QSqlError error = m_dbinstance.lastError();
        throw EDBError(PL_ERROR_ROLLBACK, error.number(),
                       PL_ErrorTransaction.arg("See rollback status").arg(error.number()).arg(error.databaseText()));
		}
    m_IsBeginTransaction = false;
    return;
}

/*===============================================================*/

/*
QFileInfo::fileName         - test.sign.bak
QFileInfo::baseName         - test
QFileInfo::completeSuffix   - sign.bak
QFileInfo::completeBaseName - test.sign
QFileInfo::suffix           - bak
*/

// путь к файлу уже содержит "/" и сохранен внутри класса
// aFileName - имя файла БД, путь к которому сохранен внутри класса и хеш которого необходимо рассчитать

QString DBEngine::CalcFileHash(const QString& aFileName)
{
    if (aFileName.isEmpty() || aFileName.isNull()) {
            throw EDBError(PL_ERROR_DATA, 0, PL_DataError.arg("No details"));
        }
    QFile file(aFileName);

    if (!file.open(QIODevice::ReadOnly))
        throw EDBError(PL_ERROR_OPEN_FILE, 0,
                        PL_ErrorOpenFile.arg(aFileName).arg(file.errorString()));

	QByteArray buf = file.readAll();
    if (file.error() != QFile::NoError) {
        file.close();
        throw EDBError(PL_ERROR_LOAD_FILE, 0,
						   PL_ErrorLoadingFile.arg(aFileName).arg(file.errorString()));
        }
    file.close();

	QCryptographicHash _Hash(QCryptographicHash::Sha1);
    _Hash.addData(buf);

	return _Hash.result().toHex();
}
void DBEngine::SaveHashSumToFile(const QString& aFileName, const QString& aHashSum)
{
    if ((aFileName.isEmpty() || aFileName.isNull()) ||
       (aHashSum.isEmpty() || aHashSum.isNull())) {
            throw EDBError(PL_ERROR_DATA, 0,PL_DataError.arg("No details"));
        }

    QFileInfo fi(m_dbdir + aFileName);
    QFile file(m_dbdir + aFileName);

    if (file.exists())
    if (!file.remove())
        throw EDBError(PL_ERROR_DELETE_FILE, 0,
                           PL_ErrorDeleteFile.arg(fi.fileName()).arg(file.errorString()));
	if (!file.open(QIODevice::WriteOnly | QIODevice::Text))
        throw EDBError(PL_ERROR_OPEN_FILE, 0,
						PL_ErrorOpenFile.arg(fi.fileName()).arg(file.errorString()));

	QTextStream out(&file);
    out << aHashSum;
    file.close();
    return;
}
void DBEngine::LoadHashSumFromFile(const QString &aFileName, QString &aHashSum)
{
    if ((aFileName.isEmpty() || aFileName.isNull()) ||
        (aHashSum.isEmpty() || aHashSum.isNull())) {
            throw EDBError(PL_ERROR_DATA,0, PL_DataError.arg("No details"));
        }

    QFileInfo fi(m_dbdir + aFileName);
    QFile file(m_dbdir + aFileName);

	if (!file.exists())
        throw EDBError(PL_FILE_NOT_FIND, 0,
						PL_FileNotFind.arg(fi.fileName()));

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        throw EDBError(PL_ERROR_OPEN_FILE, 0,
						PL_ErrorOpenFile.arg(fi.fileName()).arg(file.errorString()));

	QTextStream in(&file);
    in >> aHashSum;
    file.close();
	return;
}

/*===============================================================*/

void DBEngine::BackupDB(const QString &aSource, const QString &aBackupPath)
{
    //1. проверяем наличие пути для бакапа
    //2. проверяем наличие файла для бекапирования
    //3. Бекап:
    //  3.1. сформировать имя файла бакапа
    //  3.2. удалить существующий бакап с этим именем и забекапить файл

    // -1-
	QDir dir(FilePathBuilder(aBackupPath));
	if (!dir.exists())
        throw EDBError(PL_PATH_NOT_FIND,0,PL_PathNotFind.arg(aBackupPath));

        // -2-
    QFileInfo fi(m_dbdir + aSource);
    QFile file(m_dbdir + aSource);
    if (!file.exists())
        throw EDBError(PL_FILE_NOT_FIND,0,PL_FileNotFind.arg(fi.fileName()));
    // -3.1-
    QDate date = QDate::currentDate();
    QString Backupname = DefBackupName.arg(fi.baseName()).arg(date.toString(DefDateFormat)).arg(DefBkpExt);
    // -3.2-
	QFile df(aBackupPath + QDir::separator() + Backupname);
    if (df.exists ())
            if (!df.remove ())
                throw EDBError(PL_ERROR_DELETE_FILE, 0,
                                           PL_ErrorDeleteFile.arg(Backupname).arg(df.errorString()));
    if (!file.copy(aBackupPath + Backupname))
            throw EDBError(PL_ERROR_COPY_FILE,0,PL_ErrorCopyFile.arg(fi.fileName()).arg(file.errorString()));

    return;
}
void DBEngine::RestoreDB(const QString &aBackupPath, const QString &aSource, const QDate &aDate)
{
    // 1. проверяем наличие пути
    // 2. проверяем наличие файла для восстановления
    // 3. ресторе:
    //  3.1. восстанавливаем нужное имя
    //  3.2. удаляем ненужный файл
    //  3.3. выполнение восстановления

    // -1-
	QDir dir(aBackupPath);
	if (!dir.exists(aBackupPath))
        throw EDBError(PL_PATH_NOT_FIND,0,PL_PathNotFind.arg(aBackupPath));
    // -2-
    QFileInfo fi(aSource);
    QString Backupname = aBackupPath + DefBackupName.arg(fi.baseName()).arg(aDate.toString(DefDateFormat)).arg(DefBkpExt);
    QFile file(Backupname);
        if (!file.exists())
            throw EDBError(PL_FILE_NOT_FIND,0,PL_FileNotFind.arg(fi.fileName()));
    // -3.1-
    QString newname = fi.baseName () + DefDBExt;
    // -3.2-
    QFile dbf(m_dbdir + newname);
    if (dbf.exists())
        if (!dbf.remove())
            throw EDBError(PL_ERROR_DELETE_FILE,0,
                                       PL_ErrorDeleteFile.arg(newname).arg(dbf.errorString()));
    // -3.3-
    if (!file.copy(m_dbdir + newname))
        throw EDBError(PL_ERROR_COPY_FILE,0,PL_ErrorCopyFile.arg(newname).arg(file.errorString()));
    return;
}

/*===============================================================*/

void DBEngine::_VacuumDB()
{
    try {
        _SQLExec(Vacuum_DB);
    } catch (...) {
        throw;
        }
    return;
}
void DBEngine::Execute(const QString &aSQLString)
{
    if (aSQLString.isEmpty() || aSQLString.isNull()) {
        throw EDBError(PL_ERROR_DATA,0,
                       PL_DataError.arg(aSQLString));
        }

    try {
        //_DBLock();
        _SQLExec(aSQLString);
        //_DBUnLock();
    } catch (...) {
        //_DBUnLock();
        throw;
        }
    return;
}
void DBEngine::PrepareInsert(const QString &aSQLString)
{
    if (aSQLString.isEmpty() || aSQLString.isNull()) {
        throw EDBError(PL_ERROR_DATA,0,
                       PL_DataError.arg(aSQLString));
        }
    try {
        //_DBLock();
        _Prepare(aSQLString);
    } catch (...) {
        //_DBUnLock();
        throw;
        }
    return;
}
void DBEngine::BindValue(THolderList HolderList, TValueList ValList)
{
    if (HolderList.isEmpty() || ValList.isEmpty()){
            //_DBUnLock();
            throw EDBError(PL_ERROR_DATA,0,
                           PL_DataError.arg("No data to bind"));
        }
    try {
        _BindValue(HolderList,ValList);
    } catch (...) {
        //_DBUnLock();
        throw;
        }
    //_DBUnLock();
    return;
}
void DBEngine::WhoSearch(const QString &aSQLString)
{
    if (aSQLString.isEmpty() || aSQLString.isNull()) {
        throw EDBError(PL_ERROR_DATA,0,
                       PL_DataError.arg(aSQLString));
        }
    try {
        //_DBLock();
        _SQLExec(aSQLString);
    } catch (...) {
        //_DBUnLock();
        throw;
        }
    return;
}
bool DBEngine::SearchResult(TValueList &ValList, int &ColumnCnt)
{
    ValList.clear();
    bool Next = m_SQLRes.next();    
    if (Next) {
        if (ColumnCnt == NO_COLUMNS) {
            ColumnCnt = m_SQLRes.record().count(); //получаем кол-во столбцов в ответе
            if (ColumnCnt == 0) {
                //_DBUnLock();
                QSqlError error = m_SQLRes.lastError();
                throw EDBError(PL_GET_DATA_ERROR,error.number(),
                               PL_GetDataError.arg(error.databaseText()));
                }
            } // (ColumnCnt == NO_COLUMNS)
        try {
            for (int i = 0; i < ColumnCnt; ++i) {
                ValList.append(m_SQLRes.value(i));
                }
        } catch (...) {
            //_DBUnLock();
            throw EDBError(PL_GET_DATA_ERROR,-1,"Error append data");
        }

        }
    else {
        //_DBUnLock();
        if (m_SQLRes.lastError().type() == QSqlError::NoError)
            ColumnCnt = END_OF_DATA;
        else {
            QSqlError error = m_SQLRes.lastError();
            throw EDBError(PL_GET_DATA_ERROR,error.number(),
                           PL_GetDataError.arg(error.databaseText()));
            }
        }
    return Next;
}
